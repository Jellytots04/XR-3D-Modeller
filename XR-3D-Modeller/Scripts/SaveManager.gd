extends Node

const PACKAGE_NAME = "com.jello.polymesh"
const SAVE_PATH = "/sdcard/Android/data/" + PACKAGE_NAME + "/files/saves/"

func save_scene(file_name):
	var clean_name = file_name.replace(" ", "_")
	DirAccess.make_dir_recursive_absolute(SAVE_PATH)
	var save = PackedScene.new()
	save.pack(get_tree().current_scene)
	ResourceSaver.save(save, SAVE_PATH + clean_name + ".scn")
	WorldOptions.current_file_name = clean_name
	WorldOptions.is_saved = true
	print("Scene saved as : ", clean_name)
