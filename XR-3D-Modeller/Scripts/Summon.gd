extends XRController3D

# Dev Note #
# Pickable functions will not work due to the CSGMesh style.
# Not allowing the players to pick up the objets via grabbing.
# Will use a separate function for that.
signal objectSummoned
signal verticeSummoned

@export var object_scene: PackedScene
@export var spawn_distance := 1.0
@export var summon_rate:int = 1

# Onready variables used 
@onready var timer = $Timer
@onready var raycast_3d = $RayCast3D # Fix path later when the ToolNodebox is implemented
@onready var vertexRaycast = $BuildRayCast
# @export var bland

# Flags
var triggerPressed = false

# Select variables
var selectIndex = 0
var currentSelectedObject 
var multiSelectHolder = []

# var summonableObjects = []
# var ghostedObjects = []
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

func load_summonables():
	summonableObjects.clear()
	for path in summonablePaths:
		var scene = load(path)
		if scene:
			summonableObjects.append(scene)
		else:
			print("Could not load: ", path)

func load_ghosted():
	ghostedObjects.clear()
	for path in ghostedPaths:
		var scene = load(path)
		if scene:
			ghostedObjects.append(scene)
		else:
			print("Could not load: ", path)

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
	# print(remover)
	remover.connect("objectRemoved", Callable(self, "update_list"))
	var editor = get_node("FunctionToolNode/EditFunction") # Editing function
	editor.connect("objectEdited", Callable(self, "update_list"))
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
		print("Controller found ", ui_controller)
	else:
		print("UI Controller not found")

func _time_out():
	can_summon = true

func _process(_delta):
	# Will activate when the user presses the A button on the controller
	if is_active:
		if is_button_pressed("ax_button") and can_summon: # Meta Quest A button
			if not ghostingOn:
				ghostInstance = ghostedObjects[summonIndex].instantiate()
				ghostInstance.scale = objectSize * Vector3.ONE # sets all of the values to objectSize
				get_tree().current_scene.add_child(ghostInstance)
				ghostingOn = true
			if summonIndex == 3:
				var spawn_pos = global_transform.origin + -global_transform.basis.z * spawn_distance
				ghostInstance.global_transform.origin = spawn_pos
			else:
				if raycast_3d.is_colliding():
					var obj = raycast_3d.get_collider()
					if obj in summonedObjects:
						var snap_pos = raycast_3d.get_collision_point() + raycast_3d.get_collision_normal() * 0.01
						ghostInstance.global_position = snap_pos
						ghostInstance.look_at(raycast_3d.get_collision_point(), raycast_3d.get_collision_normal())
				else:
					var spawn_pos = global_transform.origin + -global_transform.basis.z * spawn_distance
					ghostInstance.global_transform.origin = spawn_pos

		else:
			if ghostingOn:
				ghostInstance.queue_free()
				ghostInstance = null
				ghostingOn = false
				timer.start()
				can_summon = false
				if summonIndex == 3:
					summon_vertex()
				else:
					if raycast_3d.is_colliding():
						var obj = raycast_3d.get_collider()
						if obj in summonedObjects:
							# print("Combined")
							combine_objects(summonIndex, obj, raycast_3d.get_collision_point(), raycast_3d.get_collision_normal())
					else:
						summon_object(summonIndex)
		
		update_highlighted_object()
		update_highlighted_vertex()
		
		# If the user clicks / presses right trigger on an highlighted object it will become the selected object
		if is_button_pressed("trigger_click") and !triggerPressed: # This is group select aka entire object because highlighted_object will be the CSGCombiner
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

		elif not is_button_pressed("trigger_click"):
			triggerPressed = false
			
		# Grip logic for gripping a vertex to connect it to another vertex creating an edge
		if is_button_pressed("grip"):
			if not currentlyConnecting and highlighted_vertex:
				currentlyConnecting = highlighted_vertex
				await _apply_highlight(currentlyConnecting, selected_color)
			if currentlyConnecting and highlighted_vertex:
				preview_edge(currentlyConnecting, highlighted_vertex)
			else:
				if ghostEdge and is_instance_valid(ghostEdge):
					ghostEdge.queue_free()
					ghostEdge = null

		else:
			if currentlyConnecting:
				var deselect_color = currentlyConnecting
				if highlighted_vertex and highlighted_vertex != currentlyConnecting:
					connect_vertex(currentlyConnecting, highlighted_vertex)
				currentlyConnecting = null
				await _remove_highlight(deselect_color)

# Summoning Functions
func combine_objects(index, combiner, spawnPoint, objectNormal):
	if index < summonableObjects.size():
		# Instantiate the object in the scene
		var new_obj = summonableObjects[index].instantiate()
		# Grabs the position of the hand and will add to it to spawn the hand in
		# Will replace this with a marker tag later on
		new_obj.global_transform.origin = (spawnPoint + objectNormal * 0.01)
		# objectsInScene.append(new_obj)
		# print("Added", new_obj)
		# Add the new object to the scene
		new_obj.scale = objectSize * Vector3.ONE
		new_obj.operation = csgIndex
		get_tree().current_scene.add_child(new_obj)
		new_obj.look_at(spawnPoint, objectNormal)
		new_obj.add_to_group("summonedObjects")
		new_obj.reparent(combiner)
		new_obj.use_collision = true
		new_obj.collision_layer = 2
		print("Parent is : ", new_obj.get_parent())
		summonedObjects = get_tree().get_nodes_in_group("summonedObjects") # Updates the summoned list within script
		emit_signal("objectSummoned") # This gets called as an upadte is to be sent out due to a reparenting
		print(summonedObjects)
	else:
		print("Summonables out of index")

func summon_object(index):
	# Checks to see if index is inside the size of the array
	if index < summonableObjects.size(): # Prevent from spawning in a vertex
		# Instantiate the object in the scene
		var new_obj = summonableObjects[index].instantiate()
		
		var combiner = CSGCombiner3D.new()
		# Grabs the position of the hand and will add to it to spawn the hand in
		# Will replace this with a marker tag later on
		var spawn_pos = global_transform.origin + -global_transform.basis.z * spawn_distance
		
		combiner.global_transform.origin = spawn_pos
		#new_obj.global_transform.origin = spawn_pos
		#new_obj.add_to_group("summonedObjects")
		# objectsInScene.append(new_obj)
		# print("Added", new_obj)
		# Add the new object to the scene
		new_obj.scale = objectSize * Vector3.ONE
		get_tree().current_scene.add_child(combiner)
		combiner.add_child(new_obj)
		new_obj.position = Vector3.ZERO
		combiner.use_collision = true
		
		combiner.collision_layer = combiner.collision_layer | (1 << 20)
		combiner.collision_mask = combiner.collision_mask | (1 << 20)
		
		new_obj.use_collision = true
		new_obj.collision_layer = 2
		print("Object Collision", new_obj.use_collision)
		print("Object Layer", new_obj.collision_layer)
		combiner.add_to_group("summonedObjects")
		summonedObjects = get_tree().get_nodes_in_group("summonedObjects") # Updates the summoned list within script
		emit_signal("objectSummoned")
		print(summonedObjects)
	else:
		print("Summonables out of index")

# Vertex / Verticies Functions
func summon_vertex():
	print("Summoning the vertex")
	var vertex = summonableObjects[3].instantiate()
	var spawn_pos = global_transform.origin + -global_transform.basis.z * spawn_distance
	vertex.global_position = spawn_pos
	get_tree().current_scene.add_child(vertex)
	
	await get_tree().process_frame
	
	vertex.use_collision = true
	vertex.collision_layer = 8
	vertex.collision_mask = 8
	vertex.add_to_group("placedVertices")
	
	placed_vertices = get_tree().get_nodes_in_group("placedVertices")
	connect_vertices[vertex] = []
	emit_signal("verticeSummoned")
	# print("Vertex placed : ", vertex.global_position)

func connect_vertex(vertex_1, vertex_2): # Assuming the this follows grip logic
	print("Connecting vertex : ", vertex_1, " : With vertex : ", vertex_2)
	if not is_instance_valid(vertex_1) or not is_instance_valid(vertex_2):
		return
	
	if vertex_2 not in connect_vertices[vertex_1]:
		connect_vertices[vertex_1].append(vertex_2)
	if vertex_1 not in connect_vertices[vertex_2]:
		connect_vertices[vertex_2].append(vertex_1)
	
	if ghostEdge and is_instance_valid(ghostEdge):
		ghostEdge.queue_free()
		ghostEdge = null

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
	
	mesh.global_position = mid
	mesh.look_at(vertex_1.global_position, Vector3.UP)
	mesh.rotate_object_local(Vector3.RIGHT, PI / 2)

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

func validate_mesh() -> bool:
	if placed_vertices.size() < 4:
		print("Required Vertices is 4")
		return false
		
	var vertices_usable = []
	for vertex in placed_vertices:
		if connect_vertices[vertex].size() == 0:
			print("Skip this vertex: Empty Connections :, ", vertex.global_position)
			continue
		if connect_vertices[vertex].size() < 3:
			print("Required connections is 3: ", vertex.global_position, " : only has : ", connect_vertices[vertex].size())
			continue
		vertices_usable.append(vertex)
		
	if vertices_usable.size() < 4:
		print("Required usable (connected) vertices is 4")
		return false
		
	var edge_count = 0
	for vertex in vertices_usable:
		edge_count += connect_vertices[vertex].size()
	edge_count /= 2
	
	var face_count = 0
	var vertex_index = {}
	for index in vertices_usable.size(): # Give each of the nodes dictionary index
		vertex_index[vertices_usable[index]] = index
	
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
	print("Vertices : ", V, " : Edges : ", E, " : Faces : ", F)
	
	if V - E + F != 2:
		print("Mesh isn't a closed manifold mesh")
		return false
		
	print("Valid Shape")
	return true

func build_mesh():
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
	
	var center = Vector3.ZERO
	for vertex in vertices_usable:
		center += vertex.global_position
	center /= vertices_usable.size()
	
	var vertex_index = {}
	for index in vertices_usable.size():
		vertex_index[vertices_usable[index]] = index
	
	var mesh_instance = MeshInstance3D.new()
	get_tree().current_scene.add_child(mesh_instance)
	mesh_instance.global_position = center
	
	await get_tree().process_frame
	
	var positions = []
	for v in vertices_usable:
		positions.append(mesh_instance.to_local(v.global_position))
	
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	
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
					var e1 = p2 - p1
					var e2 = p3 - p1
					var n = e1.cross(e2).normalized()
					vertices.push_back(p1)
					vertices.push_back(p2)
					vertices.push_back(p3)
					normals.push_back(n)
					normals.push_back(n)
					normals.push_back(n)
	
	if vertices.size() == 0:
		print("No triangles found")
		mesh_instance.queue_free()
		return
	
	var arr_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	
	var mat = StandardMaterial3D.new()
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	
	mesh_instance.mesh = arr_mesh
	mesh_instance.material_override = mat
	
	await get_tree().process_frame
	
	#if is_instance_valid(mesh_instance):
		#convert_to_csg(mesh_instance)
		#print("Converting the new mesh to a CSG")

	# print("Mesh built at: ", mesh_instance.global_position)

# Unused function due to CSGMesh3D not working with Dynamic ArrayMesh at Runtime 
func convert_to_csg(mesh_instance):
	if not is_instance_valid(mesh_instance):
		return
	
	var csg_mesh = csg.instantiate()
	var combiner = CSGCombiner3D.new()
	
	get_tree().current_scene.add_child(combiner)
	combiner.global_position = mesh_instance.global_position
	combiner.add_child(csg_mesh)
	csg_mesh.position = Vector3.ZERO
	
	await get_tree().process_frame
	
	var source_mesh = mesh_instance.mesh
	var surface_arrays = source_mesh.surface_get_arrays(0)

	if not surface_arrays[Mesh.ARRAY_TEX_UV]:
		var uvs = PackedVector2Array()
		for i in surface_arrays[Mesh.ARRAY_VERTEX].size():
			uvs.append(Vector2(0, 0))
		surface_arrays[Mesh.ARRAY_TEX_UV] = uvs

	var new_mesh = ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, surface_arrays)

	csg_mesh.call_deferred("set_mesh", new_mesh)
	
	await get_tree().process_frame

	print("mesh assigned to csg: ", csg_mesh.mesh)
	print("surface count: ", csg_mesh.mesh.get_surface_count())
	print("aabb: ", csg_mesh.mesh.get_aabb())
	print("vertex count: ", csg_mesh.mesh.surface_get_array_len(0))
	var format = csg_mesh.mesh.surface_get_format(0)
	print("has vertex: ", format & Mesh.ARRAY_FORMAT_VERTEX)
	print("has normal: ", format & Mesh.ARRAY_FORMAT_NORMAL)
	print("has UV: ", format & Mesh.ARRAY_FORMAT_TEX_UV)
	print("csg_mesh visible: ", csg_mesh.visible)
	print("combiner visible: ", combiner.visible)
	print("csg_mesh position: ", csg_mesh.position)
	print("combiner global position: ", combiner.global_position)
	
	await get_tree().process_frame
	
	csg_mesh.use_collision = true
	csg_mesh.collision_layer = 2
	combiner.use_collision = true
	combiner.collision_layer = true
	combiner.collision_layer = combiner.collision_layer | (1 << 20)
	combiner.collision_mask = combiner.collision_mask | (1 << 20)
	
	combiner.add_to_group("summonedObjects")
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects")
	emit_signal("objectSummoned")
	
	mesh_instance.queue_free()
	print("Coverted Mesh Instance to CSG at : ", combiner.global_position)
	
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

				for child in combiner.get_children():
					if child is CSGMesh3D:
						var aabb = child.get_aabb()
						var global_aabb = child.global_transform * aabb
						if global_aabb.has_point(hit_point):
							selected_obj = child
							break

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
		is_active = false

func change_csg_operation(idx):
	print("The new oepration is : ")
	csgIndex = idx

func update_list():
	#print("Hello from update list in Summon")
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects")
	placed_vertices = get_tree().get_nodes_in_group("placedVertices")

func set_summon_index(idx):
	print("Summon Called")
	summonIndex = idx
	if summonIndex == 3:
		ui_controller.build_load.visible = true
	else:
		ui_controller.build_load.visible = false
	
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
	else:
		print("No valid mesh is present")
