extends XRController3D

var ui_controller

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var ui_controllers = get_tree().get_nodes_in_group("ui_controller")
	if ui_controllers.size() > 0:
		ui_controller = ui_controllers[0]
	else:
		print("UI Controller not found")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_button_pressed("ax_button"): # Meta Quest A button
		ui_controller.global_transform = self.global_transform
