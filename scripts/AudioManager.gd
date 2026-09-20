extends Node

var _sfx: AudioStreamPlayer
var _bgm: AudioStreamPlayer
var _current_song: String = ""


func _ready() -> void:
	_sfx = AudioStreamPlayer.new()
	_sfx.bus = "Master"
	add_child(_sfx)
	_bgm = AudioStreamPlayer.new()
	_bgm.bus = "Master"
	_bgm.volume_db = -8.0
	add_child(_bgm)
	_bgm.finished.connect(_on_bgm_finished)


func play(name: String) -> void:
	var path := "res://assets/audio/%s.wav" % name
	if not ResourceLoader.exists(path):
		return
	_sfx.stream = load(path)
	_sfx.pitch_scale = randf_range(0.94, 1.06)
	_sfx.play()


func play_song(name: String, volume_db: float = -8.0) -> void:
	if _current_song == name and _bgm.playing:
		return
	var path := "res://assets/audio/%s.wav" % name
	if not ResourceLoader.exists(path):
		return
	_current_song = name
	_bgm.stream = load(path)
	_bgm.volume_db = volume_db
	_bgm.play()


func stop_song() -> void:
	_current_song = ""
	_bgm.stop()


func _on_bgm_finished() -> void:
	if _current_song != "":
		_bgm.play()
