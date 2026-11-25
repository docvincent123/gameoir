class_name SlabArt
extends RefCounted

const SHEET := preload("res://assets/clay/slabs.jpg")
const PATCH := 320.0
const COLUMNS := 5
const DIRECTIONS := [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

static func exposed(board: BoardManager, cells: PackedByteArray, tile: Vector2i) -> int:
	var edges := 0
	for side in DIRECTIONS.size():
		var neighbor: Vector2i = tile + DIRECTIONS[side]
		if not board.is_inside(neighbor) or cells[board.index(neighbor)] == 0:
			edges |= 1 << side
	return edges

static func piece_edges(cells: Array, tile: Vector2i) -> int:
	var edges := 0
	for side in DIRECTIONS.size():
		if tile + DIRECTIONS[side] not in cells:
			edges |= 1 << side
	return edges

func swatch(canvas: CanvasItem, area: Rect2, style: int) -> void:
	canvas.draw_texture_rect_region(SHEET, area, material_rect(style), Color.WHITE, false, true)

func material_rect(style: int) -> Rect2:
	var origin := Vector2(style % COLUMNS, floori(style / float(COLUMNS))) * PATCH
	return Rect2(origin, Vector2.ONE * PATCH)

func face(canvas: CanvasItem, area: Rect2, tile: Vector2i, style: int,
		edges: int, tint: Color, radius: float = 15.0) -> void:
	var tile_size := PATCH / BoardManager.SIZE
	var source := Rect2(material_rect(style).position + Vector2(tile) * tile_size, Vector2.ONE * tile_size)
	if not has_corner(edges):
		canvas.draw_texture_rect_region(SHEET, area, source, tint, false, false)
		return
	var points := perimeter(area, edges, radius)
	var uvs := PackedVector2Array()
	for point in points:
		var uv := source.position + (point - area.position) / area.size * source.size
		uvs.append(uv / SHEET.get_size())
	canvas.draw_polygon(points, PackedColorArray([tint]), uvs, SHEET)

func base(canvas: CanvasItem, area: Rect2, edges: int, color: Color, radius := 15.0) -> void:
	if has_corner(edges):
		canvas.draw_colored_polygon(perimeter(area, edges, radius), color)
	else:
		canvas.draw_rect(area, color)

func bevel(canvas: CanvasItem, cell: Rect2, edges: int, strength: float) -> void:
	var inset := minf(11.0, cell.size.x * 0.23)
	for side in DIRECTIONS.size():
		if (edges & (1 << side)) == 0:
			continue
		var before := (side + 3) % 4
		var after := (side + 1) % 4
		var path := edge_points(cell, side, inset if edges & (1 << before) else 0.0,
			inset if edges & (1 << after) else 0.0)
		var inside := -Vector2(DIRECTIONS[side])
		var tint := Color(1.0, 0.92, 0.77, 0.36 * strength) if side == 0 or side == 3 			else Color(0.38, 0.18, 0.16, 0.34 * strength)
		var clear := Color(tint, 0.0)
		var points := PackedVector2Array([path[0], path[1], path[1] + inside * inset, path[0] + inside * inset])
		canvas.draw_polygon(points, PackedColorArray([tint, tint, clear, clear]))

func piece(canvas: CanvasItem, cells: Array, source: Vector2i, origin: Vector2, unit: float,
		style: int, tint: Color, depth: float) -> void:
	var radius := minf(15.0, unit * 0.16)
	for tile: Vector2i in cells:
		var rect := Rect2(origin + Vector2(tile) * unit, Vector2.ONE * unit)
		var edge := piece_edges(cells, tile)
		base(canvas, Rect2(rect.position + Vector2(0, depth), rect.size),
			edge, Color(0.44, 0.23, 0.19, tint.a * 0.73), radius)
	for tile: Vector2i in cells:
		var rect := Rect2(origin + Vector2(tile) * unit, Vector2.ONE * unit)
		var edge := piece_edges(cells, tile)
		face(canvas, rect, source + tile, style, edge, tint, radius)
		bevel(canvas, rect, edge, tint.a)

static func edge_points(cell: Rect2, side: int, first_inset: float = 0.0,
		last_inset: float = 0.0) -> PackedVector2Array:
	var corners := [cell.position, Vector2(cell.end.x, cell.position.y), cell.end,
		Vector2(cell.position.x, cell.end.y)]
	var start: Vector2 = corners[side]
	var finish: Vector2 = corners[(side + 1) % 4]
	var along := start.direction_to(finish)
	return PackedVector2Array([start + along * first_inset, finish - along * last_inset])

static func has_corner(edges: int) -> bool:
	return (edges & ((edges << 1) | (edges >> 3))) != 0

func perimeter(area: Rect2, edges: int, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var anchors := [area.position, Vector2(area.end.x, area.position.y), area.end,
		Vector2(area.position.x, area.end.y)]
	var shifts := [Vector2.ONE, Vector2(-1, 1), -Vector2.ONE, Vector2(1, -1)]
	for corner in 4:
		if (edges & (1 << corner)) == 0 or (edges & (1 << ((corner + 3) % 4))) == 0:
			points.append(anchors[corner])
			continue
		var center: Vector2 = anchors[corner] + shifts[corner] * radius
		var first := PI + corner * PI * 0.5
		for step in 5:
			points.append(center + Vector2.from_angle(first + step * PI / 8.0) * radius)
	return points
