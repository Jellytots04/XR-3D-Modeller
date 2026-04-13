extends Node

# Load toast scene
var toast_scene = preload("res://GeneralUI/ToastUI/ToastScene.tscn")
# Array to hold any active toasts in the scene 
var active_toasts = []
# Toast offset and variables
var toast_offset_y = 0.0
const TOAST_SPACING = 0.15
const TOAST_DURATION = 5.0

# Enum for the type of toasts possible
enum ToastType {
	SUCCESS,
	ERROR,
	INFO
}
# Function to show and summon the toast
func show_toast(title: String, message: String, type: ToastType = ToastType.INFO):
	# Grab the XRCamera
	var xr_camera = get_tree().get_first_node_in_group("xr_camera")
	
	# Return if not found
	if not xr_camera:
		return
	
	# Match the correct type with audio
	match type:
		ToastType.SUCCESS:
			AudioManager.play_success_toast()
		ToastType.ERROR:
			AudioManager.play_error_toast()
		ToastType.INFO:
			AudioManager.play_info_toast()
	
	# Initailize the toast scene and add to root scene
	var toast = toast_scene.instantiate()
	get_tree().root.add_child(toast)
	
	# Set the toasts spawn point 
	var forward = -xr_camera.global_transform.basis.z
	var spawn_pos = xr_camera.global_position + forward * 1.2
	spawn_pos.y = xr_camera.global_position.y - 0.2 + toast_offset_y
	
	toast.global_position = spawn_pos
	
	# Turn the toast into the user
	var target_pos = xr_camera.global_position
	target_pos.y = toast.global_position.y
	toast.look_at(target_pos, Vector3.UP)
	toast.rotate_y(deg_to_rad(180))
	
	# Configure the toast' message, title and type correctly
	_configure_toast(toast, title, message, type)
	
	# Connect the toast' close button
	_connect_close_button(toast)
	
	# Add it to the active toasts
	active_toasts.append(toast)
	toast_offset_y += TOAST_SPACING
	
	# Create a timer for the toast' duration
	await get_tree().create_timer(TOAST_DURATION).timeout
	# If it is no longer a valid instance, remove the toast
	if is_instance_valid(toast):
		_remove_toast(toast)

# Toast configuration function
func _configure_toast(toast: Node,title: String, message: String, type: ToastType):
	# Grab the nodes
	var viewport = toast.get_node("Viewport/Viewport")
	var LabelContainer = viewport.find_child("BoxLabel", true, false)
	
	var titleLabel = LabelContainer.find_child("Title", true, false)
	if titleLabel:
		titleLabel.text = title
	
	var descLabel = LabelContainer.find_child("Desc", true, false)
	if descLabel:
		descLabel.text = message
	
	# Set the toast' conditions and edit style
	var panel = viewport.find_child("Panel", true, false)
	if panel:
		var style_box = StyleBoxFlat.new()
		style_box.corner_radius_top_left = 4
		style_box.corner_radius_top_right = 4
		style_box.corner_radius_bottom_left = 4
		style_box.corner_radius_bottom_right = 4
		
		# Match the color to the type
		match type:
			ToastType.SUCCESS:
				style_box.bg_color = Color(0.063, 0.725, 0.506, 0.95)
			ToastType.ERROR:
				style_box.bg_color = Color(0.937, 0.267, 0.267, 0.95)
			ToastType.INFO:
				style_box.bg_color = Color(0.231, 0.510, 0.965, 0.95)
		panel.add_theme_stylebox_override("panel", style_box)

# Remove toast function after expiring or X is pressed
func _remove_toast(toast: Node):
	if toast in active_toasts:
		active_toasts.erase(toast)
	
	if is_instance_valid(toast):
		toast.queue_free()
		
	toast_offset_y = active_toasts.size() * TOAST_SPACING

# Connects the close button on the toast popup
func _connect_close_button(toast: Node):
		var viewport = toast.get_node("Viewport/Viewport")
		
		var close_button = viewport.find_child("CloseButton", true, false)
		
		if close_button:
			close_button.pressed.connect(func(): 
				AudioManager.play_icon_click()
				print("X clicked!")
				_remove_toast(toast))
			print("Close button connected for toast")
		else:
			print("Close button not found in toast!")

# Usable simplifier functions to be used in other scripts
func success(title: String, message: String):
	show_toast(title, message, ToastType.SUCCESS)

func error(title: String, message: String):
	show_toast(title, message, ToastType.ERROR)

func info(title: String, message: String):
	show_toast(title, message, ToastType.INFO)
