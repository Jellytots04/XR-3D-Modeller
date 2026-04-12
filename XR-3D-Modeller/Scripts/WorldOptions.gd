extends Node3D

var snapEnabled: bool = false
var snapSizeMM: float = 10.0
var snapSizeM: float:
	get: return snapSizeMM / 1000

var showIntersection: bool = false
var showSubtraction: bool = false

signal intersectionsVisibilityChanged(visible:bool)
signal subtractionVisibilityChanged(visible: bool)

var is_saved: bool = false
var current_file_name: String = ""

func snap(value):
	if not snapEnabled:
		# print("Snap is not true!")
		return value
	# print("Welcome to snaps ville")
	var s = snapSizeM
	return round(value / s) * s

func snap_angle(radian):
	if not snapEnabled:
		return radian
	var step = deg_to_rad(snapSizeMM)
	return round(radian / step) * step

func snap_vec(v):
	return Vector3(snap(v.x), snap(v.y), snap(v.z))

func update_snap_state():
	var floating_hud = get_tree().get_first_node_in_group("floating_hud")
	if floating_hud:
		floating_hud.update_snap(snapEnabled, snapSizeMM)
