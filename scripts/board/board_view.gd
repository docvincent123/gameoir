class_name BoardView
extends Node2D

const VALID := Color("#146752")
const INVALID := Color("#a82a58")
const GRID_INK := Color(0.10, 0.20, 0.16, 0.39)
const DEPTH := Color(0.52, 0.31, 0.23, 0.72)

var slab := SlabArt.new()

func render(canvas: CanvasItem, art: ClayArt, run: GameManager, frame: Rect2, style: int,
		animation: AnimationManager, input: InputManager, metal: Color, over: float, reduced: bool,
		workshop: Color, numbers: Font) -> void:
	var unit := frame.size.x / BoardManager.SIZE
	var board := frame
	board.position += animation.displace(run.streak, reduced)
	var frame_tint := Color.WHITE.darkened(over * 0.24)
	art.panel(canvas, shift(board.grow(48), Vector2(0, 11)), Color(0.30, 0.22, 0.15, 0.19), 48)
	canvas.draw_texture_rect(PremiumArt.FRAME, board.grow(49), false, frame_tint)

	var visible := visible_clay(run.board, animation)
	var whole := Color.WHITE.darkened(over * 0.24)
	var edges := PackedByteArray()
	edges.resize(BoardManager.COUNT)
	for y in BoardManager.SIZE:
		for x in BoardManager.SIZE:
			var tile := Vector2i(x, y)
			var index := run.board.index(tile)
			var cell := cell_rect(board, tile, unit)
			if visible[index] == 0:
				if run.board.pending[y] > 0 or run.board.pending[BoardManager.SIZE + x] > 0:
					canvas.draw_rect(cell, Color(0.96, 0.62, 0.28, 0.15))
				continue
			edges[index] = SlabArt.exposed(run.board, visible, tile)
			if edges[index] > 0:
				slab.base(canvas, shift(cell, Vector2(2, 9)), edges[index], DEPTH)

	for y in BoardManager.SIZE:
		for x in BoardManager.SIZE:
			var tile := Vector2i(x, y)
			var index := run.board.index(tile)
			if visible[index] == 0:
				continue
			var cell := cell_rect(board, tile, unit)
			var pressed: bool = animation.active and animation.elapsed < AnimationManager.PRESS and tile in animation.change.removed
			var shade := whole.darkened(0.13 * clampf(animation.elapsed / AnimationManager.PRESS, 0, 1)) if pressed else whole
			slab.face(canvas, cell, tile, animation.slab_style if pressed else style, edges[index], shade)
			slab.bevel(canvas, cell, edges[index], 1.0)
			canvas.draw_texture_rect(PremiumArt.CELL, cell, false, Color(1, 1, 1, 0.70))
			if over > 0.12 and edges[index] > 0 and (x * 7 + y * 3) % 4 == 0:
				crack(canvas, cell, over * 0.46)

	draw_grid(canvas, board, unit)
	if animation.active:
		rise(canvas, board, unit, style, animation)
		stamp(canvas, art, unit, animation, metal, reduced)
		if not reduced:
			refill_trails(canvas, art, board, unit, animation)
	if not run.order.cells.is_empty() and not (animation.active and animation.change.order.bonus > 0):
		var mark := Color("#fff9dc") if run.order.clean else Color("#ffbd68")
		outline(canvas, board, unit, run.order.cells, Vector2i.ZERO, Color(mark, 0.88), true)
		for tile: Vector2i in run.order.cells:
			if visible[run.board.index(tile)] != 0:
				var spot := cell_rect(board, tile, unit).get_center()
				canvas.draw_circle(spot, 9.0, Color("#244c38"), true, -1.0, true)
				canvas.draw_circle(spot, 8.0, mark, false, 3.0, true)
	var form := run.cutters.shape(input.slot)
	if input.touched_board and not form.is_empty():
		outline(canvas, board, unit, form.cells, input.anchor, VALID if input.valid else INVALID, false)
	draw_queue(canvas, art, run.board, board, unit, numbers)

func visible_clay(board: BoardManager, animation: AnimationManager) -> PackedByteArray:
	var cells := board.cells.duplicate()
	if not animation.active:
		return cells
	for tile: Vector2i in animation.change.refill:
		if refill_progress(animation, tile) < 1.0:
			cells[board.index(tile)] = 0
	if animation.elapsed < AnimationManager.PRESS:
		for tile: Vector2i in animation.change.removed:
			cells[board.index(tile)] = 1
	return cells

func rise(canvas: CanvasItem, board: Rect2, unit: float, style: int, animation: AnimationManager) -> void:
	for tile: Vector2i in animation.change.refill:
		var progress := refill_progress(animation, tile)
		if progress <= 0.0 or progress >= 1.0:
			continue
		var cell := cell_rect(board, tile, unit)
		var reach := 1.0 - pow(1.0 - progress, 3.0)
		var size := cell.size * Vector2(lerpf(0.18, 1.0, reach), lerpf(0.28, 1.0, reach))
		var patch := Rect2(cell.get_center() - size * 0.5, size)
		var radius := lerpf(7.0, 13.0, reach)
		slab.base(canvas, shift(patch, Vector2(0, 7 * reach)), 15, DEPTH, radius)
		slab.face(canvas, patch, tile, style, 15, Color.WHITE.lerp(Color("#ffefc4"), (1.0 - reach) * 0.4), radius)
		slab.bevel(canvas, patch, 15, reach)

func refill_progress(animation: AnimationManager, tile: Vector2i) -> float:
	return clampf((animation.elapsed - AnimationManager.REFILL - line_offset(animation.change, tile) * 0.016) / 0.26, 0.0, 1.0)

func draw_grid(canvas: CanvasItem, board: Rect2, unit: float) -> void:
	for i in range(1, BoardManager.SIZE):
		var offset := float(i) * unit
		var x := board.position.x + offset
		var y := board.position.y + offset
		canvas.draw_line(Vector2(x, board.position.y + 3), Vector2(x, board.end.y - 3), GRID_INK, 2.3, true)
		canvas.draw_line(Vector2(board.position.x + 3, y), Vector2(board.end.x - 3, y), GRID_INK, 2.3, true)

func outline(canvas: CanvasItem, board: Rect2, unit: float, shape: Array,
		origin: Vector2i, tint: Color, guide: bool) -> void:
	for offset: Vector2i in shape:
		var tile := origin + offset
		if tile.x < 0 or tile.y < 0 or tile.x >= BoardManager.SIZE or tile.y >= BoardManager.SIZE:
			continue
		var cell := cell_rect(board, tile, unit)
		if not guide:
			canvas.draw_rect(cell, Color(tint, 0.17))
		var edges := SlabArt.piece_edges(shape, offset)
		for side in SlabArt.DIRECTIONS.size():
			if (edges & (1 << side)) == 0:
				continue
			var path := SlabArt.edge_points(cell, side)
			if guide:
				canvas.draw_dashed_line(path[0], path[1], Color(0.10, 0.25, 0.18, 0.65), 8.0, 17.0, true)
				canvas.draw_dashed_line(path[0], path[1], tint, 5.0, 17.0, true)
			else:
				canvas.draw_line(path[0], path[1], Color("#fff5dc"), 9.0, true)
				canvas.draw_line(path[0], path[1], tint, 4.8, true)

func cell_rect(board: Rect2, tile: Vector2i, unit: float) -> Rect2:
	return Rect2(board.position + Vector2(tile) * unit, Vector2.ONE * unit)

func draw_queue(canvas: CanvasItem, art: ClayArt, grid: BoardManager, area: Rect2, unit: float, numbers: Font) -> void:
	for line in BoardManager.LINE_COUNT:
		var remaining := grid.pending[line]
		if remaining == 0:
			continue
		var row := line < BoardManager.SIZE
		var offset := (float(line % BoardManager.SIZE) + 0.5) * unit
		var center := Vector2(area.end.x + 25, area.position.y + offset) if row else Vector2(area.position.x + offset, area.end.y + 25)
		var badge := Rect2(center - Vector2(22, 20), Vector2(44, 40))
		art.panel(canvas, badge, Color("#f9be62") if remaining == 1 else Color("#fffbec"), 15, Color("#428072"), 2)
		var tint := Color("#243b35")
		var baseline := center.y + (numbers.get_ascent(25) - numbers.get_descent(25)) / 2
		canvas.draw_string(numbers, Vector2(badge.position.x, baseline), str(remaining),
			HORIZONTAL_ALIGNMENT_CENTER, badge.size.x, 25, tint)

func refill_trails(canvas: CanvasItem, art: ClayArt, area: Rect2, unit: float, animation: AnimationManager) -> void:
	if animation.elapsed < AnimationManager.REFILL:
		return
	var progress := clampf((animation.elapsed - AnimationManager.REFILL) / 0.34, 0.0, 1.0)
	var glow := sin(progress * PI)
	for line: int in animation.change.refilled:
		var first := area.position + (Vector2(BoardManager.line_cell(line, 0)) + Vector2.ONE * 0.5) * unit
		var last := area.position + (Vector2(BoardManager.line_cell(line, BoardManager.SIZE - 1)) + Vector2.ONE * 0.5) * unit
		if line % 2 == 1:
			var opposite := first
			first = last
			last = opposite
		var movement := first.lerp(last, progress)
		var trail := first.lerp(last, maxf(0, progress - 0.31))
		canvas.draw_line(trail, movement, Color("#bd7837", glow * 0.70), 5.0, true)
		art.effect(canvas, ClayArt.Effect.GLINT, movement, 48.0 + 27.0 * glow, Color(Color.WHITE, glow))

func stamp(canvas: CanvasItem, art: ClayArt, unit: float,
		animation: AnimationManager, metal: Color, reduced: bool) -> void:
	var elapsed := animation.elapsed
	var pressing := clampf(elapsed / AnimationManager.PRESS, 0.0, 1.0)
	if elapsed < 0.26:
		var descent := pressing * pressing
		var contact := sin(clampf((elapsed - AnimationManager.PRESS) / 0.095, 0, 1) * PI)
		var center := animation.stamp_center + Vector2(0, -36.0 * (1.0 - descent) + 5.0 * contact)
		var fade := 1.0 - smoothstep(AnimationManager.PRESS, 0.26, elapsed)
		art.cutter(canvas, animation.stamp_id, center, unit * lerpf(1.025, 1.0, pressing), Color(metal, fade))
	if not reduced and elapsed >= AnimationManager.PRESS and elapsed < 0.44:
		var bloom := inverse_lerp(AnimationManager.PRESS, 0.44, elapsed)
		var alpha := sin(bloom * PI) * 0.90
		PremiumArt.sparkle(canvas, animation.stamp_center, unit * (0.7 + bloom * 1.6), alpha)
		art.effect(canvas, ClayArt.CUT_PULSES[animation.cut_effect], animation.stamp_center,
			unit * lerpf(0.7, 2.3, bloom), Color(Color.WHITE, alpha))
	if elapsed >= AnimationManager.PRESS and elapsed <= 0.47:
		var progress := inverse_lerp(AnimationManager.PRESS, 0.47, elapsed)
		var lift := sin(progress * PI * 0.72)
		var scale := 1.0 + 0.055 * sin(progress * PI) - smoothstep(0.49, 1.0, progress) * 0.14
		var opacity := 1.0 - smoothstep(0.48, 1.0, progress)
		var form: Dictionary = animation.change.form
		var center := animation.stamp_center + Vector2(33 * progress, -unit * 0.65 * lift)
		var cut_unit := unit * scale
		var origin := center - Vector2(form.size) * cut_unit / 2.0
		slab.piece(canvas, form.cells, animation.change.origin, origin, cut_unit,
			animation.slab_style, Color(Color.WHITE, opacity), unit * lerpf(0.08, 0.18, lift))

	if not reduced and animation.change.order.done and elapsed > AnimationManager.PRESS + 0.06:
		var progress := smoothstep(0.19, 0.49, elapsed)
		var seal := ClayArt.Seal.PRECISE if animation.change.order.clean else ClayArt.Seal.ORDER
		var point := animation.stamp_center + Vector2(unit * 0.32, -unit * (0.32 + 0.27 * progress))
		var scale := 0.77 + sin(progress * PI) * 0.35
		art.seal(canvas, seal, point, unit * scale, Color(Color.WHITE, minf(1.0, sin(progress * PI) * 2.5)))

func line_offset(change: Dictionary, tile: Vector2i) -> int:
	var offset := BoardManager.SIZE
	for line: int in change.refilled:
		var row := line < BoardManager.SIZE
		if line % BoardManager.SIZE != (tile.y if row else tile.x):
			continue
		var position := tile.x if row else tile.y
		if line % 2 == 1:
			position = BoardManager.SIZE - 1 - position
		offset = mini(offset, position)
	return offset

func crack(canvas: CanvasItem, cell: Rect2, intensity: float) -> void:
	var p := cell.position
	var side := cell.size.x
	var points := PackedVector2Array([p + Vector2(0.40, 0.02) * side, p + Vector2(0.54, 0.30) * side,
		p + Vector2(0.45, 0.52) * side, p + Vector2(0.63, 0.69) * side, p + Vector2(0.53, 0.96) * side])
	canvas.draw_polyline(points, Color(0.1, 0.03, 0.18, intensity * 0.78), 3.4, true)

func shift(area: Rect2, offset: Vector2) -> Rect2:
	return Rect2(area.position + offset, area.size)
