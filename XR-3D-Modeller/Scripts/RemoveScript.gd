extends Node

# Since this will always be attached to the right controller
@onready var controller = get_parent().get_parent()
@onready var raycast_3d = controller.get_node("RayCast3D")

var is_active = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var ui_controllers = get_tree().get_nodes_in_group("ui_controller")
	if ui_controllers.size() > 0:
		var ui_controller = ui_controllers[0]
		print("Hello from readying Remover")
		var connected = ui_controller.connect("change_page", Callable(self, "set_page_index"))
		print("Connection made: ", connected)
		print("UI Controller: ", ui_controller)
	print("Players controller: ", controller)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# print(controller.is_button_pressed("ax_button"))
	if controller.is_button_pressed("ax_button") and is_active:
		print("Hello From remove Script")

func set_page_index(idx):
	# print("Hello from remove call index")
	if idx == 1:
		is_active = true
	else:
		is_active = false
