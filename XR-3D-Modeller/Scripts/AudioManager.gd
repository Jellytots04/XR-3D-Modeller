extends Node

var error_toast_1 = preload("res://Sounds/ErrorToast.sfxr")
var error_toast_2 = preload("res://Sounds/ErrorToast2.sfxr")
var success_toast = preload("res://Sounds/SuccessToast.sfxr")
var info_toast = preload("res://Sounds/InfoToast.sfxr")
var icon_click = preload("res://Sounds/IconClick.mp3")
var place_down_effect = preload("res://Sounds/PlaceDownEffect.wav")
var snap_effect = preload("res://Sounds/SnapSoundEffect.mp3")
var delete_whoosh = preload("res://Sounds/WhooshDeleteAudio.mp3")

var audio_player = []
const MAX_PLAYERS = 10

var volume_level

var haptic_timers = {}

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in range(MAX_PLAYERS):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		audio_player.append(player)

func _get_available_player() -> AudioStreamPlayer:
	for player in audio_player:
		if not player.playing:
			return player
	
	return audio_player[0]

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

func haptic_light(controller: XRController3D):
	if controller:
		controller.trigger_haptic_pulse("haptic", 0, 0.3, 0.1, 0)

func haptic_medium(controller: XRController3D):
	if controller:
		controller.trigger_haptic_pulse("haptic", 0, 0.5, 0.15, 0)

func haptic_heavy(controller: XRController3D):
	if controller:
		controller.trigger_haptic_pulse("haptic", 0, 0.8, 0.2, 0)

func haptic_continue(controller: XRController3D, duration: float, intensity: float):
	if not controller:
		return
	
	haptic_stop(controller)

	var timer = get_tree().create_timer(duration)
	haptic_timers[controller] = timer

	while is_instance_valid(controller) and timer.time_left > 0 and controller in haptic_timers:
		controller.trigger_haptic_pulse("haptic", 0, intensity, 0.05, 0)
		await get_tree().create_timer(0.05).timeout

	if controller in haptic_timers:
		haptic_timers.erase(controller)

func haptic_stop(controller: XRController3D):
	if controller in haptic_timers:
		haptic_timers.erase(controller)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
