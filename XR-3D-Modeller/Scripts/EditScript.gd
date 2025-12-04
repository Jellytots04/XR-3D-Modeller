extends Node

signal objectMoved

@onready var controller = get_parent().get_parent()
@onready var raycast_3d = controller.get_node("RayCast3D")

var is_active = false
var summonedObjects
var objectsCurrentPos

# Highlighting variables
var original_materials = {}
var highlighted_object = null
var highlight_color = Color(0.587, 0.944, 0.536, 1.0) # Red highlight / Pinkish highlight
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
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

func _process(delta: float) -> void:
	if is_active:
		print("Currently Active")
		if controller.is_button_pressed("grip_click") and highlighted_object:
			print("Grip is active")
			moveObject(highlighted_object)
		update_highlighted_object()

func update_highlighted_object():
	# print("Ray update")
	if raycast_3d.is_colliding():
		var obj = raycast_3d.get_collider()
		if obj in summonedObjects:
			if obj != highlighted_object:
				if highlighted_object:
					_remove_highlight(highlighted_object)
				highlighted_object = obj
				_apply_highlight(highlighted_object)

	else:
		if highlighted_object:
			_remove_highlight(highlighted_object)
			highlighted_object = null

func moveObject(obj):
	print("Hello moving object moment")

func _apply_highlight(obj):
	var mesh_inst = null
	if obj is CSGMesh3D:
		print("obj is a CSGMesh3D")
		print(obj)
		mesh_inst = obj
		if obj.get_children():
			for child in obj.get_children():
				# _apply_highlight(obj.find_child("*CSGMesh3D*", true, false))
				_apply_highlight(child)
	elif obj.has_node("CSGMesh3D"):
		print("OBJ has a CSGMesh3D")
		mesh_inst = obj.get_node("CSGMesh3D")

	else:
		print("No CSGMesh3D available on object!")
		return

	if not mesh_inst.mesh:
		print("No mesh resource found on CSGMesh3D!")
		return

	original_materials[mesh_inst] = mesh_inst.material

	if mesh_inst.material:
		var mat = mesh_inst.material.duplicate()
		mat.albedo_color = highlight_color
		mesh_inst.material = mat

func _remove_highlight(obj):
	var mesh_inst = null
	if obj is CSGMesh3D:
		mesh_inst = obj
		if obj.get_children():
			for child in obj.get_children():
				# _remove_highlight(obj.find_child("*CSGMesh3D*", true, false))
				_remove_highlight(child)
	elif obj.has_node("CSGMesh3D"):
		mesh_inst = obj.get_node("CSGMesh3D")
	else:
		return
	if not mesh_inst.mesh:
		return
	if mesh_inst in original_materials:
		mesh_inst.material = original_materials[mesh_inst]
			# mesh_inst.set_surface_override_material(i, original_materials[mesh_inst][i])
		original_materials.erase(mesh_inst)

func set_page_index(idx):
	# print("Hello from remove call index")
	if idx == 2:
		is_active = true
	else:
		is_active = false

func update_list():
	print("Hello from Edit script new object update signal")
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects")
