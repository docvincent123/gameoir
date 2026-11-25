class_name AudioManager
extends Node

const MUSIC := preload("res://assets/audio/workshop.ogg")
const SAMPLES := {
	"tap": preload("res://assets/audio/tap.wav"),
	"press": preload("res://assets/audio/press.wav"),
	"stretch": preload("res://assets/audio/stretch.wav"),
	"cut": preload("res://assets/audio/cut.wav"),
	"separate": preload("res://assets/audio/separate.wav"),
	"land": preload("res://assets/audio/land.wav"),
	"refill": preload("res://assets/audio/refill.wav"),
	"combo": preload("res://assets/audio/combo.wav"),
	"best": preload("res://assets/audio/best.wav"),
	"over": preload("res://assets/audio/over.wav"),
}

var music: AudioStreamPlayer
var players: Array[AudioStreamPlayer] = []
var next_voice := 0
var sfx := true
var haptics := true

func _ready() -> void:
	for i in 8:
		var player := AudioStreamPlayer.new()
		add_child(player)
		players.append(player)
	music = AudioStreamPlayer.new()
	music.stream = MUSIC
	music.volume_db = -23
	add_child(music)

func configure(save: SaveManager) -> void:
	sfx = save.setting("sound", true)
	haptics = save.setting("haptics", true)
	if save.setting("music", true) and DisplayServer.get_name() != "headless":
		if not music.playing:
			music.play()
	else:
		music.stop()

func effect(key: String, volume := 0.0) -> void:
	if not sfx or DisplayServer.get_name() == "headless":
		return
	var player := players[next_voice]
	next_voice = (next_voice + 1) % players.size()
	player.stream = SAMPLES[key]
	player.pitch_scale = randf_range(0.93, 1.075)
	player.volume_db = volume - 8.0
	player.play()

func buzz(strength: int) -> void:
	if haptics and (OS.has_feature("android") or OS.has_feature("ios")):
		Input.vibrate_handheld(strength)

func _exit_tree() -> void:
	music.stop()
	music.stream = null
	for player in players:
		player.stop()
		player.stream = null
