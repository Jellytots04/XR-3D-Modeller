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
		"description": "Press the X button to summon the tablet infront of you, this is where all the magic happens and all the functionalities are here, if you press the Y Button you can have it attached to your arm.",
		"tab": 0
	},
	{
		"title": "Build Tab (Summoning)",
		"description": "With this tab you can spawn in shapes and vertices to make your objects as well as copy any existing ones. \nPress the A Button and summon a cube!",
		"tab": 1
	},
	{
		"title": "Build Tab (Operations)",
		"description": "You can also select different types of operations for the objects summoned, Uinon (Merge), Intersection (Overlap only) or Subtract (Cut away). \nSelect subtract to cut a sphere from a cube",
		"tab": 2
	},
	{
		"title": "Build Tab (Vertices)",
		"description": "Here you can create objects from scratch, place vertices down connect them with grip then click load to create the shape. \n(These objects are on their own and don't work with summoned objects)",
		#"description": "Here you can create complex objects from scratch, this building style is on its own, (due to a Godot limitation this operation is on its own and does not work with other summoned objects), place vertices down with the A Button and combine it with the right grip.\nWhen you are happy press load and the object will appear. (Follows the Eulers Polyhedron Theorem)",
		"tab": 3
	},
	{
		"title": "Build Tab (Select and Copy)",
		"description": "The bottom row is in most of the tabs and is used for specifying the select type, Whole Select (Entire object), Multi Select (Individual Nodes), Single Node Select. \nCopy with Whole select and place down your copied object.",
		#"description": "Lastly selecting and Copy, the bottom row appears in most of the other tabs, they consist of Whole Select (The entie object tree), Multi Select (Select multiple single objects) or Single Select (Single node within a tree). \nFor copying you must use Whole select and once highlighted you can press the A Button to summon your copied object.",
		"tab": 4
	},
	{
		"title": "Remove Tab",
		"description": "Point and select an object, then press A to delete the object(s).\nHold A+B together for 2 seconds to clear the entire scene.",
		"tab": 5
	},
	{
		"title": "Edit Tab (Free Move)",
		"description": "This tab is where specifications can be done, firstly moving an object when you select object(s), you can press the right grip and the object will move along your controller!, \nTry move your object!",
		"tab": 6
	},
	{
		"title": "Edit Tab (Plane Move)",
		"description": "Now that you can move freely, as you can see when you select an object while in move mode, arrows appear, when you grip at one and you start moving your controller in that plane the object moves along side it!",
		"tab": 7
	},
	{
		"title": "Edit Tab (Stretch)",
		"description": "After moving you may want to change the object size, using the stretchy mode once selected you can use the two controller grips and start stretching your arms apart to increase the size, this works both ways!",
		"tab": 8
	},
	{
		"title": "Edit Tab (Free Rotation)",
		"description": "Rotating the object freely works the same as free move, when you have a selected object, you can press grip to start rotating your controller and the object will rotate in the same way. \nTry to spin a cube!",
		"tab": 9
	},
	{
		"title": "Edit Tab (Plane Rotation)",
		"description": "You might have noticed the gizmo infront of you, this is for plane rotation, similar to plane movements when you grip one of the rings, you can rotate in that oreintation and the object will rotate accordingly",
		"tab": 10
	},
	{
		"title": "Edit Tab (Plane Scaling)",
		"description": "Maybe you want more percise scaling, when you click the plane scaling option and you select an object, orbs will spawn, gripping one will allow you to scale the same way plane moving works!",
		"tab": 11
	},
	{
		"title": "World Tab (Visibility)",
		"description": "You may have noticed you can't see your Intersection or Subtractions, in the world Tab you can click the intersection or subtraction buttons to make them appear.\nThey can be edited now",
		"tab": 12
	},
	{
		"title": "World Tab (Snap feature)",
		"description": "Now everything is moving freely maybe you want things to be more measured, you can select the scale of meters to snap objects to, things will move in that increment.\n Works for Build and Edit functions",
		"tab": 13
	},
	{
		"title": "World Tab (Passthrough)",
		"description": "Maybe you would like to visualize your objects in the real world, well if you click the passthrough button, you'll be able to now work in your mixed reality setting.\nPress it again and you'll be back virtual!",
		"tab": 14
	},
	{
		"title": "File Tab (Saving the Scene)",
		"description": "Let's assume you're in a hurry and need to go, don't worry if you press the Save as button, you'll be able to type a name for your file and it will be saved to the headset!\nJust use the keyboard above to type then hit confirm",
		"tab": 15
	},
	{
		"title": "File Tab (Loading up files)",
		"description": "You're ready to start working on your project again, fantastic! Just click on the file name below then click load!\nJust be careful your current scene will not be saved so make sure to save before loading a new scene!",
		"tab": 16
	},
	{
		"title": "File Tab (Quick Save)",
		"description": "Incase you need to quickly save something, as long as you currently have saved the current scene or loaded an old scene, just hit Quick Save and you'll re save the scene no name needed!\nHowever if you're not on a saved file you will be prompted to save it first!",
		"tab": 17
	},
	{
		"title": "Export (Render)",
		"description": "Finally you have completed your object and you'd like to see it rendered, you can select the object, click render and it'll appear infront of you, you can play around with it and throw it about\n(This is not permanent and will not be saved to the scene)",
		"tab": 18
	},
	{
		"title": "Export (Godot Export)",
		"description": "These Rendered objects can be saved as well so don't worry too much, you can save it as a Godot Scene .tscn to be used in other Godot Projects.\nSelect your object, click Godot Export, give it a name and hit Godot Export again.",
		"tab": 19
	},
	{
		"title": "Export (.OBJ Export)",
		"description": "Lastly you can also export the objects as .OBJ to be used in other commercial and professional softwares, press .OBJ Export, select your object, give it a name and press .OBJ Export!\n(This will save its .mtl and .obj together)",
		"tab": 20
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
