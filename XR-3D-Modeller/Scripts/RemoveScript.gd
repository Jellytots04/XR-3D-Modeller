extends Node

signal objectRemoved
# Since this will always be attached to the right controller
@onready var controller = get_parent().get_parent()
@onready var raycast_3d = controller.get_node("RayCast3D")

# Flags
var triggerPressed = false
var is_active = false

# Scene Variables
var summonedObjects
var placed_vertices = []

# Select Variables
var currentSelectedObject
var selectIndex = 0 # Default Group select
var multiSelectHolder = [] # Holds the objects that are currently selected

# Highlighting Variables
var highlighting_cancelled = false
var highlighting = false
var remove_highlighting_cancelled = false
var remove_highlighting = false
var original_materials = {}
var true_materials = {}
var highlighted_object = null
var highlight_color = Color(0.833, 0.363, 0.379, 1.0) # Red highlight / Pinkish highlight
var selected_color = Color(0.913, 0.967, 0.331, 1.0) # When clicked on this is the color the object will assume

# Clear All variables
@onready var clear_confirmation = controller.get_node("RemoveAllProgressBar")
var is_holding_clear = false
var clear_cooldown_timer: float = 0.0
const CLEAR_COOLDOWN = 1.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects") # If there are any existing objects already then load, will be used later on for previous saves
	var summoner = get_node("../..") # Summoner is the main script and is and will be attached to the main user
	# print(summoner)
	summoner.connect("objectSummoned", Callable(self,  "update_list"))
	summoner.connect("verticeSummoned", Callable(self, "update_list"))
	var editor = get_node("../EditFunction")
	editor.connect("objectEdited", Callable(self, "update_list"))
	SaveManager.scene_loaded.connect(Callable(self, "update_list"))
	var ui_controllers = get_tree().get_nodes_in_group("ui_controller")
	if ui_controllers.size() > 0:
		var ui_controller = ui_controllers[0]
		# print("Hello from readying Remover")
		ui_controller.connect("change_page", Callable(self, "set_page_index"))
		ui_controller.connect("select_change", Callable(self, "select_index_change"))
		# print("UI Controller: ", ui_controller)
	clear_confirmation.clear_confirmed.connect(_on_clear_confirmed)
	clear_confirmation.hide_confirmation()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# print(controller.is_button_pressed("ax_button"))
	if is_active:
		
		if clear_cooldown_timer > 0:
			clear_cooldown_timer -= delta
		
		# Delete the selected objects
		if controller.is_button_pressed("ax_button") and not controller.is_button_pressed("by_button") and (currentSelectedObject or !multiSelectHolder.is_empty()):
			# print("Hello From remove Script")
			remove_object()
		update_highlighted_object()

		if controller.is_button_pressed("ax_button") and controller.is_button_pressed("by_button"):
			if not is_holding_clear and clear_cooldown_timer <= 0:
				clear_confirmation.start_holding()
				is_holding_clear = true
				AudioManager.haptic_continue(controller, 999.0, 0.5)
			return
		else:
			if is_holding_clear:
				clear_confirmation.stop_holding()
				is_holding_clear = false
				AudioManager.haptic_stop(controller)

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

		elif not controller.is_button_pressed("trigger_click"):
			triggerPressed = false

func _on_clear_confirmed():
	print("Clear all confirmed!")
	AudioManager.haptic_stop(controller)
	clear_all()
	is_holding_clear = false
	clear_cooldown_timer = CLEAR_COOLDOWN
	print("Timer started")

func clear_all():
	AudioManager.play_whoosh()
	
	for obj in get_tree().get_nodes_in_group("summonedObjects"):
		if is_instance_valid(obj):
			obj.queue_free()
			
	var main = get_tree().get_first_node_in_group("main_node")
	main.clear_ghosted("intersection_ghosts")
	main.clear_ghosted("subtraction_ghosts")
	
	currentSelectedObject = null
	highlighted_object = null
	multiSelectHolder.clear()
	true_materials.clear()
	original_materials.clear()
	
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects")
	emit_signal("objectRemoved")
	print("Scene cleared!")

func remove_object():
	AudioManager.haptic_medium(controller)
	if currentSelectedObject and (currentSelectedObject.is_in_group("intersection_ghosts") or currentSelectedObject.is_in_group("subtraction_ghosts")):
		AudioManager.play_whoosh()
		var main = get_tree().get_nodes_in_group("main_node")[0]
		main.delete_ghosted(currentSelectedObject)
		currentSelectedObject = null
		highlighted_object = null
		return
	
	if selectIndex == 0:
		AudioManager.play_whoosh()
		if currentSelectedObject and is_instance_valid(currentSelectedObject):
			var removed_obj = currentSelectedObject
			currentSelectedObject = null
			highlighted_object = null
			if is_instance_valid(removed_obj):
				removed_obj.queue_free()
			emit_signal("objectRemoved")
			summonedObjects = get_tree().get_nodes_in_group("summonedObjects")
	
	if selectIndex == 1:
		var combiners = []
		if !multiSelectHolder.is_empty():
			AudioManager.play_whoosh()
			for obj in multiSelectHolder:
				if is_instance_valid(obj):
					var combiner_parent = obj.get_parent() # Get the combiner
					if combiner_parent not in combiners: # Ensure the combiner is not already inside the array
						combiners.append(combiner_parent) # Add the unique combiner to the array
					obj.queue_free()
			
			await get_tree().process_frame # Ensure that the frame has passed and the above loop is processed
			
			for combiner in combiners: # If the combiner has no more children it shall be cleared
				if is_instance_valid(combiner) and combiner.get_child_count() == 0: # Check if there is no more children existing
					combiner.queue_free() 

			multiSelectHolder.clear()
			highlighted_object = null
			emit_signal("objectRemoved")
			summonedObjects = get_tree().get_nodes_in_group("summonedObjects")

	if selectIndex == 2:
		if currentSelectedObject and is_instance_valid(currentSelectedObject):
			AudioManager.play_whoosh()
			var removed_obj = currentSelectedObject
			var combiner = removed_obj.get_parent()
			currentSelectedObject = null
			highlighted_object = null
			var main = get_tree().get_nodes_in_group("main_node")[0]
			main.clear_ghost_for_original(removed_obj)
			removed_obj.queue_free()
			
			await get_tree().process_frame 
			if is_instance_valid(combiner) and combiner.get_child_count() == 0:
				combiner.queue_free()
			
			emit_signal("objectRemoved")
			summonedObjects = get_tree().get_nodes_in_group("summonedObjects")

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

func set_page_index(idx):
	# print("Hello from remove call index")
	if idx == 1:
		is_active = true
	else:
		clear_select(selectIndex) # Clear any selected objects in the scene
		is_active = false

func update_list():
	#print("Hello from remove script new object update signal")
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects")
	placed_vertices = get_tree().get_nodes_in_group("placedVertices")

# Add a clearance previous select on change
func select_index_change(idx):
	await clear_select(idx) # Clears and sets the new index
	
