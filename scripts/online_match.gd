class_name OnlineMatch
extends Node

signal opponent_joined(state: Dictionary)
signal state_updated(state: Dictionary)
signal join_failed(reason: String)

const FIREBASE_URL := "https://sshhoo-67dd8-default-rtdb.europe-west1.firebasedatabase.app"
const POLL_INTERVAL := 0.4
const ROOM_CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const ROOM_CODE_LENGTH := 5
const SESSION_PATH := "user://online_session.json"
const GAMES_PATH := "games"
const PUBLIC_ROOMS_PATH := "public_rooms"
const ROOM_NAME_MAX_LENGTH := 40
const STALE_SECONDS := 86400  # 24 hours of no activity — auto-expire and delete.

var room_code: String = ""
var room_name: String = ""
var my_color: String = "w"
var is_host: bool = false
var active: bool = false
var is_public: bool = false

var _last_move_count: int = -1
var _waiting_for_opponent: bool = false
var _poll_timer: Timer
var _window_focused: bool = true
var _poll_in_flight: bool = false

func _ready() -> void:
	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_INTERVAL
	_poll_timer.timeout.connect(_poll)
	add_child(_poll_timer)

	var window := get_tree().get_root()
	window.focus_exited.connect(_on_window_focus_lost)
	window.focus_entered.connect(_on_window_focus_gained)

func _on_window_focus_lost() -> void:
	_window_focused = false
	if active:
		_poll_timer.stop()

func _on_window_focus_gained() -> void:
	_window_focused = true
	if active:
		_poll_timer.start()
		_poll()

static func generate_room_code() -> String:
	var code := ""
	for i in ROOM_CODE_LENGTH:
		code += ROOM_CODE_CHARS[randi() % ROOM_CODE_CHARS.length()]
	return code

static func sanitize_room_code(raw: String) -> String:
	var cleaned := ""
	for c in raw.strip_edges().to_upper():
		if c in "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789":
			cleaned += c
	return cleaned

static func safe_int(value: Variant, default: int) -> int:
	# int() raises a runtime error on anything that isn't already a
	# number — this value comes from a Firebase room anyone can write
	# to, so never hand it an unchecked Variant.
	return int(value) if value is int or value is float else default

static func safe_string(value: Variant, default: String) -> String:
	return value if value is String else default

static func safe_bool(value: Variant, default: bool) -> bool:
	return value if value is bool else default

func _is_stale(data: Dictionary) -> bool:
	var updated_at = data.get("updated_at", null)
	if not (updated_at is int or updated_at is float):
		return false  # no timestamp recorded — don't expire it blindly
	return Time.get_unix_time_from_system() - updated_at > STALE_SECONDS

func _delete_room(code: String) -> void:
	_send_delete("%s/%s" % [GAMES_PATH, code], func(_ok): pass)
	_send_delete("%s/%s" % [PUBLIC_ROOMS_PATH, code], func(_ok): pass)

# A room's visibility is derived from whether the host typed a code: leave it
# blank and the room is public (auto-generated code, joinable by picking its
# name from the room list, no code needed); type a code and the room is
# private (still listed by name, but joining it needs that exact code).
func create_room(logic_state: Dictionary, code: String, name: String) -> void:
	var trimmed_code := code.strip_edges()
	var clean_code: String
	var make_public: bool
	if trimmed_code == "":
		clean_code = generate_room_code()
		make_public = true
	else:
		clean_code = sanitize_room_code(trimmed_code)
		make_public = false
	if clean_code == "":
		join_failed.emit("ONLINE_CODE_EMPTY_ERR")
		return
	room_code = clean_code
	room_name = name.strip_edges().substr(0, ROOM_NAME_MAX_LENGTH)
	is_host = true
	my_color = "w"
	is_public = make_public
	_send_get("%s/%s" % [GAMES_PATH, room_code], _on_create_room_checked.bind(logic_state))

func _on_create_room_checked(ok: bool, existing: Variant, logic_state: Dictionary) -> void:
	if ok and existing is Dictionary and existing.get("status", "") in ["waiting", "active"]:
		join_failed.emit("ONLINE_CODE_TAKEN")
		return
	var data := logic_state.duplicate(true)
	data["status"] = "waiting"
	data["move_count"] = 0
	data["last_move"] = null
	data["is_public"] = is_public
	data["name"] = room_name
	data["updated_at"] = Time.get_unix_time_from_system()
	_send_put("%s/%s" % [GAMES_PATH, room_code], data, _on_create_room_done)

func _on_create_room_done(ok: bool, _data: Variant) -> void:
	if not ok:
		join_failed.emit("ONLINE_CREATE_FAILED")
		return
	_last_move_count = 0
	_waiting_for_opponent = true
	active = true
	_poll_timer.start()
	_save_session()
	# Every room gets a listing entry now, public or private — names are
	# visible to everyone either way, only joining a private one needs its code.
	_send_put("%s/%s" % [PUBLIC_ROOMS_PATH, room_code], {
		"created_at": Time.get_unix_time_from_system(),
		"name": room_name,
		"is_public": is_public,
	}, func(_ok, _d): pass)

func list_rooms(on_done: Callable) -> void:
	_send_get(PUBLIC_ROOMS_PATH, func(ok: bool, data: Variant):
		if not ok or not (data is Dictionary):
			on_done.call([])
			return
		var now := Time.get_unix_time_from_system()
		var result := []
		for code in data.keys():
			var entry = data[code]
			if not (entry is Dictionary):
				continue
			var created_at = entry.get("created_at", null)
			if (created_at is int or created_at is float) and now - created_at > STALE_SECONDS:
				# Stale — nobody joined within 24h. Clean it up opportunistically
				# and leave it off the list rather than show a dead room.
				_delete_room(code)
				continue
			result.append({
				"code": code,
				"name": safe_string(entry.get("name", ""), ""),
				"is_public": safe_bool(entry.get("is_public", true), true),
			})
		on_done.call(result)
	)

func join_room(code: String) -> void:
	var clean_code := sanitize_room_code(code)
	if clean_code == "":
		join_failed.emit("ONLINE_ENTER_CODE")
		return
	_send_get("%s/%s" % [GAMES_PATH, clean_code], _on_join_room_fetched.bind(clean_code))

func _on_join_room_fetched(ok: bool, data: Variant, clean_code: String) -> void:
	if not ok or not (data is Dictionary):
		join_failed.emit("ONLINE_ROOM_NOT_FOUND")
		return
	if _is_stale(data):
		_delete_room(clean_code)
		join_failed.emit("ONLINE_ROOM_NOT_FOUND")
		return
	if data.get("status", "") != "waiting":
		join_failed.emit("ONLINE_ROOM_BUSY")
		return
	room_code = clean_code
	is_host = false
	my_color = "b"
	is_public = safe_bool(data.get("is_public", false), false)
	room_name = safe_string(data.get("name", ""), "")
	data["status"] = "active"
	data["updated_at"] = Time.get_unix_time_from_system()
	_send_put("%s/%s" % [GAMES_PATH, room_code], data, _on_join_room_put_done)

func _on_join_room_put_done(ok: bool, data: Variant) -> void:
	if not ok:
		join_failed.emit("ONLINE_CONNECT_FAILED")
		return
	_last_move_count = safe_int(data.get("move_count", 0), 0)
	active = true
	_poll_timer.start()
	_save_session()
	_send_delete("%s/%s" % [PUBLIC_ROOMS_PATH, room_code], func(_ok): pass)
	opponent_joined.emit(data)

func resume_session(saved_room_code: String, saved_my_color: String, saved_is_host: bool) -> void:
	room_code = saved_room_code
	my_color = saved_my_color
	is_host = saved_is_host
	_send_get("%s/%s" % [GAMES_PATH, room_code], _on_resume_fetched)

func _on_resume_fetched(ok: bool, data: Variant) -> void:
	if not ok or not (data is Dictionary):
		join_failed.emit("ONLINE_ROOM_GONE")
		return
	if _is_stale(data):
		_delete_room(room_code)
		join_failed.emit("ONLINE_ROOM_EXPIRED")
		return
	is_public = safe_bool(data.get("is_public", false), false)
	room_name = safe_string(data.get("name", ""), "")
	_last_move_count = safe_int(data.get("move_count", 0), 0)
	active = true
	_poll_timer.start()
	if data.get("status", "") == "waiting":
		_waiting_for_opponent = true
	else:
		_waiting_for_opponent = false
		opponent_joined.emit(data)

func submit_move(logic_state: Dictionary, last_move: Array) -> void:
	var data := logic_state.duplicate(true)
	data["status"] = "active"
	data["move_count"] = _last_move_count + 1
	data["last_move"] = _encode_move(last_move)
	data["is_public"] = is_public
	data["name"] = room_name
	data["updated_at"] = Time.get_unix_time_from_system()
	_send_put("%s/%s" % [GAMES_PATH, room_code], data, _on_submit_move_done)

func _on_submit_move_done(ok: bool, data: Variant) -> void:
	if ok:
		_last_move_count = safe_int(data.get("move_count", 0), _last_move_count)

func leave() -> void:
	if active and is_host and _waiting_for_opponent:
		# Nobody ever joined — no point leaving a dead room sitting around
		# for 24h, clean it up immediately instead of waiting for it to expire.
		_delete_room(room_code)
	active = false
	_poll_timer.stop()
	clear_saved_session()

# The game reached checkmate/stalemate — unlike leave(), this deletes the
# room unconditionally (win or lose, it's done either way), so a finished
# match doesn't sit around forever looking "active" and getting offered
# back as an unfinished game to resume.
func finish() -> void:
	if active:
		_delete_room(room_code)
	active = false
	_poll_timer.stop()
	clear_saved_session()

# One-shot cleanup for a room this client knows the code of but never
# instantiated a full session for (e.g. declining to resume a saved match).
# Frees itself once the delete requests have had time to land.
func discard_room(code: String) -> void:
	_delete_room(code)
	get_tree().create_timer(3.0).timeout.connect(queue_free)

static func load_saved_session() -> Dictionary:
	if not FileAccess.file_exists(SESSION_PATH):
		return {}
	var file := FileAccess.open(SESSION_PATH, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}

static func clear_saved_session() -> void:
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists("online_session.json"):
		dir.remove("online_session.json")

func _save_session() -> void:
	var file := FileAccess.open(SESSION_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({
			"room_code": room_code,
			"my_color": my_color,
			"is_host": is_host,
		}))
		file.close()

func _encode_move(last_move: Array) -> Variant:
	if last_move.size() != 2:
		return null
	var from: Vector2i = last_move[0]
	var to: Vector2i = last_move[1]
	return {"from": {"x": from.x, "y": from.y}, "to": {"x": to.x, "y": to.y}}

func _poll() -> void:
	if not active or _poll_in_flight:
		return
	_poll_in_flight = true
	_send_get("%s/%s" % [GAMES_PATH, room_code], _on_poll_fetched)

func _on_poll_fetched(ok: bool, data: Variant) -> void:
	_poll_in_flight = false
	if not ok or not (data is Dictionary):
		return
	if _is_stale(data):
		# Our own room went 24h with nobody acting on it (most likely we
		# created it and left the app open waiting, and nobody ever
		# joined). Expire it rather than poll a dead room forever.
		_delete_room(room_code)
		active = false
		_poll_timer.stop()
		clear_saved_session()
		join_failed.emit("ONLINE_ROOM_EXPIRED")
		return
	if _waiting_for_opponent and data.get("status", "") == "active":
		_waiting_for_opponent = false
		opponent_joined.emit(data)
	var move_count: int = safe_int(data.get("move_count", 0), 0)
	if move_count != _last_move_count:
		_last_move_count = move_count
		state_updated.emit(data)

# --- Network primitives: plain signal callbacks, no await/coroutines.
# (A version of this built on `await http.request_completed` reliably
# crashed the whole process within a few dozen window focus-loss/gain
# cycles while a match was active, even after pausing the poll timer and
# actively cancelling any in-flight request on focus loss. Rewritten to
# avoid coroutine suspension across a network callback entirely.)

func _send_get(path: String, on_done: Callable) -> void:
	if not _window_focused:
		on_done.call(false, null)
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_get_done.bind(http, on_done))
	var err := http.request("%s/%s.json" % [FIREBASE_URL, path])
	if err != OK:
		http.queue_free()
		on_done.call(false, null)

func _on_get_done(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, on_done: Callable) -> void:
	http.queue_free()
	if response_code != 200:
		on_done.call(false, null)
		return
	on_done.call(true, JSON.parse_string(body.get_string_from_utf8()))

func _send_put(path: String, data: Dictionary, on_done: Callable) -> void:
	if not _window_focused:
		on_done.call(false, data)
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_put_done.bind(http, on_done, data))
	var body_str := JSON.stringify(data)
	var err := http.request("%s/%s.json" % [FIREBASE_URL, path], ["Content-Type: application/json"], HTTPClient.METHOD_PUT, body_str)
	if err != OK:
		http.queue_free()
		on_done.call(false, data)

func _on_put_done(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray, http: HTTPRequest, on_done: Callable, data: Dictionary) -> void:
	http.queue_free()
	on_done.call(response_code == 200, data)

func _send_delete(path: String, on_done: Callable) -> void:
	if not _window_focused:
		on_done.call(false)
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_delete_done.bind(http, on_done))
	var err := http.request("%s/%s.json" % [FIREBASE_URL, path], [], HTTPClient.METHOD_DELETE)
	if err != OK:
		http.queue_free()
		on_done.call(false)

func _on_delete_done(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray, http: HTTPRequest, on_done: Callable) -> void:
	http.queue_free()
	on_done.call(response_code == 200)
