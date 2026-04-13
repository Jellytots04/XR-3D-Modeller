extends Node3D

# Snap variables
var snapEnabled: bool = false
var snapSizeMM: float = 10.0
var snapSizeM: float:
	get: return snapSizeMM / 1000

# Interaction booleans
var showIntersection: bool = false
var showSubtraction: bool = false

# Signals
signal intersectionsVisibilityChanged(visible:bool)
signal subtractionVisibilityChanged(visible: bool)

# Saving variables
var is_saved: bool = false
var current_file_name: String = ""

# Snap function for rounding up the world snap value
func snap(value):
	if not snapEnabled:
		return value
	var s = snapSizeM
	return round(value / s) * s

# Snap angle snapping angle for rotations
func snap_angle(radian):
	if not snapEnabled:
		return radian
	var step = deg_to_rad(snapSizeMM)
	return round(radian / step) * step

# Snap vector function, snaps the vector3 value
func snap_vec(v):
	return Vector3(snap(v.x), snap(v.y), snap(v.z))

# Updates the snapped state in the HUD
func update_snap_state():
	var floating_hud = get_tree().get_first_node_in_group("floating_hud")
	if floating_hud:
		floating_hud.update_snap(snapEnabled, snapSizeMM)
