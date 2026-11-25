class_name BoardManager
extends RefCounted

const SIZE := 7
const COUNT := SIZE * SIZE
const LINE_COUNT := SIZE * 2

var cells := PackedByteArray()
var pending := PackedInt32Array()

func _init() -> void:
	reset()

func reset() -> void:
	cells.resize(COUNT)
	cells.fill(1)
	pending.resize(LINE_COUNT)
	pending.fill(0)

func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < SIZE and cell.y < SIZE

func index(cell: Vector2i) -> int:
	return cell.y * SIZE + cell.x

func filled(cell: Vector2i) -> bool:
	return is_inside(cell) and cells[index(cell)] == 1

func can_cut(shape: Array, origin: Vector2i) -> bool:
	if shape.is_empty():
		return false
	for offset: Vector2i in shape:
		if not filled(origin + offset):
			return false
	return true

func has_placement(shape: Array, bounds: Vector2i) -> bool:
	for y in range(SIZE - bounds.y + 1):
		for x in range(SIZE - bounds.x + 1):
			if can_cut(shape, Vector2i(x, y)):
				return true
	return false

func preview_cut(shape: Array, origin: Vector2i) -> Dictionary:
	if not can_cut(shape, origin):
		return {}
	var removed: Array[Vector2i] = []
	for offset: Vector2i in shape:
		removed.append(origin + offset)
	return {"removed": removed, "completed": empty_lines(removed), "full": cells.count(1) == removed.size()}

func cut(shape: Array, origin: Vector2i) -> Dictionary:
	var change := preview_cut(shape, origin)
	if not change.is_empty():
		for tile: Vector2i in change.removed:
			cells[index(tile)] = 0
	return change

static func line_cell(line: int, offset: int) -> Vector2i:
	return Vector2i(offset, line) if line < SIZE else Vector2i(line - SIZE, offset)

func empty_lines(removing: Array[Vector2i] = []) -> Array[int]:
	var completed: Array[int] = []
	for line in LINE_COUNT:
		if pending[line] > 0:
			continue
		var empty := true
		for offset in SIZE:
			var cell := line_cell(line, offset)
			if filled(cell) and cell not in removing:
				empty = false
				break
		if empty:
			completed.append(line)
	return completed

func has_pending() -> bool:
	return soonest() > 0

func soonest() -> int:
	var next := 0
	for remaining in pending:
		if remaining > 0 and (next == 0 or remaining < next):
			next = remaining
	return next

func advance(completed: Array[int], delay: int) -> Dictionary:
	var ready: Array[int] = []
	var refill: Array[Vector2i] = []
	for line in LINE_COUNT:
		if pending[line] == 0:
			continue
		pending[line] -= 1
		if pending[line] == 0:
			ready.append(line)

	for line in ready:
		for offset in SIZE:
			var target := line_cell(line, offset)
			var position := index(target)
			if cells[position] == 0:
				cells[position] = 1
				refill.append(target)

	# Start newly cleared lines after ticking earlier lines so this move never counts twice.
	for line in completed:
		pending[line] = delay
	return {"refill": refill, "refilled": ready}
