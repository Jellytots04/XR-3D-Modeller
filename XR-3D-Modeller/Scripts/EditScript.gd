extends Node

signal objectMoved
signal selectedScale(value) # signal should send the current scale value for the UI

@onready var secondary_controller = get_parent().get_parent().get_parent().get_node("LeftHand") # Left Controller
@onready var controller = get_parent().get_parent() # Right Controller / Main Controller hence controller as the name
@onready var raycast_3d = controller.get_node("RayCast3D")

# Flags
var triggerPressed = false # Flag to signal if the trigger has been clicked
var is_active = false
var currentlyMoving = false
var currentlyStretching = false

var summonedObjects
var moveOffset
var moveBasis
var currentlyMovingObject # to prevent the user from moving another object when raycast hits new object
var currentSelectedObject # for when the user clicks a specific object
var editOptionsHolder = [] # Should correspond to the children of the editOptions node
var editIndex # holds the current index value the user has selected
var ui_controller # holds the Controller node to allow edits to be made
var stretchDistance # holds the value between the two controllers to be compared for stretching
var startingScale # holds the starting scale of the object before the scale changes
# var objectsCurrentPos

# Highlighting variables
var highlighting_cancelled = false
var highlighting = false
var remove_highlighting_cancelled = false
var remove_highlighting = false
var original_materials = {}
var highlighted_object = null
var highlight_color = Color(0.587, 0.944, 0.536, 1.0) # Red highlight / Pinkish highlight
var selected_color = Color(0.913, 0.967, 0.331, 1.0) # When clicked on this is the color the object will assume
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects") # If there are any existing objects already then load, will be used later on for previous saves
	var summoner = get_node("../..") # Later this path should reach the summon part of function tool node
	# print(summoner)
	summoner.connect("objectSummoned", Callable(self,  "update_list"))
	var ui_controllers = get_tree().get_nodes_in_group("ui_controller")
	if ui_controllers.size() > 0:
		ui_controller = ui_controllers[0]
		print("Hello from readying Remover")
		ui_controller.connect("edit_selected", Callable(self, "set_edit_index"))
		var connected = ui_controller.connect("change_page", Callable(self, "set_page_index"))
		ui_controller.connect("scaleSize", Callable(self, "scale_selected_object"))
		print("Connection made: ", connected)
		print("UI Controller: ", ui_controller)
	print("Players controller: ", controller)

func _process(delta: float) -> void:
	# Allows this script to be ran
	if is_active:
		if controller.is_button_pressed("grip_click") and highlighted_object and editIndex == 0: # Moving object only with raycast, default index
			if not currentlyMoving:
				currentlyMovingObject = highlighted_object
				startMove(currentlyMovingObject)
				currentlyMoving = true
			# print("Grip is active")
			moveObject(currentlyMovingObject)
		else:
			currentlyMovingObject = null
			currentlyMoving = false

		if controller.is_button_pressed("grip_click") and secondary_controller.is_button_pressed("grip_click") and editIndex == 1: # Stretch the object when gripping controllers and pulling outwards or inwards, second / first index value
			if currentSelectedObject:
				if not currentlyStretching:
					startStretch(controller.global_position, secondary_controller.global_position, currentSelectedObject)
					currentlyStretching = true
					# print("Distance from stretching process : ", stretchDistance)
				stretchObject(controller.global_position, secondary_controller.global_position, currentSelectedObject)
		else:
			currentlyStretching = false

		# If the user clicks / presses right trigger on an highlighted object it will become the selected object
		if controller.is_button_pressed("trigger_click") and !currentlyMoving and !triggerPressed:
			if highlighted_object:
				# Release trigger / click
				if currentSelectedObject == highlighted_object:
					# print("Goodbye previous selected object", currentSelectedObject)
					_remove_highlight(currentSelectedObject)
					ui_controller._remove_scale()
					currentSelectedObject = null

				elif not currentSelectedObject:
					# print("Hello new selected object", highlighted_object)
					currentSelectedObject = highlighted_object
					# print(currentSelectedObject, highlighted_object)
					selectedScale.emit(currentSelectedObject)
					_remove_highlight(currentSelectedObject) # Remove any previous highlighting
					_select_highlighted_object(currentSelectedObject)
					# print(currentSelectedObject.scale)
					ui_controller._change_scale_value(currentSelectedObject.scale)
					# Select case for ensuring the object is selected
				triggerPressed = true
				# print(triggerPressed)

		elif not controller.is_button_pressed("trigger_click"):
			triggerPressed = false

		
		# For highlighting an object alerting the user where they're pointing at
		update_highlighted_object()

func _select_highlighted_object(obj):
	print("Highlighting this new object : ")
	_apply_highlight(obj, selected_color)

func update_highlighted_object():
	# print("Ray update")
	if raycast_3d.is_colliding():
		var obj = raycast_3d.get_collider()
		if obj in summonedObjects:
			if obj != highlighted_object:
				if highlighted_object:
					_remove_highlight(highlighted_object)
				highlighted_object = obj
				if highlighted_object != currentSelectedObject:
					_apply_highlight(highlighted_object, highlight_color)

	else:
		if highlighted_object and highlighted_object != currentSelectedObject:
			_remove_highlight(highlighted_object)
		highlighted_object = null

# Unused function
func scaleSelectedObject():
	# Will be used to scale an object that is selected
	# Open up scale screen on UI controller
	print("Will be used to scale")

# Stretching functions
# Main and secondary are both controllers
func startStretch(main, secondary, obj):
	stretchDistance = main.distance_to(secondary)
	startingScale = obj.scale
	print(stretchDistance)

# Main and secondary are both controllers and obj is the currently selected object
func stretchObject(main, secondary, obj):
	var currentDistance = main.distance_to(secondary)
	
	# Return if controllers aren't separated
	if stretchDistance == 0:
		return
	
	var ratio = currentDistance / stretchDistance
	var newScale = startingScale * ratio
	
	newScale = (newScale * 10).round() / 10
	
	newScale = newScale.clamp(Vector3.ONE * 0.1, Vector3.ONE * 2.0)
	obj.scale = newScale
	ui_controller._change_scale_value(obj.scale)

# Moving functions
func startMove(obj):
	moveOffset = obj.global_position - self.global_position # distance between object and controller
	moveBasis = self.global_transform.basis # starting basis for the object to rotate around
	# print(moveOffset)

func moveObject(obj):
	# print("Object is : ", obj)
	# Moves the objects position based on the rotation and distance the controller has moved
	var rotation = self.global_transform.basis * moveBasis.inverse()
	obj.global_position = self.global_position + rotation * moveOffset

# Highlighting recursive function
func _apply_highlight(obj, color):
	highlighting_cancelled = true
	await get_tree().process_frame
	
	highlighting_cancelled = false
	highlighting = true
	
	await _apply_highlight_recursive(obj, color)
	
	highlighting = false

func _apply_highlight_recursive(obj, color):
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
				mat.albedo_color = color
				mesh_inst.material = mat
			
			# Will pause after applying material to reduce lag
			await get_tree().process_frame
		else:
			print("No Mesh resource found on CSGMesh3D!")
		
		if obj.get_children():
			for child in obj.get_children():
				if highlighting_cancelled:
					return
				await _apply_highlight_recursive(child, color)
	
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

func scale_selected_object(value):
	# print("New scale size should be: ", value)
	if currentSelectedObject:
		currentSelectedObject.scale = value * Vector3.ONE

func set_page_index(idx):
	# print("Hello from remove call index")
	if idx == 2:
		is_active = true
	else:
		is_active = false

func set_edit_index(idx):
	print("Edit Called")
	editIndex = idx

func update_list():
	print("Hello from Edit script new object update signal")
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects")
