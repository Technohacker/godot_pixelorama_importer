@tool
extends EditorImportPlugin

var editor: EditorInterface


func _init(editor_interface: EditorInterface):
	editor = editor_interface


func _get_importer_name() -> String:
	return "com.technohacker.pixelorama.spriteframe"


func _get_visible_name() -> String:
	return "SpriteFrames"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["pxo"])


# We save directly to ctex because ImageTexture doesn't work for some reason
func _get_save_extension() -> String:
	return "tres"


func _get_resource_type() -> String:
	return "SpriteFrames"


func _get_priority() -> float:
	return 1.0


func _get_import_order() -> int:
	return 1


func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return [{"name": "animation_fps", "default_value": 6}]


func _get_option_visibility(_path: String, _option_name: StringName, _options: Dictionary) -> bool:
	return true


func _get_preset_count() -> int:
	return 0


func _import(
	source_file: String,
	save_path: String,
	options: Dictionary,
	_platform_variants: Array[String],
	gen_files: Array[String]
) -> int:
	"""
	Main import function. Reads the Pixelorama project and creates the SpriteFrames resource
	"""

	var spritesheet_path = "%s.spritesheet" % [save_path]

	# Open the project
	var load_res = preload("./util/read_pxo_file.gd").read_pxo_file(source_file, spritesheet_path)

	if load_res.error != OK:
		printerr("Project Load Error")
		return load_res.error

	var project = load_res.value

	# Note the spritesheet
	spritesheet_path = "%s.ctex" % spritesheet_path
	gen_files.push_back(spritesheet_path)

	# Load the spritesheet as a .ctex
	var spritesheet_tex = CompressedTexture2D.new()
	spritesheet_tex.load(spritesheet_path)

	# Create the frames
	var frame_size = Vector2(project.size_x, project.size_y)

	var frames = SpriteFrames.new()
	if project.tags.size() == 0:
		# No tags, put all in default
		project.tags.append({"name": "default", "from": 1, "to": project.frames.size()})
	else:
		# Has tags, delete the default
		frames.remove_animation("default")

	for tag in project.tags:
		frames.add_animation(tag.name)
		frames.set_animation_speed(tag.name, options.animation_fps)

		for frame in range(tag.from, tag.to + 1):
			var image_rect := Rect2i(Vector2((frame - 1) * frame_size.x, 0), frame_size)
			var image := Image.new()
			image = spritesheet_tex.get_image().get_region(image_rect)
			var image_texture := ImageTexture.create_from_image(image)  #,0
			frames.add_frame(tag.name, image_texture)

	var err = ResourceSaver.save(frames, "%s.%s" % [save_path, _get_save_extension()])

	if err != OK:
		printerr("Error saving SpriteFrames")
		return err

	return OK
