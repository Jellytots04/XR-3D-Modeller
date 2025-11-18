extends XRController3D

# Exported objects and nodes
@export var summonableFolder = "res://Objects_Summonable/"
@export var ghostedFolder = "res://Objects_Ghosted/"
@export var object_scene: PackedScene
@export var spawn_distance := 1.0
@export var summon_rate:int = 1

# Onready variables used 
@onready var timer = $Timer
@onready var raycast_3d = $RayCast3D
# @export var bland

var summonedObjects = []
var summonableObjects = []
var ghostedObjects = []
var objectsInScene = []
var summonIndex = 0
var ghostInstance
var ghostingOn = false
var can_summon = true

# Highlighting variables
var original_materials = {}
var highlighted_object = null
var highlight_color = Color(1,0,0) # Red highlight

# For Pickup and relase signalling
var last_grabbed_object = null

# Load the summonable objects from the Objects_Summonable Folder
func load_summonables():
	# Open the directory
	var directory = DirAccess.open(summonableFolder)
	if directory:
		# Starts listing the directory stream
		directory.list_dir_begin()
		var file_name = directory.get_next()
		# While the file name exists
		while file_name != "":
			# Ensure the file is a scene tscn
			if file_name.ends_with(".tscn"):
				# Combine the directory path and the file
				var scene = load(summonableFolder + file_name)
				# Add it to the list of obejcts
				summonableObjects.append(scene)
			# Move to the next item
			file_name = directory.get_next()
		# Ends the stream
		directory.list_dir_end()
		# print(summonableFolder)
	else:
		print("No folder applicable")

func load_ghosted():
	# Open the directory
	var directory = DirAccess.open(ghostedFolder)
	if directory:
		# Starts listing the directory stream
		directory.list_dir_begin()
		var file_name = directory.get_next()
		# While the file name exists
		while file_name != "":
			# Ensure the file is a scene tscn
			if file_name.ends_with(".tscn"):
				# Combine the directory path and the file
				var scene = load(ghostedFolder + file_name)
				# Add it to the list of obejcts
				ghostedObjects.append(scene)
			# Move to the next item
			file_name = directory.get_next()
		# Ends the stream
		directory.list_dir_end()
		# print(summonableFolder)
	else:
		print("No folder applicable")

func _ready() -> void:
	# Load the summonables when started
	load_summonables()
	load_ghosted()
	timer.wait_time = 1.0 / summon_rate
	timer.connect("timeout", _time_out)
	# Get the path for the left Hand controller
	var ui_controllers = get_tree().get_nodes_in_group("ui_controller")
	if ui_controllers.size() > 0:
		var ui_controller = ui_controllers[0]
		# Connect the script to the summonable Selected function with a signal to call the set_summon_index
		ui_controller.connect("summonable_selected", Callable(self, "set_summon_index"))
		print("Controller foubd", ui_controller)
	else:
		print("UI Controller not found")
	
func _time_out():
	can_summon = true

func _process(_delta):
	# Will activate when the user presses the A button on the controller
	if is_button_pressed("ax_button") and can_summon: # Meta Quest A button
		if not ghostingOn:
			ghostInstance = ghostedObjects[summonIndex].instantiate()
			get_tree().current_scene.add_child(ghostInstance)
			ghostingOn = true
		var spawn_pos = global_transform.origin + -global_transform.basis.z * spawn_distance
		ghostInstance.global_transform.origin = spawn_pos
	else:
		if ghostingOn:
			ghostInstance.queue_free()
			ghostInstance = null
			ghostingOn = false
			timer.start()
			can_summon = false
			summon_object(summonIndex)
	if is_button_pressed("by_button"):
		print("Removing time")
		remove_object()
	update_highlighted_object()

func update_highlighted_object():
	# print("Ray update")
	if raycast_3d.is_colliding():
		var obj = raycast_3d.get_collider()
		if obj in objectsInScene:
			if obj != highlighted_object:
				if highlighted_object:
					_remove_highlight(highlighted_object)
				highlighted_object = obj
				_apply_highlight(highlighted_object)
	else:
		if highlighted_object:
			_remove_highlight(highlighted_object)
			highlighted_object = null
			
func summon_object(index):
	# Checks to see if index is inside the size of the array
	if index < summonableObjects.size():
		# Instantiate the object in the scene
		var new_obj = summonableObjects[index].instantiate()
		# Grabs the position of the hand and will add to it to spawn the hand in
		# Will replace this with a marker tag later on
		var spawn_pos = global_transform.origin + -global_transform.basis.z * spawn_distance
		new_obj.global_transform.origin = spawn_pos
		new_obj.add_to_group("summonedObjects")
		objectsInScene.append(new_obj)
		# Add the new object to the scene
		get_tree().current_scene.add_child(new_obj)
	else:
		print("Summonables out of index")
	
func set_summon_index(idx):
	print("Summon Called")
	summonIndex = idx

func _apply_highlight(obj):
	var mesh_inst = null
	if obj is MeshInstance3D:
		mesh_inst = obj
	elif obj.has_node("MeshInstance3D"):
		mesh_inst = obj.get_node("MeshInstance3D")
	else:
		print("No MeshInstance3D available on object!")
		return

	if not mesh_inst.mesh:
		print("No mesh resource found on MeshInstance3D!")
		return

	var mesh = mesh_inst.mesh
	original_materials[mesh_inst] = []
	for i in range(mesh.get_surface_count()):
		original_materials[mesh_inst].append(mesh_inst.get_active_material(i))
		var mat = mesh_inst.get_active_material(i)
		if mat:
			mat = mat.duplicate()
			mat.albedo_color = highlight_color
			mesh_inst.set_surface_override_material(i, mat)

func _remove_highlight(obj):
	var mesh_inst = null
	if obj is MeshInstance3D:
		mesh_inst = obj
	elif obj.has_node("MeshInstance3D"):
		mesh_inst = obj.get_node("MeshInstance3D")
	else:
		return

	if not mesh_inst.mesh:
		return

	var mesh = mesh_inst.mesh
	if mesh_inst in original_materials:
		for i in range(mesh.get_surface_count()):
			mesh_inst.set_surface_override_material(i, original_materials[mesh_inst][i])
		original_materials.erase(mesh_inst)

func remove_object():
	if highlighted_object and highlighted_object.is_in_group("summonedObjects"):
		# Clean up highlight first if you want
		_remove_highlight(highlighted_object)
		# Remove the actual instance from scene
		highlighted_object.queue_free()
		highlighted_object = null

func _apply_transparency(obj):
	var mesh_inst = null
	if obj is MeshInstance3D:
		mesh_inst = obj
	elif obj.has_node("MeshInstance3D"):
		mesh_inst = obj.get_node("MeshInstance3D")
	else:
		print("No MeshInstance3D available on object!")
		return

	if not mesh_inst.mesh:
		print("No mesh resource found on MeshInstance3D!")
		return

	#if obj in objectsInScene:
		# last_grabbed_object = obj
	var mesh = mesh_inst.mesh
	original_materials[mesh_inst] = []
	for i in range(mesh.get_surface_count()):
		original_materials[mesh_inst].append(mesh_inst.get_active_material(i))
		var mat = mesh_inst.get_active_material(i)
		if mat:
			mat = mat.duplicate()
			var c = mat.albedo_color
			c.a = 0.3
			mat.albedo_color = c
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh_inst.set_surface_override_material(i, mat)

func _remove_main_collision(obj):
	if obj.has_node("CollisionShape3D"):
		var collision = obj.get_node("CollisionShape3D")
		collision.disabled = true

func _return_collision(obj):
	if obj.has_node("CollisionShape3D"):
		var collision = obj.get_node("CollisionShape3D")
		collision.disabled = false

func _on_function_pickup_has_picked_up(obj):
	if obj in objectsInScene:
		last_grabbed_object = obj
		_apply_transparency(obj)
		_remove_main_collision(obj)
		
		print("Old transform : ", obj.global_transform)
		var grab_position = global_transform.origin + -global_transform.basis.z * 5
		var new_transform = Transform3D(global_transform.basis, grab_position)
		obj.global_transform = new_transform

	#print("New transform : ", obj.global_transform)
	#print("Mesh global transform: ", obj.get_node("MeshInstance3D").global_transform)

# ui_controller.get_node("PickableObject").transform = Transform3D.IDENTITY
# ghostInstance.global_transform.origin = spawn_pos
# var spawn_pos = global_transform.origin + -global_transform.basis.z * spawn_distance

func _on_function_pickup_has_dropped() -> void:
	if last_grabbed_object:
		_remove_highlight(last_grabbed_object)
		_return_collision(last_grabbed_object)
		last_grabbed_object = null
