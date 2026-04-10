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

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
