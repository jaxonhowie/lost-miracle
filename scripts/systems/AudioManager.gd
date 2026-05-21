extends Node

var bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer
var _current_bgm_path: String = ""
var _bgm_fading: bool = false

func _ready():
	_ensure_bus("Music")
	_ensure_bus("SFX")

	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Music"
	bgm_player.name = "BGMPlayer"
	add_child(bgm_player)

	sfx_player = AudioStreamPlayer.new()
	sfx_player.bus = "SFX"
	sfx_player.name = "SFXPlayer"
	add_child(sfx_player)

func _ensure_bus(bus_name: String):
	if AudioServer.get_bus_index(bus_name) == -1:
		var idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")

func play_bgm(path: String):
	if path == _current_bgm_path and bgm_player.playing:
		return
	_current_bgm_path = path
	if not ResourceLoader.exists(path):
		bgm_player.stop()
		return
	var stream = load(path)
	if not stream:
		return
	if bgm_player.playing and not _bgm_fading:
		_bgm_fading = true
		var tween = create_tween()
		tween.tween_property(bgm_player, "volume_db", -40.0, 0.3)
		await tween.finished
	_bgm_fading = false
	bgm_player.stream = stream
	bgm_player.volume_db = -40.0
	bgm_player.play()
	var tween = create_tween()
	tween.tween_property(bgm_player, "volume_db", 0.0, 0.5)

func stop_bgm():
	if bgm_player.playing:
		_bgm_fading = true
		var tween = create_tween()
		tween.tween_property(bgm_player, "volume_db", -40.0, 0.5)
		await tween.finished
		bgm_player.stop()
		_bgm_fading = false
		_current_bgm_path = ""

func play_sfx(path: String):
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if not stream:
		return
	# Use a temporary player so multiple SFX can overlap
	var player = AudioStreamPlayer.new()
	player.bus = "SFX"
	player.stream = stream
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func play_sfx_pitched(path: String, pitch: float = 1.0):
	if not ResourceLoader.exists(path):
		return
	var stream = load(path)
	if not stream:
		return
	var player = AudioStreamPlayer.new()
	player.bus = "SFX"
	player.stream = stream
	player.pitch_scale = pitch
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
