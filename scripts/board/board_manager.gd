class_name BoardManager
extends RefCounted

const SIZE := 8
const COUNT := SIZE * SIZE

var cells := PackedByteArray()

func _init() -> void:
	reset()

func reset() -> void:
	cells.resize(COUNT)
	cells.fill(1)

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

func cut(shape: Array, origin: Vector2i) -> Dictionary:
	if not can_cut(shape, origin):
		return {}
	var removed: Array[Vector2i] = []
	for offset: Vector2i in shape:
		var cell := origin + offset
		cells[index(cell)] = 0
		removed.append(cell)

	var rows: Array[int] = []
	var columns: Array[int] = []
	for line in SIZE:
		var row_empty := true
		var column_empty := true
		for i in SIZE:
			row_empty = row_empty and cells[index(Vector2i(i, line))] == 0
			column_empty = column_empty and cells[index(Vector2i(line, i))] == 0
		if row_empty:
			rows.append(line)
		if column_empty:
			columns.append(line)

	var full_board := rows.size() == SIZE
	var refill: Array[Vector2i] = []
	for y in SIZE:
		for x in SIZE:
			if y in rows or x in columns:
				var cell := Vector2i(x, y)
				cells[index(cell)] = 1
				refill.append(cell)

	return {"removed": removed, "rows": rows, "columns": columns, "refill": refill, "full": full_board}
