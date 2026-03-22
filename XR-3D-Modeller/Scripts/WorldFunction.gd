extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	WorldOptions.intersectionsVisibilityChanged.connect(intersections_visibility_changed)
	WorldOptions.subtractionVisibilityChanged.connect(subtraction_visibility_changed)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

var ghosted_mesh = {}

func intersections_visibility_changed(show):
	if show:
		for combiner in get_tree().get_nodes_in_group("summonedObjects"):
			for child in combiner.get_children():
				if child is CSGMesh3D and child.operation == CSGShape3D.OPERATION_INTERSECTION:
					spawn_ghosted_obj(child)
	else:
		clear_ghosted("intersection_ghosts")

func subtraction_visibility_changed(show):
	if show:
		for combiner in get_tree().get_nodes_in_group("summonedObjects"):
			for child in combiner.get_children():
				if child is CSGMesh3D and child.operation == CSGShape3D.OPERATION_SUBTRACTION:
					spawn_ghosted_obj(child)
	else:
		clear_ghosted("subtraction_ghosts")

func spawn_ghosted_obj(obj):
	var ghost = obj.duplicate()
	ghost.operation = CSGShape3D.OPERATION_UNION
	ghost.global_transform = obj.global_transform
	
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
		
		if is_instance_valid(original):
			original.queue_free()

		if is_instance_valid(combiner) and combiner.get_child_count() <= 1:
			combiner.queue_free()
		
		ghosted_mesh.erase(ghost)
		ghost.queue_free()
