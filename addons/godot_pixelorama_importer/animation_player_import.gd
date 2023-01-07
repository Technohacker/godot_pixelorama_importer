tool
extends EditorImportPlugin

var editor: EditorInterface


func _init(editor_interface):
	editor = editor_interface


func get_importer_name():
	return "com.technohacker.pixelorama.animationplayer"


func get_visible_name():
	return "Sprite & AnimationPlayer"


func get_recognized_extensions():
	return ["pxo"]


# We save directly to stex because ImageTexture doesn't work for some reason
func get_save_extension():
	return "tscn"


func get_resource_type():
	return "PackedScene"


func get_import_options(_preset):
	var default_scale: Vector2 = ProjectSettings.get_setting("pixelorama/default_scale")
	var default_external_save: bool = ProjectSettings.get_setting(
		"pixelorama/default_external_save"
	)
	var default_external_save_path: String = ProjectSettings.get_setting(
		"pixelorama/default_external_save_path"
	)

	return [
		{"name": "Sprite2D", "default_value": false, "usage": PROPERTY_USAGE_GROUP},
		{"name": "scale", "default_value": default_scale},
		{"name": "Animation", "default_value": false, "usage": PROPERTY_USAGE_GROUP},
		# 65536 = PROPERTY_USAGE_UPDATE_ALL_IF_MODIFIED, but not exported in GDscript.
		{
			"name": "external_save",
			"default_value": default_external_save,
			"usage": PROPERTY_USAGE_DEFAULT | 65536
		},
		{
			"name": "external_save_path",
			"default_value": default_external_save_path,
			"property_hint": PROPERTY_HINT_DIR
		},
	]


func get_option_visibility(option, options):
	if option == "external_save_path" and options.has("external_save"):
		return options["external_save"]
	return true


func get_preset_count():
	return 0


func import(source_file, save_path, options, _r_platform_variants, gen_files):
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

	var base_animation_path: String = options.external_save_path
	if base_animation_path == "" and options.external_save:
		base_animation_path = source_file.get_base_dir() + source_file.get_file().get_basename()
		var directory = Directory.new()
		if not directory.dir_exists(base_animation_path):
			var tmp = directory.make_dir(base_animation_path)
		base_animation_path = base_animation_path + "/"

	# Note the spritesheet
	spritesheet_path = "%s.stex" % spritesheet_path
	gen_files.push_back(spritesheet_path)

	# Load the spritesheet as a .stex
	var spritesheet_tex = StreamTexture.new()
	spritesheet_tex.load(spritesheet_path)

	# create the Sprite
	var sprite := Sprite.new()
	sprite.texture = spritesheet_tex
	sprite.name = source_file.get_file().get_basename()
	sprite.apply_scale(options.scale)
	sprite.hframes = project.frames.size()

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

	var err: int  # Error enum
	# import all animations
	for tag in project.tags:
		var animation: Animation
		var animation_path: String
		if options.external_save:
			# in case the animation is already save, try to load it
			animation_path = "%s/%s.tres" % [base_animation_path, tag.name]
			var file = File.new()
			if file.file_exists(animation_path):
				animation = load(animation_path)
			else:
				animation = Animation.new()
				animation.resource_path = animation_path
		else:
			animation = Animation.new()
		animation_player.add_animation(tag.name, animation)

		var track_index := animation.find_track(".:frame")
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
			animation.loop = true

		# update/set the length
		animation.length = time

		if options.external_save:
			err = ResourceSaver.save(animation_path, animation)
			if err != OK:
				printerr("Error saving Animation %s: error %s" % [tag.name, err])
				return err
			gen_files.push_back(animation_path)

	var scene = PackedScene.new()
	err = scene.pack(sprite)
	if err != OK:
		printerr("Error creating PackedScene")
		return err

	var packed_scene_path = "%s.%s" % [save_path, get_save_extension()]
	err = ResourceSaver.save(packed_scene_path, scene)
	if err != OK:
		printerr("Error saving PackedScene")
		return err
	gen_files.push_back(packed_scene_path)

	editor.get_inspector().refresh()
	return OK
