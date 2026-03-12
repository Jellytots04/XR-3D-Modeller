extends XRController3D

var ui_controller
var controller_Start
var docked = false
var dock_offset = Transform3D.IDENTITY

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
	if is_button_pressed("ax_button"): # Meta Quest X button
		ui_controller.global_transform = self.global_transform
		ui_controller.get_node("PickableObject").transform = dock_offset
	
	if is_button_pressed("by_button"): # Meta Quest Y button
		ui_controller.global_transform = self.global_transform
		ui_controller.get_node("PickableObject").transform = dock_offset
