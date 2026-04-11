extends Node3D

@onready var filter_type_option = $Viewport/Viewport/Panel/VBoxContainer/ColorBlind/ColorblindOptions
@onready var intensity_slider = $Viewport/Viewport/Panel/VBoxContainer/ColorBlind/IntensityBox/Intensity
@onready var intensity_box = $Viewport/Viewport/Panel/VBoxContainer/ColorBlind/IntensityBox
var colorblind_filter: MeshInstance3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	colorblind_filter = get_tree().get_first_node_in_group("color_blind_filter")
	
	if not colorblind_filter:
		push_error("Colorblind filter not found")
		return
	
	filter_type_option.item_selected.connect(filter_type_changed)
	
	intensity_slider.value_changed.connect(intensity_changed)
	
	print("Colorblind filter initialized!")
	
func filter_type_changed(index):
	print("Filter changed! : ", index)
	if index != 0:
		print("Visible time")
		intensity_box.visible = true
	else:
		print("Not so visible")
		intensity_box.visible = false

	if colorblind_filter and colorblind_filter.material_override:
		colorblind_filter.material.set_shader_parameter("filter_type", index)
		print("Filter changed")

func intensity_changed(value: float):
	if colorblind_filter and colorblind_filter.material_override:
		colorblind_filter.material.set_shader_parameter("severity", value)
		print("Severity changed to: ", value)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
