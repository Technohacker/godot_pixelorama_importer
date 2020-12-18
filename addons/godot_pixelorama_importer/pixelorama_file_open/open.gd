extends EditorInspectorPlugin

var tex:StreamTexture
var user_config_req:bool = true
var pixel_path:String

var ctl

func _init():
	#load config file settings
	var cfg = ConfigFile.new()
	var err = cfg.load("user://pixel_plugin.ini")
	if err == ERR_FILE_NOT_FOUND:
		cfg.save("user://pixel_plugin.ini")
		err = cfg.load("user://pixel_plugin.ini")
	if err == OK:
		if cfg.has_section_key("location","pixelorama"):
			pixel_path = cfg.get_value("location","pixelorama")
			user_config_req = false
	else:
		print("Error loading Plugin \n", err)

func can_handle(object):
	if object is StreamTexture:
		tex = object
		return true
	return false

func parse_end():
	ctl = preload("inspector_menu.tscn").instance()
	var btn = ctl.get_node("VBoxContainer/OpenButton")
	btn.connect("pressed",self,"open_btn_pressed")
	btn.disabled = user_config_req
	var win = ctl.get_node("WindowDialog")
	win.connect("confirmed",self,"_folder_selected")
	ctl.get_node("VBoxContainer/ConfigButton").connect("pressed",self,"_on_ConfigButton_pressed", [win])
	add_custom_control(ctl)

func open_btn_pressed():
	var tex_path = ProjectSettings.globalize_path(tex.resource_path)
	var extension = ""
	match (OS.get_name()):
		"X11": 
			extension = ".x86_64"
		"Windows":
			extension = ".exe"
		_:
			push_warning("PixeloramaPlugin: Unsupported Platform")
			return

	var f:File = File.new()
	if !f.file_exists(pixel_path+"/Pixelorama"+ extension):
		push_error("PixeloramaPlugin: Pixelorama executable not found. Check config")
		return
	if !f.file_exists(pixel_path+"/Pixelorama"+ ".pck"):
		push_error("PixeloramaPlugin: Pixelorama.pck not found. Check config")
		return
	OS.execute(pixel_path+"/Pixelorama"+extension,["--path", pixel_path + "/", "--main-pack", "Pixelorama.pck", tex_path], false)

func _on_ConfigButton_pressed(win):
	win.get_node("MarginContainer/VBoxContainer/HBoxContainer/TextEdit").text = pixel_path
	win.popup_centered()

func _folder_selected(folder_path:String):
	pixel_path = folder_path
	var cfg = ConfigFile.new()
	var err = cfg.load("user://pixel_plugin.ini")
	if err == OK:
		cfg.set_value("location","pixelorama",pixel_path)
		cfg.save("user://pixel_plugin.ini")
		pass
	user_config_req = false
