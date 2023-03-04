@tool
extends EditorImportPlugin

const VISIBLE_NAME := "Sprite2D & AnimationPlayer"

var editor: EditorInterface


func _init(editor_interface):
	editor = editor_interface


func _get_importer_name() -> String:
	return "com.technohacker.pixelorama.animationplayer"


func _get_visible_name() -> String:
	return VISIBLE_NAME


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["pxo"])


func _get_save_extension() -> String:
	return "tscn"


func _get_resource_type() -> String:
	return "PackedScene"


func _get_import_order() -> int:
	return 1


func _get_import_options(path: String, _preset_index: int) -> Array:
	var default_scale: Vector2 = ProjectSettings.get_setting("pixelorama/default_scale")
	var default_external_save: bool = ProjectSettings.get_setting(
		"pixelorama/default_animation_external_save"
	)
	var default_external_save_path: String = ProjectSettings.get_setting(
		"pixelorama/default_animation_external_save_path"
	)

	if default_external_save_path == "":
		default_external_save_path = path.get_base_dir()

	return [
		{"name": "Sprite2D", "default_value": false, "usage": PROPERTY_USAGE_GROUP},
		{"name": "scale", "default_value": default_scale},
		{"name": "Animation", "default_value": false, "usage": PROPERTY_USAGE_GROUP},
		{
			"name": "external_save",
			"default_value": default_external_save,
			"usage": PROPERTY_USAGE_DEFAULT | PROPERTY_USAGE_UPDATE_ALL_IF_MODIFIED
		},
		{
			"name": "external_save_path",
			"default_value": default_external_save_path,
			"property_hint": PROPERTY_HINT_DIR
		},
	]


func _get_option_visibility(_path: String, option_name: StringName, options: Dictionary) -> bool:
	if option_name == "external_save_path" and options.has("external_save"):
		return options["external_save"]
	return true


func _get_preset_count() -> int:
	return 0


func _get_priority() -> float:
	var default_import_type: String = ProjectSettings.get_setting("pixelorama/default_import_type")
	if default_import_type == _get_visible_name():
		return 2.0
	return 1.0


func _import(
	source_file: String,
	save_path: String,
	options: Dictionary,
	_platform_variants: Array[String],
	gen_files: Array[String]
) -> Error:
	"""
	Main import function. Reads the Pixelorama project and creates the animation player resource
	"""

	var spritesheet_path = "%s.spritesheet" % [save_path]

	# Open the project
	var load_res = preload("./util/read_pxo_file.gd").read_pxo_file(source_file, spritesheet_path)

	if load_res.error != OK:
		printerr("Project Load Error")
		return load_res.error

	var project = load_res.value

	# Path to the spritesheet
	spritesheet_path = "%s.ctex" % spritesheet_path
	gen_files.push_back(spritesheet_path)

	# Load the spritesheet as a .stex
	var spritesheet_tex = CompressedTexture2D.new()
	spritesheet_tex.load(spritesheet_path)

	# create the Sprite
	var sprite := Sprite2D.new()
	sprite.texture = spritesheet_tex
	sprite.name = source_file.get_file().get_basename()
	sprite.apply_scale(options.scale)
	sprite.hframes = project.frames.size()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	# create the AnimationPlayer
	var animation_player := AnimationPlayer.new()
	sprite.add_child(animation_player)
	animation_player.name = "AnimationPlayer"
	animation_player.owner = sprite  # for PackedScene

	# add some default animations
	if project.tags.size() == 0:
		# No tags, put all in default
		project.tags.append({"name": "default", "from": 1, "to": project.frames.size()})
	# puts a RESET track
	project.tags.append({"name": "RESET", "from": 1, "to": 1})

	var animation_library: AnimationLibrary
	var animation_library_path: String
	if options.external_save:
		var base_dir = options.external_save_path
		if base_dir == "":
			base_dir = source_file.get_file().get_base_dir()
		animation_library_path = (
			"%s%s-animations.tres"
			% [options.external_save_path, source_file.get_file().get_basename()]
		)
		if FileAccess.file_exists(animation_library_path):
			# in case the AnimationLibrary is already save, try to load it
			animation_library = load(animation_library_path)
		else:
			animation_library = AnimationLibrary.new()
			animation_library.resource_path = animation_library_path
	else:
		animation_library = AnimationLibrary.new()
	animation_player.add_animation_library("", animation_library)

	# import all animations
	for tag in project.tags:
		var animation: Animation
		if animation_library.has_animation(tag.name):
			animation = animation_library.get_animation(tag.name)
		else:
			animation = Animation.new()
			animation_library.add_animation(tag.name, animation)

		var track_index := animation.find_track(".:frame", Animation.TYPE_VALUE)
		if track_index != -1:
			# track exist, remove it to add a fresh one
			animation.remove_track(track_index)

		# add the track for the frame
		track_index = animation.add_track(Animation.TYPE_VALUE)
		animation.track_set_path(track_index, ".:frame")
		animation.track_set_interpolation_loop_wrap(track_index, false)

		# insert the new animation keys
		var time := 0.0
		for frame in range(tag.from - 1, tag.to):
			animation.track_insert_key(track_index, time, frame)
			time += 1.0 / (project.fps / project.frames[frame].duration)

		# loop handling
		if (
			tag.name.begins_with("loop")
			or tag.name.begins_with("cycle")
			or tag.name.ends_with("loop")
			or tag.name.ends_with("cycle")
		):
			animation.loop_mode = Animation.LOOP_LINEAR

		# update/set the length
		animation.length = time

	var err: int  # Error enum
	if options.external_save:
		err = ResourceSaver.save(animation_library, animation_library_path)
		if err != OK:
			printerr("Error saving AnimationLibrary: error %s" % [err])
			return err
		gen_files.push_back(animation_library_path)

	var scene = PackedScene.new()
	err = scene.pack(sprite)
	if err != OK:
		printerr("Error creating PackedScene")
		return err

	var packed_scene_path = "%s.%s" % [save_path, _get_save_extension()]
	err = ResourceSaver.save(scene, packed_scene_path)
	if err != OK:
		printerr("Error saving PackedScene")
		return err
	gen_files.push_back(packed_scene_path)

	return OK
