class_name OnlineMatch
extends Node

signal opponent_joined(state: Dictionary)
signal state_updated(state: Dictionary)
signal join_failed(reason: String)

const FIREBASE_URL := "https://sshhoo-67dd8-default-rtdb.europe-west1.firebasedatabase.app"
const POLL_INTERVAL := 1.5
const ROOM_CODE_CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const ROOM_CODE_LENGTH := 5
const SESSION_PATH := "user://online_session.json"

var room_code: String = ""
var my_color: String = "w"
var is_host: bool = false
var active: bool = false

var _last_move_count: int = -1
var _waiting_for_opponent: bool = false
var _poll_timer: Timer
var _window_focused: bool = true

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

func create_room(logic_state: Dictionary) -> void:
	room_code = _generate_room_code()
	is_host = true
	my_color = "w"
	var data := logic_state.duplicate(true)
	data["status"] = "waiting"
	data["move_count"] = 0
	data["last_move"] = null
	_send_put(data, _on_create_room_done)

func _on_create_room_done(ok: bool, _data: Variant) -> void:
	if not ok:
		join_failed.emit("Не удалось создать комнату. Проверьте связь.")
		return
	_last_move_count = 0
	_waiting_for_opponent = true
	active = true
	_poll_timer.start()
	_save_session()

func join_room(code: String) -> void:
	var clean_code := code.strip_edges().to_upper()
	_send_get(clean_code, _on_join_room_fetched.bind(clean_code))

func _on_join_room_fetched(ok: bool, data: Variant, clean_code: String) -> void:
	if not ok or not (data is Dictionary):
		join_failed.emit("Комната не найдена.")
		return
	if data.get("status", "") != "waiting":
		join_failed.emit("В этой комнате уже играют.")
		return
	room_code = clean_code
	is_host = false
	my_color = "b"
	data["status"] = "active"
	_send_put(data, _on_join_room_put_done)

func _on_join_room_put_done(ok: bool, data: Variant) -> void:
	if not ok:
		join_failed.emit("Не удалось подключиться. Проверьте связь.")
		return
	_last_move_count = int(data.get("move_count", 0))
	active = true
	_poll_timer.start()
	_save_session()
	opponent_joined.emit(data)

func resume_session(saved_room_code: String, saved_my_color: String, saved_is_host: bool) -> void:
	room_code = saved_room_code
	my_color = saved_my_color
	is_host = saved_is_host
	_send_get(room_code, _on_resume_fetched)

func _on_resume_fetched(ok: bool, data: Variant) -> void:
	if not ok or not (data is Dictionary):
		join_failed.emit("Комната больше не существует.")
		return
	_last_move_count = int(data.get("move_count", 0))
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
	_send_put(data, _on_submit_move_done)

func _on_submit_move_done(ok: bool, data: Variant) -> void:
	if ok:
		_last_move_count = data["move_count"]

func leave() -> void:
	active = false
	_poll_timer.stop()
	clear_saved_session()

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

func _generate_room_code() -> String:
	var code := ""
	for i in ROOM_CODE_LENGTH:
		code += ROOM_CODE_CHARS[randi() % ROOM_CODE_CHARS.length()]
	return code

func _poll() -> void:
	if not active:
		return
	_send_get(room_code, _on_poll_fetched)

func _on_poll_fetched(ok: bool, data: Variant) -> void:
	if not ok or not (data is Dictionary):
		return
	if _waiting_for_opponent and data.get("status", "") == "active":
		_waiting_for_opponent = false
		opponent_joined.emit(data)
	var move_count: int = int(data.get("move_count", 0))
	if move_count != _last_move_count:
		_last_move_count = move_count
		state_updated.emit(data)

# --- Network primitives: plain signal callbacks, no await/coroutines.
# (A version of this built on `await http.request_completed` reliably
# crashed the whole process within a few dozen window focus-loss/gain
# cycles while a match was active, even after pausing the poll timer and
# actively cancelling any in-flight request on focus loss. Rewritten to
# avoid coroutine suspension across a network callback entirely.)

func _send_get(code: String, on_done: Callable) -> void:
	if not _window_focused:
		on_done.call(false, null)
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_get_done.bind(http, on_done))
	var err := http.request("%s/games/%s.json" % [FIREBASE_URL, code])
	if err != OK:
		http.queue_free()
		on_done.call(false, null)

func _on_get_done(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, http: HTTPRequest, on_done: Callable) -> void:
	http.queue_free()
	if response_code != 200:
		on_done.call(false, null)
		return
	on_done.call(true, JSON.parse_string(body.get_string_from_utf8()))

func _send_put(data: Dictionary, on_done: Callable) -> void:
	if not _window_focused:
		on_done.call(false, data)
		return
	var http := HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_put_done.bind(http, on_done, data))
	var body_str := JSON.stringify(data)
	var err := http.request("%s/games/%s.json" % [FIREBASE_URL, room_code], ["Content-Type: application/json"], HTTPClient.METHOD_PUT, body_str)
	if err != OK:
		http.queue_free()
		on_done.call(false, data)

func _on_put_done(_result: int, response_code: int, _headers: PackedStringArray, _body: PackedByteArray, http: HTTPRequest, on_done: Callable, data: Dictionary) -> void:
	http.queue_free()
	on_done.call(response_code == 200, data)
