tool
extends EditorImportPlugin

var editor: EditorInterface

func _init(editor_interface):
	editor = editor_interface

func get_importer_name():
	return "com.technohacker.pixelorama.spriteframe"

func get_visible_name():
	return "SpriteFrames"

func get_recognized_extensions():
	return ["pxo"]

# We save directly to stex because ImageTexture doesn't work for some reason
func get_save_extension():
	return "tres"

func get_resource_type():
	return "SpriteFrames"

func get_import_options(preset):
	return [
		{"name": "animation_fps", "default_value": 6}
	]

func get_option_visibility(option, options):
	return true

func get_preset_count():
	return 0

func import(source_file, save_path, options, r_platform_variants, r_gen_files):
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
	spritesheet_path = "%s.stex" % spritesheet_path
	r_gen_files.push_back(spritesheet_path)

	# Load the spritesheet as a .stex
	var spritesheet_tex = StreamTexture.new()
	spritesheet_tex.load(spritesheet_path)

	# Create the frames
	var frame_size = Vector2(project.size_x, project.size_y)

	var frames = SpriteFrames.new()
	if project.tags.size() == 0:
		# No tags, put all in default
		project.tags.append({
			"name": "default",
			"from": 1,
			"to": project.frames.size()
		})
	else:
		# Has tags, delete the default
		frames.remove_animation("default")

	for tag in project.tags:
		frames.add_animation(tag.name)
		frames.set_animation_speed(tag.name, options.animation_fps)

		for frame in range(tag.from, tag.to + 1):
			var atlas = AtlasTexture.new()
			atlas.atlas = spritesheet_tex
			atlas.region = Rect2(Vector2((frame - 1) * frame_size.x, 0), frame_size)
			frames.add_frame(tag.name, atlas)

	var err = ResourceSaver.save("%s.%s" % [save_path, get_save_extension()], frames)

	if err != OK:
		printerr("Error saving SpriteFrames")
		return err

	editor.get_inspector().refresh()
	return OK
