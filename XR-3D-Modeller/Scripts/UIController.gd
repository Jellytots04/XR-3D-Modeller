extends Node3D

signal summonable_selected(index)

func _ready():
	add_to_group("ui_controller")
	var viewport_scene = $PickableObject/Viewport2Din3D/Viewport.get_child(0)
	print(viewport_scene)
	if viewport_scene:
		var build_options = viewport_scene.get_node("Build/VerticalArrangement/BuildOptions")
		print(build_options)
		if build_options:
			for idx in range(build_options.get_child_count()):
				var button = build_options.get_child(idx)
				button.connect("pressed", Callable(self, "_on_button_pressed").bind(idx))
				print(idx)
		else:
			print("BuildOptions node not found!")
	else:
		print("Viewport root scene not loaded!")
		
func _on_button_pressed(idx):
	print("Button Pressed Summon", idx)
	emit_signal("summonable_selected", idx)
