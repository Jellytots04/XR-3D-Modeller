extends Node3D

# Set the variables
const HOLD_DURATION = 2.0
var hold_timer: float = 0.0
var is_holding: bool = false
var is_visible_ui: bool = false

# Signal for the remove script
signal clear_confirmed

func _ready():
	# Hides the confirmation node
	hide_confirmation()

func _process(delta):
	if not is_visible_ui:
		return
	
	# While the user holds start the timer variable.
	if is_holding:
		hold_timer += delta
		# Progressivly update the progress variable and the progress bar
		var progress = (hold_timer / HOLD_DURATION) * 100.0
		
		# Update progress bar safely
		update_progress_bar(progress)
		
		# Once completed emit the signal
		if hold_timer >= HOLD_DURATION:
			clear_confirmed.emit()
			reset()
	else:
		if hold_timer > 0:
			reset()

# Start the hold condition
func start_holding():
	is_holding = true
	show_confirmation()

# Stops the holding condition
func stop_holding():
	is_holding = false

# Reset the timer after timeout or upon premptive release
func reset():
	hold_timer = 0.0
	is_holding = false

	update_progress_bar(0)
	
	hide_confirmation()

# Updates the bar
func update_progress_bar(value: float):
	var viewport2 = get_node_or_null("Viewport2D")
	if not viewport2:
		return
	
	var viewport = viewport2.get_node_or_null("Viewport")
	if not viewport:
		return
	
	var progress_bar = viewport.find_child("ProgressBar", true, false)
	if not progress_bar:
		return
	
	progress_bar.value = value

func show_confirmation():
	is_visible_ui = true
	visible = true

func hide_confirmation():
	is_visible_ui = false
	visible = false
