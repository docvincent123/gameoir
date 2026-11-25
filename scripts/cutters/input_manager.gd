class_name InputManager
extends RefCounted

const IDLE := -2
const MOUSE := -1

var pointer := IDLE
var slot := -1
var position := Vector2.ZERO
var anchor := Vector2i.ZERO
var touched_board := false
var valid := false
var touchscreen := false
var forecast: Dictionary = {}

func begin(id: int, cutter: int, at: Vector2) -> void:
	pointer = id
	slot = cutter
	position = at
	touchscreen = id >= 0
	touched_board = false
	valid = false
	forecast.clear()

func move(at: Vector2, board_rect: Rect2, bounds: Vector2i, hold_size: float, board: BoardManager, shape: Array) -> void:
	position = at
	var lifted := at - Vector2(0, hold_size * (1.02 if touchscreen else 0.29))
	var origin := (lifted - board_rect.position) / hold_size - Vector2(bounds) / 2.0
	anchor = Vector2i(origin.round())
	var proposed := Rect2(board_rect.position + Vector2(anchor) * hold_size, Vector2(bounds) * hold_size)
	touched_board = proposed.intersects(board_rect)
	valid = touched_board and board.can_cut(shape, anchor)

func cancel() -> void:
	pointer = IDLE
	slot = -1
	touched_board = false
	valid = false
	forecast.clear()
