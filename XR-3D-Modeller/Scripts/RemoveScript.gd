extends Node

signal objectRemoved
# Since this will always be attached to the right controller
@onready var controller = get_parent().get_parent()
@onready var raycast_3d = controller.get_node("RayCast3D")
@onready var selectCast_3d = controller.get_node("SelectRayCast")

# Flags
var triggerPressed = false
var is_active = false

# Scene Variables
var summonedObjects

# Select Variables
var currentSelectedObject
var selectIndex = 2 # Default Group select
var multiSelectHolder = [] # Holds the objects that are currently selected

# Highlighting Variables
var highlighting_cancelled = false
var highlighting = false
var remove_highlighting_cancelled = false
var remove_highlighting = false
var original_materials = {}
var highlighted_object = null
var highlight_color = Color(0.833, 0.363, 0.379, 1.0) # Red highlight / Pinkish highlight
var selected_color = Color(0.913, 0.967, 0.331, 1.0) # When clicked on this is the color the object will assume

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print(selectCast_3d.collision_mask)
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects") # If there are any existing objects already then load, will be used later on for previous saves
	var summoner = get_node("../..") # Later this path should reach the summon part of function tool node
	# print(summoner)
	summoner.connect("objectSummoned", Callable(self,  "update_list"))
	var ui_controllers = get_tree().get_nodes_in_group("ui_controller")
	if ui_controllers.size() > 0:
		var ui_controller = ui_controllers[0]
		print("Hello from readying Remover")
		var connected = ui_controller.connect("change_page", Callable(self, "set_page_index"))
		print("Connection made: ", connected)
		print("UI Controller: ", ui_controller)
	print("Players controller: ", controller)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# print(controller.is_button_pressed("ax_button"))
	if is_active:
		if controller.is_button_pressed("ax_button"):
			# print("Hello From remove Script")
			remove_object()
		update_highlighted_object()

		# If the user clicks / presses right trigger on an highlighted object it will become the selected object
		if controller.is_button_pressed("trigger_click") and !triggerPressed: # This is group select aka entire object because highlighted_object will be the CSGCombiner
			if highlighted_object:
				if selectIndex == 0:
					print("This is Group / All select")
					# Release trigger / click
					if currentSelectedObject == highlighted_object:
						# print("Goodbye previous selected object", currentSelectedObject)
						_remove_highlight(currentSelectedObject)
						currentSelectedObject = null

					elif not currentSelectedObject:
						# print("Hello new selected object", highlighted_object)
						currentSelectedObject = highlighted_object
						# print(currentSelectedObject, highlighted_object)
						_remove_highlight(currentSelectedObject) # Remove any previous highlighting
						_select_highlighted_object(currentSelectedObject)
						# print(currentSelectedObject.scale)
						# Select case for ensuring the object is selected
					triggerPressed = true

				elif selectIndex == 1: # Multi Select
					print("This will be multi select")
					if currentSelectedObject == highlighted_object:
						# print("Goodbye previous selected object", currentSelectedObject)
						_remove_highlight(currentSelectedObject)
						currentSelectedObject = null

					elif not currentSelectedObject:
						# print("Hello new selected object", highlighted_object)
						currentSelectedObject = highlighted_object
						# print(currentSelectedObject, highlighted_object)
						_remove_highlight(currentSelectedObject) # Remove any previous highlighting
						_select_highlighted_object(currentSelectedObject)
						# print(currentSelectedObject.scale)
						# Select case for ensuring the object is selected
					triggerPressed = true

				elif selectIndex == 2: # Single Select
					print("This will be single select")
					if currentSelectedObject == highlighted_object:
						_remove_highlight(currentSelectedObject)
						currentSelectedObject = null

					elif not currentSelectedObject:
						currentSelectedObject = highlighted_object
						
						_remove_highlight(currentSelectedObject)
						_select_highlighted_object(currentSelectedObject)
					triggerPressed = true

		elif not controller.is_button_pressed("trigger_click"):
			triggerPressed = false

func _select_highlighted_object(obj):
	print("Highlighting this new object : ")
	_apply_highlight(obj, selected_color)

func update_highlighted_object():
	# print("Ray update")
	if raycast_3d.is_colliding():
		if selectIndex == 0:
			print("For Group / All select")
			var obj = raycast_3d.get_collider()
			if obj in summonedObjects:
				if obj != highlighted_object:
					if highlighted_object:
						_remove_highlight(highlighted_object)
					highlighted_object = obj
					if highlighted_object != currentSelectedObject:
						_apply_highlight(highlighted_object, highlight_color)

		else:
			# print("For Multi and Single selecting")
			var combiner = raycast_3d.get_collider()
			if combiner in summonedObjects:
				var hit_point = raycast_3d.get_collision_point()
				var selected_obj = null # Object holder variable

				for child in combiner.get_children():
					if child is CSGMesh3D:
						var aabb = child.get_aabb()
						var global_aabb = child.global_transform * aabb
						if global_aabb.has_point(hit_point):
							selected_obj = child
							break

				#if selected_obj == null: # If the AABB doesn't work reuse the distance formula
					#print("Using distance formula")
					#var closest_dist = INF
					#for child in combiner.get_children():
						#var dist = child.global_transform.origin.distance_to(hit_point)
						#if dist < closest_dist:
							#closest_dist = dist
							#selected_obj = child
				if selected_obj != null:
					currentSelectedObject = selected_obj
					print("Selected this child : ", currentSelectedObject)
				else:
					print("No child has been found here")

	else:
		if highlighted_object and highlighted_object != currentSelectedObject:
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
		
	var mesh_inst = null
	
	if obj is CSGCombiner3D:
		for child in obj.get_children():
			if highlighting_cancelled:
				return
			await _apply_highlight_recursive(child, color)
	
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
	
	if obj is CSGCombiner3D:
		for child in obj.get_children():
			return
		await _remove_highlight_recursive(obj)
		
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

func remove_object():
	if highlighted_object and highlighted_object.is_in_group("summonedObjects"):
		# Clean up highlight first if you want
		# Remove the actual instance from scene
		highlighted_object.queue_free()
		highlighted_object.remove_from_group("summonedObjects")
		highlighted_object = null
		emit_signal("objectRemoved")
		summonedObjects = get_tree().get_nodes_in_group("summonedObjects") # Update the list
		# print(summonedObjects)

func set_page_index(idx):
	# print("Hello from remove call index")
	if idx == 1:
		is_active = true
	else:
		is_active = false

func update_list():
	print("Hello from remove script new object update signal")
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects")
