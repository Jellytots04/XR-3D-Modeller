extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Ready called worldfunction : ", get_path())
	add_to_group("main_node")
	if not WorldOptions.intersectionsVisibilityChanged.is_connected(intersections_visibility_changed):
		WorldOptions.intersectionsVisibilityChanged.connect(intersections_visibility_changed)
	if not WorldOptions.subtractionVisibilityChanged.is_connected(subtraction_visibility_changed):
		WorldOptions.subtractionVisibilityChanged.connect(subtraction_visibility_changed)
	var env = get_node("WorldEnvironment").environment
	env.background_color = Color(0.902, 0.902, 0.922, 1.0)
	env.volumetric_fog_enabled = true
	get_node("Floor/MeshInstance3D2").visible = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

var ghosted_mesh = {}

var passthrough_on = false

func toggle_passthrough():
	passthrough_on = not passthrough_on
	var start_xr = get_node("StartXR")
	start_xr.enable_passthrough = passthrough_on
	
	var env = get_node("WorldEnvironment").environment
	var floor_node = get_node("Floor/MeshInstance3D2")
	floor_node.visible = not passthrough_on
	env.volumetric_fog_enabled = not passthrough_on
	if passthrough_on:
		env.background_color = Color(0, 0, 0, 0)
	else:
		env.background_color = Color(0.506, 0.667, 0.667, 1.0) 

func intersections_visibility_changed(show):
	print("Show : ", show)
	if show:
		for combiner in get_tree().get_nodes_in_group("summonedObjects"):
			print("Checking combiner : ", combiner.name)
			if not combiner is CSGCombiner3D:
				continue
			for child in combiner.get_children():
				print("Child : ", child.name, " : operation : ", child.operation if child is CSGMesh3D else "N/A")
				if child is CSGMesh3D and child.operation == CSGShape3D.OPERATION_INTERSECTION:
					spawn_ghosted_obj(child)
	else:
		clear_ghosted("intersection_ghosts")

func subtraction_visibility_changed(show):
	print(show)
	if show:
		for combiner in get_tree().get_nodes_in_group("summonedObjects"):
			for child in combiner.get_children():
				if child is CSGMesh3D and child.operation == CSGShape3D.OPERATION_SUBTRACTION:
					spawn_ghosted_obj(child)
	else:
		clear_ghosted("subtraction_ghosts")

func spawn_ghosted_obj(obj):
	for ghost in ghosted_mesh.keys():
		if ghosted_mesh[ghost]["original"] == obj:
			return
	
	var ghost = obj.duplicate()
	
	ghost.remove_from_group("summonedObjects")
	ghost.remove_from_group("intersection_ghosts")
	ghost.remove_from_group("subtraction_ghosts")
	
	ghost.operation = CSGShape3D.OPERATION_UNION
	ghost.global_transform = obj.global_transform
	
	ghost.collision_layer = 4
	ghost.collision_mask = 0
	ghost.scale *= 1.002
	
	var mat = StandardMaterial3D.new()
	if obj.operation == CSGShape3D.OPERATION_INTERSECTION:
		mat.albedo_color = Color(1.0, 1.0, 0.5, 0.5)
		ghost.add_to_group("intersection_ghosts")
	else:
		mat.albedo_color = Color(1.0, 0, 0, 0.5)
		ghost.add_to_group("subtraction_ghosts")
		
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.material = mat
	
	get_tree().root.add_child(ghost)
	ghost.remove_from_group("summonedObjects")
	
	ghosted_mesh[ghost] = {
		"original": obj,
		"original_combiner": obj.get_parent()
	}

func clear_ghosted(group):
	for ghost in get_tree().get_nodes_in_group(group):
		if is_instance_valid(ghost):
			ghosted_mesh.erase(ghost)
			ghost.queue_free()

func delete_ghosted(ghost):
	if ghost in ghosted_mesh:
		var data = ghosted_mesh[ghost]
		var original = data["original"]
		var combiner = data["original_combiner"]
		print("Deleting ghost: ", ghost)
		print("Deleting original: ", original)
		print("Deleting combiner: ", combiner)

		if is_instance_valid(original):
			original.queue_free()

		if is_instance_valid(combiner) and combiner.get_child_count() <= 1:
			combiner.queue_free()
		
		ghosted_mesh.erase(ghost)
		ghost.queue_free()
		
		await get_tree().process_frame

func clear_ghost_for_original(original):
	for ghost in ghosted_mesh.keys():
		if ghosted_mesh[ghost]["original"] == original:
			if is_instance_valid(ghost):
				ghost.queue_free()
			ghosted_mesh.erase(ghost)
			return
