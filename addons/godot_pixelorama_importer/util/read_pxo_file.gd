extends Node

const Result = preload("./Result.gd")

static func read_pxo_file(source_file: String, image_save_path: String):
	var result = Result.new()

	# Open the Pixelorama project file
	var file = File.new()
	var err = file.open_compressed(source_file, File.READ, File.COMPRESSION_ZSTD)
	if err != OK:
		file.open(source_file, File.READ)

	# Parse it as JSON
	var text = file.get_line()
	var json = JSON.parse(text)

	if json.error != OK:
		printerr("JSON Parse Error")
		result.error = json.error
		return result

	var project = json.result;

	# Make sure it's a JSON Object
	if typeof(project) != TYPE_DICTIONARY:
		printerr("Invalid Pixelorama project file")
		result.error = ERR_FILE_UNRECOGNIZED;
		return result;

	# Load the cel dimensions and frame count
	var size = Vector2(project.size_x, project.size_y)
	var frame_count = project.frames.size()

	# Prepare the spritesheet image
	var spritesheet = Image.new()
	spritesheet.create(size.x * frame_count, size.y, false, Image.FORMAT_RGBA8)

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
				var cel_img := Image.new()
				cel_img.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, file.get_buffer(cel_data_size))

				if opacity < 1.0:
					cel_img.lock()
					for x in range(size.x):
						for y in range(size.y):
							var color := cel_img.get_pixel(x, y)
							color.a *= opacity
							cel_img.set_pixel(x, y, color)
					cel_img.unlock()

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
			spritesheet.blit_rect(frame_img, Rect2(Vector2.ZERO, size), Vector2((size.x * i), 0))

	save_stex(spritesheet, image_save_path)
	result.value = project
	result.error = OK

	return result

# Taken from https://github.com/lifelike/godot-animator-import
static func save_stex(image, save_path):
	var tmppng = "%s-tmp.png" % [save_path]
	image.save_png(tmppng)
	var pngf = File.new()
	pngf.open(tmppng, File.READ)
	var pnglen = pngf.get_len()
	var pngdata = pngf.get_buffer(pnglen)
	pngf.close()
	Directory.new().remove(tmppng)

	var stexf = File.new()
	stexf.open("%s.stex" % [save_path], File.WRITE)
	stexf.store_8(0x47) # G
	stexf.store_8(0x44) # D
	stexf.store_8(0x53) # S
	stexf.store_8(0x54) # T
	stexf.store_32(image.get_width())
	stexf.store_32(image.get_height())
	stexf.store_32(0) # flags: Disable all of it as we're dealing with pixel-perfect images
	stexf.store_32(0x07100000) # data format
	stexf.store_32(1) # nr mipmaps
	stexf.store_32(pnglen + 6)
	stexf.store_8(0x50) # P
	stexf.store_8(0x4e) # N
	stexf.store_8(0x47) # G
	stexf.store_8(0x20) # space
	stexf.store_buffer(pngdata)
	stexf.close()

	print("stex saved")

	return OK
