extends Node

# Signal to send upon loading the scene
signal scene_loaded

# Set the package name as well as the locaitons for the save paths
const PACKAGE_NAME = "com.jello.polymesh"
const SAVE_PATH = "/sdcard/Android/data/" + PACKAGE_NAME + "/files/saves/"
const MESH_PATH = "/sdcard/Android/data/" + PACKAGE_NAME + "/files/meshes/"
const OBJECT_PATH = "/sdcard/Android/data/" + PACKAGE_NAME + "/files/objects/"

# Save the scene node
func save_scene(file_name):
	# Clean up the name by replacing white space with _
	var clean_name = file_name.replace(" ", "_")
	
	var rendered = get_tree().get_nodes_in_group("rendered_objects")
	var rendered_parents = {}
	for obj in rendered:
		# Ensure the object is valid
		if is_instance_valid(obj):
			rendered_parents[obj] = obj.get_parent()
			obj.get_parent().remove_child(obj)
	
	# Set the current scene as the root
	var root = get_tree().current_scene
	# Recursively set the children of scene to be re parented to the scene, saving the scenes node structure
	_set_owner_recursive(root, root)
	
	# Save it into a packed scene
	var save = PackedScene.new()
	save.pack(root)
	var result = ResourceSaver.save(save, SAVE_PATH + clean_name + ".scn")
	
	# Add any rendered objects to the array
	for obj in rendered_parents:
		if is_instance_valid(obj):
			rendered_parents[obj].add_child(obj)
	
	# I fthe resource save is okay
	if result == OK:
		# Set the world options variables as true and ping the user with a success Toast
		WorldOptions.current_file_name = clean_name
		WorldOptions.is_saved = true
		ToastManager.success("Scene Saved", "Saved as: " + clean_name)
		
		# Update the floating HUD
		var floating_hud = get_tree().get_first_node_in_group("floating_hud")
		if floating_hud:
			floating_hud.update_save_state(true, file_name)
		
	# Give the user an error toast if result != OK
	else:
		ToastManager.error("Save Failed", "Could not save scene")
	
# Re parenting script
func _set_owner_recursive(node, ownerNode):
	for child in node.get_children():
		child.owner = ownerNode
		_set_owner_recursive(child, ownerNode)

# Loading scene function
func load_scene(file_name):
	# Grab the path .scn
	var path = SAVE_PATH + file_name + ".scn"
	 
	# Guard to check if the path exists
	if not ResourceLoader.exists(path):
		ToastManager.error("Load Failed", "File not found : " + file_name)
		return
	
	# Clearing everything in the scene
	for obj in get_tree().get_nodes_in_group("summonedObjects"):
		if is_instance_valid(obj):
			obj.queue_free()
	
	# Gets the main node in the scene to clear intersection and subtraction ghosts
	var main = get_tree().get_first_node_in_group("main_node")
	main.clear_ghosted("intersection_ghosts")
	main.clear_ghosted("subtraction_ghosts")
	
	# Take a frame pause
	await get_tree().process_frame
	
	# Load the saved packed scene
	var packed = load(path)
	# Instantiate the scene
	var instance = packed.instantiate()
	
	# Process the frame to ensure its been instantiated
	await get_tree().process_frame
	
	# Set up the objects from that scene
	var objects_summon = []
	for obj in instance.get_children():
		# Add only combiners to the list
		if obj is CSGCombiner3D:
			objects_summon.append(obj)
	
	# Instantiate that object and add them to the summonedObjects group
	for obj in objects_summon:
		instance.remove_child(obj)
		get_tree().current_scene.add_child(obj)
		obj.owner = get_tree().current_scene
		obj.add_to_group("summonedObjects")
	
	await get_tree().process_frame
	
	# Free up the instance
	instance.free()
	
	# Set the worldoptions variables
	WorldOptions.current_file_name = file_name
	WorldOptions.is_saved = true
	
	# Update the HUD
	var floating_hud = get_tree().get_first_node_in_group("floating_hud")
	if floating_hud:
		floating_hud.update_save_state(true, file_name)
	
	# Emit the signal
	scene_loaded.emit()
	
	# Give user a success toast
	ToastManager.success("Scene Loaded", "Loaded : " + file_name)

# Grab the saved files from the headset
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
		# print("No saves folder found")
		ToastManager.error("No Saved Files", "No path found in the files, re initialize application")
	return files

# Delete the save from the users files
func delete_save(file_name):
	var path = SAVE_PATH + file_name + ".scn"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		# Give info toast when successful
		ToastManager.info("Filed Deleted", "Deleted : " + file_name)
	else:
		# Give error toast if its the file doesn't exist
		ToastManager.error("Delete Failed", "File not found : " + file_name)

# Export the users singluar Godot Scene
func export_mesh(node, file_name):
	# Replace the file name whitespaces with _
	var clean_name = file_name.replace(" ", "_")
	var node_to_export = null
	
	# If the object is a RigidBody3D
	if node is RigidBody3D:
		for child in node.get_children():
			if child is MeshInstance3D:
				var mesh_instance = MeshInstance3D.new()
				mesh_instance.mesh = child.mesh
				node_to_export = mesh_instance
				break
	
	# If the object is CSGCombiner3D
	if node is CSGCombiner3D:
		await get_tree().process_frame
		var meshes = node.get_meshes()
		if meshes.size() < 2:
			# print("No mesh data")
			ToastManager.error("Export Failed", "No mesh data available")
			return
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = meshes[1]
		node_to_export = mesh_instance
	
	# If the object is inside of placedMesh'
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
		ToastManager.error("Export Failed", "Nothing to export")
		return
	
	# Create the packed scene.
	var packed = PackedScene.new()
	packed.pack(node_to_export)
	
	# Save the scene results to the file
	var result = ResourceSaver.save(packed, MESH_PATH + clean_name + ".tscn")
	if result == OK:
		# Give the user a successful toast
		ToastManager.success("Mesh Exported", "Saved as : "+ clean_name + ".tscn")
	else:
		ToastManager.error("Export Failed", "Could not save mesh file")

# Exporting the object as a .obj file
func export_obj(node: Node, file_name: String):
	# Replace the whitespace with _
	var clean_name = file_name.replace(" ", "_")
	var mesh: Mesh = null
	
	# If the node is a RigidBody3D
	if node is RigidBody3D:
		for child in node.get_children():
			if child is MeshInstance3D:
				mesh = child.mesh
				break

	# If the node is a CSGCombiner3D
	elif node is CSGCombiner3D:
		await get_tree().process_frame
		var meshes = node.get_meshes()
		if meshes.size() < 2:
			ToastManager.error("Export Failed", "No mesh data available")
			return
		mesh = meshes[1]
	
	# If the node is from the placedMesh' group
	elif node.is_in_group("placedMeshes"):
		for child in node.get_children():
			if child is MeshInstance3D:
				mesh = child.mesh
				break
	elif node is MeshInstance3D:
		mesh = node.mesh
	
	# Guard to ensure there is a mesh
	if not mesh:
		ToastManager.error("Export Failed", "No mesh found")
		return
	
	# Give Positive toast for exporting the .obj
	ToastManager.info("Exporting OBJ", "Creating : " + clean_name + ".obj")
	# OBJExporter Singleton funciton for export completed and saving the mesh to the files.
	# Saves both .OBJ and .MTL
	OBJExporter.export_completed.connect(_on_obj_export_completed, CONNECT_ONE_SHOT)
	OBJExporter.save_mesh_to_files(mesh, OBJECT_PATH, clean_name)

# Toast manager to ensure the obj was exported
func _on_obj_export_completed(obj_file, mtl_file):
	ToastManager.success("OBJ Exported", "Files created succesfully!")

# Upon load ensure directories exist
func ensure_directories():
	DirAccess.make_dir_recursive_absolute(SAVE_PATH)
	DirAccess.make_dir_recursive_absolute(MESH_PATH)
	DirAccess.make_dir_recursive_absolute(OBJECT_PATH)
