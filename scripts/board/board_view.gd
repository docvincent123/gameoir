class_name BoardView
extends Node2D

const GILT := Color("#fff2b2")
const VALID := Color("#006e62")
const INVALID := Color("#ab245a")
const WELL := Color("#b6d0c4")
const QUEUED_WELL := Color("#f9cf9d")

func render(canvas: CanvasItem, art: ClayArt, run: GameManager, frame: Rect2, palette: Array,
		animation: AnimationManager, input: InputManager, metal: Color, over: float, reduced: bool, workshop: Color, numbers: Font) -> void:
	var unit := frame.size.x / BoardManager.SIZE
	var board := frame
	board.position += animation.displace(run.streak, reduced)
	var frame_tint := workshop.lerp(Color.WHITE, 0.83).darkened(over * 0.30)
	art.panel(canvas, shift(board.grow(49), Vector2(0, 11)), Color(0.18, 0.37, 0.31, 0.19), 48)
	art.panel(canvas, board.grow(13), Color("#c2dacc"), 29)
	canvas.draw_texture_rect(ClayArt.FRAME, board.grow(49), false, frame_tint)

	var preview := run.cutters.shape(input.slot)
	for y in BoardManager.SIZE:
		for x in BoardManager.SIZE:
			var tile := Vector2i(x, y)
			var cell := Rect2(board.position + Vector2(tile) * unit, Vector2.ONE * unit)
			var occupied := run.board.filled(tile)
			var state := animation.cell_state(tile, occupied, input, preview)
			var pattern := (x * 11 + y * 13 + x * y) % ClayArt.VARIANTS
			var regular := 1.012
			var material := ThemeCatalog.material_at(palette, tile)
			var warm := Color.WHITE.darkened(over * 0.20)
			var queued := run.board.pending[y] > 0 or run.board.pending[BoardManager.SIZE + x] > 0
			if state == ClayCell.State.CUTTING:
				var progress := clampf(animation.elapsed / AnimationManager.PRESS, 0.0, 1.0)
				var wobble := sin(progress * PI)
				var squish := centered(cell, Vector2(1.035 + wobble * 0.035, 1.035 - wobble * (0.10 + (pattern % 3) * 0.02)))
				art.cell(canvas, squish, ThemeCatalog.material_at(animation.palette, tile), ClayArt.PRESSED)
				art.panel(canvas, cell.grow(-6.0), Color.TRANSPARENT, 18, Color(GILT, progress * 0.72), 4)
			elif state == ClayCell.State.REFILLING:
				art.cell(canvas, cell, material, ClayArt.CAVITY, WELL)
				var wave := line_offset(animation.change, tile) * 0.015
				var progress := clampf((animation.elapsed - AnimationManager.REFILL - wave) / 0.29, 0.0, 1.0)
				if progress > 0.0:
					var bounce := ease(progress, -1.65)
					var pulse := sin(progress * PI)
					var stretch := Vector2(0.08, -0.035) if pattern % 2 == 0 else Vector2(-0.05, 0.085)
					var swell := centered(cell, Vector2.ONE * lerpf(0.24, 1.012, bounce) + stretch * pulse)
					art.cell(canvas, swell, material, pattern, warm.lerp(GILT, (1.0 - progress) * 0.54))
					art.panel(canvas, cell.grow(-3.0), Color.TRANSPARENT, 21, Color(GILT, sin(progress * PI) * 0.72), 3)
			else:
				var tint := warm if occupied else QUEUED_WELL if queued else WELL
				art.cell(canvas, centered(cell, Vector2.ONE * regular), material, pattern if occupied else ClayArt.CAVITY, tint)
				if queued and not occupied:
					art.panel(canvas, cell.grow(-9), Color("#ffd891", 0.06), 23, Color("#c78954", 0.42), 2)
				if state == ClayCell.State.VALID_PREVIEW or state == ClayCell.State.INVALID_PREVIEW:
					var cue := VALID if input.valid else INVALID
					art.panel(canvas, cell.grow(-5.5), Color(cue, 0.16), 23, cue, 5)
			if over > 0.12 and occupied and (x * 7 + y * 3) % 4 == 0:
				crack(canvas, cell, over)

	if animation.active:
		stamp(canvas, art, board, unit, animation, metal)
		if not reduced:
			refill_trails(canvas, art, board, unit, animation)
	draw_queue(canvas, art, run.board, board, unit, numbers)

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
		art.icon(canvas, &"shine", movement, 40.0 + 23.0 * glow, Color(Color.WHITE, glow))

func stamp(canvas: CanvasItem, art: ClayArt, board: Rect2, unit: float, animation: AnimationManager, metal: Color) -> void:
	var elapsed := animation.elapsed
	var center := animation.stamp_center + Vector2(0, -24.0 * maxf(0.0, 1.0 - elapsed / 0.125))
	if elapsed < 0.24:
		var fade := 1.0 - smoothstep(0.12, 0.24, elapsed)
		art.cutter(canvas, animation.stamp_id, center, animation.stamp_unit, Color(metal, fade))
	if elapsed >= AnimationManager.PRESS and elapsed <= 0.425:
		var pop := inverse_lerp(AnimationManager.PRESS, 0.425, elapsed)
		var tension := sin(pop * PI)
		var opacity := 1.0 - smoothstep(0.48, 1.0, pop)
		for tile: Vector2i in animation.change.removed:
			var cell := Rect2(board.position + Vector2(tile) * unit, Vector2.ONE * unit)
			var style := (tile.x + tile.y * 2) % 3
			var flight := Vector2((style - 1) * 25, -35 - style * 12) * tension
			var raised := centered(cell, Vector2(1.0 + tension * (0.05 + style * 0.031), 1.0 + tension * (0.22 - style * 0.08)))
			art.panel(canvas, shift(raised.grow(-8), Vector2(0, 8)), Color(0.10, 0.02, 0.16, opacity * 0.48), 25)
			art.cell(canvas, shift(raised, flight), ThemeCatalog.material_at(animation.palette, tile), ClayArt.PRESSED, Color(1.0, 0.99, 0.97, opacity))

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

func centered(area: Rect2, stretch: Vector2) -> Rect2:
	var dimensions := area.size * stretch
	return Rect2(area.get_center() - dimensions / 2.0, dimensions)

func crack(canvas: CanvasItem, cell: Rect2, intensity: float) -> void:
	var p := cell.position
	var side := cell.size.x
	var points := PackedVector2Array([p + Vector2(0.40, 0.02) * side, p + Vector2(0.54, 0.30) * side,
		p + Vector2(0.45, 0.52) * side, p + Vector2(0.63, 0.69) * side, p + Vector2(0.53, 0.96) * side])
	canvas.draw_polyline(points, Color(0.1, 0.03, 0.18, intensity * 0.78), 3.4, true)

func shift(area: Rect2, offset: Vector2) -> Rect2:
	return Rect2(area.position + offset, area.size)
