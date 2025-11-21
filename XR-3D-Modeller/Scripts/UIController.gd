extends Node3D

signal change_page(index) # Signal for changing the page, will be used for state machine implementation
signal summonable_selected(index) # Singal for changing summonables in Summon script.
signal remove_selected(index) # Signal for choosing remove funcitons.
signal edit_selected(index) # Signal for choosing edit functions.

func _ready():
	add_to_group("ui_controller")
	var viewport_scene = $PickableObject/Viewport2Din3D/Viewport.get_child(0)
	if viewport_scene:
		var index = viewport_scene.current_tab
		var page = viewport_scene.get_child(index).name
		print("Current starting page: ", page)
		viewport_scene.connect("tab_changed", Callable(self, "_swap_page"))
		# Currently the values above do nothing.
		# But are here to prepare for swapping to state machine scripting
		var build_options = viewport_scene.get_node("Build/VerticalArrangement/BuildOptions")
		var remove_options = viewport_scene.get_node("Remove/VerticalArrangement/RemoveOptions")
		var edit_options = viewport_scene.get_node("Edit/VBoxContainer/EditOptions")
		# print(build_options)
		if build_options:
			for idx in range(build_options.get_child_count()):
				var button = build_options.get_child(idx)
				button.connect("pressed", Callable(self, "_build_option").bind(idx))
				print(idx)
		else:
			print("BuildOptions node not found!")

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

	else:
		print("Viewport root scene not loaded!")

func _build_option(idx):
	print("Button Pressed Summon", idx)
	emit_signal("summonable_selected", idx)

func _remove_option(idx):
	emit_signal("remove_selected", idx)

func _edit_option(idx):
	emit_signal("edit_selected", idx)

func _swap_page(idx):
	print("UI Controller idx emit, from _swap_page: ", idx)
	emit_signal("change_page", idx)
