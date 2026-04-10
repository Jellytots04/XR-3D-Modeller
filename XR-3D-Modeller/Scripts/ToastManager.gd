extends Node

var toast_scene = preload("res://GeneralUI/ToastUI/ToastScene.tscn")
var active_toasts = []
var toast_offset_y = 0.0
const TOAST_SPACING = 0.15
const TOAST_DURATION = 5.0

enum ToastType {
	SUCCESS,
	ERROR,
	INFO
}

func show_toast(title: String, message: String, type: ToastType = ToastType.INFO):
	var xr_camera = get_tree().get_first_node_in_group("xr_camera")
	
	if not xr_camera:
		print("No XR camera found for toast!")
		return
	
	match type:
		ToastType.SUCCESS:
			AudioManager.play_success_toast()
		ToastType.ERROR:
			AudioManager.play_error_toast()
		ToastType.INFO:
			AudioManager.play_info_toast()
	
	var toast = toast_scene.instantiate()
	get_tree().root.add_child(toast)
	
	var forward = -xr_camera.global_transform.basis.z
	var spawn_pos = xr_camera.global_position + forward * 1.2
	spawn_pos.y = xr_camera.global_position.y - 0.2 + toast_offset_y
	
	toast.global_position = spawn_pos
	
	var target_pos = xr_camera.global_position
	target_pos.y = toast.global_position.y
	toast.look_at(target_pos, Vector3.UP)
	toast.rotate_y(deg_to_rad(180))
	
	_configure_toast(toast, title, message, type)
	
	_connect_close_button(toast)
	
	active_toasts.append(toast)
	toast_offset_y += TOAST_SPACING
	
	await get_tree().create_timer(TOAST_DURATION).timeout
	if is_instance_valid(toast):
		_remove_toast(toast)
	
func _configure_toast(toast: Node,title: String, message: String, type: ToastType):
	var viewport = toast.get_node("Viewport/Viewport")
	var LabelContainer = viewport.find_child("BoxLabel", true, false)
	
	var titleLabel = LabelContainer.find_child("Title", true, false)
	if titleLabel:
		titleLabel.text = title
	else:
		print("Title")
	
	var descLabel = LabelContainer.find_child("Desc", true, false)
	if descLabel:
		descLabel.text = message
	
	var panel = viewport.find_child("Panel", true, false)
	if panel:
		var style_box = StyleBoxFlat.new()
		style_box.corner_radius_top_left = 4
		style_box.corner_radius_top_right = 4
		style_box.corner_radius_bottom_left = 4
		style_box.corner_radius_bottom_right = 4
		match type:
			ToastType.SUCCESS:
				style_box.bg_color = Color(0.063, 0.725, 0.506, 0.95)
			ToastType.ERROR:
				style_box.bg_color = Color(0.937, 0.267, 0.267, 0.95)
			ToastType.INFO:
				style_box.bg_color = Color(0.231, 0.510, 0.965, 0.95)
		panel.add_theme_stylebox_override("panel", style_box)
		
func _remove_toast(toast: Node):
	if toast in active_toasts:
		active_toasts.erase(toast)
	
	if is_instance_valid(toast):
		toast.queue_free()
		
	toast_offset_y = active_toasts.size() * TOAST_SPACING

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

func success(title: String, message: String):
	show_toast(title, message, ToastType.SUCCESS)

func error(title: String, message: String):
	show_toast(title, message, ToastType.ERROR)

func info(title: String, message: String):
	show_toast(title, message, ToastType.INFO)
