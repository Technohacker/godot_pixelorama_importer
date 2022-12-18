extends Node

const Result = preload("./Result.gd")


static func read_pxo_file(source_file: String, image_save_path: String):
	var result = Result.new()

	# Open the Pixelorama project file
	var file = FileAccess.open_compressed(source_file, FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if FileAccess.get_open_error() != OK:
		file = FileAccess.open(source_file, FileAccess.READ)

	# Parse it as JSON
	var text = file.get_line()
	var test_json_conv = JSON.new()
	var json_error = test_json_conv.parse(text)

	if json_error != OK:
		printerr("JSON Parse Error")
		result.error = json_error
		return result

	var project = test_json_conv.get_data()

	# Make sure it's a JSON Object
	if typeof(project) != TYPE_DICTIONARY:
		printerr("Invalid Pixelorama project file")
		result.error = ERR_FILE_UNRECOGNIZED
		return result

	# Load the cel dimensions and frame count
	var size = Vector2(project.size_x, project.size_y)
	var frame_count = project.frames.size()

	# Prepare the spritesheet image
	var spritesheet = Image.create(size.x * frame_count, size.y, false, Image.FORMAT_RGBA8)

	var cel_data_size: int = size.x * size.y * 4

	for i in range(frame_count):
		var frame = project.frames[i]

		# Prepare the frame image
		var frame_img: Image = null
		var layer := 0
		for cel in frame.cels:
			var opacity: float = cel.opacity

			if project.layers[layer].visible and opacity > 0.0:
				# Load the cel image
				var cel_img = (
					Image
					. create_from_data(
						size.x, size.y, false, Image.FORMAT_RGBA8, file.get_buffer(cel_data_size)
					)
				)

				if opacity < 1.0:
					for x in range(size.x):
						for y in range(size.y):
							var color := cel_img.get_pixel(x, y)
							color.a *= opacity
							cel_img.set_pixel(x, y, color)

				if frame_img == null:
					frame_img = cel_img
				else:
					# Overlay each Cel on top of each other
					frame_img.blend_rect(cel_img, Rect2(Vector2.ZERO, size), Vector2.ZERO)
			else:
				# Skip this cel's data
				file.seek(file.get_position() + cel_data_size)

			layer += 1

		if frame_img != null:
			# Add to the spritesheet
			spritesheet.blit_rect(frame_img, Rect2(Vector2.ZERO, size), Vector2(size.x * i, 0))

	save_ctex(spritesheet, image_save_path)
	result.value = project
	result.error = OK

	return result


# Based on CompressedTexture2D::_load_data from
# https://github.com/godotengine/godot/blob/master/scene/resources/texture.cpp
static func save_ctex(image, save_path: String):
	var tmpwebp = "%s-tmp.webp" % [save_path]
	image.save_webp(tmpwebp)  # not quite sure, but the png import that I tested was in webp

	var webpf = FileAccess.open(tmpwebp, FileAccess.READ)
	var webplen = webpf.get_length()
	var webpdata = webpf.get_buffer(webplen)
	webpf = null  # setting null will close the file

	var dir := DirAccess.open(tmpwebp.get_base_dir())
	dir.remove(tmpwebp.get_file())

	var ctexf = FileAccess.open("%s.ctex" % [save_path], FileAccess.WRITE)
	ctexf.store_8(0x47)  # G
	ctexf.store_8(0x53)  # S
	ctexf.store_8(0x54)  # T
	ctexf.store_8(0x32)  # 2
	ctexf.store_32(0x01)  # FORMAT_VERSION
	ctexf.store_32(image.get_width())
	ctexf.store_32(image.get_height())
	ctexf.store_32(0xD000000)  # data format (?)
	ctexf.store_32(0xFFFFFFFF)  # mipmap_limit
	ctexf.store_32(0x0)  # reserved
	ctexf.store_32(0x0)  # reserved
	ctexf.store_32(0x0)  # reserved
	ctexf.store_32(0x02)  # data format (WEBP, it's DataFormat enum but not available in gdscript)
	ctexf.store_16(image.get_width())  # w
	ctexf.store_16(image.get_height())  # h
	ctexf.store_32(0x00)  # mipmaps
	ctexf.store_32(Image.FORMAT_RGBA8)  # format
	ctexf.store_32(webplen)  # webp length
	ctexf.store_buffer(webpdata)
	ctexf = null  # setting null will close the file

	print("ctex saved")

	return OK
