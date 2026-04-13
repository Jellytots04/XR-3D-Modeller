extends Node3D

# Grab the nodes inside of the HUD
@onready var viewport = $PickableObject/Viewport2Din3D/Viewport#
@onready var MainContainer = viewport.get_node("Panel/MainContainer")
@onready var Status = MainContainer.get_node("Status/StatusName")
@onready var Current = MainContainer.get_node("CurrentTab/TabName")
@onready var Select = MainContainer.get_node("SelectTab/SelectName")
@onready var Tool = MainContainer.get_node("ToolTab/ToolName")
@onready var SnapBool = MainContainer.get_node("SnapTab/SnapBool")
@onready var SnapSize = MainContainer.get_node("SnapTab/SnapSize")
@onready var FPS = MainContainer.get_node("PerformanceTab/FPS")

# Set variables to be used in the script 
var select_mode: String = "Group"
var tab_mode: String = "Summon"
var snap_enabled: bool = false
var snap_size_value: float = 0.1
var is_saved: bool = false
var world_name: String = ""
var edit_tool: String = "Enter Edit"
var current_tab: String = "Summon"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Set the worlds save state
	update_save_state(false, "")

	# Connect the signals
	connect_to_signals()
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Update the FPS every frame
	FPS.text = "%d" % Engine.get_frames_per_second()

# Updates all the labels
func update_all_labels():
	if is_saved and world_name != "":
		Status.text = "Saved (%s)" % world_name
	else:
		Status.text = "Not Saved"
	
	Current.text = tab_mode
	
	Select.text = select_mode
	
	Tool.text = edit_tool
	
	SnapBool.text = ("ON" if snap_enabled else "OFF")
	
	if snap_enabled:
		SnapSize.text = "%.1fMM" % snap_size_value
		SnapSize.visible = true
	else:
		SnapSize.visible = false

# Variable to connect signals together from the UI Controller
func connect_to_signals():
	var ui_controllers = get_tree().get_nodes_in_group("ui_controller")
	if ui_controllers.size() > 0:
		var ui_controller = ui_controllers[0]
		# Connect signals if they exist
		if ui_controller.has_signal("select_change"):
			ui_controller.select_change.connect(select_changed)
		if ui_controller.has_signal("change_page"):
			ui_controller.change_page.connect(tab_changed)

# Sets the changed select 
func select_changed(index):
	match index:
		0: select_mode = "Group"
		1: select_mode = "Multi"
		2: select_mode = "Single"
	update_all_labels()
	
# Sets the changed tab
func tab_changed(index):
	match index:
		0: tab_mode = "Summon"
		1: tab_mode = "Remove"
		2: tab_mode = "Edit"
		3: tab_mode = "World"
		4: tab_mode = "File"
		5: tab_mode = "Export"
	
	current_tab = tab_mode
	
	update_all_labels()

# Updates the snap variable
func update_snap(enabled, size):
	snap_enabled = enabled
	snap_size_value = size
	update_all_labels()

# Update the worlds saved state
func update_save_state(saved, name):
	is_saved = saved
	world_name = name
	update_all_labels()

# Update the edits tool
func update_edit_tool(tool_index):
	var tool_name = ""
	match tool_index:
		0: tool_name = "Move"
		1: tool_name = "Stretch"
		2: tool_name = "Rotate"
		3: tool_name = "Plane Scale"

	edit_tool = tool_name
	update_all_labels()

# Update the current tool used
func update_current_tool(tool_name):
	edit_tool = tool_name
	update_all_labels()
