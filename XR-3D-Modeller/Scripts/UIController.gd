extends Node3D

# Signals
signal change_page(index) # Signal for changing the page, will be used for state machine implementation
signal summonable_selected(index) # Singal for changing summonables in Summon script.
signal remove_selected(index) # Signal for choosing remove funcitons.
signal edit_selected(index) # Signal for choosing edit functions.
signal csg_operation(index) # Signal for choosing the csg operation in each of the scripts
signal scaleSize(value) # Signal for changing the building Scale size

@export var edit_scaleSize: HSlider # Allows this variable to be edited by variables in other scripts

func _ready():
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
		var remove_options = viewport_scene.get_node("Remove/VerticalArrangement/RemoveOptions") 
		var edit_tab = viewport_scene.get_node("Edit/VBoxContainer")
		var edit_options = edit_tab.get_node("EditOptions")
		edit_scaleSize = viewport_scene.get_node("ScaleBox/Scale") # HSlider node 

		# print(build_options)
		if build_options:
			for idx in range(build_options.get_child_count()):
				var button = build_options.get_child(idx)
				button.connect("pressed", Callable(self, "_build_option").bind(idx))
				print(idx)
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
				button.connect("pressed", Callable(self, "_csg_operation").bind(idx))
		else:
			print("csg operations are not found")

		if remove_options:
			for idx in range(remove_options.get_child_count()):
				var button = remove_options.get_child(idx)
				button.connect("pressed", Callable(self, "_remove_option").bind(idx))
				# print(idx)
		else:
			print("RemoveOptions node not found!")

		if edit_options:
			for idx in range(edit_options.get_child_count()):
				var button = edit_options.get_child(idx)
				button.connect("pressed", Callable(self, "_edit_option").bind(idx))
				# print(idx)
		else:
			print("EditOptions node not found!")
			
		if edit_scaleSize:
			edit_scaleSize.connect("value_changed", Callable(self, "_size_change"))
			print("Edit scales are connected")

	else:
		print("Viewport root scene not loaded!")

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
