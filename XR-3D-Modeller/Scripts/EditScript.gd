extends Node

signal objectMoved

@onready var controller = get_parent().get_parent()
@onready var raycast_3d = controller.get_node("RayCast3D")

var is_active = false
var summonedObjects
var moveOffset
var moveBasis
var currentlyMoving = false
var currentSelectedObject # to prevent the user from moving another object when raycast hits new object
var editOptionsHolder = [] # Should correspond to the children of the editOptions node
var editIndex # holds the current index value the user has selected
# var objectsCurrentPos

# Highlighting variables
var original_materials = {}
var highlighted_object = null
var highlight_color = Color(0.587, 0.944, 0.536, 1.0) # Red highlight / Pinkish highlight
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects") # If there are any existing objects already then load, will be used later on for previous saves
	var summoner = get_node("../..") # Later this path should reach the summon part of function tool node
	# print(summoner)
	summoner.connect("objectSummoned", Callable(self,  "update_list"))
	var ui_controllers = get_tree().get_nodes_in_group("ui_controller")
	if ui_controllers.size() > 0:
		var ui_controller = ui_controllers[0]
		print("Hello from readying Remover")
		ui_controller.connect("edit_selected", Callable(self, "set_edit_index"))
		var connected = ui_controller.connect("change_page", Callable(self, "set_page_index"))
		print("Connection made: ", connected)
		print("UI Controller: ", ui_controller)
	print("Players controller: ", controller)

func _process(delta: float) -> void:
	if is_active:
		if controller.is_button_pressed("grip_click") and highlighted_object:
			if not currentlyMoving:
				currentSelectedObject = highlighted_object
				startMove(currentSelectedObject)
				currentlyMoving = true
			# print("Grip is active")
			moveObject(currentSelectedObject)
		else:
			currentSelectedObject = null
			currentlyMoving = false
			
	# If the user clicks / presses right trigger on an highlighted object it will become the selected object
		if controller.is_button_pressed("trigger_click") and highlighted_object:
			if not currentSelectedObject:
				currentSelectedObject = highlighted_object
				# Select case for ensuring the object is selected
				

		update_highlighted_object()
		
				
		

func update_highlighted_object():
	# print("Ray update")
	if raycast_3d.is_colliding():
		var obj = raycast_3d.get_collider()
		if obj in summonedObjects:
			if obj != highlighted_object:
				if highlighted_object:
					_remove_highlight(highlighted_object)
				highlighted_object = obj
				_apply_highlight(highlighted_object)

	else:
		if highlighted_object:
			_remove_highlight(highlighted_object)
			highlighted_object = null

func scaleSelectedObject():
	# Will be used to scale an object that is selected
	# Open up scale screen on UI controller
	print("Will be used to scale")
	

func startMove(obj):
	moveOffset = obj.global_position - self.global_position # distance between object and controller
	moveBasis = self.global_transform.basis # starting basis for the object to rotate around
	print(moveOffset)

func moveObject(obj):
	print("Object is : ", obj)
	# objectsCurrentPos = obj.global_position
	
	# Distance should be self - obj.global_position
	# have it face the forward direction of the Vector3 of the users controller
	# var offset = self.global_position - obj.global_position
	var rotation = self.global_transform.basis * moveBasis.inverse()
	obj.global_position = self.global_position + rotation * moveOffset

	# var move_pos = controller.global_position + -controller.global_transform.basis.z * offset
	# obj.global_position = controller.global_position + offset * controller.global_transform.basis

func _apply_highlight(obj):
	var mesh_inst = null
	if obj is CSGMesh3D:
		print("obj is a CSGMesh3D")
		print(obj)
		mesh_inst = obj
		if obj.get_children():
			for child in obj.get_children():
				# _apply_highlight(obj.find_child("*CSGMesh3D*", true, false))
				_apply_highlight(child)
	elif obj.has_node("CSGMesh3D"):
		print("OBJ has a CSGMesh3D")
		mesh_inst = obj.get_node("CSGMesh3D")

	else:
		print("No CSGMesh3D available on object!")
		return

	if not mesh_inst.mesh:
		print("No mesh resource found on CSGMesh3D!")
		return

	original_materials[mesh_inst] = mesh_inst.material

	if mesh_inst.material:
		var mat = mesh_inst.material.duplicate()
		mat.albedo_color = highlight_color
		mesh_inst.material = mat

func _remove_highlight(obj):
	var mesh_inst = null
	if obj is CSGMesh3D:
		mesh_inst = obj
		if obj.get_children():
			for child in obj.get_children():
				# _remove_highlight(obj.find_child("*CSGMesh3D*", true, false))
				_remove_highlight(child)
	elif obj.has_node("CSGMesh3D"):
		mesh_inst = obj.get_node("CSGMesh3D")
	else:
		return
	if not mesh_inst.mesh:
		return
	if mesh_inst in original_materials:
		mesh_inst.material = original_materials[mesh_inst]
			# mesh_inst.set_surface_override_material(i, original_materials[mesh_inst][i])
		original_materials.erase(mesh_inst)

func set_page_index(idx):
	# print("Hello from remove call index")
	if idx == 2:
		is_active = true
	else:
		is_active = false

func set_edit_index(idx):
	# print("Summon Called")
	editIndex = idx

func update_list():
	print("Hello from Edit script new object update signal")
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects")
