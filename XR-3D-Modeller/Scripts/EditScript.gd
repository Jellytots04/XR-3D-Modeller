extends Node

signal objectEdited
signal selectedScale(value) # signal should send the current scale value for the UI

@onready var secondary_controller = get_parent().get_parent().get_parent().get_node("LeftHand") # Left Controller
@onready var controller = get_parent().get_parent() # Right Controller / Main Controller hence controller as the name
@onready var raycast_3d = controller.get_node("RayCast3D")
@onready var scaleCast = controller.get_node("BuildRayCast")

var orb_scene = preload("res://Scenes/orb_plane_scale.tscn")
var arrow_scene = preload("res://Scenes/arrow.tscn")

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
var highlighted_orb = null
var activeOrb = null
var scaleAxis
var scaleStartingDistance
var scaleStartingScale
var scaleStartingPosition
var scaleWorldAxis

# Plane Moving variables
var currentlyPlaneMoving
var planeMoveArrows = []
var highlighted_arrow = null
var activeArrow = null
var moveArrowAxis
var moveWorldAxis
var moveStartingPosition
var moveStartingPositionMulti = {}
var moveStartingDistance

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
		if editIndex == 0:
			if not currentlyPlaneMoving and not currentlyMoving:
				update_highlighted_arrow()
				
			if controller.is_button_pressed("grip_click"):
				if highlighted_arrow and not currentlyMoving:
					if not currentlyPlaneMoving:
						startPlaneMove()
						currentlyPlaneMoving = true
					planeMoveObject()
				
				elif not currentlyPlaneMoving:
					if selectIndex == 0 or selectIndex == 2:
						if currentSelectedObject:
							if not currentlyMoving:
								startMove()
								currentlyMoving = true
							moveObject(delta)
					
					elif selectIndex == 1 and not multiSelectHolder.is_empty():
						if not currentlyMoving:
							startMove()
							currentlyMoving = true
						moveObject(delta)
			else:
				if currentlyPlaneMoving:
					_remove_highlight(activeArrow)
					currentlyPlaneMoving = false
					activeArrow = null
					moveArrowAxis = Vector3.ZERO
					moveWorldAxis = Vector3.ZERO
					moveStartingDistance = 0.0
					moveStartingPosition = Vector3.ZERO
					moveStartingPositionMulti.clear()
					var obj = planeMoveTarget()
					if obj:
						spawnArrows(obj)
				
				if currentlyMoving:
					if highlighted_object:
						if selectIndex == 1:
							for obj in multiSelectHolder:
								reattach(obj, highlighted_object)
						else:
							reattach(currentSelectedObject, highlighted_object)
					
					spawnArrows(planeMoveTarget())
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

		if editIndex == 3:
			if selectIndex == 2 and currentSelectedObject:
				if not currentlyScaling:
					update_highlighted_orb()
				if controller.is_button_pressed("grip_click") and highlighted_orb:
					if not currentlyScaling:
						startScale()
						currentlyScaling = true
					plane_orb_scaling()

				else:
					if currentlyScaling:
						_remove_highlight(activeOrb)
						currentlyScaling = false
						activeOrb = null
						scaleAxis = Vector3.ZERO
						scaleWorldAxis = Vector3.ZERO
						scaleStartingDistance = 0.0
						scaleStartingScale = Vector3.ZERO
						scaleStartingPosition = Vector3.ZERO
				
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
						clearArrows()
						await _remove_highlight(deselct_object)

					elif not currentSelectedObject:
						# print("Hello new selected object", highlighted_object)
						currentSelectedObject = highlighted_object
						highlighted_object = null
						await _apply_highlight(currentSelectedObject, selected_color)
						if editIndex == 0:
							spawnArrows(currentSelectedObject)

				# Multiple selecting (Can select an infinite amount of objects)
				elif selectIndex == 1: # Multi Select
					triggerPressed = true
					# print("This will be multi select")
					if highlighted_object in multiSelectHolder:
						# print("Removing : ", highlighted_object, " : To the multiSelectHolder")
						var deselect_object = highlighted_object
						highlighted_object = null
						multiSelectHolder.erase(deselect_object)
						if multiSelectHolder.is_empty():
							clearArrows()
						await _remove_highlight(deselect_object)

					elif highlighted_object not in multiSelectHolder:
						_apply_highlight(highlighted_object, selected_color)
						multiSelectHolder.append(highlighted_object)
						currentSelectedObject = null
						if editIndex == 0:
							spawnArrows(multiSelectHolder[0])

				# Single object selecting (Select a single object at a time)
				elif selectIndex == 2: # Single Select
					triggerPressed = true
					# print("This will be single select")
					if currentSelectedObject == highlighted_object:
						# print("Object is no longer selected")
						var deselect_object = currentSelectedObject
						currentSelectedObject = null
						highlighted_object = null
						clearArrows()
						clearOrbs()
						await _remove_highlight(deselect_object)

					elif not currentSelectedObject:
						# print("Object is selected")
						currentSelectedObject = highlighted_object
						await _apply_highlight(currentSelectedObject, selected_color)
						
						if editIndex == 0: # Plane Moving
							spawnArrows(currentSelectedObject)

						if editIndex == 3: # Plane Scaling
							spawnPlaneOrbs(currentSelectedObject)

		elif not controller.is_button_pressed("trigger_click"):
			triggerPressed = false

# Stretching functions
# Main and secondary are both controllers
func startStretch(main, secondary):
	stretchDistance = main.distance_to(secondary)
	
	if stretchDistance < 0.05:
		currentlyStretching = false
		return
	
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
		
		newScale.x = clamp(newScale.x, 0.1, 10.0)
		newScale.y = clamp(newScale.y, 0.1, 10.0)
		newScale.z = clamp(newScale.z, 0.1, 10.0)
		currentSelectedObject.scale = newScale
		var avgScale = (newScale.x + newScale.y + newScale.z) / 3.0
		ui_controller._change_scale_value(Vector3(avgScale, avgScale, avgScale))

	if selectIndex == 1 and !multiSelectHolder.is_empty():
		for obj in multiSelectHolder:
			var newScale = startingScaleMulti[obj] * ratio
			newScale.x = clamp(newScale.x, 0.1, 10.0)
			newScale.y = clamp(newScale.y, 0.1, 10.0)
			newScale.z = clamp(newScale.z, 0.1, 10.0)
			obj.scale = newScale
		
	emit_signal("objectEdited")

# Moving functions
func startMove():
	if selectIndex == 0 or selectIndex == 2:
		moveOffset = WorldOptions.snap_vec(currentSelectedObject.global_position) - self.global_position # distance between object and controller
		moveBasis = self.global_transform.basis # starting basis for the object to rotate around
		# print(moveOffset)
	elif selectIndex == 1 and !multiSelectHolder.is_empty():
		for obj in multiSelectHolder:
			moveOffsetMulti[obj] = WorldOptions.snap_vec(obj.global_position) - self.global_position
		moveBasis = self.global_transform.basis

func moveObject(delta):
	var rotation = self.global_transform.basis * moveBasis.inverse()
	var offset_direction = -controller.global_transform.basis.z
	var joystick = controller.get_vector2("primary")
	if selectIndex == 0:
		# Moves the objects position based on the rotation and distance the controller has moved
		currentSelectedObject.global_position = WorldOptions.snap_vec(self.global_position + rotation * moveOffset)
		if abs(joystick.y) > 0.1:
			#print("Object is being pulled towards me : ", joystick.y)
			#print("offset direction : ", offset_direction)
			moveOffset += offset_direction * joystick.y * moveSpeed * delta
			#print("Moving objects location : ",currentSelectedObject.global_position)

	elif selectIndex == 2:
		# Moves the objects position based on the rotation and distance the controller has moved
		currentSelectedObject.global_position = WorldOptions.snap_vec(self.global_position + rotation * moveOffset)
		if abs(joystick.y) > 0.1:
			#print("Object is being pulled towards me : ", joystick.y)
			#print("offset direction : ", offset_direction)
			moveOffset += offset_direction * joystick.y * moveSpeed * delta
			#print("Moving objects location : ",currentSelectedObject.global_position)
		var original = get_ghost_original(currentSelectedObject)
		if original:
			original.global_position = currentSelectedObject.global_position

	elif selectIndex == 1 and !multiSelectHolder.is_empty():
		for obj in multiSelectHolder:
			obj.global_position = WorldOptions.snap_vec(self.global_position + rotation * moveOffsetMulti[obj])

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
	
	if selectIndex == 0:
		currentSelectedObject.global_transform.basis = rotation * objectStartingBasis

	elif selectIndex == 2:
		currentSelectedObject.global_transform.basis = rotation * objectStartingBasis
		var original = get_ghost_original(currentSelectedObject)
		if original:
			original.global_transform.basis = currentSelectedObject.global_transform.basis

	elif selectIndex == 1:
		for obj in multiSelectHolder:
			obj.global_transform.basis = rotation * objectStartingBasisMulti[obj]

	emit_signal("objectEdited")

# Plane Scaling functions
func startScale():
	print("Beginning of the scaling")
	print("current Scale : ", currentSelectedObject.scale)
	print("current Position : ", currentSelectedObject.global_position)
	activeOrb = highlighted_orb
	scaleAxis = activeOrb.get_meta("scale_axis")
	scaleStartingScale = currentSelectedObject.scale
	scaleStartingPosition = WorldOptions.snap_vec(currentSelectedObject.global_position)
	
	scaleWorldAxis = (currentSelectedObject.global_transform.basis.orthonormalized() * scaleAxis).normalized()
	scaleStartingDistance = controller.global_position.dot(scaleWorldAxis)

func plane_orb_scaling():
	print("Use this orb to SCALE!!!")
	if not is_instance_valid(currentSelectedObject) or not is_instance_valid(activeOrb):
		return

	var currentDistance = controller.global_position.dot(scaleWorldAxis)
	var delta = currentDistance - scaleStartingDistance
	var snapped_delta = WorldOptions.snap(delta* 10.0) / 10.0
	
	var newScale = scaleStartingScale
	if scaleAxis == Vector3.RIGHT:
		newScale.x = clamp(scaleStartingScale.x + snapped_delta * 10.0, 0.1, 10.0)
	elif scaleAxis == Vector3.UP:
		newScale.y = clamp(scaleStartingScale.y + snapped_delta * 10.0, 0.1, 10.0)
	elif scaleAxis == Vector3.FORWARD:
		newScale.z = clamp(scaleStartingScale.z + snapped_delta * 10.0, 0.1, 10.0)
		
	var scaleChange = newScale - scaleStartingScale
	var axis_component = scaleChange.x if scaleAxis == Vector3.RIGHT \
		else scaleChange.y if scaleAxis == Vector3.UP \
		else scaleChange.z
	currentSelectedObject.global_position = WorldOptions.snap_vec(scaleStartingPosition + scaleWorldAxis * (axis_component * 0.5))

	currentSelectedObject.scale = newScale
	updateOrbPositions(currentSelectedObject)
	
	var original = get_ghost_original(currentSelectedObject)
	if original:
		original.global_position = currentSelectedObject.global_position
		original.scale = currentSelectedObject.scale
	
	emit_signal("objectEdited")

func spawnPlaneOrbs(obj): # Spawn the orbs
	if obj == null:
		return
	clearOrbs()
	print("Spawning the orbs on this object : ", obj)
	var axes = [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD] # Directions
	for axis in axes:
		var orb = orb_scene.instantiate()
		get_tree().root.add_child(orb)
		orb.set_meta("scale_axis", axis)
		planeScalingOrbs.append(orb)
		print("Orb now exists : ", orb)
	updateOrbPositions(obj)

func updateOrbPositions(obj): # Update their positions once spawned
	var axes = [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD] # Directions
	for i in range(planeScalingOrbs.size()):
		var orb = planeScalingOrbs[i]
		if not is_instance_valid(orb):
			continue
		var world_offset = obj.global_transform.basis * axes[i]
		orb.global_position = obj.global_position + world_offset
		print("Orb has been moved to here : ", orb.global_position)

func clearOrbs(): # Remove the orbs from the world
	for orb in planeScalingOrbs:
		if is_instance_valid(orb):
			orb.queue_free()
	print("Removing the orbs")
	planeScalingOrbs.clear()

func update_highlighted_orb():
	var closest_orb = null
	
	if scaleCast.is_colliding():
		print("Orb has been hit")
		var obj = scaleCast.get_collider()
		for orb in planeScalingOrbs:
			if not is_instance_valid(orb):
				continue
			if obj == orb or orb.is_ancestor_of(obj):
				closest_orb = orb
				break
	
	if closest_orb == highlighted_orb:
		return
	
	if highlighted_orb != null and is_instance_valid(highlighted_orb):
		_remove_highlight(highlighted_orb)
	
	highlighted_orb = closest_orb
	if highlighted_orb != null:
		_apply_highlight(highlighted_orb, highlight_color)

# Plane moving functions
func spawnArrows(obj):
	if obj == null:
		return
	clearArrows()
	print("Summoning the arrows at : ", obj)
	var axes = [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD]
	for axis in axes:
		var arrow = arrow_scene.instantiate()
		get_tree().root.add_child(arrow)
		arrow.set_meta("move_axis", axis)
		planeMoveArrows.append(arrow)
	updateArrowPositions(obj)

func updateArrowPositions(obj):
	var axes = [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD]
	for i in range(planeMoveArrows.size()):
		var arrow= planeMoveArrows[i]
		if not is_instance_valid(arrow):
			continue
		var world_offset = axes[i]
		arrow.global_position = obj.global_position + world_offset

		var up = world_offset
		var forward = Vector3.FORWARD if abs(world_offset.dot(Vector3.FORWARD)) < 0.99 else Vector3.UP
		var right = up.cross(forward).normalized()
		forward = right.cross(up).normalized()
		arrow.global_transform.basis = Basis(right, up, -forward)

func clearArrows():
	for arrow in planeMoveArrows:
		if is_instance_valid(arrow):
			arrow.queue_free()
	print("Removing the arrows")
	planeMoveArrows.clear()

func update_highlighted_arrow():
	var closest_arrow = null
	
	if scaleCast.is_colliding(): # Can use the scaleCast raycast as it won't oppearate at the same time as each other
		var obj = scaleCast.get_collider()
		for arrow in planeMoveArrows:
			if not is_instance_valid(arrow):
				continue
			if obj == arrow or arrow.is_ancestor_of(obj):
				closest_arrow = arrow
				break
		
	if closest_arrow == highlighted_arrow:
		return
		
	if highlighted_arrow != null and is_instance_valid(highlighted_arrow):
		_remove_highlight(highlighted_arrow)
	
	highlighted_arrow = closest_arrow
	
	if highlighted_arrow != null:
		_apply_highlight(highlighted_arrow, highlight_color)

func planeMoveTarget():
	if selectIndex == 0 or selectIndex == 2:
		return currentSelectedObject
	elif selectIndex == 1 and not multiSelectHolder.is_empty():
		return multiSelectHolder[0]
	return null

func startPlaneMove():
	activeArrow = highlighted_arrow
	moveArrowAxis = activeArrow.get_meta("move_axis")
	
	var target = planeMoveTarget()
	moveStartingPosition = WorldOptions.snap_vec(target.global_position)
	moveWorldAxis = moveArrowAxis
	moveStartingDistance = controller.global_position.dot(moveWorldAxis)
	
	if selectIndex == 1:
		moveStartingPositionMulti.clear()
		for obj in multiSelectHolder:
			moveStartingPositionMulti[obj] = WorldOptions.snap_vec(obj.global_position)

func planeMoveObject():
	var target = planeMoveTarget()
	if target == null or not is_instance_valid(activeArrow):
		return
	
	var currentDistance = controller.global_position.dot(moveWorldAxis)
	var delta = (currentDistance - moveStartingDistance) * 10.0
	
	if selectIndex == 0:
		target.global_position = WorldOptions.snap_vec(moveStartingPosition + moveWorldAxis * delta)
		
	elif selectIndex == 2:
		target.global_position = WorldOptions.snap_vec(moveStartingPosition + moveWorldAxis * delta)
		var original = get_ghost_original(target)
		if original:
			original.global_position = target.global_position
	
	elif selectIndex == 1 and not multiSelectHolder.is_empty():
		for obj in multiSelectHolder:
			if is_instance_valid(obj):
				obj.global_position = WorldOptions.snap_vec(moveStartingPositionMulti[obj] + moveWorldAxis * delta)
	
	emit_signal("objectEdited")

# Highlighting Functions
func update_highlighted_object():
	# print("Ray update")
	if raycast_3d.is_colliding():
		var combiner = raycast_3d.get_collider()
		
		if combiner.is_in_group("intersection_ghosts") or combiner.is_in_group("subtraction_ghosts"):
			if combiner != highlighted_object:
				if highlighted_object and highlighted_object != currentSelectedObject:
					_remove_highlight(highlighted_object)
				highlighted_object = combiner
				if highlighted_object != currentSelectedObject:
					_apply_highlight(highlighted_object, highlight_color)
			return
		
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
	
	if obj.is_in_group("intersection_ghosts") or obj.is_in_group("subtraction_ghosts"):
		if not obj in true_materials:
			true_materials[obj] = obj.material
		if obj.material == null:
			return
		var mat = obj.material.duplicate()
		mat.albedo_color = color
		obj.material = mat
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
	
	if obj.is_in_group("intersection_ghosts") or obj.is_in_group("subtraction_ghosts"):
		if obj in true_materials:
			obj.material = true_materials[obj]
			true_materials.erase(obj)
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

# Intersection / Subtraction helper functions
func get_ghost_original(obj):
	var main = get_tree().get_nodes_in_group("main_node")[0]
	if obj.is_in_group("intersection_ghosts") or obj.is_in_group("subtraction_ghosts"):
		if obj in main.ghosted_mesh:
			return main.ghosted_mesh[obj]["original"]
	return null

# Called when a new select index is chosen
func clear_select(idx):
	if selectIndex == 0 or selectIndex == 2:
		var cleared_object = currentSelectedObject
		currentSelectedObject = null
		clearOrbs()
		clearArrows()
		_remove_highlight(cleared_object)

	if selectIndex == 1:
		clearOrbs()
		clearArrows()
		for child in multiSelectHolder:
			await _remove_highlight(child)
		multiSelectHolder.clear()

	selectIndex = idx

func scale_selected_object(value):
	if selectIndex == 0 or selectIndex == 2:
		if currentSelectedObject:
			var current = currentSelectedObject.scale
			var ratio = value / ((current.x + current.y + current.z) / 3.0)
			var newScale = current * ratio
			newScale.x = clamp(newScale.x, 0.01, 10.0)
			newScale.y = clamp(newScale.y, 0.01, 10.0)
			newScale.z = clamp(newScale.z, 0.01, 10.0)
			currentSelectedObject.scale = newScale

	if selectIndex == 1:
		if !multiSelectHolder.is_empty():
			for obj in multiSelectHolder:
				var current = obj.scale
				var ratio = value / ((current.x + current.y + current.z) / 3.0)
				var newScale = current * ratio
				newScale.x = clamp(newScale.x, 0.01, 10.0)
				newScale.y = clamp(newScale.y, 0.01, 10.0)
				newScale.z = clamp(newScale.z, 0.01, 10.0)
				obj.scale = newScale

func set_page_index(idx):
	# print("Hello from remove call index")
	clear_select(selectIndex)
	if idx == 2:
		is_active = true
	else:
		is_active = false

func set_edit_index(idx):
	print("Edit Called")
	clearArrows()
	clearOrbs()
	editIndex = idx
	spawnArrows(planeMoveTarget())
	spawnPlaneOrbs(currentSelectedObject)

func update_list():
	print("Hello from Edit script new object update signal")
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects")

# Add a clearance previous select on change
func select_index_change(idx):
	await clear_select(idx) # Clears and sets the new index
