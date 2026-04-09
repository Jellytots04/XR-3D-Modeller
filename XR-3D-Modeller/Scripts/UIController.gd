extends Node3D

# Signals
signal change_page(index) # Signal for changing the page, will be used for state machine implementation
signal summonable_selected(index) # Singal for changing summonables in Summon script.
signal remove_selected(index) # Signal for choosing remove funcitons.
signal edit_selected(index) # Signal for choosing edit functions.
signal csg_operation(index) # Signal for choosing the csg operation in each of the scripts
signal scaleSize(value) # Signal for changing the building Scale size
signal select_change(index) # Signal for changing the selected (select) option
signal load_mesh()
signal clear_vertices()
signal render_object
signal export_object(file_name)
signal export_obj_file(file_name)

@export var edit_scaleSize: HSlider # Allows this variable to be edited by variables in other scripts
@export var build_load: Button
@export var build_clear: Button
@export var build_vertex: HBoxContainer
var snap_controller: Control

# Build Button groups
var build_options_group = ButtonGroup.new()
var build_csg_group = ButtonGroup.new()
var build_select_group = ButtonGroup.new()

# Remove Button groups
var remove_options_group = ButtonGroup.new()
var remove_select_group = ButtonGroup.new()

# Edit Button groups
var edit_options_group = ButtonGroup.new()
var edit_select_group = ButtonGroup.new()

# Intersection and Subtraciton buttons
var intersection_button: Button
var subtraction_button: Button

# Virtual Keyboard / Saving and Loading variables
var save_name_input: LineEdit
var keyboard: Node
var confirm_button: Button
var loaded_scenes_container: HBoxContainer
var file_tab_node: Node
var selected_load_file: String = ""
var export_input_active = false
var export_name_input: LineEdit
var object_export_input_active = false

func _ready():
	_group_fix()
	add_to_group("ui_controller")
	var viewport_scene = $PickableObject/Viewport2Din3D/Viewport.get_child(0)
	if viewport_scene:
		var index = viewport_scene.current_tab
		var page = viewport_scene.get_child(index).name
		print("Current starting page: ", page)
		viewport_scene.connect("tab_changed", Callable(self, "_swap_page"))
		# Viewport_scene is = ControlPadDisplay
		# Currently the values above do nothing.
		# But are here to prepare for swapping to state machine scripting
		# Build tab used for getting to the children nodes quicker
		var build_tab = viewport_scene.get_node("Build/VerticalArrangement")
		var build_options = build_tab.get_node("BuildOptions") # Top hotbar for the build options
		var build_scaleSize = build_tab.get_node("ScaleOptions/Size")
		var build_always = build_tab.get_node("AlwaysEditable")
		var build_select = build_tab.get_node("SelectOptions")
		var remove_select = viewport_scene.get_node("Remove/VerticalArrangement/SelectOptions")
		var edit_tab = viewport_scene.get_node("Edit/VBoxContainer")
		var edit_options = edit_tab.get_node("EditOptions")
		var edit_select = edit_tab.get_node("SelectOptions")
		var edit_csg = edit_tab.get_node("AlwaysEditable")
		var world_tab = viewport_scene.get_node("World/MainContainer")
		intersection_button = world_tab.get_node("ShowingContainer/Showing/Operations/Intersection")
		subtraction_button = world_tab.get_node("ShowingContainer/Showing/Operations/Subtraction")
		var movement_slider = world_tab.get_node("MovementContainer/Movement/HSlider")
		var movement_toggle = world_tab.get_node("MovementContainer/Toggle")
		var movement_spinbox = world_tab.get_node("MovementContainer/Movement/SpinBox")
		var visual_button = world_tab.get_node("VisualButton")
		var file_tab = viewport_scene.get_node("File/MainContainer")
		var save_as_button = file_tab.get_node("SavingContainer/Showing/Operations/SaveAs")
		var quick_save_button = file_tab.get_node("SavingContainer/Showing/Operations/QuickSave")
		var load_button = file_tab.get_node("LoadContainer/LoadButton")
		var export_tab = viewport_scene.get_node("Export/VerticalArrangement")
		var rendering_button = export_tab.get_node("RenderingTab/RenderButton")
		var godot_export_button = export_tab.get_node("ExportingTab/SceneExport/SceneExportButton")
		var obj_export_button = export_tab.get_node("ExportingTab/OBJExport/OBJExportButton")
		
		loaded_scenes_container = file_tab.get_node("LoadContainer/SceneScroller/LoadedScenes")
		confirm_button = file_tab.get_node("SavingContainer/Showing/Confirm")
		save_name_input = file_tab.get_node("SavingContainer/Showing/File_Name")
		export_name_input = export_tab.get_node("SceneEdit")
		keyboard = get_node("PickableObject/VirtualKeyboard")
		
		
		movement_toggle.button_pressed = WorldOptions.snapEnabled
		movement_slider.value = WorldOptions.snapSizeMM
		movement_spinbox.value = WorldOptions.snapSizeMM
		
		movement_toggle.pressed.connect(_snap_toggled)
		movement_slider.value_changed.connect(_snap_slider_chaned.bind(movement_spinbox))
		movement_spinbox.value_changed.connect(_snap_spinBox_changed.bind(movement_slider))
		intersection_button.pressed.connect(_intersection_toggled)
		subtraction_button.pressed.connect(_subtraction_toggled)
		
		edit_scaleSize = edit_tab.get_node("ScaleBox/Scale") # HSlider node

		build_vertex = build_tab.get_node("VertexBuild") # HBoxContainer node
		build_load = build_vertex.get_node("Load") # Button Node
		build_clear = build_vertex.get_node("Clear") # Button Node
		
		save_as_button.connect("pressed", Callable(self, "_save_as_pressed"))
		confirm_button.connect("pressed", Callable(self, "_save_as_confirmed"))
		quick_save_button.connect("pressed", Callable(self, "_quick_save_pressed"))
		
		viewport_scene.connect("tab_changed", Callable(self, "_on_tab_changed"))
		load_button.connect("pressed", Callable(self, "_load_file"))
		
		rendering_button.connect("pressed", Callable(self, "_render_object"))
		
		godot_export_button.connect("pressed", Callable(self, "_export_pressed"))
		
		obj_export_button.connect("pressed", Callable(self, "_export_object_pressed"))
		
		# print(build_options)
		if build_options:
			for idx in range(build_options.get_child_count()):
				var button = build_options.get_child(idx)
				button.button_group = build_options_group
				button.connect("pressed", Callable(self, "_build_option").bind(idx))
				# print(idx)
		else:
			print("BuildOptions node not found!")

		print(build_scaleSize)
		if build_scaleSize:
			build_scaleSize.connect("value_changed", Callable(self, "_size_change"))
			# print("Build Scales are connected")
		else:
			print("Build Scales not found")

		if build_always:
			for idx in range(build_always.get_child_count()):
				var button = build_always.get_child(idx)
				button.button_group = build_csg_group
				button.connect("pressed", Callable(self, "_csg_operation").bind(idx))
		else:
			print("csg operations are not found")

		if build_select:
			for idx in range(build_select.get_child_count()):
				var button = build_select.get_child(idx)
				button.button_group = build_select_group
				button.connect("pressed", Callable(self, "_select_option").bind(idx))

		if build_load:
			build_load.connect("pressed", Callable(self, "_load_mesh"))
			
		if build_clear:
			build_clear.connect("pressed", Callable(self, "_clear_vertices"))

		if remove_select:
			for idx in range(remove_select.get_child_count()):
				var button = remove_select.get_child(idx)
				button.button_group = remove_select_group
				button.connect("pressed", Callable(self, "_select_option").bind(idx))
		else:
			print("Remove select is not available")

		if edit_options:
			for idx in range(edit_options.get_child_count()):
				var button = edit_options.get_child(idx)
				button.button_group = edit_options_group
				button.connect("pressed", Callable(self, "_edit_option").bind(idx))
				# print(idx)
		else:
			print("EditOptions node not found!")
			
		if edit_csg:
			for idx in range(edit_csg.get_child_count()):
				var button = edit_csg.get_child(idx)
				button.connect("pressed", Callable(self, "_csg_operation").bind(idx))
		else:
			print("Edit CSGs node not found")
		
		if edit_scaleSize:
			edit_scaleSize.connect("value_changed", Callable(self, "_size_change"))
			print("Edit scales are connected")
			
		if edit_select:
			for idx in range(edit_select.get_child_count()):
				var button = edit_select.get_child(idx)
				button.button_group = edit_select_group
				button.connect("pressed", Callable(self, "_select_option").bind(idx))
				
		if visual_button:
			visual_button.connect("pressed", Callable(self, "_passthrough_toggled"))

		_load_saved_list()

	else:
		print("Viewport root scene not loaded!")

func _group_fix():
	build_options_group.allow_unpress = false
	build_csg_group.allow_unpress = false
	build_select_group.allow_unpress = false
	remove_options_group.allow_unpress = false
	remove_select_group.allow_unpress = false
	edit_options_group.allow_unpress = false
	edit_select_group.allow_unpress = false

func _change_scale_value(value):
	edit_scaleSize.get_parent().visible = true
	edit_scaleSize.value = value.x 
	# can use any of the values z or y as they will always be the same

func _remove_scale():
	edit_scaleSize.get_parent().visible = false

func _build_option(idx):
	# print("Button Pressed Summon", idx)
	emit_signal("summonable_selected", idx)

func _remove_option(idx):
	emit_signal("remove_selected", idx)

func _edit_option(idx):
	emit_signal("edit_selected", idx)

func _swap_page(idx):
	# print("UI Controller idx emit, from _swap_page: ", idx)
	emit_signal("change_page", idx)

func _size_change(value):
	# print(value)
	scaleSize.emit(value) # Another way to emit signals with argument(s)

func _csg_operation(idx):
	csg_operation.emit(idx)

func _select_option(idx):
	emit_signal("select_change", idx)

func _load_mesh():
	emit_signal("load_mesh")

func _clear_vertices():
	emit_signal("clear_vertices")

func _snap_toggled():
	WorldOptions.snapEnabled = not WorldOptions.snapEnabled
	
func _snap_slider_chaned(value, spinBox):
	WorldOptions.snapSizeMM = value
	spinBox.set_value_no_signal(value)

func _snap_spinBox_changed(value, slider):
	WorldOptions.snapSizeMM = value
	slider.set_value_no_signal(value)
	
func _intersection_toggled():
	print("Called")
	WorldOptions.showIntersection = not WorldOptions.showIntersection
	WorldOptions.intersectionsVisibilityChanged.emit(WorldOptions.showIntersection)
	
func _subtraction_toggled():
	WorldOptions.showSubtraction = not WorldOptions.showSubtraction
	WorldOptions.subtractionVisibilityChanged.emit(WorldOptions.showSubtraction)

func _passthrough_toggled():
	var main = get_tree().get_first_node_in_group("main_node")
	main.toggle_passthrough()

func _save_as_pressed():
	save_name_input.visible = true
	save_name_input.grab_focus()
	keyboard.visible = true
	confirm_button.visible = true

func _save_as_confirmed():
	save_name_input.visible = false
	keyboard.visible = false
	confirm_button.visible = false
	var file_name = save_name_input.text
	if file_name.length() > 0 and file_name.length() <= 60:
		SaveManager.save_scene(file_name)
		keyboard.visible = false
		save_name_input.visible = false
	else:
		print("Invalid file name!")

func _quick_save_pressed():
	if not WorldOptions.is_saved or WorldOptions.current_file_name == "":
		_save_as_confirmed()
	else:
		SaveManager.save_scene(WorldOptions.current_file_name)

func _on_tab_changed(idx):
	if idx == 4:
		_load_saved_list()
		
func _load_saved_list():
	for child in loaded_scenes_container.get_children():
		child.queue_free()
		
	print("Loading files list")
	print("Container : ", loaded_scenes_container)
	var files = SaveManager.get_save_files()
	if files.size() == 0:
		print("No files found")
		return
	
	for file in files:
		
		var container = Control.new()
		container.custom_minimum_size = Vector2(45, 45)
		container.size = Vector2(45, 45)
		container.clip_contents = true
		
		var btn = Button.new()
		btn.text = file
		btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		btn.connect("pressed", Callable(self, "_select_load_file").bind(file, btn))
		loaded_scenes_container.add_child(btn)
		#print("Added button for : ", file)
		
		var del_btn = Button.new()
		del_btn.text = "X"
		del_btn.size = Vector2(15, 15)
		del_btn.position = Vector2(0,0)
		del_btn.connect("pressed", Callable(self, "_delete_save_file").bind(file))
		
		container.add_child(btn)
		container.add_child(del_btn)
		loaded_scenes_container.add_child(container)

func _select_load_file(file_name, btn):
	for child in loaded_scenes_container.get_children():
		child.modulate = Color(1,1,1,1)
		
	btn.modulate = Color(0.913, 0.967, 0.331, 1.0)
	selected_load_file = file_name
	print("Selected file : ", file_name)

func _load_file():
	if selected_load_file == "":
		print("No file selected")
		return
	print("Loading : ", selected_load_file)
	SaveManager.load_scene(selected_load_file)

func _delete_save_file(file_name):
	SaveManager.delete_save(file_name)
	_load_saved_list()

func _export_pressed():
	if not export_input_active and not object_export_input_active:
		export_name_input.visible = true
		export_name_input.grab_focus()
		keyboard.visible = true
		export_input_active = true
	elif export_input_active:
		var file_name = export_name_input.text
		if file_name.length() > 0 and file_name.length() <= 60:
			export_object.emit(file_name)
			export_name_input.text = ""
			export_name_input.visible = false
			keyboard.visible = false
			export_input_active = false
		else:
			print("Invalid file name")

func _export_object_pressed():
	if not object_export_input_active and not export_input_active:
		export_name_input.visible = true
		export_name_input.grab_focus()
		keyboard.visible = true
		object_export_input_active = true
	elif object_export_input_active:
		var file_name = export_name_input.text
		if file_name.length() > 0 and file_name.length() <= 60:
			export_obj_file.emit(file_name)
			export_name_input.text = ""
			export_name_input.visible = false
			keyboard.visible = false
			object_export_input_active = false
		else:
			print("Invalid file name")

func _render_object():
	emit_signal("render_object")
	
func switch_to_tab(tab_index: int):
	var viewport_scene = $PickableObject/Viewport2Din3D/Viewport.get_child(0)
	if viewport_scene:
		viewport_scene.current_tab = tab_index
		print("Switched tab via tutorial : ", tab_index)
