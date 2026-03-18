extends Node

signal objectEdited
signal selectedScale(value) # signal should send the current scale value for the UI

@onready var secondary_controller = get_parent().get_parent().get_parent().get_node("LeftHand") # Left Controller
@onready var controller = get_parent().get_parent() # Right Controller / Main Controller hence controller as the name
@onready var raycast_3d = controller.get_node("RayCast3D")

var orb_scene = preload("res://Scenes/orb_plane_scale.tscn")

# Flags
var triggerPressed = false # Flag to signal if the trigger has been clicked
var is_active = false
var currentlyMoving = false
var currentlyStretching = false
var currentlyRotating = false

# Moving variables
var moveOffset
var moveOffsetMulti = {}
var moveBasis
var moveSpeed = 2.0 # Variable to direct how fast the object will move towards the user using the joystick
# var currentlyMovingObject # to prevent the user from moving another object when raycast hits new object

# Stretching varibales
var stretchDistance # holds the value between the two controllers to be compared for stretching
var startingScale # holds the starting scale of the object before the scale changes
var startingScaleMulti = {}

# Scene and UI variables
var summonedObjects
var editIndex # holds the current index value the user has selected
var ui_controller # holds the Controller node to allow edits to be made

# Select variables
var currentSelectedObject # for when the user clicks a specific object
var selectIndex = 0 # Default selcet all (Combiner select)
var multiSelectHolder = []

# Rotation variables
var startingBasis
var objectStartingBasis
var objectStartingBasisMulti = {}

# Plane Currently Scaling
var currentlyScaling
var planeScalingOrbs = []

# Highlighting variables
var highlighting_cancelled = false
var highlighting = false
var remove_highlighting_cancelled = false
var remove_highlighting = false
var original_materials = {}
var true_materials = {}
var highlighted_object = null
var highlight_color = Color(0.587, 0.944, 0.536, 1.0) # Red highlight / Pinkish highlight
var selected_color = Color(0.913, 0.967, 0.331, 1.0) # When clicked on this is the color the object will assume
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects") # If there are any existing objects already then load, will be used later on for previous saves
	var summoner = get_node("../..") # Later this path should reach the summon part of function tool node
	# print(summoner)
	summoner.connect("objectSummoned", Callable(self,  "update_list"))
	var remover = get_node("../RemoveFunction")
	remover.connect("objectRemoved", Callable(self, "update_list"))
	var ui_controllers = get_tree().get_nodes_in_group("ui_controller")
	if ui_controllers.size() > 0:
		ui_controller = ui_controllers[0]
		print("Hello from readying Remover")
		ui_controller.connect("edit_selected", Callable(self, "set_edit_index"))
		ui_controller.connect("change_page", Callable(self, "set_page_index"))
		ui_controller.connect("scaleSize", Callable(self, "scale_selected_object"))
		ui_controller.connect("select_change", Callable(self, "select_index_change"))
		print("UI Controller: ", ui_controller)
	print("Players controller: ", controller)

func _process(delta: float) -> void:
	# Allows this script to be ran
	if is_active:
		if controller.is_button_pressed("grip_click") and editIndex == 0: # Moving object only with raycast, default index
			if selectIndex == 0 or selectIndex == 2:
				if currentSelectedObject:
					if not currentlyMoving:
						startMove()
						currentlyMoving = true
					# print("Grip is active")
					moveObject(delta)

			elif selectIndex == 1 and !multiSelectHolder.is_empty():
				if not currentlyMoving:
					startMove()
					currentlyMoving = true
				moveObject(delta)
		else:
			if currentlyMoving and highlighted_object:
				if selectIndex == 1:
					for obj in multiSelectHolder:
						reattach(obj, highlighted_object)
				else:
					reattach(currentSelectedObject, highlighted_object)
			currentlyMoving = false

		if controller.is_button_pressed("grip_click") and secondary_controller.is_button_pressed("grip_click") and editIndex == 1: # Stretch the object when gripping controllers and pulling outwards or inwards, second / first index value
			if selectIndex == 0 or selectIndex == 2:
				if currentSelectedObject:
					if not currentlyStretching:
						startStretch(controller.global_position, secondary_controller.global_position)
						currentlyStretching = true
						# print("Distance from stretching process : ", stretchDistance)
					stretchObject(controller.global_position, secondary_controller.global_position)
				elif selectIndex == 1 and !multiSelectHolder.is_empty():
					if not currentlyStretching:
						startStretch(controller.global_position, secondary_controller.global_position)
						currentlyStretching = true
					stretchObject(controller.global_position, secondary_controller.global_position)
		else:
			currentlyStretching = false

		if controller.is_button_pressed("grip_click") and editIndex == 2: # Rotating objects around their own center
			# print("Welcome the rotaters to the party")
			if selectIndex == 0 or selectIndex == 2:
				if currentSelectedObject:
					if not currentlyRotating:
						startRotate()
						currentlyRotating = true
					_rotateObject()
					
			elif selectIndex == 1 and not multiSelectHolder.is_empty():
				if not currentlyRotating:
					startRotate()
					currentlyRotating = true
				_rotateObject()
		else:
			if currentlyRotating:
				objectStartingBasisMulti.clear()
			currentlyRotating = false

		if controller.is_button_pressed("grip_click") and editIndex == 3:
			if selectIndex == 2 and currentSelectedObject:
				if not currentlyScaling:
					plane_orb_scaling()

		else:
			if currentlyScaling:
				currentlyScaling = false

		update_highlighted_object()

		# If the user clicks / presses right trigger on an highlighted object it will become the selected object
		if controller.is_button_pressed("trigger_click") and !triggerPressed: # This is group select aka entire object because highlighted_object will be the CSGCombiner
			if highlighted_object:
				# Group selecting (Entire CSGCombiner included)
				if selectIndex == 0:
					triggerPressed = true
					# print("This is Group / All select")
					# Release trigger / click
					if currentSelectedObject == highlighted_object:
						# print("Goodbye previous selected object", currentSelectedObject)
						var deselct_object = currentSelectedObject
						currentSelectedObject = null
						highlighted_object = null
						await _remove_highlight(deselct_object)

					elif not currentSelectedObject:
						# print("Hello new selected object", highlighted_object)
						currentSelectedObject = highlighted_object
						highlighted_object = null
						await _apply_highlight(currentSelectedObject, selected_color)

				# Multiple selecting (Can select an infinite amount of objects)
				elif selectIndex == 1: # Multi Select
					triggerPressed = true
					# print("This will be multi select")
					if highlighted_object in multiSelectHolder:
						# print("Removing : ", highlighted_object, " : To the multiSelectHolder")
						var deselect_object = highlighted_object
						highlighted_object = null
						multiSelectHolder.erase(deselect_object)
						await _remove_highlight(deselect_object)

					elif highlighted_object not in multiSelectHolder:
						# print("Adding : ", highlighted_object, " : To the multiSelectHolder")
						# print("Hello new selected object", highlighted_object)
						# print(currentSelectedObject, highlighted_object)
						# _remove_highlight(currentSelectedObject) # Remove any previous highlighting
						_apply_highlight(highlighted_object, selected_color)
						multiSelectHolder.append(highlighted_object)
						# print(currentSelectedObject.scale)
						# Select case for ensuring the object is selected
						currentSelectedObject = null

				# Single object selecting (Select a single object at a time)
				elif selectIndex == 2: # Single Select
					triggerPressed = true
					# print("This will be single select")
					if currentSelectedObject == highlighted_object:
						# print("Object is no longer selected")
						var deselect_object = currentSelectedObject
						currentSelectedObject = null
						highlighted_object = null
						await _remove_highlight(deselect_object)

					elif not currentSelectedObject:
						# print("Object is selected")
						currentSelectedObject = highlighted_object
						await _apply_highlight(currentSelectedObject, selected_color)
						if editIndex == 3:
							spawnPlaneOrbs(currentSelectedObject)

		elif not controller.is_button_pressed("trigger_click"):
			triggerPressed = false

# Stretching functions
# Main and secondary are both controllers
func startStretch(main, secondary):
	stretchDistance = main.distance_to(secondary)
	if selectIndex == 0 or selectIndex == 2:
		startingScale = currentSelectedObject.scale
	
	elif selectIndex == 1 and !multiSelectHolder.is_empty():
		for obj in multiSelectHolder:
			startingScaleMulti[obj] = obj.scale

# Main and secondary are both controllers and obj is the currently selected object
func stretchObject(main, secondary):
	var currentDistance = main.distance_to(secondary)
	# Return if controllers aren't separated
	if stretchDistance == 0:
		return

	var ratio = currentDistance / stretchDistance
	
	if selectIndex == 0 or selectIndex == 2:
		var newScale = startingScale * ratio
		
		newScale = (newScale * 10).round() / 10
		
		newScale = newScale.clamp(Vector3.ONE * 0.1, Vector3.ONE * 2.0)
		currentSelectedObject.scale = newScale
		ui_controller._change_scale_value(currentSelectedObject.scale)

	if selectIndex == 1 and !multiSelectHolder.is_empty():
		for obj in multiSelectHolder:
			var newScale = startingScaleMulti[obj] * ratio
			newScale = (newScale * 10).round() / 10
			newScale = newScale.clamp(Vector3.ONE * 0.1, Vector3.ONE * 2.0)
			obj.scale = newScale
		
	emit_signal("objectEdited")

# Moving functions
func startMove():
	if selectIndex == 0 or selectIndex == 2:
		moveOffset = currentSelectedObject.global_position - self.global_position # distance between object and controller
		moveBasis = self.global_transform.basis # starting basis for the object to rotate around
		# print(moveOffset)
	elif selectIndex == 1 and !multiSelectHolder.is_empty():
		for obj in multiSelectHolder:
			moveOffsetMulti[obj] = obj.global_position - self.global_position
		moveBasis = self.global_transform.basis

func moveObject(delta):
	var rotation = self.global_transform.basis * moveBasis.inverse()
	var offset_direction = -controller.global_transform.basis.z
	var joystick = controller.get_vector2("primary")
	if selectIndex == 0 or selectIndex == 2:
		# Moves the objects position based on the rotation and distance the controller has moved
		currentSelectedObject.global_position = self.global_position + rotation * moveOffset
		if abs(joystick.y) > 0.1:
			#print("Object is being pulled towards me : ", joystick.y)
			#print("offset direction : ", offset_direction)
			moveOffset += offset_direction * joystick.y * moveSpeed * delta
			#print("Moving objects location : ",currentSelectedObject.global_position)

	elif selectIndex == 1 and !multiSelectHolder.is_empty():
		for obj in multiSelectHolder:
			obj.global_position = self.global_position + rotation * moveOffsetMulti[obj]

			if abs(joystick.y) > 0.1:
				moveOffsetMulti[obj] += offset_direction * joystick.y * moveSpeed * delta

	emit_signal("objectEdited")

# Reattach functions
func reattach(obj, combiner):
	print("Reattach this object : ", obj, " : to the new object : ", combiner)
	var target_combiner
	if combiner is CSGCombiner3D:
		target_combiner = combiner
	elif combiner is CSGMesh3D:
		target_combiner = combiner.get_parent() as CSGCombiner3D

	# Fail safe incase the 
	if target_combiner == null:
		# print("The target attaching too is not a combiner nor is not tied to a combiner")
		return

	if obj is CSGMesh3D:
		var old_combiner = obj.get_parent() as CSGCombiner3D
		if old_combiner == target_combiner:
			# print("This is already the combiner of this object")
			return
		
		var obj_transform = obj.global_transform
		old_combiner.remove_child(obj)
		target_combiner.add_child(obj)
		obj.global_transform = obj_transform
		await no_children_left(old_combiner) # Function for later

	elif obj is CSGCombiner3D:
		if obj == target_combiner:
			print("This is me!!")
			return
		
		for child in obj.get_children():
			var obj_transform = child.global_transform
			obj.remove_child(child)
			target_combiner.add_child(child)
			child.global_transform = obj_transform
		
		await no_children_left(obj)
	
	emit_signal("objectEdited")

func no_children_left(combiner):
	if combiner.get_child_count() == 0:
		combiner.queue_free()
		# print("MY CHILDREN ARE GONE")

# Rotation functions
func startRotate():
	# print("Begin the rotations!")
	startingBasis = controller.global_transform.basis
	if selectIndex == 0 or selectIndex == 2:
		# print("Take the object at hand's BASIS!!")
		objectStartingBasis = currentSelectedObject.global_transform.basis
	
	elif selectIndex == 1:
		for obj in multiSelectHolder:
			objectStartingBasisMulti[obj] = obj.global_transform.basis

func _rotateObject():
	var rotation = controller.global_transform.basis * startingBasis.inverse()
	
	if selectIndex == 0 or selectIndex == 2:
		currentSelectedObject.global_transform.basis = rotation * objectStartingBasis
	
	elif selectIndex == 1:
		for obj in multiSelectHolder:
			obj.global_transform.basis = rotation * objectStartingBasisMulti[obj]

	emit_signal("objectEdited")

# Plane Scaling functions
func plane_orb_scaling():
	print("Summoning the Orbs")

func spawnPlaneOrbs(obj):
	print("Spawning the orbs on this object : ", obj)
	var axes = [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD] # Directions
	for axis in axes:
		var orb = orb_scene.instantiate()
		get_tree().root.add_child(orb)
		orb.set_meta("scale_axis", axis)
		planeScalingOrbs.append(orb)
		print("Orb now exists : ", orb)
	

# Highlighting Functions
func update_highlighted_object():
	# print("Ray update")
	if raycast_3d.is_colliding():
		var combiner = raycast_3d.get_collider()
		if selectIndex == 0:
			if combiner in summonedObjects:
				if combiner != highlighted_object:
					if highlighted_object and highlighted_object != currentSelectedObject:
						_remove_highlight(highlighted_object)
					highlighted_object = combiner
					if highlighted_object != currentSelectedObject:
						_apply_highlight(highlighted_object, highlight_color)

		else:
			# print("For Multi and Single selecting")
			if combiner in summonedObjects:
				var hit_point = raycast_3d.get_collision_point()
				var selected_obj = null # Object holder variable
				
				var closest_obj = null
				var closest_dist = INF

				for child in combiner.get_children():
					if child is CSGMesh3D:
						var aabb = child.get_aabb()
						var local_hit = child.global_transform.affine_inverse() * hit_point
						if aabb.has_point(local_hit):
							var world_center = child.global_transform * aabb.get_center()
							var dist = world_center.distance_to(hit_point)
							var world_size = (child.global_transform.basis * aabb.size).length()
							var normalised_dist = dist / world_size if world_size > 0.0 else dist
							if normalised_dist < closest_dist:
								closest_dist = normalised_dist
								closest_obj = child

				if closest_obj != null:
					selected_obj = closest_obj

				if selected_obj != null:
					if selectIndex == 2 and highlighted_object and highlighted_object != currentSelectedObject: # Checking for single select
						_remove_highlight(highlighted_object)
					
					elif selectIndex == 1 and highlighted_object not in multiSelectHolder:
						_remove_highlight(highlighted_object)
					
					highlighted_object = selected_obj
					
					if selectIndex == 2 and highlighted_object != currentSelectedObject:
						_apply_highlight(highlighted_object, highlight_color)
					elif selectIndex == 1 and highlighted_object not in multiSelectHolder:
						_apply_highlight(highlighted_object, highlight_color) 
					# print("Selected this child : ", currentSelectedObject)

	else:
		if highlighted_object:
			if selectIndex == 0 and highlighted_object != currentSelectedObject:
				_remove_highlight(highlighted_object)
			if selectIndex == 2 and highlighted_object != currentSelectedObject:
				_remove_highlight(highlighted_object)
			elif selectIndex == 1 and highlighted_object not in multiSelectHolder:
				_remove_highlight(highlighted_object)
		highlighted_object = null

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
	
	if not is_instance_valid(obj):
		return
	
	var mesh_inst = null
	
	if obj is CSGCombiner3D:
		for child in obj.get_children():
			if highlighting_cancelled:
				return
			await _apply_highlight_recursive(child, color)
	
	if obj is CSGMesh3D:
		# print("obj is a CSGMesh3D")
		mesh_inst = obj
		
		if mesh_inst.mesh:
			
			if not mesh_inst in true_materials:
				true_materials[mesh_inst] = mesh_inst.material
			
			original_materials[mesh_inst] = mesh_inst.material
			if mesh_inst.material:
				var mat = mesh_inst.material.duplicate()
				mat.albedo_color = color
				mesh_inst.material = mat
			
			# Will pause after applying material to reduce lag
			await get_tree().process_frame
			if not is_instance_valid(obj):
				return
		else:
			print("No Mesh resource found on CSGMesh3D!")

		if obj.get_children():
			for child in obj.get_children():
				if highlighting_cancelled:
					return
				if not is_instance_valid(child):
					continue
				await _apply_highlight_recursive(child, color)
	
	elif obj.has_node("CSGMesh3D"):
		# print("OBJ has a CSGMesh3D")
		mesh_inst = obj.get_node("CSGMesh3D")
		
		if mesh_inst.mesh:

			if not mesh_inst in true_materials:
				true_materials[mesh_inst] = mesh_inst.material

			original_materials[mesh_inst] = mesh_inst.material
			if mesh_inst.material:
				var mat = mesh_inst.material.duplicate()
				mat.albedo_color = color
				mesh_inst.material = mat
				
			await get_tree().process_frame
			if not is_instance_valid(obj):
				return
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
	
	if not is_instance_valid(obj):
			return

	var mesh_inst = null
	
	if obj is CSGCombiner3D:
		for child in obj.get_children():
			if remove_highlighting_cancelled:
				return
			if not is_instance_valid(child):
				continue
			await _remove_highlight_recursive(child)
		
	elif obj is CSGMesh3D:
		mesh_inst = obj
		
		if mesh_inst.mesh:
			if mesh_inst in true_materials:
				mesh_inst.material = true_materials[mesh_inst]
				if not currentSelectedObject:
					true_materials.erase(mesh_inst)
					original_materials.erase(mesh_inst)
				
			await get_tree().process_frame
			if not is_instance_valid(obj):
				return

		if obj.get_children():
			for child in obj.get_children():
				if remove_highlighting_cancelled:
					return
				await _remove_highlight_recursive(child)
				
	elif obj.has_node("CSGMesh3D"):
		mesh_inst = obj.get_node("CSGMesh3D")
		
		if mesh_inst.mesh:
			if mesh_inst in true_materials:
				mesh_inst.material = true_materials[mesh_inst]
				if not currentSelectedObject:
					true_materials.erase(mesh_inst)
					original_materials.erase(mesh_inst)
				
			await get_tree().process_frame
			if not is_instance_valid(obj):
				return

# Called when a new select index is chosen
func clear_select(idx):
	if selectIndex == 0 or selectIndex == 2:
		var cleared_object = currentSelectedObject
		currentSelectedObject = null
		_remove_highlight(cleared_object)
	
	if selectIndex == 1:
		for child in multiSelectHolder:
			await _remove_highlight(child)
		multiSelectHolder.clear()

	selectIndex = idx

func scale_selected_object(value):
	# print("New scale size should be: ", value)
	if selectIndex == 0 or selectIndex == 2:
		if currentSelectedObject:
			currentSelectedObject.scale = value * Vector3.ONE
	
	if selectIndex == 1:#
		if !multiSelectHolder.is_empty():
			for obj in multiSelectHolder:
				obj.scale = value * Vector3.ONE

func set_page_index(idx):
	# print("Hello from remove call index")
	if idx == 2:
		is_active = true
	else:
		clear_select(selectIndex) # Clear any previously selected after changing index
		is_active = false

func set_edit_index(idx):
	print("Edit Called")
	editIndex = idx

func update_list():
	print("Hello from Edit script new object update signal")
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects")

# Add a clearance previous select on change
func select_index_change(idx):
	await clear_select(idx) # Clears and sets the new index
