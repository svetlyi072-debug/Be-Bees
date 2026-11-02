class_name ChessLogic
extends RefCounted

const WHITE := "w"
const BLACK := "b"

const PIECE_CODES := {"pawn": "p", "knight": "n", "bishop": "b", "rook": "r", "queen": "q", "king": "k"}
const CODE_PIECES := {"p": "pawn", "n": "knight", "b": "bishop", "r": "rook", "q": "queen", "k": "king"}

var board: Array = []
var turn: String = WHITE
var en_passant_target: Vector2i = Vector2i(-1, -1)
var castling_rights: Dictionary = {}

func _init() -> void:
	reset_board()

func reset_board() -> void:
	board = []
	for y in 8:
		var row: Array = []
		row.resize(8)
		board.append(row)
	turn = WHITE
	en_passant_target = Vector2i(-1, -1)
	castling_rights = {"w_king": true, "w_queen": true, "b_king": true, "b_queen": true}
	var back_order := ["rook", "knight", "bishop", "queen", "king", "bishop", "knight", "rook"]
	for x in 8:
		board[0][x] = {"type": back_order[x], "color": WHITE}
		board[1][x] = {"type": "pawn", "color": WHITE}
		board[6][x] = {"type": "pawn", "color": BLACK}
		board[7][x] = {"type": back_order[x], "color": BLACK}

func in_bounds(pos: Vector2i) -> bool:
	return pos.x >= 0 and pos.x < 8 and pos.y >= 0 and pos.y < 8

func get_piece(pos: Vector2i):
	if not in_bounds(pos):
		return null
	return board[pos.y][pos.x]

func set_piece(pos: Vector2i, piece) -> void:
	board[pos.y][pos.x] = piece

func opponent(color: String) -> String:
	return BLACK if color == WHITE else WHITE

func find_king(color: String, b = null) -> Vector2i:
	var src = b if b != null else board
	for y in 8:
		for x in 8:
			var p = src[y][x]
			if p != null and p.color == color and p.type == "king":
				return Vector2i(x, y)
	return Vector2i(-1, -1)

func clone_board(b = null) -> Array:
	var src = b if b != null else board
	var copy: Array = []
	for y in 8:
		var row: Array = []
		for x in 8:
			var p = src[y][x]
			row.append(p.duplicate() if p != null else null)
		copy.append(row)
	return copy

func is_square_attacked(pos: Vector2i, by_color: String, b = null) -> bool:
	var src = b if b != null else board
	var dir = 1 if by_color == WHITE else -1
	for dx in [-1, 1]:
		var p_pos = pos + Vector2i(dx, -dir)
		if in_bounds(p_pos):
			var p = src[p_pos.y][p_pos.x]
			if p != null and p.color == by_color and p.type == "pawn":
				return true
	var knight_offsets = [Vector2i(1, 2), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(-2, 1), Vector2i(1, -2), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(-2, -1)]
	for off in knight_offsets:
		var n_pos = pos + off
		if in_bounds(n_pos):
			var p = src[n_pos.y][n_pos.x]
			if p != null and p.color == by_color and p.type == "knight":
				return true
	for dx2 in [-1, 0, 1]:
		for dy2 in [-1, 0, 1]:
			if dx2 == 0 and dy2 == 0:
				continue
			var k_pos = pos + Vector2i(dx2, dy2)
			if in_bounds(k_pos):
				var p = src[k_pos.y][k_pos.x]
				if p != null and p.color == by_color and p.type == "king":
					return true
	var rook_dirs = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	for d in rook_dirs:
		var cur = pos + d
		while in_bounds(cur):
			var p = src[cur.y][cur.x]
			if p != null:
				if p.color == by_color and (p.type == "rook" or p.type == "queen"):
					return true
				break
			cur += d
	var bishop_dirs = [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	for d in bishop_dirs:
		var cur = pos + d
		while in_bounds(cur):
			var p = src[cur.y][cur.x]
			if p != null:
				if p.color == by_color and (p.type == "bishop" or p.type == "queen"):
					return true
				break
			cur += d
	return false

func is_in_check(color: String, b = null) -> bool:
	var src = b if b != null else board
	var king_pos = find_king(color, src)
	if king_pos.x < 0:
		return false
	return is_square_attacked(king_pos, opponent(color), src)

func generate_pseudo_moves(pos: Vector2i) -> Array:
	var piece = get_piece(pos)
	if piece == null:
		return []
	match piece.type:
		"pawn":
			return _pawn_moves(pos, piece)
		"knight":
			return _knight_moves(pos, piece)
		"bishop":
			return _sliding_moves(pos, piece, [Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)])
		"rook":
			return _sliding_moves(pos, piece, [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)])
		"queen":
			return _sliding_moves(pos, piece, [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)])
		"king":
			return _king_moves(pos, piece)
	return []

func _pawn_moves(pos: Vector2i, piece) -> Array:
	var moves: Array = []
	var dir = 1 if piece.color == WHITE else -1
	var start_rank = 1 if piece.color == WHITE else 6
	var one = pos + Vector2i(0, dir)
	if in_bounds(one) and get_piece(one) == null:
		moves.append(one)
		var two = pos + Vector2i(0, dir * 2)
		if pos.y == start_rank and get_piece(two) == null:
			moves.append(two)
	for dx in [-1, 1]:
		var cap = pos + Vector2i(dx, dir)
		if in_bounds(cap):
			var target = get_piece(cap)
			if target != null and target.color != piece.color:
				moves.append(cap)
			elif cap == en_passant_target:
				moves.append(cap)
	return moves

func _knight_moves(pos: Vector2i, piece) -> Array:
	var moves: Array = []
	var offsets = [Vector2i(1, 2), Vector2i(2, 1), Vector2i(-1, 2), Vector2i(-2, 1), Vector2i(1, -2), Vector2i(2, -1), Vector2i(-1, -2), Vector2i(-2, -1)]
	for off in offsets:
		var p = pos + off
		if in_bounds(p):
			var target = get_piece(p)
			if target == null or target.color != piece.color:
				moves.append(p)
	return moves

func _sliding_moves(pos: Vector2i, piece, dirs: Array) -> Array:
	var moves: Array = []
	for d in dirs:
		var cur = pos + d
		while in_bounds(cur):
			var target = get_piece(cur)
			if target == null:
				moves.append(cur)
			else:
				if target.color != piece.color:
					moves.append(cur)
				break
			cur += d
	return moves

func _king_moves(pos: Vector2i, piece) -> Array:
	var moves: Array = []
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var p = pos + Vector2i(dx, dy)
			if in_bounds(p):
				var target = get_piece(p)
				if target == null or target.color != piece.color:
					moves.append(p)
	var rights_king = piece.color + "_king"
	var rights_queen = piece.color + "_queen"
	if not is_square_attacked(pos, opponent(piece.color)):
		if castling_rights.get(rights_king, false):
			var f1 = pos + Vector2i(1, 0)
			var f2 = pos + Vector2i(2, 0)
			if get_piece(f1) == null and get_piece(f2) == null:
				if not is_square_attacked(f1, opponent(piece.color)) and not is_square_attacked(f2, opponent(piece.color)):
					moves.append(f2)
		if castling_rights.get(rights_queen, false):
			var q1 = pos + Vector2i(-1, 0)
			var q2 = pos + Vector2i(-2, 0)
			var q3 = pos + Vector2i(-3, 0)
			if get_piece(q1) == null and get_piece(q2) == null and get_piece(q3) == null:
				if not is_square_attacked(q1, opponent(piece.color)) and not is_square_attacked(q2, opponent(piece.color)):
					moves.append(q2)
	return moves

func generate_legal_moves(pos: Vector2i) -> Array:
	var piece = get_piece(pos)
	if piece == null:
		return []
	var pseudo = generate_pseudo_moves(pos)
	var legal: Array = []
	for to in pseudo:
		if _is_move_safe(pos, to, piece):
			legal.append(to)
	return legal

func _is_move_safe(from: Vector2i, to: Vector2i, piece) -> bool:
	var sim = clone_board()
	sim[to.y][to.x] = piece.duplicate()
	sim[from.y][from.x] = null
	if piece.type == "pawn" and to == en_passant_target:
		var captured_pawn_pos = Vector2i(to.x, from.y)
		sim[captured_pawn_pos.y][captured_pawn_pos.x] = null
	if piece.type == "king" and abs(to.x - from.x) == 2:
		var rook_from_x = 7 if to.x > from.x else 0
		var rook_to_x = (from.x + 1) if to.x > from.x else (from.x - 1)
		var rook = sim[from.y][rook_from_x]
		sim[from.y][rook_to_x] = rook
		sim[from.y][rook_from_x] = null
	return not is_in_check(piece.color, sim)

func has_any_legal_moves(color: String) -> bool:
	for y in 8:
		for x in 8:
			var p = board[y][x]
			if p != null and p.color == color:
				if generate_legal_moves(Vector2i(x, y)).size() > 0:
					return true
	return false

func move_piece(from: Vector2i, to: Vector2i, promotion_type: String = "queen") -> Dictionary:
	var piece = get_piece(from)
	var result = {"captured": null, "en_passant": false, "castle": false, "promoted": false}
	if piece == null:
		return result
	var captured = get_piece(to)
	if piece.type == "pawn" and to == en_passant_target and captured == null:
		var captured_pawn_pos = Vector2i(to.x, from.y)
		result["captured"] = get_piece(captured_pawn_pos)
		result["en_passant"] = true
		set_piece(captured_pawn_pos, null)
	elif captured != null:
		result["captured"] = captured

	set_piece(to, piece)
	set_piece(from, null)

	if piece.type == "king" and abs(to.x - from.x) == 2:
		result["castle"] = true
		var rook_from_x = 7 if to.x > from.x else 0
		var rook_to_x = (from.x + 1) if to.x > from.x else (from.x - 1)
		var rook = get_piece(Vector2i(rook_from_x, from.y))
		set_piece(Vector2i(rook_to_x, from.y), rook)
		set_piece(Vector2i(rook_from_x, from.y), null)

	if piece.type == "pawn" and (to.y == 7 or to.y == 0):
		piece.type = promotion_type
		result["promoted"] = true

	if piece.type == "king":
		castling_rights[piece.color + "_king"] = false
		castling_rights[piece.color + "_queen"] = false
	_update_castling_rights_for_rook_move(piece, from)
	_update_castling_rights_for_corner(to)

	if piece.type == "pawn" and abs(to.y - from.y) == 2:
		en_passant_target = Vector2i(from.x, int((from.y + to.y) / 2.0))
	else:
		en_passant_target = Vector2i(-1, -1)

	turn = opponent(turn)
	return result

func _update_castling_rights_for_rook_move(piece, from: Vector2i) -> void:
	if piece.type != "rook":
		return
	_update_castling_rights_for_corner(from)

func _update_castling_rights_for_corner(pos: Vector2i) -> void:
	if pos == Vector2i(0, 0):
		castling_rights["w_queen"] = false
	elif pos == Vector2i(7, 0):
		castling_rights["w_king"] = false
	elif pos == Vector2i(0, 7):
		castling_rights["b_queen"] = false
	elif pos == Vector2i(7, 7):
		castling_rights["b_king"] = false

func to_dict() -> Dictionary:
	# The board travels as a single flat string ("wp", "bn", ".." for an
	# empty square, 64 squares concatenated) rather than a nested array
	# with null entries. Firebase Realtime Database mangles JSON arrays
	# that contain null elements (common for a board — half the squares
	# are empty in a fresh game), sometimes turning them into objects or
	# dropping trailing nulls, which broke loading the very first
	# synced position on some clients. A plain string has no such ambiguity.
	var board_str := ""
	for y in 8:
		for x in 8:
			var p = board[y][x]
			board_str += (p.color + PIECE_CODES[p.type]) if p != null else ".."
	return {
		"board": board_str,
		"turn": turn,
		"en_passant": {"x": en_passant_target.x, "y": en_passant_target.y},
		"castling": castling_rights.duplicate(),
	}

func load_from_dict(data: Dictionary) -> void:
	var board_str: String = str(data.get("board", ""))
	board = []
	for y in 8:
		var row: Array = []
		row.resize(8)
		for x in 8:
			var idx := (y * 8 + x) * 2
			var code := board_str.substr(idx, 2) if idx + 2 <= board_str.length() else ".."
			if code == "..":
				row[x] = null
			else:
				row[x] = {"type": CODE_PIECES.get(code.substr(1, 1), "pawn"), "color": code.substr(0, 1)}
		board.append(row)
	turn = data.get("turn", WHITE)
	var ep: Dictionary = data.get("en_passant", {})
	en_passant_target = Vector2i(int(ep.get("x", -1)), int(ep.get("y", -1)))
	castling_rights = data.get("castling", {"w_king": true, "w_queen": true, "b_king": true, "b_queen": true})
