extends Node3D

var snapEnabled: bool = false
var snapSizeMM: float = 10.0
var snapSizeM: float:
	get: return snapSizeMM / 1000

var showIntersection: bool = false
var showSubtraction: bool = false

signal intersectionsVisibilityChanged(visible:bool)
signal subtractionVisibilityChanged(visible: bool)

func snap(value):
	if not snapEnabled:
		print("Snap is not true!")
		return value
	print("Welcome to snaps ville")
	var s = snapSizeM
	return round(value / s) * s

func snap_vec(v):
	return Vector3(snap(v.x), snap(v.y), snap(v.z))
