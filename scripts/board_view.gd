class_name BoardView
extends Control

signal square_clicked(pos: Vector2i)

var SQUARE_SIZE: int = 80
const LIGHT_COLOR := Color(0.93, 0.87, 0.73)
const DARK_COLOR := Color(0.55, 0.38, 0.26)
const SELECT_COLOR := Color(0.95, 0.85, 0.25, 0.55)
const LAST_MOVE_COLOR := Color(0.85, 0.75, 0.2, 0.35)
const MOVE_DOT_COLOR := Color(0.1, 0.1, 0.1, 0.45)
const CHECK_COLOR := Color(0.9, 0.15, 0.15, 0.55)

const PIECE_LETTERS := {"pawn": "P", "knight": "N", "bishop": "B", "rook": "R", "queen": "Q", "king": "K"}

var logic: ChessLogic = null
var selected_pos: Vector2i = Vector2i(-1, -1)
var legal_moves: Array = []
var last_move: Array = []
var flipped: bool = false

var piece_layer: Control
var _texture_cache: Dictionary = {}
var _flip_tween: Tween

func _init(square_size: int = 80) -> void:
	SQUARE_SIZE = square_size
	custom_minimum_size = Vector2(SQUARE_SIZE * 8, SQUARE_SIZE * 8)
	size = custom_minimum_size
	pivot_offset = custom_minimum_size / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	piece_layer = Control.new()
	piece_layer.size = custom_minimum_size
	piece_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(piece_layer)

func _display(pos: Vector2i) -> Vector2i:
	# Orientation is now a visual Control.rotation tween (see set_flipped),
	# not a coordinate-space flip, so content is always laid out the same way.
	return pos

# Smoothly spins the whole board 180° instead of snapping pieces/squares to
# their mirrored positions instantly. Rotating the Control (around its own
# center, via pivot_offset) is visually identical to the old (7-x, 7-y)
# coordinate flip — Godot delivers _gui_input positions already adjusted for
# the node's rotation, so click-to-square mapping keeps working unchanged.
# Pieces counter-rotate around their OWN centers (see _counter_rotate_pieces)
# so their icons stay upright throughout — only the board itself visibly spins.
func set_flipped(new_flipped: bool, animate: bool = true) -> void:
	if new_flipped == flipped:
		return
	flipped = new_flipped
	var target_rotation := PI if flipped else 0.0
	if _flip_tween != null and _flip_tween.is_valid():
		_flip_tween.kill()
	if not animate:
		rotation = target_rotation
		_counter_rotate_pieces()
		return
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flip_tween = create_tween()
	_flip_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_flip_tween.tween_method(_apply_rotation, rotation, target_rotation, 0.5)
	_flip_tween.finished.connect(func(): mouse_filter = Control.MOUSE_FILTER_STOP)

func _apply_rotation(value: float) -> void:
	rotation = value
	_counter_rotate_pieces()

func _counter_rotate_pieces() -> void:
	for child in piece_layer.get_children():
		child.rotation = -rotation

func _to_screen(pos: Vector2i) -> Vector2:
	var d := _display(pos)
	return Vector2(d.x * SQUARE_SIZE, (7 - d.y) * SQUARE_SIZE)

func _to_board(local_pos: Vector2) -> Vector2i:
	var x = int(local_pos.x / SQUARE_SIZE)
	var y = 7 - int(local_pos.y / SQUARE_SIZE)
	return _display(Vector2i(x, y))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var board_pos = _to_board(event.position)
		if board_pos.x >= 0 and board_pos.x < 8 and board_pos.y >= 0 and board_pos.y < 8:
			square_clicked.emit(board_pos)

func refresh() -> void:
	queue_redraw()
	_rebuild_pieces()

func _rebuild_pieces() -> void:
	for child in piece_layer.get_children():
		child.queue_free()
	if logic == null:
		return
	for y in 8:
		for x in 8:
			var piece = logic.get_piece(Vector2i(x, y))
			if piece != null:
				piece_layer.add_child(_make_piece_node(Vector2i(x, y), piece))

func _load_piece_texture(path: String) -> Texture2D:
	if _texture_cache.has(path):
		return _texture_cache[path]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		var res := load(path)
		if res is Texture2D:
			tex = res
	_texture_cache[path] = tex
	return tex

func _make_piece_node(pos: Vector2i, piece) -> Control:
	var screen_pos := _to_screen(pos)
	var texture_path := "res://assets/pieces/%s_%s.png" % [piece.color, piece.type]
	var tex := _load_piece_texture(texture_path)
	if tex != null:
		var margin := SQUARE_SIZE * 0.08
		var rect := TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.position = Vector2(screen_pos.x + margin, screen_pos.y + margin)
		rect.size = Vector2(SQUARE_SIZE - margin * 2, SQUARE_SIZE - margin * 2)
		rect.pivot_offset = rect.size / 2.0
		rect.rotation = -rotation
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return rect
	return _make_placeholder_node(screen_pos, piece)

func _make_placeholder_node(screen_pos: Vector2, piece) -> Control:
	var holder := Control.new()
	holder.position = screen_pos
	holder.size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
	holder.pivot_offset = holder.size / 2.0
	holder.rotation = -rotation
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var d := SQUARE_SIZE * 0.72
	var panel := ColorRect.new()
	panel.size = Vector2(d, d)
	panel.position = Vector2((SQUARE_SIZE - d) / 2.0, (SQUARE_SIZE - d) / 2.0)
	panel.color = Color(0.97, 0.97, 0.95) if piece.color == "w" else Color(0.12, 0.12, 0.14)
	holder.add_child(panel)

	var label := Label.new()
	label.text = PIECE_LETTERS[piece.type]
	label.size = Vector2(SQUARE_SIZE, SQUARE_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", int(SQUARE_SIZE * 0.4))
	label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1) if piece.color == "w" else Color(0.9, 0.9, 0.9))
	holder.add_child(label)

	return holder

func _draw() -> void:
	if logic == null:
		return
	for y in 8:
		for x in 8:
			var pos := Vector2i(x, y)
			var color = LIGHT_COLOR if (x + y) % 2 == 0 else DARK_COLOR
			draw_rect(Rect2(_to_screen(pos), Vector2(SQUARE_SIZE, SQUARE_SIZE)), color)

	for mv in last_move:
		draw_rect(Rect2(_to_screen(mv), Vector2(SQUARE_SIZE, SQUARE_SIZE)), LAST_MOVE_COLOR)

	for color in ["w", "b"]:
		if logic.is_in_check(color):
			var king_pos = logic.find_king(color)
			if king_pos.x >= 0:
				draw_rect(Rect2(_to_screen(king_pos), Vector2(SQUARE_SIZE, SQUARE_SIZE)), CHECK_COLOR)

	if selected_pos.x >= 0:
		draw_rect(Rect2(_to_screen(selected_pos), Vector2(SQUARE_SIZE, SQUARE_SIZE)), SELECT_COLOR)

	for mv in legal_moves:
		var c := _to_screen(mv) + Vector2(SQUARE_SIZE / 2.0, SQUARE_SIZE / 2.0)
		draw_circle(c, SQUARE_SIZE * 0.14, MOVE_DOT_COLOR)
