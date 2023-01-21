tool
extends EditorPlugin

var editor_settings := get_editor_interface().get_editor_settings()

var import_plugins

func handles(object: Object) -> bool:
	# Find .pxo files
	if object is Resource && (object as Resource).resource_path.ends_with(".pxo"):
		return true

	return false

func edit(object: Object) -> void:
	# Safeguard
	if object is Resource && (object as Resource).resource_path.ends_with(".pxo"):
		if editor_settings.get_setting("pixelorama/path") == "":
			var popup = AcceptDialog.new()
			popup.window_title = "No Pixelorama Binary found!"
			popup.dialog_text = "Specify the path to the binary in the Editor Settings (Editor > Editor Settings...) under Pixelorama > Path"
			popup.popup_exclusive = true
			popup.set_as_minsize()

			get_editor_interface().get_base_control().add_child(popup)
			popup.popup_centered_minsize()
			
			yield(popup, "confirmed")
			popup.queue_free()
			return

		var file = File.new()
		var path = editor_settings.get_setting("pixelorama/path")
		if OS.get_name() == "OSX":
			path += "/Contents/MacOS/Pixelorama"

		if file.open(path, File.READ):
			push_error("Pixelorama binary could not be found")
			return

		OS.execute(path, [ProjectSettings.globalize_path(object.resource_path)], false)

func _enter_tree() -> void:
	var property_info = {
		"name": "pixelorama/path",
		"type": TYPE_STRING,
	}
	
	# Set some sane default paths for each OS and their File Selectors
	match OS.get_name():
		"Windows":
			property_info["hint"] = PROPERTY_HINT_GLOBAL_FILE
			property_info["hint_string"] = "*.exe"
		"OSX":
			property_info["hint"] = PROPERTY_HINT_GLOBAL_DIR
			property_info["hint_string"] = "*.app"
		"X11":
			property_info["hint"] = PROPERTY_HINT_GLOBAL_FILE
			property_info["hint_string"] = "*.x86_64"

	# If there isn't a property for the path yet, use an empty string
	if !editor_settings.has_setting("pixelorama/path"):
		editor_settings.set_setting("pixelorama/path", "")

	editor_settings.add_property_info(property_info)

	import_plugins = [
		preload("single_image_import.gd").new(),
		preload("spriteframes_import.gd").new(get_editor_interface())
	]
	for plugin in import_plugins:
		add_import_plugin(plugin)

func _exit_tree() -> void:
	for plugin in import_plugins:
		remove_import_plugin(plugin)
	import_plugins = null
