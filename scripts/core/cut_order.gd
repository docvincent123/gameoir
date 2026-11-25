class_name CutOrder
extends RefCounted

const NEIGHBORS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var cells: Array[Vector2i] = []
var clean := true
var completed := 0

func remaining(board: BoardManager) -> int:
	var count := 0
	for cell in cells:
		if board.filled(cell):
			count += 1
	return count

func preview(board: BoardManager, removed: Array, balance: GameBalance) -> Dictionary:
	var hits := 0
	for cell: Vector2i in removed:
		if cell in cells:
			hits += 1
	if hits == 0:
		return {"hit": false, "clean": clean, "done": false, "bonus": 0}
	var exact := clean and hits == removed.size()
	for cell in cells:
		if board.filled(cell) and cell not in removed:
			return {"hit": true, "clean": exact, "done": false, "bonus": 0}
	return {"hit": true, "clean": exact, "done": true, "bonus": balance.clean_order_points if exact else balance.order_points}

func apply(result: Dictionary) -> void:
	if result.hit:
		clean = result.clean
	if result.done:
		completed += 1
		cells.clear()

func issue(board: BoardManager, cutters: CutterManager) -> void:
	clean = true
	var offset := completed * 17 + board.cells.count(0) * 5
	for index in cutters.hand.size():
		var slot := (index + completed) % cutters.hand.size()
		var form := cutters.shape(slot)
		if form.is_empty():
			continue
		var first := find_footprint(board, form.cells, offset, [])
		if first.is_empty():
			continue
		cells = first
		if completed > 0:
			for other in cutters.hand.size():
				var second := cutters.shape(other)
				if other == slot or second.is_empty() or first.size() + second.cells.size() > 10:
					continue
				var joined := find_footprint(board, second.cells, offset + 9, first)
				if not joined.is_empty():
					cells.append_array(joined)
					break
		return

func find_footprint(board: BoardManager, shape: Array, start: int, beside: Array[Vector2i]) -> Array[Vector2i]:
	for i in BoardManager.COUNT:
		var index := posmod(start + i * 17, BoardManager.COUNT)
		var origin := Vector2i(index % BoardManager.SIZE, floori(float(index) / BoardManager.SIZE))
		if not board.can_cut(shape, origin):
			continue
		var placed: Array[Vector2i] = []
		for cell: Vector2i in shape:
			placed.append(origin + cell)
		if beside.is_empty() or can_join(placed, beside):
			return placed
	return []

func can_join(placed: Array[Vector2i], beside: Array[Vector2i]) -> bool:
	var touches := false
	for cell in placed:
		if cell in beside:
			return false
		for direction: Vector2i in NEIGHBORS:
			if cell + direction in beside:
				touches = true
	return touches

func snapshot() -> Dictionary:
	return {"cells": cells.duplicate(), "clean": clean, "completed": completed}

func restore(data: Variant, board: BoardManager) -> void:
	cells.clear()
	clean = true
	completed = 0
	if not data is Dictionary:
		return
	completed = maxi(0, int(data.get("completed", 0)))
	clean = bool(data.get("clean", true))
	var stored: Variant = data.get("cells", [])
	if not stored is Array:
		return
	var checked: Array[Vector2i] = []
	for cell: Variant in stored:
		if not cell is Vector2i or not board.is_inside(cell) or cell in checked:
			return
		checked.append(cell)
	if checked.any(func(cell: Vector2i) -> bool: return board.filled(cell)):
		cells = checked
