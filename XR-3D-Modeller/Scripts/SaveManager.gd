extends Node

const PACKAGE_NAME = "com.jello.polymesh"
const SAVE_PATH = "/sdcard/Android/data/" + PACKAGE_NAME + "/files/saves/"
const MESH_PATH = "/sdcard/Android/data/" + PACKAGE_NAME + "/files/meshes/"
const OBJECT_PATH = "/sdcard/Android/data/" + PACKAGE_NAME + "/files/objects/"

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
		# print("Child: ", obj.name, " groups: ", obj.get_groups())
		if obj is CSGCombiner3D:
			objects_summon.append(obj)

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

func delete_save(file_name):
	var path = SAVE_PATH + file_name + ".scn"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("Deleted : ", file_name)
	else:
		print("File not found : ", file_name)

func export_mesh(node, file_name):
	print("Export mesh called with: ", node, " name: ", file_name)
	var clean_name = file_name.replace(" ", "_")
	print("Saving to: ", MESH_PATH + clean_name + ".tscn")
	var node_to_export = null
	
	if node is RigidBody3D:
		print("Is RigidBody3D")
		for child in node.get_children():
			if child is MeshInstance3D:
				var mesh_instance = MeshInstance3D.new()
				mesh_instance.mesh = child.mesh
				node_to_export = mesh_instance
				print("Found mesh instance")
				break
	
	if node is CSGCombiner3D:
		await get_tree().process_frame
		var meshes = node.get_meshes()
		if meshes.size() < 2:
			print("No mesh data")
			return
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = meshes[1]
		node_to_export = mesh_instance
	
	elif node.is_in_group("placedMeshes"):
		for child in node.get_children():
			if child is MeshInstance3D:
				var mesh_instance = MeshInstance3D.new()
				mesh_instance.mesh = child.mesh
				node_to_export = mesh_instance
				break
	
	elif node is MeshInstance3D:
		node_to_export = node
	
	if not node_to_export:
		print("Nothing to export")
		return
		
	var packed = PackedScene.new()
	packed.pack(node_to_export)
	ResourceSaver.save(packed, MESH_PATH + clean_name + ".tscn")
	print("Exported mesh as : ", clean_name)

func export_obj(node: Node, file_name: String):
	var clean_name = file_name.replace(" ", "_")
	var mesh: Mesh = null
	
	if node is RigidBody3D:
		for child in node.get_children():
			if child is MeshInstance3D:
				mesh = child.mesh
				print("Found mesh: ", mesh)
				print("Surface count: ", mesh.get_surface_count() if mesh else 0)
				break
	elif node is CSGCombiner3D:
		await get_tree().process_frame
		var meshes = node.get_meshes()
		if meshes.size() < 2:
			print("No mesh data")
			return
		mesh = meshes[1]
	elif node.is_in_group("placedMeshes"):
		for child in node.get_children():
			if child is MeshInstance3D:
				mesh = child.mesh
				break
	elif node is MeshInstance3D:
		mesh = node.mesh
	
	if not mesh:
		print("No mesh found for obj export")
		return
	
	print("Exporting obj to: ", OBJECT_PATH, clean_name)
	OBJExporter.export_completed.connect(_on_obj_export_completed, CONNECT_ONE_SHOT)
	OBJExporter.save_mesh_to_files(mesh, OBJECT_PATH, clean_name)

func _on_obj_export_completed(obj_file, mtl_file):
	print("OBJ exported: ", obj_file)
	print("MTL exported: ", mtl_file)

func ensure_directories():
	DirAccess.make_dir_recursive_absolute(SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(MESH_PATH)
	DirAccess.make_dir_recursive_absolute(OBJECT_PATH)
