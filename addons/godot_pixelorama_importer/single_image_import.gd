@tool
extends EditorImportPlugin


func _get_importer_name() -> String:
	return "com.technohacker.pixelorama"


func _get_visible_name() -> String:
	return "Single Image"


func _get_recognized_extensions() -> PackedStringArray:
	return PackedStringArray(["pxo"])


# We save directly to stex because ImageTexture doesn't work for some reason
func _get_save_extension() -> String:
	return "ctex"


func _get_resource_type() -> String:
	return "CompressedTexture2D"


func _get_priority() -> float:
	return 1.0


func _get_import_order() -> int:
	return 1


func _get_import_options(_path: String, _preset_index: int) -> Array[Dictionary]:
	return []


func _get_option_visibility(_path: String, _option_name: StringName, _options: Dictionary) -> bool:
	return true


func _get_preset_count() -> int:
	return 0


func _import(
	source_file: String,
	save_path: String,
	_options: Dictionary,
	_platform_variants: Array[String],
	_gen_files: Array[String]
) -> int:
	"""
	Main import function. Reads the Pixelorama project and extracts the PNG image from it
	"""

	# Open the project
	var load_res = preload("./util/read_pxo_file.gd").read_pxo_file(source_file, save_path)

	return load_res.error
