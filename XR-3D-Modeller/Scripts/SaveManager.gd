extends Node

const PACKAGE_NAME = "com.jello.polymesh"
const SAVE_PATH = "/sdcard/Android/data/" + PACKAGE_NAME + "/files/saves/"

func save_scene(file_name):
	var clean_name = file_name.replace(" ", "_")
	
	var root = get_tree().current_scene
	_set_owner_recursive(root, root)
	
	DirAccess.make_dir_recursive_absolute(SAVE_PATH)
	var save = PackedScene.new()
	save.pack(root)
	ResourceSaver.save(save, SAVE_PATH + clean_name + ".scn")
	WorldOptions.current_file_name = clean_name
	WorldOptions.is_saved = true
	print("Scene saved as : ", clean_name)

func _set_owner_recursive(node, ownerNode):
	for child in node.get_children():
		child.owner = ownerNode
		_set_owner_recursive(child, ownerNode)

func load_scene(file_name):
	var path = SAVE_PATH + file_name + ".scn"
	if ResourceLoader.exists(path):
		PhysicsServer3D.set_active(false)
		await get_tree().process_frame
		get_tree().call_deferred("change_scene_to_file", path)
	else:
		print("Save file not found : ", path)

func get_save_files():
	var files = []
	var dir = DirAccess.open(SAVE_PATH)
	if dir:
		dir.list_dir_begin()
		var file = dir.get_next()
		while file != "":
			if file.ends_with(".scn"):
				files.append(file.replace(".scn", ""))
			file = dir.get_next()
	else:
		print("No saves folder found")
	return files
