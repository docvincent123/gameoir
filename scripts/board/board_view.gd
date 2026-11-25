class_name BoardView
extends Node2D

const TRACK := Color("#2b1543")
const GILT := Color("#ffe0a0")
const VALID := Color("#afffcd")
const INVALID := Color("#ff7f9c")

func render(canvas: CanvasItem, art: ClayArt, run: GameManager, frame: Rect2, material: int,
		animation: AnimationManager, input: InputManager, metal: Color, over: float, reduced: bool, workshop: Color) -> void:
	var unit := frame.size.x / BoardManager.SIZE
	var board := frame
	board.position += animation.displace(run.streak, reduced)
	var frame_color := workshop.lerp(Color("#251139"), 0.36)
	art.panel(canvas, shift(board.grow(34), Vector2(0, 12)), Color(0.065, 0.02, 0.10, 0.57), 68)
	art.panel(canvas, board.grow(31), frame_color, 65, workshop.lightened(0.23), 3)
	art.panel(canvas, board.grow(11), TRACK.darkened(0.32), 44)
	art.panel(canvas, board.grow(3), TRACK, 39, Color("#331950"), 3)

	var preview := run.cutters.shape(input.slot)
	for y in BoardManager.SIZE:
		for x in BoardManager.SIZE:
			var tile := Vector2i(x, y)
			var cell := Rect2(board.position + Vector2(tile) * unit, Vector2.ONE * unit)
			var occupied := run.board.filled(tile)
			var state := animation.cell_state(tile, occupied, input, preview)
			var pattern := (x * 11 + y * 13 + x * y) % 3
			var regular := 1.012
			var warm := Color.WHITE.darkened(over * 0.48)
			if state == ClayCell.State.CUTTING:
				var progress := clampf(animation.elapsed / AnimationManager.PRESS, 0.0, 1.0)
				var squish := centered(cell, Vector2(1.035, 1.035 - 0.13 * sin(progress * PI)))
				art.cell(canvas, squish, animation.material, 3)
				art.panel(canvas, cell.grow(-6.0), Color.TRANSPARENT, 18, Color(GILT, progress * 0.72), 4)
			elif state == ClayCell.State.REFILLING:
				art.cell(canvas, centered(cell, Vector2.ONE), material, 4)
				var wave := line_offset(animation.change, tile) * 0.015
				var progress := clampf((animation.elapsed - AnimationManager.REFILL - wave) / 0.29, 0.0, 1.0)
				if progress > 0.0:
					var bounce := ease(progress, -1.65)
					var swell := centered(cell, Vector2.ONE * lerpf(0.24, 1.012, bounce) + Vector2(0.04, -0.015) * sin(progress * PI))
					art.cell(canvas, swell, material, pattern, Color.WHITE.lerp(GILT, (1.0 - progress) * 0.54))
					art.panel(canvas, cell.grow(-3.0), Color.TRANSPARENT, 21, Color(GILT, sin(progress * PI) * 0.72), 3)
			else:
				art.cell(canvas, centered(cell, Vector2.ONE * regular), material, pattern if occupied else 4, warm)
				if state == ClayCell.State.VALID_PREVIEW or state == ClayCell.State.INVALID_PREVIEW:
					var cue := VALID if input.valid else INVALID
					art.panel(canvas, cell.grow(-5.5), Color(cue, 0.29), 23, cue, 4)
			if over > 0.12 and occupied and (x * 7 + y * 3) % 4 == 0:
				crack(canvas, cell, over)

	if animation.active:
		stamp(canvas, art, board, unit, animation, metal)

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
			var raised := centered(cell, Vector2(1.0 + tension * 0.055, 1.0 + tension * 0.19))
			art.panel(canvas, shift(raised.grow(-8), Vector2(0, 8)), Color(0.10, 0.02, 0.16, opacity * 0.48), 25)
			art.cell(canvas, shift(raised, Vector2(0, -36 * tension)), animation.material, 3, Color(1.0, 0.99, 0.97, opacity))

func line_offset(change: Dictionary, tile: Vector2i) -> int:
	var row: bool = tile.y in change.rows
	var column: bool = tile.x in change.columns
	if row and column:
		return mini(tile.x, tile.y)
	return tile.x if row else tile.y

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
