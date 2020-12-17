tool
extends EditorPlugin

var import_plugins

var open_plugin


func _enter_tree():
	import_plugins = [
		preload("single_image_import.gd").new(),
		preload("spriteframes_import.gd").new(get_editor_interface())
	]
	open_plugin = preload("pixelorama_file_open/open.gd").new()
	for plugin in import_plugins:
		add_import_plugin(plugin)
	add_inspector_plugin(open_plugin)

func _exit_tree():
	remove_inspector_plugin(open_plugin)
	for plugin in import_plugins:
		remove_import_plugin(plugin)
	import_plugins = null
