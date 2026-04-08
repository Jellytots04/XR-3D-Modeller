extends Node3D

const HOLD_DURATION = 2.0
var hold_timer: float = 0.0
var is_holding: bool = false
var is_visible_ui: bool = false

signal clear_confirmed

func _ready():
	hide_confirmation()

func _process(delta):
	if not is_visible_ui:
		return
	
	if is_holding:
		hold_timer += delta
		var progress = (hold_timer / HOLD_DURATION) * 100.0
		
		# Update progress bar safely
		update_progress_bar(progress)
		
		if hold_timer >= HOLD_DURATION:
			print("Clear confirmed! Emitting signal")
			clear_confirmed.emit()
			reset()
	else:
		if hold_timer > 0:
			reset()

func start_holding():
	is_holding = true
	show_confirmation()
	print("Started holding for clear all")

func stop_holding():
	is_holding = false
	print("Stopped holding")

func reset():
	hold_timer = 0.0
	is_holding = false

	update_progress_bar(0)
	
	hide_confirmation()

func update_progress_bar(value: float):
	var viewport2 = get_node_or_null("Viewport2D")
	if not viewport2:
		print("ERROR: Viewport2 not found!")
		return
	
	var viewport = viewport2.get_node_or_null("Viewport")
	if not viewport:
		print("ERROR: Viewport not found!")
		return
	
	var progress_bar = viewport.find_child("ProgressBar", true, false)
	if not progress_bar:
		print("ERROR: ProgressBar not found!")
		return
	
	progress_bar.value = value

func show_confirmation():
	is_visible_ui = true
	visible = true

func hide_confirmation():
	is_visible_ui = false
	visible = false
