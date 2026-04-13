extends XRController3D

# Variables for controller and HUD
var ui_controller
var floating_hud
var controller_Start
var docked = false
var dock_offset = Transform3D.IDENTITY

# Grab the nodes on the hand
@onready var dock_point = $LeftHand/Docking
@onready var dock_secondary = $LeftHand/Docking/Secondary
@onready var levitate_point = $LeftHand/Levitate
@onready var levitate_secondary = $LeftHand/Levitate/Secondary

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Grab the starting transform of the controller
	var ui_controllers = get_tree().get_nodes_in_group("ui_controller")
	if ui_controllers.size() > 0:
		ui_controller = ui_controllers[0]
	else:
		print("UI Controller not found")
	controller_Start = ui_controller.global_transform
	
	# Grab the HUD node
	var hud = get_tree().get_nodes_in_group("floating_hud")
	if hud.size() > 0:
		floating_hud = hud[0]
		print("Floating HUD found")
	else:
		print("Floating HUD not found")

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Every frame if docked set the controller and hud to follow the chand
	if docked:
		ui_controller.global_transform = dock_point.global_transform
		
		# Only lock if floating hud is active
		if floating_hud:
			floating_hud.global_transform = dock_secondary.global_transform

	# Bring the UI and HUD to the users left hand
	if is_button_pressed("ax_button"): # Meta Quest X button
		undock()
		ui_controller.global_transform = levitate_point.global_transform
		ui_controller.get_node("PickableObject").transform = dock_offset
		
		if floating_hud:
			floating_hud.global_transform = levitate_secondary.global_transform
			
			if floating_hud.has_node("PickableObject"):
				floating_hud.get_node("PickableObject").transform = dock_offset
	
	# Dock the controller and the HUD to the users left hand
	if is_button_pressed("by_button"): # Meta Quest Y button
		dock()
		ui_controller.global_transform = dock_point.global_transform
		ui_controller.get_node("PickableObject").transform = dock_offset
		
		if floating_hud:
			floating_hud.global_transform = dock_secondary.global_transform
			
			if floating_hud.has_node("PickableObject"):
				floating_hud.get_node("PickableObject").transform = dock_offset

func dock():
	docked = true
	ui_controller.global_transform = dock_point.global_transform
	if floating_hud:
		floating_hud.global_transform = dock_secondary.global_transform

func undock():
	docked = false
