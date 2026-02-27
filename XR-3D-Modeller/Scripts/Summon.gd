extends XRController3D

# Dev Note #
# Pickable functions will not work due to the CSGMesh style.
# Not allowing the players to pick up the objets via grabbing.
# Will use a separate function for that.
signal objectSummoned

@export var object_scene: PackedScene
@export var spawn_distance := 1.0
@export var summon_rate:int = 1

# Onready variables used 
@onready var timer = $Timer
@onready var raycast_3d = $RayCast3D # Fix path later when the ToolNodebox is implemented
# @export var bland

# var summonableObjects = []
# var ghostedObjects = []
var summonedObjects
var objectsInScene = []
var summonIndex = 0 # Default index value defined by the build pages button value on the UI controller
var pageIndex = 0 # Default index value defined by the pages index value on the UI controller
var ghostInstance
var ghostingOn = false
var can_summon = true
var is_active = true
var objectSize = 1.0 # Used for size scaler in the UI, starts on 1.0 scaling
var csgIndex = 0 # Default combine csgIndex

# Highlighting variables
var original_materials = {}
var highlighted_object = null
var highlight_color = Color(0.756, 0.453, 0.105, 1.0) # Red highlight / Pinkish highlight
var highlighting = false
var highlighting_cancelled = false
var remove_highlighting = false
var remove_highlighting_cancelled = false

# For Pickup and relase signalling
var last_grabbed_object = null

# Replace folder variables with arrays of file paths
@export var summonablePaths := [
	"res://Summonables_Folder/CSG_Editables/Box_CSG.tscn",
	"res://Summonables_Folder/CSG_Editables/Prism_CSG.tscn",
	"res://Summonables_Folder/CSG_Editables/Sphere_CSG.tscn",
	"res://Summonables_Folder/CSG_Editables/Vertice.tscn"
]
@export var ghostedPaths := [
	"res://Summonables_Folder/Objects_Ghosted/ghosted_cube.tscn",
	"res://Summonables_Folder/Objects_Ghosted/ghosted_prism.tscn",
	"res://Summonables_Folder/Objects_Ghosted/ghosted_sphere.tscn",
	"res://Summonables_Folder/Objects_Ghosted/ghosted_Vertice.tscn"

]

# Loaded scenes will be stored here
var summonableObjects = []
var ghostedObjects = []

func load_summonables():
	summonableObjects.clear()
	for path in summonablePaths:
		var scene = load(path)
		if scene:
			summonableObjects.append(scene)
		else:
			print("Could not load: ", path)

func load_ghosted():
	ghostedObjects.clear()
	for path in ghostedPaths:
		var scene = load(path)
		if scene:
			ghostedObjects.append(scene)
		else:
			print("Could not load: ", path)

func _ready() -> void:
	# Load the summonables when started
	load_summonables()
	load_ghosted()
	timer.wait_time = 1.0 / summon_rate
	timer.connect("timeout", _time_out)
	# Get the path for the left Hand controller
	
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects")
	var remover = get_node("FunctionToolNode/RemoveFunction") # Change to new location when the toolbox is finished
	# print(remover)
	remover.connect("objectRemoved", Callable(self, "update_list"))
	var ui_controllers = get_tree().get_nodes_in_group("ui_controller")
	if ui_controllers.size() > 0:
		var ui_controller = ui_controllers[0]
		# Connect the script to the summonable Selected function with a signal to call the set_summon_index
		ui_controller.connect("change_page", Callable(self, "set_page_index")) # changes the current selected page
		ui_controller.connect("summonable_selected", Callable(self, "set_summon_index")) # changes the selected summonable object 1 - 4 / 0 - 3
		ui_controller.connect("scaleSize", Callable(self, "set_scale_size")) # changes the scale size for summoning and ghosting objects
		ui_controller.connect("csg_operation", Callable(self, "change_csg_operation"))
		print("Controller found ", ui_controller)
	else:
		print("UI Controller not found")

func _time_out():
	can_summon = true

func _process(_delta):
	# Will activate when the user presses the A button on the controller
	if is_active:
		if is_button_pressed("ax_button") and can_summon: # Meta Quest A button
			if not ghostingOn:
				ghostInstance = ghostedObjects[summonIndex].instantiate()
				ghostInstance.scale = objectSize * Vector3.ONE # sets all of the values to objectSize
				get_tree().current_scene.add_child(ghostInstance)
				ghostingOn = true

			if raycast_3d.is_colliding():
				var obj = raycast_3d.get_collider()
				if obj in summonedObjects:
					var snap_pos = raycast_3d.get_collision_point() + raycast_3d.get_collision_normal() * 0.01
					ghostInstance.global_position = snap_pos
					ghostInstance.look_at(raycast_3d.get_collision_point(), raycast_3d.get_collision_normal())
			else:
				var spawn_pos = global_transform.origin + -global_transform.basis.z * spawn_distance
				ghostInstance.global_transform.origin = spawn_pos

		else:
			if ghostingOn:
				ghostInstance.queue_free()
				ghostInstance = null
				ghostingOn = false
				timer.start()
				can_summon = false
				if raycast_3d.is_colliding():
					var obj = raycast_3d.get_collider()
					if obj in summonedObjects:
						# print("Combined")
						combine_objects(summonIndex, obj, raycast_3d.get_collision_point(), raycast_3d.get_collision_normal())
				else:
					summon_object(summonIndex)
		update_highlighted_object()

func combine_objects(index, obj, spawnPoint, objectNormal):
	if index < summonableObjects.size():
		# Instantiate the object in the scene
		var new_obj = summonableObjects[index].instantiate()
		# Grabs the position of the hand and will add to it to spawn the hand in
		# Will replace this with a marker tag later on
		new_obj.global_transform.origin = (spawnPoint + objectNormal * 0.01)
		# objectsInScene.append(new_obj)
		# print("Added", new_obj)
		# Add the new object to the scene
		new_obj.scale = objectSize * Vector3.ONE
		new_obj.operation = csgIndex
		get_tree().current_scene.add_child(new_obj)
		new_obj.look_at(spawnPoint, objectNormal)
		new_obj.add_to_group("summonedObjects")
		new_obj.reparent(obj)
		print("Parent is : ", new_obj.get_parent())
		summonedObjects = get_tree().get_nodes_in_group("summonedObjects") # Updates the summoned list within script
		emit_signal("objectSummoned") # This gets called as an upadte is to be sent out due to a reparenting
		print(summonedObjects)
	else:
		print("Summonables out of index")

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
		# objectsInScene.append(new_obj)
		# print("Added", new_obj)
		# Add the new object to the scene
		new_obj.scale = objectSize * Vector3.ONE
		get_tree().current_scene.add_child(new_obj)
		summonedObjects = get_tree().get_nodes_in_group("summonedObjects") # Updates the summoned list within script
		emit_signal("objectSummoned")
		print(summonedObjects)
	else:
		print("Summonables out of index")

func update_highlighted_object():
	# print("Ray update")
	if raycast_3d.is_colliding():
		var obj = raycast_3d.get_collider()
		if obj in summonedObjects:
			# print("Object was found in summonedObjects")
			if obj != highlighted_object:
				if highlighted_object:
					_remove_highlight(highlighted_object)
				highlighted_object = obj
				_apply_highlight(highlighted_object)
	else:
		if highlighted_object:
			remove_highlighting_cancelled = true
			_remove_highlight(highlighted_object)
			highlighted_object = null

# Highlighting recursive function
func _apply_highlight(obj):
	highlighting_cancelled = true
	await get_tree().process_frame
	
	highlighting_cancelled = false
	highlighting = true
	
	await _apply_highlight_recursive(obj)
	
	highlighting = false

func _apply_highlight_recursive(obj):
	# If this is true then cancel the recursive script
	if highlighting_cancelled:
		return
		
	var mesh_inst = null
	if obj is CSGMesh3D:
		print("obj is a CSGMesh3D")
		mesh_inst = obj
		
		if mesh_inst.mesh:
			original_materials[mesh_inst] = mesh_inst.material
			if mesh_inst.material:
				var mat = mesh_inst.material.duplicate()
				mat.albedo_color = highlight_color
				mesh_inst.material = mat
			
			# Will pause after applying material to reduce lag
			await get_tree().process_frame
		else:
			print("No Mesh resource found on CSGMesh3D!")
		
		if obj.get_children():
			for child in obj.get_children():
				if highlighting_cancelled:
					return
				await _apply_highlight_recursive(child)
	
	elif obj.has_node("CSGMesh3D"):
		print("OBJ has a CSGMesh3D")
		mesh_inst = obj.get_node("CSGMesh3D")
		
		if mesh_inst.mesh:
			original_materials[mesh_inst] = mesh_inst.material
			if mesh_inst.material:
				var mat = mesh_inst.material.duplicate()
				mat.albedo_color = highlight_color
				mesh_inst.material = mat
				
			await get_tree().process_frame
		else:
			print("No mesh resource found on CSGMesh3D!")
	else:
		print("No mesh resource found on CSGMesh3D!")
		return

# Remove highlight recursive
func _remove_highlight(obj):
	remove_highlighting_cancelled = true
	
	await get_tree().process_frame
	
	remove_highlighting_cancelled = false
	remove_highlighting = true
	
	await _remove_highlight_recursive(obj)
	
	remove_highlighting = false


func _remove_highlight_recursive(obj):
	if remove_highlighting_cancelled:
		return
		
	var mesh_inst = null
	if obj is CSGMesh3D:
		mesh_inst = obj
		
		if mesh_inst.mesh:
			if mesh_inst in original_materials:
				mesh_inst.material = original_materials[mesh_inst]
				original_materials.erase(mesh_inst)
				
			await get_tree().process_frame
			
		if obj.get_children():
			for child in obj.get_children():
				if remove_highlighting_cancelled:
					return
				await  _remove_highlight_recursive(child)
				
	elif obj.has_node("CSGMesh3D"):
		mesh_inst = obj.get_node("CSGMesh3D")
		
		if mesh_inst.mesh:
			if mesh_inst in original_materials:
				mesh_inst.material = original_materials[mesh_inst]
				original_materials.erase(mesh_inst)
				
			await get_tree().process_frame

# Signals going and coming
func set_page_index(idx):
	# print("Hello from remove call index")
	if idx == 0:
		is_active = true
	else:
		is_active = false

func change_csg_operation(idx):
	print("The new oepration is : ")
	csgIndex = idx

func update_list():
	# print("Hello from update list in Summon")
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects")

func set_summon_index(idx):
	print("Summon Called")
	summonIndex = idx
	
func set_scale_size(value):
	objectSize = value
