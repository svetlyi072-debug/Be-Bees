extends Node

const SAVE_PATH := "user://settings.json"
const CLICK_SOUND_PATH := "res://assets/sfx/bloop.wav"
const MUSIC_PATH := "res://assets/music/background.mp3"

# Baseline volumes for the two channels — the level that 100% ("the middle"
# of the 0-200% slider) corresponds to, i.e. what we ship with today.
const SOUND_BASELINE_DB := 0.0
const MUSIC_BASELINE_DB := -10.0
const MIN_AUDIBLE_DB := -80.0

var sound_enabled: bool = true
var music_enabled: bool = true
var sound_volume_percent: float = 100.0
var music_volume_percent: float = 100.0

var _click_stream: AudioStream
var _click_player: AudioStreamPlayer
var _music_player: AudioStreamPlayer

func _ready() -> void:
	_load()

	_click_player = AudioStreamPlayer.new()
	add_child(_click_player)
	_click_stream = _load_click_stream()
	_apply_sound_volume()

	_music_player = AudioStreamPlayer.new()
	add_child(_music_player)
	_music_player.stream = _load_music_stream()
	_apply_music_volume()
	_apply_music()

func _load_click_stream() -> AudioStream:
	if not ResourceLoader.exists(CLICK_SOUND_PATH):
		return null
	var res := load(CLICK_SOUND_PATH)
	return res if res is AudioStream else null

func _load_music_stream() -> AudioStream:
	if not ResourceLoader.exists(MUSIC_PATH):
		return null
	var res := load(MUSIC_PATH)
	if res is AudioStream:
		res.loop = true
		return res
	return null

func play_click() -> void:
	if not sound_enabled or _click_stream == null:
		return
	_click_player.stream = _click_stream
	_click_player.play()

func set_sound_enabled(enabled: bool) -> void:
	sound_enabled = enabled
	_save()

func set_music_enabled(enabled: bool) -> void:
	music_enabled = enabled
	_apply_music()
	_save()

func set_sound_volume_percent(percent: float) -> void:
	sound_volume_percent = clamp(percent, 0.0, 200.0)
	_apply_sound_volume()
	_save()

func set_music_volume_percent(percent: float) -> void:
	music_volume_percent = clamp(percent, 0.0, 200.0)
	_apply_music_volume()
	_save()

func _percent_to_db(percent: float, baseline_db: float) -> float:
	if percent <= 0.5:
		return MIN_AUDIBLE_DB
	return baseline_db + 20.0 * (log(percent / 100.0) / log(10.0))

func _apply_sound_volume() -> void:
	if _click_player != null:
		_click_player.volume_db = _percent_to_db(sound_volume_percent, SOUND_BASELINE_DB)

func _apply_music_volume() -> void:
	if _music_player != null:
		_music_player.volume_db = _percent_to_db(music_volume_percent, MUSIC_BASELINE_DB)

func _apply_music() -> void:
	if _music_player == null or _music_player.stream == null:
		return
	if music_enabled:
		if not _music_player.playing:
			_music_player.play()
		_music_player.stream_paused = false
	else:
		_music_player.stream_paused = true

func _load() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			var text := file.get_as_text()
			file.close()
			var parsed = JSON.parse_string(text)
			if parsed is Dictionary:
				sound_enabled = parsed.get("sound_enabled", true)
				music_enabled = parsed.get("music_enabled", true)
				sound_volume_percent = parsed.get("sound_volume_percent", 100.0)
				music_volume_percent = parsed.get("music_volume_percent", 100.0)

func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({
			"sound_enabled": sound_enabled,
			"music_enabled": music_enabled,
			"sound_volume_percent": sound_volume_percent,
			"music_volume_percent": music_volume_percent,
		}, "\t"))
		file.close()
