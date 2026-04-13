extends Node

# Preloading sounds
var error_toast_1 = preload("res://Sounds/ErrorToast.sfxr")
var error_toast_2 = preload("res://Sounds/ErrorToast2.sfxr")
var success_toast = preload("res://Sounds/SuccessToast.sfxr")
var info_toast = preload("res://Sounds/InfoToast.sfxr")
var icon_click = preload("res://Sounds/IconClick.mp3")
var place_down_effect = preload("res://Sounds/PlaceDownEffect.wav")
var snap_effect = preload("res://Sounds/SnapSoundEffect.mp3")
var delete_whoosh = preload("res://Sounds/WhooshDeleteAudio.mp3")

# Audio Player variables
var audio_player = []
const MAX_PLAYERS = 10

# UX Settings
var volume_level = 1.0
var haptics_enabled = true

# Timer for the haptic conitue
var haptic_timers = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# This creates the pool for the AudioStreamPlayer nodes.
	# Prevents sounds from cutting each other off with different audio streams
	for i in range(MAX_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		audio_player.append(player)
	
	# Apply the initial volume level to the bus
	set_volume(volume_level)

# Function to set the volume
func set_volume(value):
	# Clamp the audio level between 0.0 and 1.0
	volume_level = clamp(value, 0.0, 1.0)
	
	var bus_index = AudioServer.get_bus_index("Master")
	
	# Will set the volume as long as the volume slider isn't at 0.0
	if volume_level > 0.0:
		var db_value = linear_to_db(volume_level)
		AudioServer.set_bus_volume_db(bus_index, db_value)
		AudioServer.set_bus_mute(bus_index, false)
	else:
		AudioServer.set_bus_mute(bus_index, true)

func get_volume():
	return volume_level

func set_haptics_enabled(enabled):
	haptics_enabled = enabled

# Grabs any available player
func _get_available_player() -> AudioStreamPlayer:
	for player in audio_player:
		if not player.playing:
			return player
	
	# Else return empty
	return audio_player[0]

# Play sound functions to be used elsewhere
func play_error_toast():
	var player1 = _get_available_player()
	player1.stream = error_toast_1
	player1.volume_db = -6.0
	player1.play()
	
	await player1.finished
	var player2 = _get_available_player()
	player2.stream = error_toast_2
	player2.volume_db = -6.0
	player2.play()

func play_info_toast():
	var player = _get_available_player()
	player.stream = info_toast
	player.volume_db = -6.0
	player.play()

func play_success_toast():
	var player = _get_available_player()
	player.stream = success_toast
	player.volume_db = -6.0
	player.play()

func play_place_down():
	var player = _get_available_player()
	player.stream = place_down_effect
	player.play()

func play_snap():
	var player = _get_available_player()
	player.stream = snap_effect
	player.play()

func play_whoosh():
	var player = _get_available_player()
	player.stream = delete_whoosh
	player.play()

func play_icon_click():
	var player = _get_available_player()
	player.stream = icon_click
	player.play()

# Haptic functions to be used elsewhere
func haptic_light(controller: XRController3D):
	if controller and haptics_enabled:
		controller.trigger_haptic_pulse("haptic", 0, 0.3, 0.1, 0)

func haptic_medium(controller: XRController3D):
	if controller and haptics_enabled:
		controller.trigger_haptic_pulse("haptic", 0, 0.5, 0.15, 0)

func haptic_heavy(controller: XRController3D):
	if controller and haptics_enabled:
		controller.trigger_haptic_pulse("haptic", 0, 0.8, 0.2, 0)

# Continuous haptic playback 
func haptic_continue(controller: XRController3D, duration: float, intensity: float):
	if not controller or not haptics_enabled:
		return
	
	haptic_stop(controller)
	
	# Create the timer
	var timer = get_tree().create_timer(duration)
	haptic_timers[controller] = timer

	# While holding the controller it will continue the haptic
	while is_instance_valid(controller) and timer.time_left > 0 and controller in haptic_timers:
		controller.trigger_haptic_pulse("haptic", 0, intensity, 0.05, 0)
		await get_tree().create_timer(0.05).timeout

	if controller in haptic_timers:
		haptic_timers.erase(controller)

# Stop the haptic
func haptic_stop(controller: XRController3D):
	if controller in haptic_timers:
		haptic_timers.erase(controller)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
