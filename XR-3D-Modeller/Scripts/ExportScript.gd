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
	SaveManager.scene_loaded.connect(Callable(self, "update_list"))
	var ui_controllers = get_tree().get_nodes_in_group("ui_controller")
	if ui_controllers.size() > 0:
		var ui_controller = ui_controllers[0]
		ui_controller.connect("change_page", Callable(self, "set_page_index"))
		ui_controller.connect("render_object", Callable(self, "render_selected"))
		ui_controller.connect("export_object", Callable(self, "export_selected"))
		ui_controller.connect("export_obj_file", Callable(self, "export_obj_selected"))
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

func render_selected():
	if not currentSelectedObject or not is_instance_valid(currentSelectedObject):
		print("Nothing selected to render")
		ToastManager.error("Render Failed", "No object selected")
		return
	
	var original = currentSelectedObject
	currentSelectedObject = null
	highlighted_object = null
	await _remove_highlight(original)
	
	var mesh: Mesh = null
	
	if original is CSGCombiner3D:
		await get_tree().process_frame
		var meshes = original.get_meshes()
		if meshes.size() < 2:
			print("CSG has no mesh data yet")
			return
		mesh = meshes[1]
		
		var st = SurfaceTool.new()
		var processed = ArrayMesh.new()
		for i in meshes[1].get_surface_count():
			st.create_from(meshes[1], i)
			st.generate_normals()
			st.index()
			st.commit(processed)
		mesh = processed
		
	elif original is MeshInstance3D:
		mesh = original.mesh
	elif original is StaticBody3D and original.is_in_group("placedMeshes"):
		for child in original.get_children():
			if child is MeshInstance3D:
				mesh = child.mesh
				break

	if not mesh:
		print("No mesh found")
		return
	
	var pickable = XRToolsPickable.new()
	pickable.add_to_group("rendered_objects")
	pickable.collision_layer = 1 | 4
	pickable.collision_mask = 1
	pickable.picked_up_layer = 0
	
	var mesh_instance = MeshInstance3D.new()
	mesh_instance.mesh = mesh
	
	var mat = StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.albedo_color = Color(0.8, 0.8, 0.8, 1.0)
	mesh_instance.material_override = mat
	
	var collision = CollisionShape3D.new()
	var convex_shape = mesh.create_convex_shape()
	collision.shape = convex_shape
	
	pickable.add_child(mesh_instance)
	pickable.add_child(collision)
	
	var spawn_pos = controller.global_transform.origin + -controller.global_transform.basis.z * 1.0
	get_tree().current_scene.add_child(pickable)
	pickable.global_transform.origin = spawn_pos
	
	# print("Rendered object spawned at: ", spawn_pos)

func export_selected(file_name):
	if not currentSelectedObject or not is_instance_valid(currentSelectedObject):
		print("Nothing selected to export")
		ToastManager.error("Export Failed", "No object selected")
		return
	await SaveManager.export_mesh(currentSelectedObject, file_name)

func export_obj_selected(file_name):
	if not currentSelectedObject or not is_instance_valid(currentSelectedObject):
		print("Nothing has been selected")
		ToastManager.error("Export Failed", "No Object selected")
		return
	await SaveManager.export_obj(currentSelectedObject, file_name)

# Update highlighted object
func update_highlighted_object():
	if raycast_3d.is_colliding():
		var obj = raycast_3d.get_collider()
		# print("Hit: ", obj, " type: ", obj.get_class(), " groups: ", obj.get_groups())

		if not obj or not is_instance_valid(obj):
			if highlighted_object and highlighted_object != currentSelectedObject:
				_remove_highlight(highlighted_object)
			highlighted_object = null
			return

		if obj in summonedObjects and obj is CSGCombiner3D:
			if obj != highlighted_object:
				if highlighted_object and highlighted_object != currentSelectedObject:
					_remove_highlight(highlighted_object)
				highlighted_object = obj
				if highlighted_object != currentSelectedObject:
					_apply_highlight(highlighted_object, highlight_color)
		
		elif obj.is_in_group("rendered_objects"):
			if obj != highlighted_object:
				if highlighted_object and highlighted_object != currentSelectedObject:
					_remove_highlight(highlighted_object)
				highlighted_object = obj
				if highlighted_object != currentSelectedObject:
					_apply_highlight(highlighted_object, highlight_color)
					
		elif obj is StaticBody3D and obj.is_in_group("placedMeshes"):
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
		return

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
				var existing = obj.get_active_material(0)
				if existing == null:
					existing = obj.material_override
				true_materials[obj] = existing
			var mat = obj.material_override if obj.get_active_material(0) == null else obj.get_active_material(0)
			if mat:
				var dup = mat.duplicate()
				dup.albedo_color = color
				obj.material_override = dup
			await get_tree().process_frame
			if not is_instance_valid(obj):
				return

	elif obj.is_in_group("rendered_objects"):
		for child in obj.get_children():
			if not child is MeshInstance3D:
				continue
			print("Highlighting : ", child)
			await _apply_highlight_recursive(child, color)
			
	elif obj is StaticBody3D and obj.is_in_group("placedMeshes"):
		for child in obj.get_children():
			if not child is MeshInstance3D:
				continue
			if not child in true_materials:
				true_materials[child] = child.material_override
			var mat = StandardMaterial3D.new()
			mat.cull_mode = BaseMaterial3D.CULL_DISABLED
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			mat.albedo_color = color
			child.material_override = mat
			await get_tree().process_frame
			if not is_instance_valid(child):
				continue

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
		if obj.mesh:
			if obj in true_materials:
				obj.material_override = true_materials[obj]
				true_materials.erase(obj)
			await get_tree().process_frame
			if not is_instance_valid(obj):
				return
	elif obj.is_in_group("rendered_objects"):
		for child in obj.get_children():
			if not child is MeshInstance3D:
				continue
			print("Removing highlight : ",child)
			await _remove_highlight_recursive(child)

	elif obj is StaticBody3D and obj.is_in_group("placedMeshes"):
		for child in obj.get_children():
			if not child is MeshInstance3D:
				continue
			if child in true_materials:
				child.material_override = true_materials[child]
				true_materials.erase(child)
			await get_tree().process_frame
			if not is_instance_valid(child):
				continue

func set_page_index(idx):
	# Adjust index to match your Render tab position
	if idx == 5:
		is_active = true
		update_list()
	else:
		is_active = false

func update_list():
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects")
