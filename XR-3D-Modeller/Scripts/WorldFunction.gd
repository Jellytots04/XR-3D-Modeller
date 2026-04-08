extends Node3D

var tutorial_toast = preload("res://TutorialUI/IntroUI/3D_Intro_UI_Screen.tscn")
var tutorial_toast_instance = null

var tutorial_panel_scene = preload("res://TutorialUI/IntroUI/TutorialPanel.tscn")
var tutorial_panel_instance = null
var current_tutorial_step = 0

var ghosted_mesh = {}
var passthrough_on = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	print("Ready called worldfunction : ", get_path())
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
	spawn_tutorial_toast()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func toggle_passthrough():
	passthrough_on = not passthrough_on
	var start_xr = get_node("StartXR")
	start_xr.enable_passthrough = passthrough_on
	
	var env = get_node("WorldEnvironment").environment
	var floor_node = get_node("Floor/MeshInstance3D2")
	floor_node.visible = not passthrough_on
	env.volumetric_fog_enabled = not passthrough_on
	if passthrough_on:
		env.background_color = Color(0, 0, 0, 0)
	else:
		env.background_color = Color(0.506, 0.667, 0.667, 1.0) 

func intersections_visibility_changed(show):
	print("Show : ", show)
	if show:
		for combiner in get_tree().get_nodes_in_group("summonedObjects"):
			print("Checking combiner : ", combiner.name)
			if not combiner is CSGCombiner3D:
				continue
			for child in combiner.get_children():
				print("Child : ", child.name, " : operation : ", child.operation if child is CSGMesh3D else "N/A")
				if child is CSGMesh3D and child.operation == CSGShape3D.OPERATION_INTERSECTION:
					spawn_ghosted_obj(child)
	else:
		clear_ghosted("intersection_ghosts")

func subtraction_visibility_changed(show):
	print(show)
	if show:
		for combiner in get_tree().get_nodes_in_group("summonedObjects"):
			for child in combiner.get_children():
				if child is CSGMesh3D and child.operation == CSGShape3D.OPERATION_SUBTRACTION:
					spawn_ghosted_obj(child)
	else:
		clear_ghosted("subtraction_ghosts")

func spawn_ghosted_obj(obj):
	for ghost in ghosted_mesh.keys():
		if ghosted_mesh[ghost]["original"] == obj:
			return
	
	var ghost = obj.duplicate()
	
	ghost.remove_from_group("summonedObjects")
	ghost.remove_from_group("intersection_ghosts")
	ghost.remove_from_group("subtraction_ghosts")
	
	ghost.operation = CSGShape3D.OPERATION_UNION
	ghost.global_transform = obj.global_transform
	
	ghost.collision_layer = 4
	ghost.collision_mask = 0
	ghost.scale *= 1.002
	
	var mat = StandardMaterial3D.new()
	if obj.operation == CSGShape3D.OPERATION_INTERSECTION:
		mat.albedo_color = Color(1.0, 1.0, 0.5, 0.5)
		ghost.add_to_group("intersection_ghosts")
	else:
		mat.albedo_color = Color(1.0, 0, 0, 0.5)
		ghost.add_to_group("subtraction_ghosts")
		
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost.material = mat
	
	get_tree().root.add_child(ghost)
	ghost.remove_from_group("summonedObjects")
	
	ghosted_mesh[ghost] = {
		"original": obj,
		"original_combiner": obj.get_parent()
	}

func clear_ghosted(group):
	for ghost in get_tree().get_nodes_in_group(group):
		if is_instance_valid(ghost):
			ghosted_mesh.erase(ghost)
			ghost.queue_free()

func delete_ghosted(ghost):
	if ghost in ghosted_mesh:
		var data = ghosted_mesh[ghost]
		var original = data["original"]
		var combiner = data["original_combiner"]
		print("Deleting ghost: ", ghost)
		print("Deleting original: ", original)
		print("Deleting combiner: ", combiner)

		if is_instance_valid(original):
			original.queue_free()

		if is_instance_valid(combiner) and combiner.get_child_count() <= 1:
			combiner.queue_free()
		
		ghosted_mesh.erase(ghost)
		ghost.queue_free()
		
		await get_tree().process_frame

func clear_ghost_for_original(original):
	for ghost in ghosted_mesh.keys():
		if ghosted_mesh[ghost]["original"] == original:
			if is_instance_valid(ghost):
				ghost.queue_free()
			ghosted_mesh.erase(ghost)
			return

# Tutorial Functions and variables
func spawn_tutorial_toast():
	if WorldOptions.has_meta("tutorial_completed"):
		print("Tutorial has been completed")
		return
	
	tutorial_toast_instance = tutorial_toast.instantiate()
	
	var xr_camera = get_node("XROrigin3D/XRCamera3D")
	
	if xr_camera:
		add_child(tutorial_toast_instance)

		var forward = -xr_camera.global_transform.basis.z
		var spawn_pos = xr_camera.global_position + forward * 1.5
		spawn_pos.y = xr_camera.global_position.y + 1.5
		
		tutorial_toast_instance.global_position = spawn_pos
		
		tutorial_toast_instance.rotation.y = xr_camera.rotation.y
		tutorial_toast_instance.rotation.x = 0
		tutorial_toast_instance.rotation.z = 0
		
		connect_tutorial_button()
		print("Spawned in tutorial")

func connect_tutorial_button():
	var tutorial = tutorial_toast_instance.find_child("QuickTutorial", true, false)
	var skip = tutorial_toast_instance.find_child("Skip", true, false)
	
	print("Tutorial button found : ", tutorial, " : Skip button found : ", skip)
	
	if tutorial:
		tutorial.pressed.connect(quick_tutorial_pressed)
		print("Tutorial button connected")
	
	if skip:
		skip.pressed.connect(skip_pressed)
		print("Skip button connected")

func skip_pressed():
	print("Skip clicked!")
	
	if is_instance_valid(tutorial_toast_instance):
		tutorial_toast_instance.queue_free()
		tutorial_toast_instance = null

func quick_tutorial_pressed():
	print("Quick Tutorial clicked!")
	
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
		"title": "UI Tablet",
		"description": "Press the X button to summon the tablet infront of you, this is where all the magic happens and all the functionalities are here, if you press the Y Button you can have it attached to your arm",
		"tab": 0
	},
	{
		"title": "Summon Tab (Summoning)",
		"description": "With this tab you can spawn in shapes and vertices to make your objects as well as copy any existing ones, try to summon a cube!",
		"tab": 1
	},
	{
		"title": "Summon Tab (Operations)",
		"description": "You can also select different types of operations for the objects summoned, Uinon (Merge), Intersection (Overlap only) or Subtract (Cut away), try to cut a sphere from a cube",
		"tab": 2
	},
	{
		"title": "Summon Tab (Vertices)",
		"description": "Here you can create complex objects from scratch, this building style is on its own, (due to a Godot limitation this operation is on its own and does not work with other summoned objects), place vertices down with the A Button and combine it with the right grip.\nWhen you are happy press load and the object will appear. (Follows the Eulers Polyhedron Theorem)",
		"tab": 3
	},
	{
		"title": "Remove Tab",
		"description": "Point and press A to delete individual objects. Hold A+B together for 2 seconds to clear the entire scene.",
		"tab": 4
	},
	{
		"title": "File Tab",
		"description": "Save your work, load previous creations, or delete old files. All files are stored on your Quest's internal storage.",
		"tab": 5
	},
	{
		"title": "Export Tab",
		"description": "Render CSG objects as grabbable mesh items, or export as OBJ/TSCN files to use in other 3D software or Godot projects.",
		"tab": 6
	},
	{
		"title": "Tutorial Complete!",
		"description": "You're ready to create! Remember, you can always access this tutorial again from the Settings menu.",
		"tab": -1
	}
]

func show_tutorial_panel():
	if tutorial_panel_instance:
		tutorial_panel_instance.queue_free()
	
	tutorial_panel_instance = tutorial_panel_scene.instantiate()
	
	var xr_camera = get_node("XROrigin3D/XRCamera3D")
	if xr_camera:
		add_child(tutorial_panel_instance)
		
		var forward = -xr_camera.global_transform.basis.z
		var spawn_pos = xr_camera.global_position + forward * 2.0
		spawn_pos.y = xr_camera.global_position.y + 0.5
		
		tutorial_panel_instance.global_position = spawn_pos
		tutorial_panel_instance.rotation.y = xr_camera.rotation.y
		tutorial_panel_instance.rotation.x = 0
		tutorial_panel_instance.rotation.z = 0
	
	_connect_tutorial_buttons()
	update_tutorial_content()

func _connect_tutorial_buttons():
	var viewport = tutorial_panel_instance.get_node("Viewport")
	
	if not viewport:
		push_error("Could not find Viewport!")
		return

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

func update_tutorial_content():
	if not tutorial_panel_instance:
		return
	
	var step = tutorial_steps[current_tutorial_step]
	var viewport = tutorial_panel_instance.get_node("Viewport")
	
	var step_label = viewport.find_child("StepLabel", true, false)
	var title_label = viewport.find_child("TitleLabel", true, false)
	var desc_label = viewport.find_child("DescLabel", true, false)
	var back_btn = viewport.find_child("BackButton", true, false)
	var next_btn = viewport.find_child("NextButton", true, false)
	
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

func _on_tutorial_back():
	print("BACK CLICKED")
	if current_tutorial_step > 0:
		current_tutorial_step -= 1
		update_tutorial_content()

func _on_tutorial_next():
	print("NEXT CLICKED")
	if current_tutorial_step < tutorial_steps.size() - 1:
		current_tutorial_step += 1
		update_tutorial_content()
	else:
		_on_tutorial_exit()

func _on_tutorial_exit():
	print("EXIT CLICKED")
	if tutorial_panel_instance:
		tutorial_panel_instance.queue_free()
		tutorial_panel_instance = null
	print("Tutorial exited")
