tool
extends EditorPlugin

var import_plugins

func _enter_tree():
	import_plugins = [
		preload("single_image_import.gd").new(),
		preload("spriteframes_import.gd").new(get_editor_interface())
	]
	for plugin in import_plugins:
		add_import_plugin(plugin)

func _exit_tree():
	for plugin in import_plugins:
		remove_import_plugin(plugin)
	import_plugins = null
