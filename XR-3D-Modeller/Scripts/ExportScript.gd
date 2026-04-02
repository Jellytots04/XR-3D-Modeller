extends Node3D

@onready var controller = get_parent().get_parent()
@onready var raycast_3d = controller.get_node("Raycast3D")

# Flags
var is_active = false
var triggerPressed = false

# Select variables
var currentSelectedObject

# Highlighting Variables
var highlighted_object
var highlight_color = Color(0.756, 0.453, 0.105, 1.0)
var selected_color = Color(0.913, 0.967, 0.331, 1.0)
var true_materials = {}
var original_materials = {}
var highlighting_cancelled = false
var remove_highlighting_cancelled = false

# objects in scene
var summonedObjects = []
var meshInstances = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects")
	var summoner = get_node("../..")
	summoner.connect("objectSummoned", Callable(self, "update_list"))
	var editor = get_node("../EditFunction")
	editor.connect("objectEdited", Callable(self, "update_list"))
	var remover = get_node("../RemoveFunction")
	remover.connect("objectRemoved", Callable(self, "update_list"))
	var ui_controllers = get_tree().get_nodes_in_group("ui_controller")
	if ui_controllers.size() > 0:
		var ui_controller = ui_controllers[0]
		ui_controller.connect("change_page", Callable(self, "set_page_index"))
		ui_controller.connect("render_object", Callable(self, "render_selected"))
		print("Render Function connected to UI")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if is_active:
		print("It is now active time for Rendering")

func set_page_index(idx):
	# Adjust index to match your Render tab position
	if idx == 5:
		is_active = true
		update_list()
	else:
		is_active = false

func update_list():
	summonedObjects = get_tree().get_nodes_in_group("summonedObjects")
