extends XRController3D

# Dev Note #
# Pickable functions will not work due to the CSGMesh style.
# Not allowing the players to pick up the objets via grabbing.
# Will use a separate function for that.
signal objectSummoned
signal verticeSummoned

# Editable variables
@export var spawn_distance := 1.0
@export var summon_rate:int = 1

# Onready variables used 
@onready var timer = $Timer
@onready var raycast_3d = $RayCast3D # Fix path later when the ToolNodebox is implemented
@onready var vertexRaycast = $BuildRayCast

# Flags
var triggerPressed = false

# Select variables
var selectIndex = 0
var currentSelectedObject 
var multiSelectHolder = []

# Summon variables
var summonedObjects
var objectsInScene = []
var summonIndex = 0 # Default index value defined by the build pages button value on the UI controller
var pageIndex = 0 # Default index value defined by the pages index value on the UI controller
var ghostInstance
var ghostingOn = false
var can_summon = true
var is_active = true
var objectSize = 1.0 # Used for size scaler in the UI, starts on 1.0 scaling
var csgIndex = 0 # Default combine csgIndex

# Vertex variables
var placed_vertices = []
var connect_vertices = {}
var currentlyConnecting = null 
var ghostEdge = null
var csg

# Copy variables
var copySelectedObject

# Vertex highlighting variables
var highlighted_vertex = null

# Highlighting variables
var highlighting_cancelled = false
var highlighting = false
var remove_highlighting_cancelled = false
var remove_highlighting = false
var original_materials = {}
var true_materials = {}
var highlighted_object = null
var highlight_color = Color(0.756, 0.453, 0.105, 1.0) # Red highlight / Pinkish highlight
var selected_color = Color(0.913, 0.967, 0.331, 1.0) # When clicked on this is the color the object will assume

# UI Controller
var ui_controller

# Replace folder variables with arrays of file paths
@export var summonablePaths := [
	"res://Summonables_Folder/CSG_Editables/Box_CSG.tscn",
	"res://Summonables_Folder/CSG_Editables/Prism_CSG.tscn",
	"res://Summonables_Folder/CSG_Editables/Sphere_CSG.tscn",
	"res://Summonables_Folder/CSG_Editables/Vertice.tscn"
]
@export var ghostedPaths := [
	"res://Summonables_Folder/Objects_Ghosted/ghosted_cube.tscn",
	"res://Summonables_Folder/Objects_Ghosted/ghosted_prism.tscn",
	"res://Summonables_Folder/Objects_Ghosted/ghosted_sphere.tscn",
	"res://Summonables_Folder/Objects_Ghosted/ghosted_Vertice.tscn"
]

# Loaded scenes will be stored here
var summonableObjects = []
var ghostedObjects = []

# Loads the summonable objects
func load_summonables():
	summonableObjects.clear()
	for path in summonablePaths:
		var scene = load(path)
		if scene:
			summonableObjects.append(scene)

# Loads the ghosted scenes
func load_ghosted():
	ghostedObjects.clear()
	for path in ghostedPaths:
		var scene = load(path)
		if scene:
			ghostedObjects.append(scene)

func _ready() -> void:
	# Load the summonables when started
	csg = load("res://Summonables_Folder/CSG_Editables/csg_spare.tscn")
	load_summonables()
	load_ghosted()
	timer.wait_time = 1.0 / summon_rate
	timer.connect("timeout", _time_out)
	# Get the path for the left Hand controller
	
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects")
	placed_vertices = get_tree().get_nodes_in_group("placedVertices")
	var remover = get_node("FunctionToolNode/RemoveFunction") # Remove Function
	remover.connect("objectRemoved", Callable(self, "update_list"))
	var editor = get_node("FunctionToolNode/EditFunction") # Editing function
	editor.connect("objectEdited", Callable(self, "update_list"))
	SaveManager.scene_loaded.connect(Callable(self, "update_list")) # upon loading update the object_summoned
	var ui_controllers = get_tree().get_nodes_in_group("ui_controller")
	if ui_controllers.size() > 0:
		ui_controller = ui_controllers[0]
		# Connect the script to the summonable Selected function with a signal to call the set_summon_index
		ui_controller.connect("change_page", Callable(self, "set_page_index")) # changes the current selected page
		ui_controller.connect("summonable_selected", Callable(self, "set_summon_index")) # changes the selected summonable object 1 - 4 / 0 - 3
		ui_controller.connect("scaleSize", Callable(self, "set_scale_size")) # changes the scale size for summoning and ghosting objects
		ui_controller.connect("csg_operation", Callable(self, "change_csg_operation"))
		ui_controller.connect("select_change", Callable(self, "select_index_change"))
		ui_controller.connect("load_mesh", Callable(self, "_load_mesh"))
		ui_controller.connect("clear_vertices", Callable(self, "_clear_vertices"))

# Timeout for summoning objects
func _time_out():
	can_summon = true

func _process(_delta):
	# Will activate when the user presses the A button on the controller
	if is_active:
		if is_button_pressed("ax_button") and can_summon: # Meta Quest A button
			if summonIndex == 4: # Copy summon
				# Ensure there is a selected object and its a valid instance
				if copySelectedObject and is_instance_valid(copySelectedObject):
					# If its preview isn't on
					if not ghostingOn:
						# Create the ghost instance
						ghostInstance = copySelectedObject.duplicate()
						if ghostInstance is CSGCombiner3D:
							ghostInstance.use_collision = false
							for child in ghostInstance.get_children():
								if child is CSGMesh3D:
									child.use_collision = false
									child.collision_layer = 0
									child.collision_mask = 0
						elif ghostInstance is CSGMesh3D:
							ghostInstance.use_collision = false
							ghostInstance.collision_layer = 0
							ghostInstance.collision_mask = 0
						var mat = StandardMaterial3D.new()
						mat.albedo_color = Color(1, 1, 1, 80.0/255.0)
						mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
						mat.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
						mat.cull_mode = BaseMaterial3D.CULL_BACK
						mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
						mat.no_depth_test = true
						if ghostInstance is CSGCombiner3D:
							for child in ghostInstance.get_children():
								if child is CSGMesh3D:
									child.material = mat.duplicate()
						elif ghostInstance is CSGMesh3D:
							ghostInstance.material = mat
						ghostInstance.scale = copySelectedObject.scale
						# Add the ghost to the scene
						get_tree().current_scene.add_child(ghostInstance)
						ghostingOn = true
					# If the raycast detects another object
					if raycast_3d.is_colliding():
						var obj = raycast_3d.get_collider()
						# Use snapping point if the collided object is inside of summonedObjects and isn't the copied object
						if obj in summonedObjects and obj != copySelectedObject:
							var snap_point = WorldOptions.snap_vec(raycast_3d.get_collision_point())
							ghostInstance.global_position = snap_point + raycast_3d.get_collision_normal() * 0.01
						else:
							var spawn_position = global_transform.origin + -global_transform.basis.z * spawn_distance
							ghostInstance.global_transform.origin = WorldOptions.snap_vec(spawn_position)
					else:
						var spawn_pos = global_transform.origin + -global_transform.basis.z * spawn_distance
						ghostInstance.global_transform.origin = WorldOptions.snap_vec(spawn_pos)
			else: # follow the other summon index features
				# Create the ghost instance if it isn't previewing
				if not ghostingOn:
					ghostInstance = ghostedObjects[summonIndex].instantiate()
					# Correct the scale of the vertice ghosted instance
					if summonIndex == 3:
						ghostInstance.scale = Vector3.ONE
					else: # Give everything else the edited scale
						ghostInstance.scale = objectSize * Vector3.ONE # sets all of the values to objectSize
					# Add the ghost to the scene
					get_tree().current_scene.add_child(ghostInstance)
					ghostingOn = true
				if summonIndex == 3: # Use world snapping features
					var spawn_pos = global_transform.origin + -global_transform.basis.z * spawn_distance
					ghostInstance.global_transform.origin = WorldOptions.snap_vec(spawn_pos)
				else: # Use world snapping features while combining
					if raycast_3d.is_colliding():
						var obj = raycast_3d.get_collider()
						if obj in summonedObjects:
							var snapped_point = WorldOptions.snap_vec(raycast_3d.get_collision_point())
							var snap_pos = snapped_point + raycast_3d.get_collision_normal() * 0.01
							ghostInstance.global_position = snap_pos
							ghostInstance.look_at(snapped_point, raycast_3d.get_collision_normal())
					else:
						# Snap the spawn position of the ghosted object while not combining
						var spawn_pos = global_transform.origin + -global_transform.basis.z * spawn_distance
						ghostInstance.global_transform.origin = WorldOptions.snap_vec(spawn_pos)
		else:
			# While ghost is on, free the ghost, start the summon timer.
			if ghostingOn:
				ghostInstance.queue_free()
				ghostInstance = null
				ghostingOn = false
				timer.start()
				can_summon = false
				if summonIndex == 4: # If its a copy index copy the selected object
					place_copy()
				elif summonIndex == 3: # If its a vertice summon the vertex
					summon_vertex()
				else: # While its colliding combine the summon to the object 
					if raycast_3d.is_colliding():
						var obj = raycast_3d.get_collider()
						if obj in summonedObjects:
							combine_objects(summonIndex, obj, raycast_3d.get_collision_point(), raycast_3d.get_collision_normal())
					else: # If not summon the object!
						summon_object(summonIndex)
		
		# Always keep highlighted variables
		update_highlighted_object()
		update_highlighted_vertex()
		
		# If the user clicks / presses right trigger on an highlighted object it will become the selected object
		if is_button_pressed("trigger_click") and !triggerPressed: # This is group select aka entire object because highlighted_object will be the CSGCombiner
			if highlighted_object:
				# Group selecting (Entire CSGCombiner included)
				if selectIndex == 0:
					triggerPressed = true
					# Release trigger / click
					if currentSelectedObject == highlighted_object:
						var deselct_object = currentSelectedObject
						copySelectedObject = null
						currentSelectedObject = null
						highlighted_object = null
						await _remove_highlight(deselct_object)

					elif not currentSelectedObject:
						currentSelectedObject = highlighted_object
						copySelectedObject = currentSelectedObject
						highlighted_object = null
						await _apply_highlight(currentSelectedObject, selected_color)

				# Multiple selecting (Can select an infinite amount of objects)
				elif selectIndex == 1: # Multi Select
					triggerPressed = true
					if highlighted_object in multiSelectHolder:
						var deselect_object = highlighted_object
						highlighted_object = null
						multiSelectHolder.erase(deselect_object)
						await _remove_highlight(deselect_object)

					elif highlighted_object not in multiSelectHolder:
						_apply_highlight(highlighted_object, selected_color)
						multiSelectHolder.append(highlighted_object)
						# Select case for ensuring the object is selected
						currentSelectedObject = null

				# Single object selecting (Select a single object at a time)
				elif selectIndex == 2: # Single Select
					triggerPressed = true
					if currentSelectedObject == highlighted_object:
						var deselect_object = currentSelectedObject
						copySelectedObject = null
						currentSelectedObject = null
						highlighted_object = null
						await _remove_highlight(deselect_object)

					elif not currentSelectedObject:
						currentSelectedObject = highlighted_object
						copySelectedObject = currentSelectedObject
						await _apply_highlight(currentSelectedObject, selected_color)

		elif not is_button_pressed("trigger_click"):
			triggerPressed = false
			
		# Grip logic for gripping a vertex to connect it to another vertex creating an edge
		if is_button_pressed("grip"):
			# Apply the highlight to vertex objects when gripping for connecting
			if not currentlyConnecting and highlighted_vertex:
				currentlyConnecting = highlighted_vertex
				await _apply_highlight(currentlyConnecting, selected_color)
			if currentlyConnecting and highlighted_vertex:
				preview_edge(currentlyConnecting, highlighted_vertex)
			else:
				if ghostEdge and is_instance_valid(ghostEdge):
					ghostEdge.queue_free()
					ghostEdge = null

		else: # If not gripping and the connecting variable is true connect the vertices together
			if currentlyConnecting:
				var deselect_color = currentlyConnecting
				if highlighted_vertex and highlighted_vertex != currentlyConnecting:
					connect_vertex(currentlyConnecting, highlighted_vertex)
				currentlyConnecting = null
				await _remove_highlight(deselect_color)

# Summoning Functions
# Combine the objects together when hovering while summoning
func combine_objects(index, combiner, spawnPoint, objectNormal):
	# Guard to ensure you don;t combine to an intersection / subtraction Object
	if combiner.is_in_group("intersection_ghosts") or combiner.is_in_group("subtraction_ghosts"):
		ToastManager.error("Combine Failed", "Cannot combine objects to ghosted nodes")
		return

	# Ensure the index is within the summonable objects
	if index < summonableObjects.size():
		# Instantiate the object in the scene
		var new_obj = summonableObjects[index].instantiate()
		var snapped_point = WorldOptions.snap_vec(spawnPoint)
		# Grabs the position of the hand and will add to it to spawn the hand in
		# Will replace this with a marker tag later on
		new_obj.global_transform.origin = snapped_point + objectNormal * 0.01
		# objectsInScene.append(new_obj)
		# Add the new object to the scene
		new_obj.scale = objectSize * Vector3.ONE
		new_obj.operation = csgIndex
		get_tree().current_scene.add_child(new_obj)
		new_obj.look_at(snapped_point, objectNormal)
		new_obj.reparent(combiner)
		new_obj.use_collision = true
		new_obj.collision_layer = 2
		# Add the combined object to the summonedObjects group
		summonedObjects = get_tree().get_nodes_in_group("summonedObjects") # Updates the summoned list within script
		AudioManager.play_snap()
		emit_signal("objectSummoned") # This gets called as an upadte is to be sent out due to a reparenting
	else:
		print("Summonables out of index")

# Summon the objects into the scene tied to nothing
func summon_object(index):
	# Checks to see if index is inside the size of the array
	if index < summonableObjects.size(): # Prevent from spawning in a vertex
		# Instantiate the object in the scene
		var new_obj = summonableObjects[index].instantiate()
		
		var combiner = CSGCombiner3D.new()
		# Grabs the position of the hand and will add to it to spawn the hand in
		# Will replace this with a marker tag later on
		var spawn_pos = global_transform.origin + -global_transform.basis.z * spawn_distance
		# Add the new object to the scene
		new_obj.scale = objectSize * Vector3.ONE
		get_tree().current_scene.add_child(combiner)
		combiner.global_transform.origin = WorldOptions.snap_vec(spawn_pos)
		combiner.add_child(new_obj)
		new_obj.position = Vector3.ZERO
		combiner.use_collision = true
		
		combiner.collision_layer = combiner.collision_layer | (1 << 20)
		combiner.collision_mask = combiner.collision_mask | (1 << 20)
		
		new_obj.use_collision = true
		new_obj.collision_layer = 2
		combiner.add_to_group("summonedObjects")
		summonedObjects = get_tree().get_nodes_in_group("summonedObjects") # Updates the summoned list within script
		AudioManager.play_place_down()
		emit_signal("objectSummoned")
	else:
		print("Summonables out of index")

# Vertex / Verticies Functions
func summon_vertex():
	# Summon the vertex into the scene
	# Instantiate and add it to the root
	var vertex = summonableObjects[3].instantiate()
	var spawn_pos = WorldOptions.snap_vec(global_transform.origin + -global_transform.basis.z * spawn_distance)
	vertex.global_position = spawn_pos
	get_tree().current_scene.add_child(vertex)
	
	await get_tree().process_frame
	
	# Set collision layer and mask to bit level 4
	vertex.use_collision = true
	vertex.collision_layer = 8
	vertex.collision_mask = 8
	
	# Add new vertex to the placed vertices group
	vertex.add_to_group("placedVertices")
	
	# Update the array
	placed_vertices = get_tree().get_nodes_in_group("placedVertices")
	connect_vertices[vertex] = []
	AudioManager.play_place_down()
	# Send out signal
	emit_signal("verticeSummoned")

# Combine the vertices together
func connect_vertex(vertex_1, vertex_2): # Assuming the this follows grip logic
	# Ensure the two vertices are valid
	if not is_instance_valid(vertex_1) or not is_instance_valid(vertex_2):
		return
	
	# Ensure they aren't already connected to each other, if true combine them
	if vertex_2 not in connect_vertices[vertex_1]:
		connect_vertices[vertex_1].append(vertex_2)
	if vertex_1 not in connect_vertices[vertex_2]:
		connect_vertices[vertex_2].append(vertex_1)
	
	# Remove the Preview edge
	if ghostEdge and is_instance_valid(ghostEdge):
		ghostEdge.queue_free()
		ghostEdge = null
	
	AudioManager.play_snap()
	# Draw the edge
	draw_edge(vertex_1, vertex_2)

# Draw the edge that was created by connecting the two vertices
func draw_edge(vertex_1, vertex_2):
	var edge = CylinderMesh.new()
	var mesh = MeshInstance3D.new()
	var dist = vertex_1.global_position.distance_to(vertex_2.global_position)
	var mid = (vertex_1.global_position + vertex_2.global_position) / 2
	
	edge.top_radius = 0.01
	edge.bottom_radius = 0.01
	edge.height = dist
	mesh.mesh = edge
	
	get_tree().current_scene.add_child(mesh)
	mesh.add_to_group("placedEdges")
	
	mesh.global_position = mid
	mesh.look_at(vertex_1.global_position, Vector3.UP)
	mesh.rotate_object_local(Vector3.RIGHT, PI / 2)

# Same as draw edge but as a preview edge
func preview_edge(vertex_1, vertex_2):
	if ghostEdge and is_instance_valid(ghostEdge):
		ghostEdge.queue_free()
		ghostEdge = null
	
	var edge = CylinderMesh.new()
	var mesh = MeshInstance3D.new()
	var dist = vertex_1.global_position.distance_to(vertex_2.global_position)
	var mid = (vertex_1.global_position + vertex_2.global_position) / 2
	
	edge.top_radius = 0.01
	edge.bottom_radius = 0.01
	edge.height = dist
	mesh.mesh = edge
	
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.4)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.material_override = mat
	
	get_tree().current_scene.add_child(mesh)
	
	mesh.global_position = mid
	mesh.look_at(vertex_1.global_position, Vector3.UP)
	mesh.rotate_object_local(Vector3.RIGHT, PI / 2)

	ghostEdge = mesh

# Validation function to ensure that the vertices object follows Eulers 
func validate_mesh() -> bool:
	# Ensure there are enough vertices in the world to make a mesh
	if placed_vertices.size() < 4:
		ToastManager.error("Invalid Mesh", "At least 4 vertices are required")
		return false
		
	# Put the vertices into a usable array
	var vertices_usable = []
	for vertex in placed_vertices:
		if connect_vertices[vertex].size() == 0:
			continue
		if connect_vertices[vertex].size() < 3:
			continue
		vertices_usable.append(vertex)
		
	# Ensure there are enough usable vertices
	if vertices_usable.size() < 4:
		print("Required usable (connected) vertices is 4")
		ToastManager.error("Invalid Connections", "Each vertex needs at least 3 connections")
		return false
	
	# Grab the total edge count
	var edge_count = 0
	for vertex in vertices_usable:
		edge_count += connect_vertices[vertex].size()
	edge_count /= 2
	
	# Grab the total possible face count
	var face_count = 0
	var vertex_index = {}
	for index in vertices_usable.size(): # Give each of the nodes dictionary index
		vertex_index[vertices_usable[index]] = index
	
	# Loop to grab the face count without recounting faces
	for vertex_1 in vertices_usable:
		for vertex_2 in connect_vertices[vertex_1]:
			for vertex_3 in connect_vertices[vertex_1]:
				if vertex_2 == vertex_3: # Ensure the loop passes same vertex loops
					continue
				if vertex_3 not in connect_vertices[vertex_2]: # Ensure vertex 3 is connected to vertex 2 to create a plane
					continue
				# Using the indexes to ensure there is no repeat / duplicate face counting
				var index_1 = vertex_index[vertex_1]
				var index_2 = vertex_index[vertex_2]
				var index_3 = vertex_index[vertex_3]
				if index_1 < index_2 and index_2 < index_3:
					face_count += 1
	
	# Euler's Formula Vertices - Edges + Faces == 2
	var V = vertices_usable.size()
	var E = edge_count
	var F = face_count
	
	# Test the mesh through Euler's formula
	if V - E + F != 2:
		ToastManager.error("Invalid Shape", "Mesh is not a closed surface V ("+str(V)+") - E ("+str(E)+") + F ("+str(F)+") ≠2)")
		return false
		
	ToastManager.success("Valid Mesh", "Shape created successfully!")
	return true

# Build the actual mesh function
func build_mesh():
	# Build the vertices usable 
	var vertices_usable = []
	
	for vertex in placed_vertices:
		if connect_vertices[vertex].size() == 0:
			continue
		if connect_vertices[vertex].size() < 3:
			continue
		vertices_usable.append(vertex)
	
	if vertices_usable.size() < 4:
		print("Need at least 4 connected vertices")
		return
	
	# Grab the center of the mesh overall
	var center = Vector3.ZERO
	for vertex in vertices_usable:
		center += vertex.global_position
	center /= vertices_usable.size()
	
	# Place the vertex into an index value 
	var vertex_index = {}
	for index in vertices_usable.size():
		vertex_index[vertices_usable[index]] = index
	
	# Create the MeshInstace3D
	var mesh_instance = MeshInstance3D.new()
	get_tree().current_scene.add_child(mesh_instance)
	mesh_instance.global_position = center
	
	# Ensure the frame is processed
	await get_tree().process_frame
	
	# Grab the positions of the vertices
	var positions = []
	for v in vertices_usable:
		positions.append(mesh_instance.to_local(v.global_position))
	
	# Create the vector Array
	var vertices = PackedVector3Array()
	
	# Create the packed scene locations
	for vertex_1 in vertices_usable:
		for vertex_2 in connect_vertices[vertex_1]:
			for vertex_3 in connect_vertices[vertex_1]:
				if vertex_2 == vertex_3:
					continue
				if vertex_3 not in connect_vertices[vertex_2]:
					continue
				var i1 = vertex_index[vertex_1]
				var i2 = vertex_index[vertex_2]
				var i3 = vertex_index[vertex_3]
				if i1 < i2 and i2 < i3:
					var p1 = positions[i1]
					var p2 = positions[i2]
					var p3 = positions[i3]
					vertices.push_back(p1)
					vertices.push_back(p2)
					vertices.push_back(p3)
	
	# Ensure there is a mesh
	if vertices.size() == 0:
		mesh_instance.queue_free()
		return
	
	# Create the surface tool
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Add the vertices to the Surface tool
	for v in vertices:
		st.add_vertex(v)
	st.generate_normals()
	st.index()
	var arr_mesh = st.commit()
	
	# Give it the standard material
	var mat = StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	mat.albedo_color = Color(0.8, 0.8, 0.8, 1.0)
	
	mesh_instance.mesh = arr_mesh
	mesh_instance.material_override = mat
	
	await get_tree().process_frame
	
	# Wrap in StaticBody3D with collision
	var static_body = StaticBody3D.new()
	get_tree().current_scene.add_child(static_body)
	static_body.global_transform = mesh_instance.global_transform
	
	# Give the object a collision shape
	var collision = CollisionShape3D.new()
	var convex_shape = arr_mesh.create_convex_shape()
	collision.shape = convex_shape
	static_body.add_child(collision)
	
	# Reparent the object
	mesh_instance.reparent(static_body)
	mesh_instance.position = Vector3.ZERO
	
	static_body.collision_layer = 4
	static_body.collision_mask = 4
	
	AudioManager.play_place_down()
	
	# Add it to its own mesh' group
	static_body.add_to_group("placedMeshes")
	
	await get_tree().process_frame
	
	# Clear the previous vertices 
	clear_vertices()

# Clear the existing vertices and edges
func clear_vertices():
	for mesh in get_tree().get_nodes_in_group("placedEdges"):
		mesh.queue_free()
		
	for vertex in placed_vertices:
		if is_instance_valid(vertex):
			vertex.queue_free()
		
	placed_vertices.clear()
	connect_vertices.clear()
	AudioManager.play_whoosh()
	currentlyConnecting = null
	highlighted_vertex = null
 
# Place a copy of the selected object
func place_copy():
	# Ensure there is a selected object
	if not copySelectedObject or not is_instance_valid(copySelectedObject):
		return

	# Check to see if the CSG operation isn't an intersection
	if csgIndex == CSGShape3D.OPERATION_INTERSECTION:
		ToastManager.error("Copy failed", "Cannot copy with intersection operations")
		return

	# Check to see if the user is hovering over another object
	if raycast_3d.is_colliding():
		var obj = raycast_3d.get_collider()
		# Ensure the object isn't the one being copied
		if obj in summonedObjects and obj != copySelectedObject:
			# If it is a group copy
			if selectIndex == 0:
				# Ensure the copied object is a CSGCombiner3D
				if not copySelectedObject is CSGCombiner3D:
					ToastManager.error("Copy Failed", "Can only copy CSG Combiners in group select!")
					return
				
				# Grab the parent and the targets position for reference
				var parent_position = copySelectedObject.global_transform.origin
				var target_position = WorldOptions.snap_vec(raycast_3d.get_collision_point())
				
				# For the amount of children in the copied object
				for i in range(copySelectedObject.get_child_count()):
					# Grab that child
					var original_child = copySelectedObject.get_child(i)
					# Ensure it's a CSGMesh3D
					if original_child is CSGMesh3D:
						# Duplicate that child
						var new_obj = original_child.duplicate()
						
						# Change its CSGIndex
						new_obj.operation = csgIndex
						
						# Grab that childs original materials
						if original_child in true_materials:
							new_obj.material = true_materials[original_child]
						else:
							new_obj.material = null
						# Set its collision layer properly 
						new_obj.use_collision = true
						new_obj.collision_layer = 2
						# Add child to the tree anda reparent 
						get_tree().current_scene.add_child(new_obj)
						new_obj.reparent(obj)
						
						# Set the offsets properly
						var offset = original_child.global_transform.origin - parent_position
						new_obj.global_transform.origin = target_position + offset + raycast_3d.get_collision_point() * 0.01
						
						new_obj.global_transform.basis = original_child.global_transform.basis
						
			elif selectIndex == 2: # If in single select mode
				# Ensure the copied object is a CSGMesh3D
				if not copySelectedObject is CSGMesh3D:
					ToastManager.error("Copy Failed", "Can only copy CSG Mesh in single select")
					return
				
				# Duplicate the object
				var new_obj = copySelectedObject.duplicate()
				
				# Have it follow the selected operation
				new_obj.operation = csgIndex
				
				# Snap the object to the location
				var _snapped = WorldOptions.snap_vec(raycast_3d.get_collision_point())
				if copySelectedObject in true_materials:
					new_obj.material = true_materials[copySelectedObject]
				else:
					new_obj.material = null
				new_obj.use_collision = true
				new_obj.collision_layer = 2
				# Add to the root and reparent
				get_tree().current_scene.add_child(new_obj)
				new_obj.reparent(obj)
				new_obj.global_transform.origin = _snapped + raycast_3d.get_collision_normal() * 0.01
			summonedObjects = get_tree().get_nodes_in_group("summonedObjects")
			AudioManager.play_snap()
			emit_signal("objectSummoned")
			return
	
	# Else the spaawn distance in the world without combining, place infront of user
	var spawn_pos = global_transform.origin + -global_transform.basis.z * spawn_distance
	if selectIndex == 0: # Group select
		if not copySelectedObject is CSGCombiner3D:
			ToastManager.error("Copy Failed", "Can only copy CSG Combiners in group select")
			return
		var new_combiner = copySelectedObject.duplicate()
		get_tree().current_scene.add_child(new_combiner)
		new_combiner.global_transform.origin = WorldOptions.snap_vec(spawn_pos)
		var original_children = copySelectedObject.get_children()
		var new_children = new_combiner.get_children()
		for i in range(min(original_children.size(), new_children.size())):
			if new_children[i] is CSGMesh3D:
				
				new_children[i].operation = csgIndex
				
				if original_children[i] in true_materials:
					new_children[i].material = true_materials[original_children[i]]
				else:
					new_children[i].material = null
				new_children[i].use_collision = true
				new_children[i].collision_layer = 2
		new_combiner.use_collision = true
		new_combiner.collision_layer = new_combiner.collision_layer | (1 << 20)
		new_combiner.collision_mask = new_combiner.collision_mask | (1 << 20)
		new_combiner.add_to_group("summonedObjects")
		summonedObjects = get_tree().get_nodes_in_group("summonedObjects")
		AudioManager.play_place_down()
		emit_signal("objectSummoned")

	elif selectIndex == 2: # Single select
		print("Elif 2 selectIndex copy")
		if not copySelectedObject is CSGMesh3D:
			ToastManager.error("Copy Failed", "Can only copy CSG Mesh in single select")
			return
		var new_combiner = CSGCombiner3D.new()
		var new_obj = copySelectedObject.duplicate()
		
		new_obj.operation = csgIndex
		
		print("new_obj mesh: ", new_obj.mesh)
		print("new_obj operation: ", new_obj.operation)
		get_tree().current_scene.add_child(new_combiner)
		new_combiner.global_transform.origin = WorldOptions.snap_vec(spawn_pos)
		new_combiner.add_child(new_obj)
		new_obj.position = Vector3.ZERO
		if copySelectedObject in true_materials:
			new_obj.material = true_materials[copySelectedObject]
		else:
			new_obj.material = null
		new_obj.use_collision = true
		new_obj.collision_layer = 2
		new_combiner.use_collision = true
		new_combiner.collision_layer = new_combiner.collision_layer | (1 << 20)
		new_combiner.collision_mask = new_combiner.collision_mask | (1 << 20)
		new_combiner.add_to_group("summonedObjects")
		summonedObjects = get_tree().get_nodes_in_group("summonedObjects")
		AudioManager.play_place_down()
		emit_signal("objectSummoned")

# Vertex highlighting
func update_highlighted_vertex():
	if vertexRaycast.is_colliding():
		var obj = vertexRaycast.get_collider()
		# print("Vertex raycast hit: ", obj)
		# print("In placed_vertices: ", obj in placed_vertices)
		if obj in placed_vertices:
			if obj != highlighted_vertex:
				if highlighted_vertex:
					_remove_highlight(highlighted_vertex)
				highlighted_vertex = obj
				_apply_highlight(highlighted_vertex, highlight_color)
	else:
		if highlighted_vertex:
			if highlighted_vertex != currentlyConnecting:
				_remove_highlight(highlighted_vertex)
			highlighted_vertex = null

# Highlighting Functions
func update_highlighted_object():
	# print("Ray update")
	if summonIndex == 4 and ghostingOn:
		# print("Returned for ghosting")
		return
	if raycast_3d.is_colliding():
		var combiner = raycast_3d.get_collider()
		
		if not combiner or not is_instance_valid(combiner):
			if highlighted_object and highlighted_object != currentSelectedObject:
				_remove_highlight(highlighted_object)
			highlighted_object = null
			return
		
		if combiner.is_in_group("intersection_ghosts") or combiner.is_in_group("subtraction_ghosts"):
			if highlighted_object and highlighted_object != currentSelectedObject:
				_remove_highlight(highlighted_object)
			highlighted_object = null
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
		await _remove_highlight(cleared_object)
	
	if selectIndex == 1:
		for child in multiSelectHolder:
			await _remove_highlight(child)
		multiSelectHolder.clear()

	selectIndex = idx

# Signals going and coming
func set_page_index(idx):
	# print("Hello from remove call index")
	if idx == 0:
		is_active = true
	else:
		clear_select(selectIndex)
		is_active = false

# Change the CSG Operation
func change_csg_operation(idx):
	csgIndex = idx

func update_list():
	#print("Hello from update list in Summon")
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects")
	placed_vertices = get_tree().get_nodes_in_group("placedVertices")

func set_summon_index(idx):
	summonIndex = idx
	if summonIndex == 3:
		ui_controller.build_vertex.visible = true
	else:
		ui_controller.build_vertex.visible = false
	
func set_scale_size(value):
	objectSize = value

# Add a clearance previous select on change
func select_index_change(idx):
	await clear_select(idx) # Clears and sets the new index

func _load_mesh():
	if validate_mesh():
		#print("Loading mesh has been pressed")
		build_mesh()
		#print("Object has been created and loaded!!")

func _clear_vertices():
	clear_vertices()
