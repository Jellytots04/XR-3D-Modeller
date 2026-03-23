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
		var remove_options = viewport_scene.get_node("Remove/VerticalArrangement/RemoveOptions") 
		var remove_select = viewport_scene.get_node("Remove/VerticalArrangement/SelectOptions")
		var edit_tab = viewport_scene.get_node("Edit/VBoxContainer")
		var edit_options = edit_tab.get_node("EditOptions")
		var edit_select = edit_tab.get_node("SelectOptions")
		var world_tab = viewport_scene.get_node("World/MainContainer")
		intersection_button = world_tab.get_node("ShowingContainer/Showing/Operations/Intersection")
		subtraction_button = world_tab.get_node("ShowingContainer/Showing/Operations/Subtraction")
		var movement_slider = world_tab.get_node("MovementContainer/Movement/HSlider")
		var movement_toggle = world_tab.get_node("MovementContainer/Toggle")
		var movement_spinbox = world_tab.get_node("MovementContainer/Movement/SpinBox")
		
		movement_toggle.button_pressed = WorldOptions.snapEnabled
		movement_slider.value = WorldOptions.snapSizeMM
		movement_spinbox.value = WorldOptions.snapSizeMM
		
		movement_toggle.toggled.connect(_snap_toggled)
		movement_slider.value_changed.connect(_snap_slider_chaned.bind(movement_spinbox))
		movement_spinbox.value_changed.connect(_snap_spinBox_changed.bind(movement_slider))
		intersection_button.pressed.connect(_intersection_toggled)
		subtraction_button.pressed.connect(_subtraction_toggled)
		
		edit_scaleSize = edit_tab.get_node("ScaleBox/Scale") # HSlider node

		build_vertex = build_tab.get_node("VertexBuild") # HBoxContainer node
		build_load = build_vertex.get_node("Load") # Button Node
		build_clear = build_vertex.get_node("Clear") # Button Node
		
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

		if remove_options:
			for idx in range(remove_options.get_child_count()):
				var button = remove_options.get_child(idx)
				button.button_group = remove_options_group
				button.connect("pressed", Callable(self, "_remove_option").bind(idx))

		else:
			print("RemoveOptions node not found!")

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
			
		if edit_scaleSize:
			edit_scaleSize.connect("value_changed", Callable(self, "_size_change"))
			print("Edit scales are connected")
			
		if edit_select:
			for idx in range(edit_select.get_child_count()):
				var button = edit_select.get_child(idx)
				button.button_group = edit_select_group
				button.connect("pressed", Callable(self, "_select_option").bind(idx))

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

func _snap_toggled(pressed):
	WorldOptions.snapEnabled = pressed
	
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
