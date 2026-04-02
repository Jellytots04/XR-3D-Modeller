extends Node3D

@onready var controller = get_parent().get_parent()
@onready var raycast_3d = controller.get_node("RayCast3D")

# Flags
var is_active = false
var triggerPressed = false

# Select variables
var currentSelectedObject

# Highlighting Variables
var highlighted_object
var highlight_color = Color(0.756, 0.453, 0.105, 1.0)
var selected_color = Color(0.913, 0.967, 0.331, 1.0)
var true_materials = {}
var original_materials = {}
var highlighting_cancelled = false
var remove_highlighting_cancelled = false
var highlighting
var remove_highlighting

# objects in scene
var summonedObjects = []
var meshInstances = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Controller: ", get_parent().get_parent())
	print("Raycast: ", raycast_3d)
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects")
	var summoner = get_node("../..")
	summoner.connect("objectSummoned", Callable(self, "update_list"))
	var editor = get_node("../EditFunction")
	editor.connect("objectEdited", Callable(self, "update_list"))
	var remover = get_node("../RemoveFunction")
	remover.connect("objectRemoved", Callable(self, "update_list"))
	var ui_controllers = get_tree().get_nodes_in_group("ui_controller")
	if ui_controllers.size() > 0:
		var ui_controller = ui_controllers[0]
		ui_controller.connect("change_page", Callable(self, "set_page_index"))
		ui_controller.connect("render_object", Callable(self, "render_selected"))
		print("Render Function connected to UI")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_active:
		update_highlighted_object()
	
		if controller.is_button_pressed("trigger_click") and not triggerPressed:
			triggerPressed = true
			if highlighted_object:
				if currentSelectedObject == highlighted_object:
					var deselect = currentSelectedObject
					currentSelectedObject = null
					highlighted_object = null
					await _remove_highlight(deselect)
				elif not currentSelectedObject:
					currentSelectedObject = highlighted_object
					highlighted_object = null
					await _apply_highlight(currentSelectedObject, selected_color)
		
		elif not controller.is_button_pressed("trigger_click"):
			triggerPressed = false

# Update highlighted object
func update_highlighted_object():
	if raycast_3d.is_colliding():
		var obj = raycast_3d.get_collider()

		if obj in summonedObjects and obj is CSGCombiner3D:
			if obj != highlighted_object:
				if highlighted_object and highlighted_object != currentSelectedObject:
					_remove_highlight(highlighted_object)
				highlighted_object = obj
				if highlighted_object != currentSelectedObject:
					_apply_highlight(highlighted_object, highlight_color)
		
		elif obj is MeshInstance3D:
			if obj != highlighted_object:
				if highlighted_object and highlighted_object != currentSelectedObject:
					_remove_highlight(highlighted_object)
				highlighted_object = obj
				if highlighted_object != currentSelectedObject:
					_apply_highlight(highlighted_object, highlight_color)
		else:
			if highlighted_object and highlighted_object != currentSelectedObject:
				_remove_highlight(highlighted_object)
			highlighted_object = null
	else:
		if highlighted_object and highlighted_object != currentSelectedObject:
			_remove_highlight(highlighted_object)
		highlighted_object = null

func _apply_highlight(obj, color):
	highlighting_cancelled = true
	await get_tree().process_frame
	
	highlighting_cancelled = false
	highlighting = true
	await _apply_highlight_recursive(obj, color)
	highlighting = false

func _apply_highlight_recursive(obj, color):
	if highlighting_cancelled or not is_instance_valid(obj):
		return
	if obj is CSGCombiner3D:
		for child in obj.get_children():
			if highlighting_cancelled:
				return
			await _apply_highlight_recursive(child, color)
	if obj is CSGMesh3D:
		if obj.mesh and obj.material:
			if not obj in true_materials:
				true_materials[obj] = obj.material
			var mat = obj.material.duplicate()
			mat.albedo_color = color
			obj.material = mat
			await get_tree().process_frame
			if not is_instance_valid(obj):
				return

	elif obj is MeshInstance3D:
		if obj.mesh:
			if not obj in true_materials:
				true_materials[obj] = obj.get_active_material(0)
			var mat = obj.get_active_material(0)
			if mat:
				var dup = mat.duplicate()
				dup.albedo_color = color
				obj.set_surface_override_material(0, dup)
			await get_tree().process_frame
			if not is_instance_valid(obj):
				return

func _remove_highlight(obj):
	remove_highlighting_cancelled = true
	await get_tree().process_frame
	remove_highlighting_cancelled = false
	remove_highlighting = true
	await _remove_highlight_recursive(obj)
	remove_highlighting = false

func _remove_highlight_recursive(obj):
	if not is_instance_valid(obj):
		return
	if obj is CSGCombiner3D:
		for child in obj.get_children():
			if remove_highlighting_cancelled:
				return
			if not is_instance_valid(child):
				continue
			await _remove_highlight_recursive(child)
	elif obj is CSGMesh3D:
		if obj in true_materials:
			obj.material = true_materials[obj]
			true_materials.erase(obj)
		await get_tree().process_frame
		if not is_instance_valid(obj):
			return
	elif obj is MeshInstance3D:
		if obj in true_materials:
			obj.set_surface_override_material(0, true_materials[obj])
			true_materials.erase(obj)
		await get_tree().process_frame
		if not is_instance_valid(obj):
			return

func set_page_index(idx):
	# Adjust index to match your Render tab position
	if idx == 5:
		is_active = true
		update_list()
	else:
		is_active = false

func update_list():
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects")
