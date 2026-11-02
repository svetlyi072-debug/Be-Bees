extends Node

const SAVE_PATH := "user://user.json"
const FIREBASE_URL := "https://sshhoo-67dd8-default-rtdb.europe-west1.firebasedatabase.app"

var id: String = ""
var player_name: String = "Игрок"
var created_at: String = ""
var last_played: String = ""
var is_new_profile: bool = false

# Score lives on the server only — never trust/persist it locally,
# otherwise a player could just edit user.json to fake wins.
var games_played: int = 0
var white_wins: int = 0
var black_wins: int = 0
var draws: int = 0
var stats_synced: bool = false

func _ready() -> void:
	_load_identity()
	_pull_stats_from_firebase()

func _load_identity() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file != null:
			var text := file.get_as_text()
			file.close()
			var parsed = JSON.parse_string(text)
			if parsed is Dictionary:
				id = parsed.get("id", "")
				player_name = parsed.get("name", "Игрок")
				created_at = parsed.get("created_at", "")
	if id == "":
		id = _generate_id()
		player_name = "Игрок"
		created_at = Time.get_datetime_string_from_system()
		is_new_profile = true
	last_played = created_at
	_save_identity()

func _generate_id() -> String:
	var chars := "0123456789abcdef"
	var result := "u_"
	for i in 16:
		result += chars[randi() % chars.length()]
	return result

func set_player_name(new_name: String) -> void:
	player_name = new_name
	_save_identity()

func _save_identity() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({
			"id": id,
			"name": player_name,
			"created_at": created_at,
		}, "\t"))
		file.close()
	_push_profile_info()

func _push_profile_info() -> void:
	_firebase_put("users/%s/profile" % id, {
		"name": player_name,
		"created_at": created_at,
		"last_played": last_played,
	}, func(_ok: bool): pass)

# --- Stats: Firebase is the single source of truth ---

func _pull_stats_from_firebase() -> void:
	_firebase_get("users/%s/stats" % id, func(data: Variant):
		if data is Dictionary:
			games_played = _safe_int(data.get("games_played", 0), 0)
			white_wins = _safe_int(data.get("white_wins", 0), 0)
			black_wins = _safe_int(data.get("black_wins", 0), 0)
			draws = _safe_int(data.get("draws", 0), 0)
			stats_synced = true
		else:
			stats_synced = false
	)

func record_game_result(winner_color: String) -> void:
	# Re-read the authoritative value from the server right before
	# incrementing, so a locally edited/stale value is never the basis
	# for the new score, and if we can't reach the server, nothing is
	# written (no local fallback that could be tampered with).
	_firebase_get("users/%s/stats" % id, func(data: Variant):
		_on_record_result_fetched(data, winner_color)
	)

func _on_record_result_fetched(data: Variant, winner_color: String) -> void:
	var server_games: int = 0
	var server_white: int = 0
	var server_black: int = 0
	var server_draws: int = 0
	if data is Dictionary:
		server_games = _safe_int(data.get("games_played", 0), 0)
		server_white = _safe_int(data.get("white_wins", 0), 0)
		server_black = _safe_int(data.get("black_wins", 0), 0)
		server_draws = _safe_int(data.get("draws", 0), 0)

	server_games += 1
	if winner_color == "w":
		server_white += 1
	elif winner_color == "b":
		server_black += 1
	else:
		server_draws += 1

	var new_stats := {
		"games_played": server_games,
		"white_wins": server_white,
		"black_wins": server_black,
		"draws": server_draws,
	}
	_firebase_put("users/%s/stats" % id, new_stats, func(ok: bool):
		if not ok:
			push_warning("Firebase unreachable — game result was not recorded.")
			stats_synced = false
			return
		games_played = server_games
		white_wins = server_white
		black_wins = server_black
		draws = server_draws
		stats_synced = true
		last_played = Time.get_datetime_string_from_system()
		_push_profile_info()
	)

func _safe_int(value: Variant, default: int) -> int:
	# int() raises a runtime error on anything that isn't already a
	# number — this value comes from Firebase, which anyone with the
	# database URL can write to, so never hand it an unchecked Variant.
	return int(value) if value is int or value is float else default

# --- Network primitives: plain signal callbacks, no await/coroutines.
# (A version of this built on `await http.request_completed` reliably
# crashed this project within a few dozen window focus-loss/gain cycles
# while HTTPRequest calls were in flight — see online_match.gd. These
# calls are far less frequent than the online-match poll loop, so the
# exposure window here is small, but the same fix applies.)

func _firebase_get(path: String, on_done: Callable) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_get_done.bind(http, path, on_done))
	var err := http.request("%s/%s.json" % [FIREBASE_URL, path])
	if err != OK:
		push_warning("Firebase GET %s: request() failed with error %d" % [path, err])
		http.queue_free()
		on_done.call(null)

func _on_get_done(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, path: String, on_done: Callable) -> void:
	http.queue_free()
	if response_code != 200:
		push_warning("Firebase GET %s failed: result=%d code=%d body=%s" % [path, result, response_code, body.get_string_from_utf8()])
		on_done.call(null)
		return
	on_done.call(JSON.parse_string(body.get_string_from_utf8()))

func _firebase_put(path: String, value, on_done: Callable) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	var body := JSON.stringify(value)
	http.request_completed.connect(_on_put_done.bind(http, path, on_done))
	var err := http.request("%s/%s.json" % [FIREBASE_URL, path], ["Content-Type: application/json"], HTTPClient.METHOD_PUT, body)
	if err != OK:
		push_warning("Firebase PUT %s: request() failed with error %d" % [path, err])
		http.queue_free()
		on_done.call(false)

func _on_put_done(result: int, response_code: int, _headers: PackedStringArray, resp_body: PackedByteArray, http: HTTPRequest, path: String, on_done: Callable) -> void:
	http.queue_free()
	if response_code != 200:
		push_warning("Firebase PUT %s failed: result=%d code=%d body=%s" % [path, result, response_code, resp_body.get_string_from_utf8()])
	on_done.call(response_code == 200)
