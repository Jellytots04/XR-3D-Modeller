extends XRController3D

var ui_controller
var controller_Start
var docked = false
var dock_offset = Transform3D.IDENTITY

@onready var dock_point = $LeftHand/Docking
@onready var levitate_point = $LeftHand/Levitate

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var ui_controllers = get_tree().get_nodes_in_group("ui_controller")
	if ui_controllers.size() > 0:
		ui_controller = ui_controllers[0]
	else:
		print("UI Controller not found")
	controller_Start = ui_controller.global_transform

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if docked:
		ui_controller.global_transform = dock_point.global_transform

# Add tween to bring the Controller infront of the user
	if is_button_pressed("ax_button"): # Meta Quest X button
		undock()
		ui_controller.global_transform = levitate_point.global_transform
		ui_controller.get_node("PickableObject").transform = dock_offset
	
	if is_button_pressed("by_button"): # Meta Quest Y button
		dock()
		ui_controller.global_transform = dock_point.global_transform
		ui_controller.get_node("PickableObject").transform = dock_offset

# Add tween animation during UX focus for bringing the dock to the user
func dock():
	docked = true
	ui_controller.global_transform = dock_point.global_transform


func undock():
	docked = false
