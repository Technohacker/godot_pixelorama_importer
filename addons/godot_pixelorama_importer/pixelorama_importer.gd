tool
extends EditorImportPlugin

func get_importer_name():
	return "com.technohacker.pixelorama"

func get_visible_name():
	return "Pixelorama Project"

func get_recognized_extensions():
	return ["pxo"]

# We save directly to stex because ImageTexture doesn't work for some reason
func get_save_extension():
	return "stex"

func get_resource_type():
	return "StreamTexture"

func get_import_options(preset):
	return []

func get_preset_count():
	return 0

func import(source_file, save_path, options, r_platform_variants, r_gen_files):
	"""
	Main import function. Reads the Pixelorama project and extracts the PNG image from it
	"""
	
	# Open the Piskel project file
	var file = File.new()
	var err = file.open_compressed(source_file, File.READ, File.COMPRESSION_ZSTD)
	if err != OK:
		file.open(source_file, File.READ)

	# Parse it as JSON
	var text = file.get_line()
	var json = JSON.parse(text)

	if json.error != OK:
		printerr("JSON Parse Error")
		return json.error

	var project = json.result;

	# Make sure it's a JSON Object
	if typeof(project) != TYPE_DICTIONARY:
		printerr("Invalid Piskel project file")
		return ERR_FILE_UNRECOGNIZED;

	# Load the cel dimensions and frame count
	var size = Vector2(project.size_x, project.size_y)
	var frame_count = project.frames.size()

	# Prepare the spritesheet image
	var spritesheet = Image.new()
	spritesheet.create(size.x * frame_count, size.y, false, Image.FORMAT_RGBA8)

	for i in range(project.frames.size()):
		var frame = project.frames[i]
		
		# Prepare the frame image
		var frame_img: Image = null
		for cel in frame.cels:
			# Load the cel image
			var cel_img = Image.new()
			cel_img.create_from_data(size.x, size.y, false, Image.FORMAT_RGBA8, file.get_buffer(size.x * size.y * 4))

			if frame_img == null:
				frame_img = cel_img
			else:
				# Overlay each Cel on top of each other
				frame_img.blend_rect(cel_img, Rect2(Vector2.ZERO, size), Vector2.ZERO)

		# Add to the spritesheet
		spritesheet.blit_rect(frame_img, Rect2(Vector2.ZERO, size), Vector2((size.x * i), 0))

	if err:
		return err

	return save_stex(spritesheet, save_path)

# Taken from https://github.com/lifelike/godot-animator-import
func save_stex(image, save_path):
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
