extends Node

# Signls going out
signal objectEdited

# onready variables used, controllers, raycast3d
@onready var secondary_controller = get_parent().get_parent().get_parent().get_node("LeftHand") # Left Controller
@onready var controller = get_parent().get_parent() # Right Controller / Main Controller hence controller as the name
@onready var raycast_3d = controller.get_node("RayCast3D")
@onready var scaleCast = controller.get_node("BuildRayCast")

# Preload scenes for Moving, Scaling and Rotating
var orb_scene = preload("res://Scenes/orb_plane_scale.tscn")
var arrow_scene = preload("res://Scenes/arrow.tscn")
var torus_scene = preload("res://Scenes/torus_rotation_plane.tscn")

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
var planeScaleGizmo = []
var highlighted_orb = null
var highlighted_gizmo_orb = null
var activeOrb = null
var activeGizmoOrb = null
var scaleAxis
var scaleStartingDistance
var scaleStartingScale
var scaleStartingPosition
var scaleWorldAxis

# Plane Moving variables
var currentlyPlaneMoving
var planeMoveArrows = []
var planeMoveGizmo = []
var highlighted_arrow = null
var highlighted_gizmo_arrow = null
var activeArrow = null
var activeGizmoArrow = null
var moveArrowAxis
var moveWorldAxis
var moveStartingPosition
var moveStartingPositionMulti = {}
var moveStartingDistance

# Plane Rotation variables
var planeRotationTorus = []
var highlighted_torus = null
var activeTorus = null
var rotationWorldAxis = Vector3.ZERO
var currentlyPlaneRotating
var rotaitonStartingBasis
var rotationObjectStartingBasis
var rotationObjectStartingBasisMulti = {}

# CSG Operation variables
var current_operation = 0

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
	summoner.connect("objectSummoned", Callable(self,  "update_list"))
	var remover = get_node("../RemoveFunction")
	remover.connect("objectRemoved", Callable(self, "update_list"))
	SaveManager.scene_loaded.connect(Callable(self, "update_list"))
	var ui_controllers = get_tree().get_nodes_in_group("ui_controller")
	if ui_controllers.size() > 0:
		ui_controller = ui_controllers[0]
		ui_controller.connect("edit_selected", Callable(self, "set_edit_index"))
		ui_controller.connect("change_page", Callable(self, "set_page_index"))
		ui_controller.connect("scaleSize", Callable(self, "scale_selected_object"))
		ui_controller.connect("select_change", Callable(self, "select_index_change"))
		ui_controller.connect("csg_operation", Callable(self, "change_csg_operation"))

func _process(delta: float) -> void:
	# Allows this script to be ran
	if is_active:
		if editIndex == 0: # Move functiojnality
			if not currentlyPlaneMoving and not currentlyMoving:
				update_highlighted_arrow()
			# Grip allowing you to move
			if controller.is_button_pressed("grip_click"):
				# Move object with gizmo or the arrows that appear on the object
				if (highlighted_gizmo_arrow or highlighted_arrow) and not currentlyMoving:
					if not currentlyPlaneMoving:
						# Start the plane movement
						startPlaneMove()
						currentlyPlaneMoving = true
					# Plane movement functionality
					planeMoveObject()
				# Using the arrows or free move
				elif not currentlyPlaneMoving:
					if selectIndex == 0 or selectIndex == 2:
						if currentSelectedObject:
							if not currentlyMoving:
								startMove()
								currentlyMoving = true
							moveObject(delta)
					
					# Multi select holder mode
					elif selectIndex == 1 and not multiSelectHolder.is_empty():
						if not currentlyMoving:
							startMove()
							currentlyMoving = true
						moveObject(delta)
			else:
				# After release play audio and remove the highlights and clear variables
				if currentlyPlaneMoving:
					AudioManager.play_place_down()
					
					if activeGizmoArrow:
						_remove_highlight(activeGizmoArrow)
					if activeArrow:
						_remove_highlight(activeArrow)
					
					_remove_highlight(activeArrow)
					currentlyPlaneMoving = false
					activeArrow = null
					activeGizmoArrow = null
					moveArrowAxis = Vector3.ZERO
					moveWorldAxis = Vector3.ZERO
					moveStartingDistance = 0.0
					moveStartingPosition = Vector3.ZERO
					moveStartingPositionMulti.clear()
					var obj = planeMoveTarget()
					if obj:
						updateArrowPositions(obj)
				# Placing it down with free move
				if currentlyMoving:
					
					AudioManager.haptic_stop(controller)
					
					# If hovering on release reattach the object
					if highlighted_object:
						AudioManager.play_snap()
						if selectIndex == 1: # Reattach all objects and nodes
							for obj in multiSelectHolder:
								reattach(obj, highlighted_object)
						else:# Reattach normally
							reattach(currentSelectedObject, highlighted_object)
							if selectIndex == 0 and currentSelectedObject is CSGCombiner3D:
								var target_combiner = highlighted_object
								if highlighted_object is CSGMesh3D:
									target_combiner = highlighted_object.get_parent()
								currentSelectedObject = target_combiner
								await _apply_highlight(currentSelectedObject, selected_color)
					else:
						AudioManager.play_place_down()

					AudioManager.haptic_stop(controller)
					
					# Re Plane MoveTarget
					var obj = planeMoveTarget()
					if obj:
						updateArrowPositions(obj)
					currentlyMoving = false
		
		# Stretch condition
		if controller.is_button_pressed("grip_click") and secondary_controller.is_button_pressed("grip_click") and editIndex == 1: # Stretch the object when gripping controllers and pulling outwards or inwards, second / first index value
			if selectIndex == 0 or selectIndex == 2:
				if currentSelectedObject:
					if not currentlyStretching: # Start stretching for regular object 
						startStretch(controller.global_position, secondary_controller.global_position)
						currentlyStretching = true
					stretchObject(controller.global_position, secondary_controller.global_position)
				elif selectIndex == 1 and !multiSelectHolder.is_empty(): # Multi stretch
					if not currentlyStretching:
						startStretch(controller.global_position, secondary_controller.global_position)
						currentlyStretching = true
					stretchObject(controller.global_position, secondary_controller.global_position)
		else: # Release the haptics on both controller at end of stretch
			if currentlyStretching:
				AudioManager.haptic_stop(controller)
				AudioManager.haptic_stop(secondary_controller)
			currentlyStretching = false

		# Rotation condition
		if editIndex == 2:
			if not currentlyRotating and not currentlyPlaneRotating:
				update_highlighted_torus()
			# Check if the user grips while hovering an torus index start rotation
			if controller.is_button_pressed("grip_click"):
				if selectIndex == 0 or selectIndex == 2:
					if currentSelectedObject:
						if highlighted_torus and not currentlyRotating:
							if not currentlyPlaneRotating:
								startPlaneRotate()
								currentlyPlaneRotating = true
							planeRotateObject()
						elif not currentlyPlaneRotating:
							if not currentlyRotating:
								startRotate()
								currentlyRotating = true
							_rotateObject()
				# Rotation condition for multi select
				elif selectIndex == 1 and not multiSelectHolder.is_empty():
					if highlighted_torus and not currentlyRotating:
						if not currentlyPlaneRotating:
							startPlaneRotate()
							currentlyPlaneRotating = true
						planeRotateObject()
					elif not currentlyPlaneRotating:
						if not currentlyRotating:
							startRotate()
							currentlyRotating = true
						_rotateObject()
			else: # Release of rotations
				if currentlyPlaneRotating:
					AudioManager.haptic_stop(controller)
					_remove_highlight(activeTorus)
					currentlyPlaneRotating = false
					activeTorus = null
					rotationWorldAxis = Vector3.ZERO
					rotationObjectStartingBasisMulti.clear()
				if currentlyRotating:
					AudioManager.haptic_stop(controller)
					objectStartingBasisMulti.clear()
				currentlyRotating = false

		# Plane Scaling condition
		if editIndex == 3:
			# Only works for Single select
			if selectIndex == 2 and currentSelectedObject:
				if not currentlyScaling:
					update_highlighted_orb()
				if controller.is_button_pressed("grip_click") and (highlighted_orb or highlighted_gizmo_orb):
					if not currentlyScaling:
						startScale()
						currentlyScaling = true
					plane_orb_scaling()
				else:
					if currentlyScaling:
						if activeGizmoOrb:
							_remove_highlight(activeGizmoOrb)
						if activeOrb:
							_remove_highlight(activeOrb)
						currentlyScaling = false
						activeOrb = null
						activeGizmoOrb = null
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
						clearMoveGizmo()
						clearRotationTorus()
						await _remove_highlight(deselct_object)

					elif not currentSelectedObject:
						# print("Hello new selected object", highlighted_object)
						currentSelectedObject = highlighted_object
						highlighted_object = null
						await _apply_highlight(currentSelectedObject, selected_color)
						if editIndex == 0:
							spawnArrows(currentSelectedObject)
						if editIndex == 2:
							spawnRotationToruses()

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
							clearMoveGizmo()
							clearRotationTorus()
						await _remove_highlight(deselect_object)

					elif highlighted_object not in multiSelectHolder:
						_apply_highlight(highlighted_object, selected_color)
						multiSelectHolder.append(highlighted_object)
						currentSelectedObject = null
						if editIndex == 0:
							spawnArrows(multiSelectHolder[0])
							
						if editIndex == 2:
							spawnRotationToruses()

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
						clearMoveGizmo()
						clearOrbs()
						clearScaleGizmo()
						clearRotationTorus()
						await _remove_highlight(deselect_object)

					elif not currentSelectedObject:
						# print("Object is selected")
						currentSelectedObject = highlighted_object
						await _apply_highlight(currentSelectedObject, selected_color)
						
						if editIndex == 0: # Plane Moving
							spawnArrows(currentSelectedObject)

						if editIndex == 3: # Plane Scaling
							spawnPlaneOrbs(currentSelectedObject)
							
						if editIndex == 2: # Plane Rotation
							spawnRotationToruses()

		elif not controller.is_button_pressed("trigger_click"):
			triggerPressed = false

# Stretching functions
# Main and secondary are both controllers
func startStretch(main, secondary):
	# Grabs the starting stretch distance
	stretchDistance = main.distance_to(secondary)
	
	# To ensure the stretching has a bit of wiggle room to not start stretching
	if stretchDistance < 0.05:
		currentlyStretching = false
		return
	
	# Begin haptics
	AudioManager.haptic_continue(controller, 999.0, 0.3)
	AudioManager.haptic_continue(secondary_controller, 999.0, 0.3)
	
	# Starting scale of the objects scale for Single and Group
	if selectIndex == 0 or selectIndex == 2:
		startingScale = currentSelectedObject.scale
	
	# Starting scale of the multi select
	elif selectIndex == 1 and !multiSelectHolder.is_empty():
		for obj in multiSelectHolder:
			startingScaleMulti[obj] = obj.scale

# Main and secondary are both controllers and obj is the currently selected object
func stretchObject(main, secondary):
	# Grab the current distance
	var currentDistance = main.distance_to(secondary)
	# Return if controllers aren't separated
	if stretchDistance == 0:
		return

	# Get the ratio of the distance by the stretch distance
	var ratio = currentDistance / stretchDistance
	
	if selectIndex == 0 or selectIndex == 2:
		var newScale = startingScale * ratio
		
		# Clamp the scale to not be bigger than 10.0 and less than 1.0
		newScale.x = clamp(newScale.x, 0.1, 10.0)
		newScale.y = clamp(newScale.y, 0.1, 10.0)
		newScale.z = clamp(newScale.z, 0.1, 10.0)
		currentSelectedObject.scale = newScale
		var avgScale = (newScale.x + newScale.y + newScale.z) / 3.0
		ui_controller._change_scale_value(Vector3(avgScale, avgScale, avgScale))

	# Clamp the scale
	if selectIndex == 1 and !multiSelectHolder.is_empty():
		for obj in multiSelectHolder:
			var newScale = startingScaleMulti[obj] * ratio
			newScale.x = clamp(newScale.x, 0.1, 10.0)
			newScale.y = clamp(newScale.y, 0.1, 10.0)
			newScale.z = clamp(newScale.z, 0.1, 10.0)
			obj.scale = newScale
		
	# Emit edit signal
	emit_signal("objectEdited")

# Moving functions
func startMove():
	# Move function begin
	AudioManager.haptic_continue(controller, 999.0, 0.25)
	# Grab the offset of the moving object 
	if selectIndex == 0 or selectIndex == 2:
		moveOffset = WorldOptions.snap_vec(currentSelectedObject.global_position) - self.global_position # distance between object and controller
		moveBasis = self.global_transform.basis # starting basis for the object to rotate around
		# print(moveOffset)
	# Same for Multi select
	elif selectIndex == 1 and !multiSelectHolder.is_empty():
		for obj in multiSelectHolder:
			moveOffsetMulti[obj] = WorldOptions.snap_vec(obj.global_position) - self.global_position
		moveBasis = self.global_transform.basis

# Move the object function
func moveObject(delta):
	# Grab the objets rotation and offset.
	var rotation = self.global_transform.basis * moveBasis.inverse()
	var offset_direction = -controller.global_transform.basis.z
	var joystick = controller.get_vector2("primary")
	# Group select movement for joystick and object
	if selectIndex == 0:
		# Moves the objects position based on the rotation and distance the controller has moved
		currentSelectedObject.global_position = WorldOptions.snap_vec(self.global_position + rotation * moveOffset)
		if abs(joystick.y) > 0.1:
			#print("Object is being pulled towards me : ", joystick.y)
			#print("offset direction : ", offset_direction)
			# Offset the objet with move speed direction and joystick
			moveOffset += offset_direction * joystick.y * moveSpeed * delta
			#print("Moving objects location : ",currentSelectedObject.global_position)
	# Single select move object 
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

	# multi select move object 
	elif selectIndex == 1 and !multiSelectHolder.is_empty():
		for obj in multiSelectHolder:
			obj.global_position = WorldOptions.snap_vec(self.global_position + rotation * moveOffsetMulti[obj])

			if abs(joystick.y) > 0.1:
				moveOffsetMulti[obj] += offset_direction * joystick.y * moveSpeed * delta

	# Edited signal
	emit_signal("objectEdited")

# Reattach object to new combiner parent
func reattach(obj, combiner):
	# Reattach the object
	var target_combiner
	if combiner is CSGCombiner3D:
		target_combiner = combiner
	elif combiner is CSGMesh3D:
		target_combiner = combiner.get_parent() as CSGCombiner3D

	# Fail safe incase the target is empty
	if target_combiner == null:
		return
	
	# If the obj is a CSGMesh3D simply add it 
	if obj is CSGMesh3D:
		var old_combiner = obj.get_parent() as CSGCombiner3D
		if old_combiner == target_combiner:
			return
		
		var obj_transform = obj.global_transform
		old_combiner.remove_child(obj)
		target_combiner.add_child(obj)
		obj.global_transform = obj_transform
		# Check if the combiner has nay children left
		await no_children_left(old_combiner)

	# If the obj is a combiner (with group select)
	elif obj is CSGCombiner3D:
		if obj == target_combiner:
			return
		
		for child in obj.get_children():
			var obj_transform = child.global_transform
			obj.remove_child(child)
			target_combiner.add_child(child)
			child.global_transform = obj_transform
		
		await no_children_left(obj)
	# Signal out
	emit_signal("objectEdited")

# Release the object with no more children
func no_children_left(combiner):
	if combiner.get_child_count() == 0:
		combiner.queue_free()

# Rotation functions
func startRotate():
	# Rotate the object opening variables
	AudioManager.haptic_continue(controller, 999.0, 0.3)
	startingBasis = controller.global_transform.basis
	# Grab starting rotations
	if selectIndex == 0 or selectIndex == 2:
		objectStartingBasis = currentSelectedObject.global_transform.basis
	
	elif selectIndex == 1:
		for obj in multiSelectHolder:
			objectStartingBasisMulti[obj] = obj.global_transform.basis

# Rotate the objects
func _rotateObject():
	# Grab the rotation done by the controller
	var rotation = controller.global_transform.basis * startingBasis.inverse()
	var euler = rotation.get_euler()
	# Get the snapped euler rotation
	var snapped_euler = Vector3(
		WorldOptions.snap_angle(euler.x),
		WorldOptions.snap_angle(euler.y),
		WorldOptions.snap_angle(euler.z)
	)
	
	var snapped_rotation = Basis.from_euler(snapped_euler)
	
	# Group select rotation
	if selectIndex == 0:
		var current_scale = currentSelectedObject.scale
		currentSelectedObject.global_transform.basis = snapped_rotation * objectStartingBasis.inverse()
		currentSelectedObject.scale = current_scale
	
	# Single select rotation
	elif selectIndex == 2:
		var current_scale = currentSelectedObject.scale
		currentSelectedObject.global_transform.basis = snapped_rotation * objectStartingBasis.inverse()
		var original = get_ghost_original(currentSelectedObject)
		if original:
			original.global_transform.basis = currentSelectedObject.global_transform.basis
			original.scale = current_scale

	# Multi select rotations
	elif selectIndex == 1:
		for obj in multiSelectHolder:
			var current_scale = obj.scale
			obj.global_transform.basis = snapped_rotation * objectStartingBasisMulti[obj]
			obj.scale = current_scale

	# Emit the signal
	emit_signal("objectEdited")

# Plane Scaling functions
func startScale():
	# Starting scale 
	if highlighted_gizmo_orb:
		activeGizmoOrb = highlighted_gizmo_orb
		scaleAxis = activeGizmoOrb.get_meta("scale_axis")
	elif highlighted_orb:
		activeOrb = highlighted_orb
		scaleAxis = activeOrb.get_meta("scale_axis")
	
	# Grab the objects starting scale
	scaleStartingScale = currentSelectedObject.scale
	scaleStartingPosition = WorldOptions.snap_vec(currentSelectedObject.global_position)
	
	# Scale to the world axis
	scaleWorldAxis = (currentSelectedObject.global_transform.basis.orthonormalized() * scaleAxis).normalized()
	scaleStartingDistance = controller.global_position.dot(scaleWorldAxis)

# Orb scaling
func plane_orb_scaling():
	# Checks to see if the currently selected object is still an instance 
	if not is_instance_valid(currentSelectedObject):
		return
	if not is_instance_valid(activeGizmoOrb) and not is_instance_valid(activeOrb):
		return

	# Grab the current distance between the orbs
	var currentDistance = controller.global_position.dot(scaleWorldAxis)
	var delta = currentDistance - scaleStartingDistance
	var snapped_delta = WorldOptions.snap(delta* 10.0) / 10.0
	
	# New scale is set
	var newScale = scaleStartingScale
	# Grabs the rotation and clamps between 10.0 and 10.0
	if scaleAxis == Vector3.RIGHT:
		newScale.x = clamp(scaleStartingScale.x + snapped_delta * 10.0, 0.1, 10.0)
	elif scaleAxis == Vector3.UP:
		newScale.y = clamp(scaleStartingScale.y + snapped_delta * 10.0, 0.1, 10.0)
	elif scaleAxis == Vector3.FORWARD:
		newScale.z = clamp(scaleStartingScale.z + snapped_delta * 10.0, 0.1, 10.0)
		
	# Gets the changed scale
	var scaleChange = newScale - scaleStartingScale
	var axis_component = scaleChange.x if scaleAxis == Vector3.RIGHT \
		else scaleChange.y if scaleAxis == Vector3.UP \
		else scaleChange.z
	currentSelectedObject.global_position = WorldOptions.snap_vec(scaleStartingPosition + scaleWorldAxis * (axis_component * 0.5))

	# Sets the objects new scale
	currentSelectedObject.scale = newScale
	# Update the position of orbs 
	updateOrbPositions(currentSelectedObject)
	
	# Grabs the original
	var original = get_ghost_original(currentSelectedObject)
	if original:
		original.global_position = currentSelectedObject.global_position
		original.scale = currentSelectedObject.scale
	
	# Emit the signal
	emit_signal("objectEdited")

# Spawn the plane scaling orbs
func spawnPlaneOrbs(obj):
	if obj == null:
		return
	clearOrbs()
	
	# set the axes and colors for the orbs 
	var axes = [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD]
	var colors = [Color(0.937, 0.267, 0.267, 0.95), Color(0.063, 0.725, 0.506, 0.95), Color(0.231, 0.510, 0.965, 0.95)]
	
	# loop through the axes and place the orbs down
	for i in range(axes.size()):
		var orb = orb_scene.instantiate()
		get_tree().root.add_child(orb)
		orb.set_meta("scale_axis", axes[i])
		
		if orb is CSGMesh3D:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = colors[i]
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			orb.material = mat
		
		planeScalingOrbs.append(orb)
	# Update the orb positions
	updateOrbPositions(obj)
	
	spawnScaleGizmo()

# Spawns the scale gizmo
func spawnScaleGizmo():
	clearScaleGizmo()
	
	# Same thing as scale orbs but for the orb gizmo
	var axes = [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD]
	var colors = [Color(0.937, 0.267, 0.267, 0.95), Color(0.063, 0.725, 0.506, 0.95), Color(0.231, 0.510, 0.965, 0.95)]
	
	for i in range(axes.size()):
		var orb = orb_scene.instantiate()
		get_tree().root.add_child(orb)
		orb.set_meta("scale_axis", axes[i])
		
		if orb is CSGMesh3D:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = colors[i]
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			orb.material = mat
		
		planeScaleGizmo.append(orb)
	
	updateScaleGizmoPosition()
	
# Updating scaling gizmo 
func updateScaleGizmoPosition():
	var spawn_pos = controller.global_transform.origin + -controller.global_transform.basis.z * 0.5
	
	 # Same as scale orb
	var axes = [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD]
	for i in range(planeScaleGizmo.size()):
		var orb = planeScaleGizmo[i]
		if not is_instance_valid(orb):
			continue
		
		var offset = axes[i] * 0.2
		orb.global_position = spawn_pos + offset
		
# Clear scale gizmo
func clearScaleGizmo():
	# Clear the orb gizmos
	for orb in planeScaleGizmo:
		if is_instance_valid(orb):
			orb.queue_free()
	planeScaleGizmo.clear()
	highlighted_gizmo_orb = null
	activeGizmoOrb = null

# Update the orb positions
func updateOrbPositions(obj): # Update their positions once spawned
	var axes = [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD] # Directions
	for i in range(planeScalingOrbs.size()):
		var orb = planeScalingOrbs[i]
		if not is_instance_valid(orb):
			continue
		var world_offset = obj.global_transform.basis * axes[i]
		orb.global_position = obj.global_position + world_offset

# Clear the regular orbs
func clearOrbs(): # Remove the orbs from the world
	for orb in planeScalingOrbs:
		if is_instance_valid(orb):
			orb.queue_free()
	planeScalingOrbs.clear()

# Highlighting feature for the orb objects
func update_highlighted_orb():
	var closest_orb = null
	var closest_gizmo_orb = null
	
	if scaleCast.is_colliding():
		# print("Orb has been hit")
		var obj = scaleCast.get_collider()
		
		for orb in planeScaleGizmo:
			if not is_instance_valid(orb):
				continue
			if obj == orb or orb.is_ancestor_of(obj):
				closest_gizmo_orb = orb
				break
		
		if not closest_gizmo_orb:
			for orb in planeScalingOrbs:
				if not is_instance_valid(orb):
					continue
				if obj == orb or orb.is_ancestor_of(obj):
					closest_orb = orb
					break
	
	if closest_gizmo_orb != highlighted_gizmo_orb:
		if highlighted_gizmo_orb and is_instance_valid(highlighted_gizmo_orb):
			_remove_highlight(highlighted_gizmo_orb)
		highlighted_gizmo_orb = closest_gizmo_orb
		if highlighted_gizmo_orb:
			_apply_highlight(highlighted_gizmo_orb, highlight_color)
	
	if closest_orb != highlighted_orb:
		if highlighted_orb and is_instance_valid(highlighted_orb):
			_remove_highlight(highlighted_orb)
		highlighted_orb = closest_orb
		if highlighted_orb:
			_apply_highlight(highlighted_orb, highlight_color)

# Plane moving functions
func spawnArrows(obj):
	if obj == null:
		return
	clearArrows()
	
	# Same as scale orb
	var axes = [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD]
	var colors = [Color(0.937, 0.267, 0.267, 0.95), Color(0.063, 0.725, 0.506, 0.95), Color(0.231, 0.510, 0.965, 0.95)]
	
	for i in range(axes.size()):
		var arrow = arrow_scene.instantiate()
		get_tree().root.add_child(arrow)
		arrow.set_meta("move_axis", axes[i])

		if arrow is CSGMesh3D:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = colors[i]
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			arrow.material = mat

		planeMoveArrows.append(arrow)
	updateArrowPositions(obj)
	
	spawnMoveGizmo()

func spawnMoveGizmo():
	# Same as Orb gizmo
	clearMoveGizmo()
	var axes = [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD]
	var colors = [Color(0.937, 0.267, 0.267, 0.95), Color(0.063, 0.725, 0.506, 0.95), Color(0.231, 0.510, 0.965, 0.95)]
	
	for i in range(axes.size()):
		var arrow = arrow_scene.instantiate()
		get_tree().root.add_child(arrow)
		arrow.set_meta("move_axis", axes[i])
		
		if arrow is CSGMesh3D:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = colors[i]
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			arrow.material = mat
		
		planeMoveGizmo.append(arrow)
	
	updateMoveGizmoPosition()

# Same as scale orbs functions but for moving gizmos
func updateMoveGizmoPosition():
	var spawn_pos = controller.global_transform.origin + -controller.global_transform.basis.z * 0.05
	
	var axes = [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD]
	for i in range(planeMoveGizmo.size()):
		var arrow = planeMoveGizmo[i]
		if not is_instance_valid(arrow):
			continue
		
		var world_offset = axes[i] * 0.7
		arrow.global_position = spawn_pos + world_offset
		
		var up = axes[i]
		var forward = Vector3.FORWARD if abs(up.dot(Vector3.FORWARD)) < 0.99 else Vector3.UP
		var right = up.cross(forward).normalized()
		forward = right.cross(up).normalized()
		arrow.global_transform.basis = Basis(right, up, -forward)

# Clear move gizmo object
func clearMoveGizmo():
	for arrow in planeMoveGizmo:
		if is_instance_valid(arrow):
			arrow.queue_free()
	planeMoveGizmo.clear()
	highlighted_gizmo_arrow = null
	activeGizmoArrow = null

# Update the arrows positions after moving
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

# Clear the arrows
func clearArrows():
	for arrow in planeMoveArrows:
		if is_instance_valid(arrow):
			arrow.queue_free()
	planeMoveArrows.clear()

# Update the highlighted arrow 
func update_highlighted_arrow():
	var closest_arrow = null
	var closest_gizmo_arrow = null
	
	if scaleCast.is_colliding(): # Can use the scaleCast raycast as it won't oppearate at the same time as each other
		var obj = scaleCast.get_collider()
		
		for arrow in planeMoveGizmo:
			if not is_instance_valid(arrow):
				continue
			if obj == arrow or arrow.is_ancestor_of(obj):
				closest_gizmo_arrow = arrow
				break
		if not closest_gizmo_arrow:
			for arrow in planeMoveArrows:
				if not is_instance_valid(arrow):
					continue
				if obj == arrow or arrow.is_ancestor_of(obj):
					closest_arrow = arrow
					break
	
	if closest_gizmo_arrow != highlighted_gizmo_arrow:
		if highlighted_gizmo_arrow and is_instance_valid(highlighted_gizmo_arrow):
			_remove_highlight(highlighted_gizmo_arrow)
		highlighted_gizmo_arrow = closest_gizmo_arrow
		if highlighted_gizmo_arrow:
			_apply_highlight(highlighted_gizmo_arrow, highlight_color)

	if closest_arrow != highlighted_arrow:
		if highlighted_arrow and is_instance_valid(highlighted_arrow):
			_remove_highlight(highlighted_arrow)
		highlighted_arrow = closest_arrow
		if highlighted_arrow:
			_apply_highlight(highlighted_arrow, highlight_color)

# Plane move target for specifying what object is selected
func planeMoveTarget():
	if selectIndex == 0 or selectIndex == 2:
		return currentSelectedObject
	elif selectIndex == 1 and not multiSelectHolder.is_empty():
		return multiSelectHolder[0]
	return null

# Starting function for plane move object
func startPlaneMove():
	if highlighted_gizmo_arrow:
		activeGizmoArrow = highlighted_gizmo_arrow
		moveArrowAxis = activeGizmoArrow.get_meta("move_axis")
	elif highlighted_arrow:
		activeArrow = highlighted_arrow
		moveArrowAxis = activeArrow.get_meta("move_axis")
	
	var target = planeMoveTarget()
	
	if not target or not is_instance_valid(target):
		currentlyPlaneMoving = false
		return
	
	moveStartingPosition = WorldOptions.snap_vec(target.global_position)
	moveWorldAxis = moveArrowAxis
	moveStartingDistance = controller.global_position.dot(moveWorldAxis)
	
	if selectIndex == 1:
		moveStartingPositionMulti.clear()
		for obj in multiSelectHolder:
			if is_instance_valid(obj):
				moveStartingPositionMulti[obj] = WorldOptions.snap_vec(obj.global_position)

# Plane move the selected object
func planeMoveObject():
	var target = planeMoveTarget()
	if target == null or not is_instance_valid(target):
		return
	
	if not is_instance_valid(activeGizmoArrow) and not is_instance_valid(activeArrow):
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
		
		if not combiner or not is_instance_valid(combiner):
			if highlighted_object and highlighted_object != currentSelectedObject:
				_remove_highlight(highlighted_object)
			highlighted_object = null
			return

		if combiner.is_in_group("intersection_ghosts") or combiner.is_in_group("subtraction_ghosts"):
			if selectIndex != 2:
				if highlighted_object and highlighted_object != currentSelectedObject:
					_remove_highlight(highlighted_object)
				highlighted_object = null
				return

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

# Spawn the rotation torus gizmo 
func spawnRotationToruses():
	# Same as orb gizmo spawn
	clearRotationTorus()
	var axes = [Vector3.RIGHT, Vector3.UP, Vector3.FORWARD]
	var colors = [Color(0.937, 0.267, 0.267, 0.95), Color(0.063, 0.725, 0.506, 0.95), Color(0.231, 0.510, 0.965, 0.95)]
	
	for i in range(axes.size()):
		var torus = torus_scene.instantiate()
		get_tree().root.add_child(torus)
		torus.set_meta("rotation_axis", axes[i])
		
		if torus is CSGMesh3D:
			var mat = StandardMaterial3D.new()
			mat.albedo_color = colors[i]
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			torus.material = mat
		
		planeRotationTorus.append(torus)
	updateTorusPosition()

# Torus rotation gizmo same as plane orb scaling function 
func updateTorusPosition():
	var spawn_pos = controller.global_transform.origin + -controller.global_transform.basis.z * 0.5
	for i in range(planeRotationTorus.size()):
		var torus = planeRotationTorus[i]
		if not is_instance_valid(torus):
			continue
		torus.global_position = spawn_pos
		# Rotates based on euler basis and rotates according to the controllers rotation as well as which torus is selected
		match i:
			0:
				torus.global_transform.basis = Basis.from_euler(Vector3(0, 0, PI/2))
			1:
				torus.global_transform.basis = Basis.from_euler(Vector3(0, 0, 0))
			2:
				torus.global_transform.basis = Basis.from_euler(Vector3(PI/2, 0, 0))
		torus.scale = Vector3.ONE * 0.15

# Clear rotation torus'
func clearRotationTorus():
	for torus in planeRotationTorus:
		if is_instance_valid(torus):
			torus.queue_free()
	planeRotationTorus.clear()
	highlighted_torus = null
	activeTorus = null

# Update the highlighted torus
func update_highlighted_torus():
	var closest_torus = null
	if scaleCast.is_colliding():
		var obj = scaleCast.get_collider()
		for torus in planeRotationTorus:
			if not is_instance_valid(torus):
				continue
			if obj == torus or torus.is_ancestor_of(obj):
				closest_torus = torus
				break
	if closest_torus == highlighted_torus:
		return
	if highlighted_torus != null and is_instance_valid(highlighted_torus):
		_remove_highlight(highlighted_torus)
	highlighted_torus = closest_torus
	if highlighted_torus != null:
		_apply_highlight(highlighted_torus, highlight_color)

# Start the plane rotations
func startPlaneRotate():
	
	AudioManager.haptic_continue(controller, 999.0, 0.3)
	# Grabs the active torus
	activeTorus = highlighted_torus
	var axis = activeTorus.get_meta("rotation_axis")
	rotationWorldAxis = axis
	rotaitonStartingBasis = controller.global_transform.basis
	# Grabs the starting rotation basis from the currently selected object 
	if selectIndex == 0 or selectIndex == 2:
		rotationObjectStartingBasis = currentSelectedObject.global_transform.basis
	elif selectIndex == 1:
		# Grabs all the starting rotation of the selected objects 
		rotationObjectStartingBasisMulti.clear()
		for obj in multiSelectHolder:
			rotationObjectStartingBasisMulti[obj] = obj.global_transform.basis

# Plane rotation object 
func planeRotateObject():
	if not is_instance_valid(activeTorus):
		return
	# Grabs the current rotation
	var rotation_delta = controller.global_transform.basis * rotaitonStartingBasis.inverse()
	var angle = rotation_delta.get_euler().dot(rotationWorldAxis)
	var snapped_angle = WorldOptions.snap_angle(angle)
	var snap_rotation = Basis(rotationWorldAxis, snapped_angle)
	
	# Using snap rotation snap the object accordingly
	if selectIndex == 0 or selectIndex == 2:
		currentSelectedObject.global_transform.basis = snap_rotation * rotationObjectStartingBasis
		var original = get_ghost_original(currentSelectedObject)
		if original:
			original.global_transform.basis = currentSelectedObject.global_transform.basis
	# Using Single select snap all of the starting rotations by the snap rotaiton
	elif selectIndex == 1:
		for obj in multiSelectHolder:
			obj.global_transform.basis = snap_rotation * rotationObjectStartingBasisMulti[obj]
	
	# Emit edited signal
	emit_signal("objectEdited")

# Intersection / Subtraction helper functions
func get_ghost_original(obj):
	# Get the ghost' original, for editing ghost objects
	var main = get_tree().get_nodes_in_group("main_node")[0]
	if obj.is_in_group("intersection_ghosts") or obj.is_in_group("subtraction_ghosts"):
		if obj in main.ghosted_mesh:
			return main.ghosted_mesh[obj]["original"]
	return null

# Called when a new select index is chosen
# Calls clearing functions
func clear_select(idx):
	if selectIndex == 0 or selectIndex == 2:
		var cleared_object = currentSelectedObject
		currentSelectedObject = null
		clearOrbs()
		clearScaleGizmo()
		clearArrows()
		clearMoveGizmo()
		clearRotationTorus()
		_remove_highlight(cleared_object)

	if selectIndex == 1:
		clearOrbs()
		clearScaleGizmo()
		clearArrows()
		clearMoveGizmo()
		clearRotationTorus()
		for child in multiSelectHolder:
			await _remove_highlight(child)
		multiSelectHolder.clear()

	selectIndex = idx

# Scale selected
func scale_selected_object(value):
	# For signel and group select change the objects new scale
	if selectIndex == 0 or selectIndex == 2:
		if currentSelectedObject:
			var current = currentSelectedObject.scale
			var ratio = value / ((current.x + current.y + current.z) / 3.0)
			var newScale = current * ratio
			newScale.x = clamp(newScale.x, 0.01, 10.0)
			newScale.y = clamp(newScale.y, 0.01, 10.0)
			newScale.z = clamp(newScale.z, 0.01, 10.0)
			currentSelectedObject.scale = newScale

	# For multi select change the objects in the arrays scale
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

# Change the selected objects current CSG Operation
func change_csg_operation(idx):
	if not is_active:
		return
	
	# Grab the current opreation selected
	current_operation = idx
	
	# If on Single select and an object is selected change the object CSG operation
	if selectIndex == 2 and currentSelectedObject:
		if currentSelectedObject is CSGMesh3D:
			currentSelectedObject.operation = idx
			
			# Match the chosen index' CSG operation
			match idx:
				CSGShape3D.OPERATION_UNION:
					AudioManager.play_place_down()
				CSGShape3D.OPERATION_INTERSECTION:
					AudioManager.play_snap()
				CSGShape3D.OPERATION_SUBTRACTION:
					AudioManager.play_whoosh()
			
			# Get the original ghost after edit
			var original = get_ghost_original(currentSelectedObject)
			if original:
				original.operation = idx
				
			emit_signal("objectEdited")

func set_page_index(idx):
	clear_select(selectIndex)
	if idx == 2:
		is_active = true
	else:
		is_active = false

func set_edit_index(idx):
	clearArrows()
	clearMoveGizmo()
	clearOrbs()
	clearScaleGizmo()
	clearRotationTorus()
	editIndex = idx
	if idx == 0:
		spawnArrows(planeMoveTarget())
	elif idx == 2:
		if currentSelectedObject:
			spawnRotationToruses()
	elif idx == 3:
		if selectIndex == 2:
			spawnPlaneOrbs(currentSelectedObject)
	var floating_hud = get_tree().get_first_node_in_group("floating_hud")
	if floating_hud:
		floating_hud.update_edit_tool(idx)

func update_list():
	# print("Hello from Edit script new object update signal")
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects")

# Add a clearance previous select on change
func select_index_change(idx):
	await clear_select(idx) # Clears and sets the new index
