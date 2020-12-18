tool
extends WindowDialog

signal confirmed 
var folder_path = ""

func _on_browse_btn_pressed():
	$FileDialog.popup_centered()

func confirm():
	folder_path = $MarginContainer/VBoxContainer/HBoxContainer/TextEdit.text
	emit_signal("confirmed",folder_path)
	hide()

func _on_FileDialog_dir_selected(dir):
	$MarginContainer/VBoxContainer/HBoxContainer/TextEdit.text = dir
	folder_path = dir

