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
	print("Loading scene from : ", path)
	if not ResourceLoader.exists(path):
		print("Save file not found: ", path)
		return
	
	for obj in get_tree().get_nodes_in_group("summonedObjects"):
		if is_instance_valid(obj):
			obj.queue_free()
	
	for obj in get_tree().get_nodes_in_group("summonedObjects"):
		if is_instance_valid(obj):
			obj.queue_free()
	
	var main = get_tree().get_first_node_in_group("main_node")
	main.clear_ghosted("intersection_ghosts")
	main.clear_ghosted("subtraction_ghosts")
	
	await get_tree().process_frame
	
	var packed = load(path)
	var instance = packed.instantiate()
	
	print("Instance: ", instance)
	print("Instance children: ", instance.get_children())
	await get_tree().process_frame
	
	var objects_summon = []
	for obj in instance.get_children():
		print("Child: ", obj.name, " groups: ", obj.get_groups())
		if obj is CSGCombiner3D:
			objects_summon.append(obj)
			for sub in obj.get_children():
				print(" Sub ", sub.name, " groups : ", sub.get_groups())
	
	for obj in objects_summon:
		instance.remove_child(obj)
		get_tree().current_scene.add_child(obj)
		obj.owner = get_tree().current_scene
		obj.add_to_group("summonedObjects")
	
	await get_tree().process_frame
	
	instance.free()
	
	WorldOptions.current_file_name = file_name
	WorldOptions.is_saved = true
	print("Loaded : ", file_name)

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
