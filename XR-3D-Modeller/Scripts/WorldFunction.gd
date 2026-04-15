extends Node3D

# Flag
var is_pressed = false

# Tutorial Toast pop up preload
var tutorial_toast = preload("res://TutorialUI/IntroUI/3D_Intro_UI_Screen.tscn")
var tutorial_toast_instance = null

# Tutorial Panel preload
var tutorial_panel_scene = preload("res://TutorialUI/IntroUI/TutorialPanel.tscn")
var tutorial_panel_instance = null
var current_tutorial_step = 0

# Manual Panel preload
var manual_scene = preload("res://GeneralUI/ManualUI/ManualScene.tscn")
var manual_scene_instance = null

# Settings menu preload
var settings_menu = preload("res://GeneralUI/SettingsUI/SettingsScene.tscn")
var settings_menu_instance = null
var settings_menu_open = false

# Variables
var ghosted_mesh = {}
var passthrough_on = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	add_to_group("main_node")
	if not WorldOptions.intersectionsVisibilityChanged.is_connected(intersections_visibility_changed):
		WorldOptions.intersectionsVisibilityChanged.connect(intersections_visibility_changed)
	if not WorldOptions.subtractionVisibilityChanged.is_connected(subtraction_visibility_changed):
		WorldOptions.subtractionVisibilityChanged.connect(subtraction_visibility_changed)
	var env = get_node("WorldEnvironment").environment
	env.background_color = Color(0.902, 0.902, 0.922, 1.0)
	env.volumetric_fog_enabled = true
	get_node("Floor/MeshInstance3D2").visible = true
	SaveManager.ensure_directories() # Upon startup ensure the directories are real for saving
	await get_tree().create_timer(1.0).timeout
	spawn_tutorial_toast()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Settings pop up button
	var left_controller = get_node("XROrigin3D/LeftHand")
	if left_controller and left_controller.is_button_pressed("menu_button") and not is_pressed:
		toggle_settings_menu()
		is_pressed = true
	elif not left_controller.is_button_pressed("menu_button"):
		is_pressed = false

# Toggle the settings menu
func toggle_settings_menu():
	if settings_menu_open:
		close_settings_menu()
	else:
		open_settings_menu()

func show_manual():
	if manual_scene_instance:
		manual_scene_instance.queue_free()
	
	manual_scene_instance = manual_scene.instantiate()
	
	var xr_camera = get_node("XROrigin3D/XRCamera3D")
	if xr_camera:
		add_child(manual_scene_instance)
		
		var forward = -xr_camera.global_transform.basis.z
		var spawn_pos = xr_camera.global_position + forward * 6
		spawn_pos.y = xr_camera.global_position.y + 0.5
		
		manual_scene_instance.global_position = spawn_pos
		manual_scene_instance.look_at(xr_camera.global_position, Vector3.UP)
		manual_scene_instance.rotate_y(deg_to_rad(180))
	
	print("Manual opened")

# Open the settings menu
func open_settings_menu():
	if settings_menu_instance:
		return
	
	settings_menu_instance = settings_menu.instantiate()
	
	add_child(settings_menu_instance)
	
	var xr_camera = get_node("XROrigin3D/XRCamera3D")
	if xr_camera:
		var forward = -xr_camera.global_transform.basis.z
		var spawn_pos = xr_camera.global_position + forward * 6
		spawn_pos.y = xr_camera.global_position.y + 0.3
		
		# Face the users camera
		settings_menu_instance.global_position = spawn_pos
		settings_menu_instance.look_at(xr_camera.global_position, Vector3.UP)
		settings_menu_instance.rotate_y(deg_to_rad(180))
		settings_menu_instance.rotation.x = 0
		settings_menu_instance.rotation.z = 0
	
	_connect_settings_buttons()
	settings_menu_open = true

# Close settings menu
func close_settings_menu():
	if settings_menu_instance:
		settings_menu_instance.queue_free()
		settings_menu_instance = null
	settings_menu_open = false

# Connect the settings buttons to the script 
func _connect_settings_buttons():
	var viewport = settings_menu_instance.get_node("Viewport/Viewport")
	
	var tutorial_button = viewport.find_child("TutorialButton", true, false)
	var exit_button = viewport.find_child("ExitButton", true, false)
	var hud_button = viewport.find_child("HudButton", true, false)
	var volume_slider = viewport.find_child("SoundSlider", true, false)
	var haptics_toggle = viewport.find_child("HapticCheck", true, false)
	
	# Set their connection to their functions
	if tutorial_button:
		tutorial_button.pressed.connect(_settings_tutorial_pressed)
	if exit_button:
		exit_button.pressed.connect(_settings_exit_pressed)
	if hud_button:
		hud_button.pressed.connect(_settings_hud_pressed)
	if volume_slider:
		volume_slider.value = AudioManager.get_volume()
		volume_slider.value_changed.connect(_on_volume_changed)
	if haptics_toggle:
		haptics_toggle.button_pressed = AudioManager.haptics_enabled
		haptics_toggle.toggled.connect(_on_haptics_toggled)

# Volume changed function
func _on_volume_changed(value):
	AudioManager.set_volume(value)
	
# Haptics toggle on / off
func _on_haptics_toggled(enabled):
	AudioManager.set_haptics_enabled(enabled)

# Settings tutorial butto pressed
func _settings_tutorial_pressed():
	AudioManager.play_icon_click()
	close_settings_menu()
	current_tutorial_step = 0
	show_manual()

# Settings exit button pressed
func _settings_exit_pressed():
	AudioManager.play_icon_click()
	close_settings_menu()
	
# Settings hud pressed 
func _settings_hud_pressed():
	AudioManager.play_icon_click()
	var floating_hud = get_tree().get_first_node_in_group("floating_hud")
	if floating_hud:
		floating_hud.visible = not floating_hud.visible

# Toggle passthrough function
func toggle_passthrough():
	# Change the passthrough variable
	passthrough_on = not passthrough_on
	
	# Find the XR node
	var start_xr = get_node("StartXR")
	start_xr.enable_passthrough = passthrough_on
	
	# Grab the environment and floor node
	var env = get_node("WorldEnvironment").environment
	var floor_node = get_node("Floor/MeshInstance3D2")
	floor_node.visible = not passthrough_on
	env.volumetric_fog_enabled = not passthrough_on
	
	# Grab the hand mesh'
	var left_hand_mesh = get_node("XROrigin3D/LeftHand/LeftHand")
	var right_hand_mesh = get_node("XROrigin3D/RightHand/RightHand")

	# Turn off visibility for hands 
	if left_hand_mesh:
		left_hand_mesh.visible = not passthrough_on
	if right_hand_mesh:
		right_hand_mesh.visible = not passthrough_on

	# Clear background for passthrough
	if passthrough_on:
		env.background_color = Color(0, 0, 0, 0)
	else:
		env.background_color = Color(0.506, 0.667, 0.667, 1.0) 

# Intersections visibility function
func intersections_visibility_changed(show):
	# Will create the ghosted variables if show is true 
	if show:
		for combiner in get_tree().get_nodes_in_group("summonedObjects"):
			if not combiner is CSGCombiner3D:
				continue
			for child in combiner.get_children():
				if child is CSGMesh3D and child.operation == CSGShape3D.OPERATION_INTERSECTION:
					spawn_ghosted_obj(child)
	else: 
		clear_ghosted("intersection_ghosts")

# Subtraction visibility functoin
func subtraction_visibility_changed(show):
	# Will create the ghosted variables if show is true
	if show:
		for combiner in get_tree().get_nodes_in_group("summonedObjects"):
			for child in combiner.get_children():
				if child is CSGMesh3D and child.operation == CSGShape3D.OPERATION_SUBTRACTION:
					spawn_ghosted_obj(child)
	else:
		clear_ghosted("subtraction_ghosts")

# Spawn the ghosted object
func spawn_ghosted_obj(obj):
	# Check the ghosted mesh keys for a similarity
	for ghost in ghosted_mesh.keys():
		if ghosted_mesh[ghost]["original"] == obj:
			return
	
	# Duplicate the object
	var ghost = obj.duplicate()
	
	# Remove that ghost from all groups
	ghost.remove_from_group("summonedObjects")
	ghost.remove_from_group("intersection_ghosts")
	ghost.remove_from_group("subtraction_ghosts")
	
	# Set its operation as a Union
	ghost.operation = CSGShape3D.OPERATION_UNION
	ghost.global_transform = obj.global_transform
	
	# Change its scale and collision layer 
	ghost.collision_layer = 4
	ghost.collision_mask = 0
	ghost.scale *= 1.002
	
	# Change its material
	var mat = StandardMaterial3D.new()
	if obj.operation == CSGShape3D.OPERATION_INTERSECTION:
		mat.albedo_color = Color(1.0, 1.0, 0.5, 0.5)
		ghost.add_to_group("intersection_ghosts")
	else:
		mat.albedo_color = Color(1.0, 0, 0, 0.5)
		ghost.add_to_group("subtraction_ghosts")
		
	# Set its transparency
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.material = mat
	
	# Grab the main scene root
	get_tree().root.add_child(ghost)
	ghost.remove_from_group("summonedObjects")
	
	# Set the ghosted objects key
	ghosted_mesh[ghost] = {
		"original": obj,
		"original_combiner": obj.get_parent()
	}

# Clear ghosted group
func clear_ghosted(group):
	# Check the ghosts in the group
	for ghost in get_tree().get_nodes_in_group(group):
		if is_instance_valid(ghost):
			# Erase them from the array and free from the queue
			ghosted_mesh.erase(ghost)
			ghost.queue_free()

# Delete the ghosted object function
func delete_ghosted(ghost):
	if ghost in ghosted_mesh:
		var data = ghosted_mesh[ghost]
		var original = data["original"]
		var combiner = data["original_combiner"]

		# Ensure the original is valid
		if is_instance_valid(original):
			original.queue_free()

		# If the combiner is now empty queue free the combiner 
		if is_instance_valid(combiner) and combiner.get_child_count() <= 1:
			combiner.queue_free()
		
		# Erase the ghost from the array
		ghosted_mesh.erase(ghost)
		ghost.queue_free()
		
		# Wait a frame to ensure its fully processed
		await get_tree().process_frame

# Clear ghost via key
func clear_ghost_for_original(original):
	for ghost in ghosted_mesh.keys():
		if ghosted_mesh[ghost]["original"] == original:
			if is_instance_valid(ghost):
				ghost.queue_free()
			ghosted_mesh.erase(ghost)
			return

# Tutorial Functions and variables
func spawn_tutorial_toast():
	# Has tutorial been completed
	if WorldOptions.has_meta("tutorial_completed"):
		return
	
	# Instantiate the tutorial
	tutorial_toast_instance = tutorial_toast.instantiate()
	
	# Grab Camera Node
	var xr_camera = get_node("XROrigin3D/XRCamera3D")
	
	if xr_camera:
		# Add the toast to the scene
		add_child(tutorial_toast_instance)

		# Set the tutorial toast
		var forward = -xr_camera.global_transform.basis.z
		var spawn_pos = xr_camera.global_position + forward * 6
		spawn_pos.y = xr_camera.global_position.y + 0.5
		
		tutorial_toast_instance.global_position = spawn_pos
		# Rotate the camera towards the users camera
		tutorial_toast_instance.rotation.y = xr_camera.rotation.y
		tutorial_toast_instance.rotation.x = 0
		tutorial_toast_instance.rotation.z = 0
		
		# Connect the buttons
		connect_tutorial_button()

func connect_tutorial_button():
	# Grab the nodes from the scene
	var tutorial = tutorial_toast_instance.find_child("QuickTutorial", true, false)
	var skip = tutorial_toast_instance.find_child("Skip", true, false)
	
	if tutorial:
		tutorial.pressed.connect(quick_tutorial_pressed)
	
	if skip:
		skip.pressed.connect(skip_pressed)

# Skip button function
func skip_pressed():
	AudioManager.play_icon_click()
	
	if is_instance_valid(tutorial_toast_instance):
		tutorial_toast_instance.queue_free()
		tutorial_toast_instance = null

# Tutorial button function
func quick_tutorial_pressed():
	AudioManager.play_icon_click()
	
	if tutorial_toast_instance:
		tutorial_toast_instance.queue_free()
		tutorial_toast_instance = null
	
	current_tutorial_step = 0
	show_tutorial_panel()

# Tutorial steps text
var tutorial_steps = [
	{
		"title": "Welcome to PolyMesh VR",
		"description": "Let's learn the basics! Use the arrows to navigate through this tutorial at your own pace.",
		"tab": -1
	},
	{
		"title": "Movement",
		"description": "Firstly moving in this void world, you can use the left joystick to move around the area and with the right joystick you can look left to right!\nMove around!",
		"tab": 0
	},
	{
		"title": "UI Tablet",
		"description": "Press the X button to summon the tablet infront of you, this is where all the magic happens and all the functionalities are here, if you press the Y Button you can have it attached to your arm.",
		"tab": 1
	},
	{
		"title": "Build Tab",
		"description": "This tab allows you to summon objects, vertices, copy existing objects and play around with CSG Operations!",
		"tab": 2
	},
	{
		"title": "Remove Tab",
		"description": "Mistakes are bound to happen, using those 3 select buttons, feel free to remove an object from the scene with the A button and clear all with A + B button",
		"tab": 3
	},
	{
		"title": "Edit Tab",
		"description": "If you want to make some changes to objects like moving them around, rotating, or scaling them differntly then feel free to do so in this tab",
		#"description": "Here you can create complex objects from scratch, this building style is on its own, (due to a Godot limitation this operation is on its own and does not work with other summoned objects), place vertices down with the A Button and combine it with the right grip.\nWhen you are happy press load and the object will appear. (Follows the Eulers Polyhedron Theorem)",
		"tab": 4
	},
	{
		"title": "World Tab",
		"description": "In this tab you can mess around with the world settings like visibility of certain nodes, snap based movements and Passthrough",
		#"description": "Here you can create complex objects from scratch, this building style is on its own, (due to a Godot limitation this operation is on its own and does not work with other summoned objects), place vertices down with the A Button and combine it with the right grip.\nWhen you are happy press load and the object will appear. (Follows the Eulers Polyhedron Theorem)",
		"tab": 5
	},
	{
		"title": "File Tab",
		"description": "In this tab you are able to save the scene with Save as or Quick save, and if you always want to return to those saved files you can do so by loading the scene!",
		#"description": "Here you can create complex objects from scratch, this building style is on its own, (due to a Godot limitation this operation is on its own and does not work with other summoned objects), place vertices down with the A Button and combine it with the right grip.\nWhen you are happy press load and the object will appear. (Follows the Eulers Polyhedron Theorem)",
		"tab": 6
	},
	{
		"title": "Export Tab",
		"description": "In this tab you can render out your structures and objects to play around with in your virtual or mixed environment, then export the rendered mesh into a Godot .tscn or .OBJ file",
		#"description": "Here you can create complex objects from scratch, this building style is on its own, (due to a Godot limitation this operation is on its own and does not work with other summoned objects), place vertices down with the A Button and combine it with the right grip.\nWhen you are happy press load and the object will appear. (Follows the Eulers Polyhedron Theorem)",
		"tab": 7
	},
	{
		"title": "Settings",
		"description": "If you press the Menu button on the left controller you can always see the settings menu, this contains optionals for volume, haptics and the HUD as well as the Manual",
		#"description": "Here you can create complex objects from scratch, this building style is on its own, (due to a Godot limitation this operation is on its own and does not work with other summoned objects), place vertices down with the A Button and combine it with the right grip.\nWhen you are happy press load and the object will appear. (Follows the Eulers Polyhedron Theorem)",
		"tab": 8
	},
	{
		"title": "Tutorial Complete!",
		"description": "You're ready to create! Remember, you can access the in depth Manual through the settings, enjoy Creating!",
		"tab": -1
	}
]

# Show tutorial panel
func show_tutorial_panel():
	if tutorial_panel_instance:
		tutorial_panel_instance.queue_free()
	
	# Grab the panel instance
	tutorial_panel_instance = tutorial_panel_scene.instantiate()
	
	# Grab the camera node from the scene
	var xr_camera = get_node("XROrigin3D/XRCamera3D")
	if xr_camera:
		add_child(tutorial_panel_instance)
		
		# Set the distance
		var forward = -xr_camera.global_transform.basis.z
		var spawn_pos = xr_camera.global_position + forward * 6
		spawn_pos.y = xr_camera.global_position.y + 0.5
		
		# Set the rotation to face the user
		tutorial_panel_instance.global_position = spawn_pos
		tutorial_panel_instance.look_at(xr_camera.global_position, Vector3.UP)
		tutorial_panel_instance.rotate_y(deg_to_rad(180))
		tutorial_panel_instance.rotation.x = 0
		tutorial_panel_instance.rotation.z = 0
	
	_connect_tutorial_buttons()
	update_tutorial_content()

# Connects the buttons on the tutorial
func _connect_tutorial_buttons():
	# Grab the viewport
	var viewport = tutorial_panel_instance.get_node("Viewport")
	
	if not viewport:
		return

	# Grab the button nodes
	var back_btn = viewport.find_child("BackButton", true, false)
	var next_btn = viewport.find_child("NextButton", true, false)
	var exit_btn = viewport.find_child("ExitButton", true, false)
	
	if back_btn:
		back_btn.pressed.connect(_on_tutorial_back)
		print("Back button connected")
	if next_btn:
		next_btn.pressed.connect(_on_tutorial_next)
		print("Next button connected")
	if exit_btn:
		exit_btn.pressed.connect(_on_tutorial_exit)
		print("Exit button connected")

# Update the tutorial content
func update_tutorial_content():
	if not tutorial_panel_instance:
		return
	
	# Grab the nodes
	var step = tutorial_steps[current_tutorial_step]
	var viewport = tutorial_panel_instance.get_node("Viewport")
	
	# Grab the control nodes
	var step_label = viewport.find_child("StepLabel", true, false)
	var title_label = viewport.find_child("TitleLabel", true, false)
	var desc_label = viewport.find_child("DescLabel", true, false)
	var back_btn = viewport.find_child("BackButton", true, false)
	var next_btn = viewport.find_child("NextButton", true, false)
	
	# Update the variables with their respective fields
	if step_label:
		step_label.text = "Step %d / %d" % [current_tutorial_step + 1, tutorial_steps.size()]
	if title_label:
		title_label.text = step["title"]
	if desc_label:
		desc_label.text = step["description"]
	
	if back_btn:
		back_btn.disabled = (current_tutorial_step == 0)
	
	if next_btn:
		if current_tutorial_step == tutorial_steps.size() - 1:
			next_btn.text = "Finish"
		else:
			next_btn.text = "Next >"
	
	if step["tab"] >= 0:
		var ui_controller = get_node_or_null("XROrigin3D/RightHand/UIController")
		if ui_controller and ui_controller.has_method("switch_to_tab"):
			ui_controller.switch_to_tab(step["tab"])

# Back button on tutorial page
func _on_tutorial_back():
	AudioManager.play_icon_click()
	if current_tutorial_step > 0:
		current_tutorial_step -= 1
		update_tutorial_content()

# Next button on tutorial page
func _on_tutorial_next():
	AudioManager.play_icon_click()
	if current_tutorial_step < tutorial_steps.size() - 1:
		current_tutorial_step += 1
		update_tutorial_content()
	else:
		_on_tutorial_exit()

# Exit button on tutorial page
func _on_tutorial_exit():
	AudioManager.play_icon_click()
	if tutorial_panel_instance:
		tutorial_panel_instance.queue_free()
		tutorial_panel_instance = null
