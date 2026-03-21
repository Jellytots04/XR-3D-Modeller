extends Node3D

var snapEnabled: bool = false
var snapSizeMM: float = 10.0
var snapSizeM: float:
	get: return snapSizeMM / 1000

var showVisiblity: bool = false
signal intersectionsVisibilityChanged(visible:bool)
