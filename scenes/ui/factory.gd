class_name Factory
extends Node2D

const DESIGN := Vector2(1080, 1920)
const WEIGHT_TAG := 0x77676874 # OpenType wght axis.
const FONT := preload("res://assets/ui/fonts/Manrope.ttf")
const BACKDROP := preload("res://assets/shaders/workshop.gdshader")
const HABITAT := preload("res://scenes/gameplay/gameplay.tscn")
const WORKSHOP := preload("res://scenes/menu/menu.tscn")
const PAGES := preload("res://scenes/ui/screens.tscn")

const INK := Color("#1f332e")
const MUTED := Color("#53685e")
const TEAL := Color("#176452")
const WARM := Color("#86502d")
const PAPER := Color("#fbfaf5")
const MINT := Color("#d1ebde")
const ROSE := Color("#f4d8d6")
const SKY := Color("#dceaf2")
const LILAC := Color("#e8e1f3")
const SUN := Color("#fae6b8")
const PEACH := Color("#f7e0d0")
const GILT := Color("#ffe093")
const EDGE := Color("#d8dfd3")
const SHADOW := Color(0.20, 0.29, 0.24, 0.10)
const SCORE_PLATE := Color("#234b3f")
const SCORE_LABEL := Color("#cfe5d8")
const ORDER_PAPER := Color("#f8e7c8")
const GRID := Rect2(88, 507, 904, 904)
const TRAY := Rect2(62, 1500, 956, 234)
const UNIT := GRID.size.x / BoardManager.SIZE
const RETURN_DURATION := 0.30
const SLOT_PREVIEW := Vector2(232, 145)
const BUTTON_ICONS := {
	"play": &"play", "daily": &"calendar", "collection": &"collection",
	"records": &"trophy", "settings": &"settings", "pause": &"pause", "back": &"arrow_left",
	"resume_game": &"play", "again": &"restart", "home": &"home",
	"pause_settings": &"sliders", "copy_daily": &"copy",
	"history_prev": &"previous", "history_next": &"next", "shape_prev": &"previous", "shape_next": &"next",
	"shape_filter": &"cycle", "shapes_catalog": &"shapes", "metal_finishes": &"sliders",
	"tab_0": &"collection", "tab_1": &"cutter", "tab_2": &"home", "tab_3": &"shine",
}

var view := "menu"
var overlay := "":
	set(value):
		if overlay != value:
			overlay = value
			overlay_age = 0.0
var overlay_age := 0.24
var day := ""
var save := SaveManager.new()
var run: GameManager
var art := ClayArt.new()
var premium := PremiumArt.new()
var input := InputManager.new()
var animation := AnimationManager.new()
var particles := ParticleManager.new()
var accent := AccentEffects.new()
var audio := AudioManager.new()
var board: BoardView
var menu
var pages
var studio = preload("res://scenes/ui/studio_pages.gd").new()
var pressure_overlay := PressureOverlay.new()
var online_board := OnlineBoard.new()
var tutorial_active := false
var tutorial_hint: Dictionary = {}
var tutorial_start_lines := 0
var tutorial_start_cells := 0
var font := FontVariation.new()
var heading := FontVariation.new()
var background: ColorRect
var backdrop := ShaderMaterial.new()
var workshop := Color("#cce9dd")
var buttons: Dictionary = {}
var disabled: Dictionary = {}
var pointer_buttons: Dictionary = {}
var pressed_button := ""
var press_depth := 0.0
var press_tween: Tween
var hovered := ""
var view_origin := Vector2.ZERO
var view_scale := 1.0
var clock := 0.0
var score_face := 0.0
var pop_age := 2.0
var pop_points := 0
var pop_center := Vector2.ZERO
var pop_combo := 0
var score_tween: Tween
var fade_age := 1.0
var over_age := 0.0
var banner := ""
var banner_seal := -1
var banner_age := 2.1
var best_celebrated := false
var daily_result_copied := false
var return_age := 0.0
var return_from := Vector2.ZERO
var return_slot := -1
var collection_tab := 0
var history_page := 0
var reduced := false
var slots: Array[Rect2] = [Rect2(86, 1523, 284, 185), Rect2(398, 1523, 284, 185), Rect2(710, 1523, 284, 185)]

func _ready() -> void:
	get_tree().quit_on_go_back = false
	Engine.max_fps = 60
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	font.base_font = FONT
	font.variation_opentype = {WEIGHT_TAG: 650}
	heading.base_font = FONT
	heading.variation_opentype = {WEIGHT_TAG: 780}
	heading.opentype_features = {0x746e756d: 1}
	var layer := CanvasLayer.new()
	layer.layer = -1
	add_child(layer)
	background = ColorRect.new()
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.shader = BACKDROP
	background.material = backdrop
	layer.add_child(background)
	board = HABITAT.instantiate()
	add_child(board)
	menu = WORKSHOP.instantiate()
	add_child(menu)
	pages = PAGES.instantiate()
	add_child(pages)
	add_child(studio)
	add_child(online_board)
	online_board.changed.connect(queue_redraw)
	add_child(pressure_overlay)
	add_child(audio)
	add_child(accent)
	accent.hide()
	apply_settings()
	get_viewport().size_changed.connect(resize)
	resize()
	refresh_day()

func resize() -> void:
	var extent := get_viewport_rect().size
	background.size = extent
	var usable := Rect2(Vector2.ZERO, extent)
	if OS.has_feature("mobile"):
		var window_size := Vector2(DisplayServer.window_get_size())
		var safe := DisplayServer.get_display_safe_area()
		if window_size.x > 0 and window_size.y > 0 and safe.size.x > 0 and safe.size.y > 0:
			var ratio := extent / window_size
			var candidate := Rect2(Vector2(safe.position) * ratio, Vector2(safe.size) * ratio).intersection(usable)
			if candidate.size.x > extent.x * 0.5 and candidate.size.y > extent.y * 0.5:
				usable = candidate
	view_scale = minf(usable.size.x / DESIGN.x, usable.size.y / DESIGN.y)
	view_origin = usable.position + (usable.size - DESIGN * view_scale) * 0.5
	accent.position = view_origin
	accent.scale = Vector2.ONE * view_scale
	queue_redraw()

func apply_settings() -> void:
	LocalizationManager.apply(save.setting("language", "auto"))
	reduced = save.setting("reduced", false)
	var style := ThemeCatalog.unlocked_choice(save, "workshop", ThemeCatalog.STYLES, save.stat("cells"))
	workshop = ThemeCatalog.STYLES[style][2]
	backdrop.set_shader_parameter("accent", workshop)
	audio.configure(save)

func refresh_day() -> void:
	day = Time.get_date_string_from_system(true)

func open(screen: String) -> void:
	view = screen
	accent.clear()
	overlay = ""
	daily_result_copied = false
	pages.reset_effect_preview()
	fade_age = 0.0
	buttons.clear()
	disabled.clear()
	pointer_buttons.clear()
	reset_press()
	hovered = ""
	input.cancel()
	return_slot = -1
	if screen == "menu" or screen == "missions":
		refresh_day()
	if screen == "online" and online_board.configured():
		online_board.refresh()
	if screen == "records":
		history_page = 0
	if screen == "collection":
		collection_tab = 0
		pages.reset_collection()
	queue_redraw()

func start(mode: String, resume: bool) -> void:
	refresh_day()
	if resume and save.has_active_run(mode, day):
		run = save.get_run(mode, day)
	else:
		run = null
	if run == null:
		run = GameManager.new()
		var seed_value := LeaderboardProvider.daily_seed(day) if mode == GameManager.DAILY else randi()
		run.start(mode, day if mode == GameManager.DAILY else "", seed_value)
	if run.ended:
		save.record(run)
	save.store_run(run)
	open("game")
	animation = AnimationManager.new()
	particles.clear()
	if score_tween != null:
		score_tween.kill()
	score_face = run.score
	over_age = 1.0 if run.ended else 0.0
	pop_age = 2.0
	if run.ended:
		overlay = "over"
	banner_age = 2.1
	best_celebrated = run.score >= 100 and run.score == save.best(run.mode, run.day, run.used_continue)
	tutorial_active = mode == GameManager.ENDLESS and not bool(save.setting("tutorial_complete", false)) and run.cut_count < 15
	tutorial_hint = run.coaching_hint() if tutorial_active else {}
	tutorial_start_lines = run.line_count
	tutorial_start_cells = run.cut_count

func _process(delta: float) -> void:
	pop_age = minf(2.0, pop_age + delta)
	pressure_overlay.update_pressure(self)
	accent.visible = view == "game" and overlay == "" and not reduced
	clock += delta
	if clock >= 600.0:
		clock -= 600.0
	var needs_redraw := fade_age < 0.3 or (view == "menu" and not reduced) or (view == "game" and pop_age < 1.0)
	fade_age = minf(0.3, fade_age + delta)
	if not overlay.is_empty() and not reduced and overlay_age < 0.24:
		overlay_age = minf(0.24, overlay_age + delta)
		needs_redraw = true
	if view == "game" and return_slot >= 0:
		return_age += delta
		if return_age >= RETURN_DURATION:
			return_slot = -1
		needs_redraw = true
	if view == "game" and overlay != "pause":
		var particles_moving := particles.tick(delta)
		needs_redraw = (needs_redraw or particles_moving or animation.active or banner_age < 1.65
			or (run.ended and over_age < 1.0) or (show_first_move() and not reduced))
		banner_age += delta
		if animation.active:
			advance_cut(delta)
		if run.ended:
			over_age = minf(1.0, over_age + delta * (1.15 if animation.active else 2.7))
	if needs_redraw:
		queue_redraw()

func advance_cut(delta: float) -> void:
	animation.step(delta)
	if animation.elapsed >= AnimationManager.PRESS and not animation.raised and not animation.stamp_id.is_empty():
		animation.raised = true
		audio.effect("cut")
		audio.effect("separate", -5.0)
		burst_cut()
		if animation.change.lines > 0 or animation.change.order.bonus > 0:
			announce_completion()
	if animation.elapsed >= AnimationManager.REFILL and not animation.glowing:
		animation.glowing = true
		if not animation.stamp_id.is_empty():
			audio.effect("land", -4.0)
		if not animation.change.refilled.is_empty():
			animate_refill()
	if not animation.active and run.ended:
		overlay = "over"
		audio.effect("over")
		pointer_buttons.clear()
		reset_press()

func announce_completion() -> void:
	var order: Dictionary = animation.change.order
	var line: String
	if order.bonus > 0:
		line = tr("ORDER_EXACT" if order.clean else "ORDER_FILLED") % group_int(order.bonus)
	elif animation.change.full:
		line = tr("FULL_BOARD")
	elif run.streak >= 2:
		line = "%s ×%d" % [tr(ComboManager.caption(run.streak)), ComboManager.multiplier(run.streak, GameManager.BALANCE)]
	else:
		line = tr("LINE_QUEUED") if animation.change.lines == 1 else tr("MULTI_QUEUED") % animation.change.lines
	if order.bonus > 0:
		announce(line, ClayArt.Seal.PRECISE if order.clean else ClayArt.Seal.ORDER)
	elif banner != tr("NEW_BEST") or banner_age >= 1.65:
		announce(line)
	if order.bonus > 0 or run.streak >= 2 or animation.change.lines >= 2:
		audio.effect("combo")
		particles.burst(animation.stamp_center, 7 if reduced else 42, animation.palette[0], GILT, true, 1.05)

func animate_refill() -> void:
	audio.effect("refill")
	audio.buzz(42)
	if not reduced:
		accent.refill(animation.refill_center)
	particles.burst(animation.refill_center, 5 if reduced else 12, animation.palette[0], GILT, true, 0.72)
	if banner_age >= 1.65:
		var count: int = animation.change.refilled.size()
		announce(tr("LINE_REFILL") if count == 1 else tr("MULTI_REFILL") % count)

func burst_cut() -> void:
	var fx := animation.cut_effect
	var color: Color = ThemeCatalog.EFFECTS[fx][2]
	for cell: Vector2i in animation.change.removed:
		var center := GRID.position + (Vector2(cell) + Vector2(0.5, 0.35)) * UNIT
		var material := ThemeCatalog.material_at(animation.palette, cell)
		particles.burst(center, 2 if reduced else 8, material, Color.WHITE, false, 0.72)
		if not reduced:
			var sprite: ClayArt.Effect = [ClayArt.Effect.CHIP, ClayArt.Effect.GLINT, ClayArt.Effect.DROP][fx]
			particles.burst(center, 1 if fx == 0 else 3, material, Color.WHITE.lerp(color, 0.22), fx > 0, 0.81, sprite)

func announce(caption: String, stamp := -1) -> void:
	banner = caption
	banner_seal = stamp
	banner_age = 0.0

func ink(value: String, area: Rect2, size: int, color := INK, align := HORIZONTAL_ALIGNMENT_CENTER, bold := true) -> void:
	var typeface := heading if bold else font
	var pixels := fitted_font(typeface, value, area, size)
	var baseline := area.get_center().y + (typeface.get_ascent(pixels) - typeface.get_descent(pixels)) / 2.0
	var origin := Vector2(area.position.x, baseline)
	draw_string(typeface, origin, value, align, area.size.x, pixels, color)

func fitted_font(typeface: Font, value: String, area: Rect2, requested: int) -> int:
	var pixels := maxi(12, requested)
	var measured := typeface.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	var height := typeface.get_height(pixels)
	var factor := minf(1.0, minf(area.size.x / maxf(1.0, measured), area.size.y / maxf(1.0, height)))
	return maxi(12, floori(pixels * factor))

func embossed(value: String, area: Rect2, size: int, color: Color, border_color: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var pixels := fitted_font(heading, value, area, size)
	var baseline := area.get_center().y + (heading.get_ascent(pixels) - heading.get_descent(pixels)) / 2.0
	var pos := Vector2(area.position.x, baseline)
	# Do not draw overlapping glyph outlines: variable font contours can produce
	# broken strokes in MSDF and Compatibility rendering.
	var shadow := Color(border_color, color.a * 0.46)
	draw_string(heading, pos + Vector2(0, 3), value, align, area.size.x, pixels, shadow)
	draw_string(heading, pos, value, align, area.size.x, pixels, color)

func brand(area: Rect2, compact: bool) -> void:
	var half := area.size.y * 0.5
	embossed(tr("TITLE_TOP").to_upper(), Rect2(area.position, Vector2(area.size.x, half)), 74 if compact else 146, Color("#176748"), Color("#fff7e4"))
	embossed(tr("TITLE_BOTTOM").to_upper(), Rect2(area.position + Vector2(0, half), Vector2(area.size.x, half)), 74 if compact else 146, Color("#ffcb55"), Color("#875023"))

func panel(area: Rect2, color: Color, radius: int, edge := Color.TRANSPARENT, border := 2) -> void:
	art.panel(self, area, color, radius, edge, border)

func card(area: Rect2, tint := PAPER) -> void:
	panel(Rect2(area.position + Vector2(0, 5), area.size).grow(-1), SHADOW, 29)
	panel(area, tint, 29, tint.darkened(0.09), 2)

func progress_bar(area: Rect2, progress: float, track: Color, fill: Color) -> void:
	panel(area, track, roundi(area.size.y / 2.0))
	if progress > 0.0:
		panel(Rect2(area.position, Vector2(area.size.x * minf(1.0, progress), area.size.y)),
			fill, roundi(area.size.y / 2.0))

func button_face(id: String, area: Rect2) -> Rect2:
	var travel := 8.0 * press_depth if pressed_button == id else 0.0
	return Rect2(area.position + Vector2(0, travel), area.size)

func register_button(id: String, area: Rect2, locked := false) -> void:
	buttons[id] = area
	disabled[id] = locked

func button(id: String, area: Rect2, caption: String, primary := false, small := false,
		locked := false, paint := Color.TRANSPARENT, show_icon := true) -> void:
	register_button(id, area, locked)
	var pressed := button_face(id, area)
	var tint := paint
	if tint.a == 0.0:
		tint = MINT if primary else PAPER
	if locked:
		tint = tint.lerp(Color("#f0e5db"), 0.42)
	elif hovered == id:
		tint = tint.lightened(0.17)
	if paint.a == 0.0 and not locked:
		premium.button(self, pressed, primary)
	else:
		panel(Rect2(area.position + Vector2(0, 6), area.size).grow(-1), SHADOW, 29)
		panel(pressed, tint, 29, tint.darkened(0.10), 2)
	var icon_id: StringName = BUTTON_ICONS.get(id, &"")
	var label := pressed.grow(-13)
	if show_icon and not icon_id.is_empty():
		var side := 53.0 if small else 65.0
		var center := pressed.get_center() if caption.is_empty() else pressed.position + Vector2(side * 0.51 + 13.0, pressed.size.y * 0.5)
		art.icon(self, icon_id, center, side, Color.WHITE if icon_id in ClayArt.ICONS else TEAL)
		if not caption.is_empty():
			var inset := side + 5.0
			label.position.x += inset
			label.size.x -= inset
	if not caption.is_empty():
		ink(caption, label, 36 if small else 48, MUTED if locked else (PAPER if primary and paint.a == 0.0 else INK))

func header(key: StringName) -> void:
	button("back", Rect2(55, 79, 185, 81), tr("BACK"), false, true)
	ink(tr(key), Rect2(263, 70, 742, 99), 67, INK, HORIZONTAL_ALIGNMENT_LEFT)
	draw_line(Vector2(60, 189), Vector2(1020, 189), EDGE, 2.0, true)

func group_int(number: int) -> String:
	var digits := str(number)
	var result := ""
	for i in digits.length():
		if i > 0 and (digits.length() - i) % 3 == 0:
			result += " "
		result += digits[i]
	return result

func _draw() -> void:
	if board == null:
		return
	draw_set_transform(view_origin, 0.0, Vector2.ONE * view_scale)
	buttons.clear()
	disabled.clear()
	match view:
		"menu":
			menu.render(self)
		"game":
			draw_game()
		"profile", "missions", "shop", "online":
			studio.render(self)
		_:
			pages.render(self)
	if fade_age < 0.23 and not reduced:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color(1.0, 0.964, 0.91, (1.0 - fade_age / 0.23) * 0.72))

func draw_game() -> void:
	var style := ThemeCatalog.slab_style(run, save)
	var active_metal := ThemeCatalog.unlocked_choice(save, "metal", ThemeCatalog.CUTTERS, save.stat("cells"))
	var metal: Color = ThemeCatalog.CUTTERS[active_metal][2]
	draw_texture_rect(PremiumArt.EMBLEM, Rect2(60, 35, 155, 155), false)
	brand(Rect2(225, 12, 620, 136), true)
	var mode := tr("DAILY") if run.mode == GameManager.DAILY else tr("ENDLESS")
	if run.used_continue:
		mode = tr("ASSISTED")
	var rank := tr(DifficultyManager.RANKS[run.tier()])
	var active_order := not run.order.cells.is_empty()
	if active_order:
		mode = "%s · %s" % [mode, rank]
	panel(Rect2(235, 151, 600, 43), Color("#e8c997"), 20, Color("#d5a466"))
	ink(mode, Rect2(244, 149, 582, 45), 29, INK)
	register_button("pause", Rect2(902, 62, 118, 118))
	draw_texture_rect(PremiumArt.PAUSE, button_face("pause", Rect2(902, 62, 118, 118)), false)

	var meter := Rect2(60, 204, 960, 188)
	draw_texture_rect(PremiumArt.SCORE, meter, false)
	draw_line(Vector2(617, 229), Vector2(617, 367), Color("#57776a"), 2.0, true)
	ink(tr("SCORE").to_upper(), Rect2(96, 220, 300, 45), 35, PAPER, HORIZONTAL_ALIGNMENT_LEFT)
	embossed(group_int(roundi(score_face)), Rect2(89, 264, 490, 105), 104, PAPER, Color("#123c2b"), HORIZONTAL_ALIGNMENT_LEFT)
	draw_texture_rect(PremiumArt.TROPHY, Rect2(631, 259, 88, 88), false)
	ink(tr("BEST").to_upper(), Rect2(724, 221, 266, 44), 33, GILT, HORIZONTAL_ALIGNMENT_LEFT)
	embossed(group_int(save.best(run.mode, run.day, run.used_continue)), Rect2(720, 267, 270, 97), 76, PAPER, Color("#123c2b"), HORIZONTAL_ALIGNMENT_LEFT)

	board.render(self, art, run, GRID, style, animation, input, metal, over_age, reduced, workshop, heading)
	var status := rank
	if active_order:
		status = tr("ORDER_PROGRESS") % [run.order.cells.size() - run.order.remaining(run.board), run.order.cells.size()]
	panel(Rect2(66, 407, 444, 57), Color("#fff1d4"), 22, Color("#d6aa68"), 2)
	ink(status, Rect2(84, 408 if active_order else 410, 407, 46), 32, WARM if active_order else TEAL, HORIZONTAL_ALIGNMENT_LEFT)
	if active_order:
		var progress := 1.0 - float(run.order.remaining(run.board)) / run.order.cells.size()
		progress_bar(Rect2(85, 451, 403, 4), progress, Color("#e0c9a1"), TEAL)
	var soonest := run.board.soonest()
	var refill_label := tr("REFILL_DELAY") % GameManager.BALANCE.refill_delay(run.score)
	if soonest == 1:
		refill_label = tr("REFILL_NEXT")
	elif soonest > 1:
		refill_label = tr("REFILL_IN") % soonest
	panel(Rect2(529, 407, 485, 57), Color("#fff1d4"), 22, Color("#d6aa68"), 2)
	art.icon(self, &"clock", Vector2(558, 437), 38.0)
	ink(refill_label, Rect2(584, 410, 420, 47), 32, WARM, HORIZONTAL_ALIGNMENT_LEFT)
	if run.streak > 1:
		ink("%s ×%d" % [tr("COMBO"), ComboManager.multiplier(run.streak, GameManager.BALANCE)],
			Rect2(372, 224, 214, 42), 25, SCORE_LABEL, HORIZONTAL_ALIGNMENT_RIGHT)
	if banner_age < 1.65 and banner_seal < 0:
		var opacity := 1.0 - smoothstep(1.30, 1.65, banner_age)
		var area := Rect2(236, 170 + sin(minf(banner_age * 3.5, PI)) * 3, 608, 40)
		panel(area, Color(ORDER_PAPER, opacity), 20)
		ink(banner, area.grow(-8), 26, Color(WARM, opacity))
	var hint := tutorial_hint if tutorial_active else (run.first_move_hint() if show_first_move() else {})
	var pulse := 0.72 if reduced else 0.57 + sin(clock * 4.2) * 0.16
	if not hint.is_empty():
		board.outline(self, GRID, UNIT, hint.cells, hint.origin, Color(TEAL, pulse), true)
	draw_texture_rect(PremiumArt.TRAY, TRAY, false)
	for slot in slots.size():
		draw_slot(slot, style, metal)
	if not hint.is_empty():
		panel(slots[hint.slot].grow(3), Color.TRANSPARENT, 24, Color(TEAL, pulse), 3)
	draw_cut_caption(hint)
	if tutorial_active and not hint.is_empty() and input.pointer == InputManager.IDLE and not animation.active and banner_age >= 1.65:
		panel(Rect2(65, 1747, 950, 112), PAPER, 24, EDGE)
		ink(tr("COACH_LINE" if run.cut_count > 0 else "COACH_DRAG"), Rect2(82, 1751, 725, 100), 27, TEAL)
		button("skip_tutorial", Rect2(822, 1761, 176, 80), tr("SKIP"), false, true)
	draw_drag(style, metal)
	particles.render(self, art)
	if not reduced and pop_age < 1.0 and overlay == "":
		draw_cut_pop()
	if overlay != "":
		draw_overlay()

func draw_cut_pop() -> void:
	var fade := 1.0 - smoothstep(0.55, 1.0, pop_age)
	var bounce := 1.0 + 0.17 * sin(minf(pop_age * 9.0, PI))
	var center := pop_center + Vector2(0, -50 - pop_age * 115)
	center.x = clampf(center.x, 245.0, 835.0)
	center.y = clampf(center.y, 525.0, 1360.0)
	var tint := Color(Color("#fff9da"), fade)
	var rim := Color(Color("#965d24"), fade)
	embossed("+%s" % group_int(pop_points), Rect2(center - Vector2(210, 53), Vector2(420, 100)), roundi(75 * bounce), tint, rim)
	if pop_combo > 1:
		embossed("%s ×%d" % [tr("COMBO").to_upper(), pop_combo], Rect2(center - Vector2(235, 121), Vector2(470, 75)), roundi(54 * bounce), Color(GILT, fade), rim)
	for i in 5:
		var angle := float(i) * TAU / 5.0 + 0.2
		var pos := pop_center + Vector2.from_angle(angle) * (45.0 + pop_age * 130.0)
		PremiumArt.sparkle(self, pos, 54.0 * fade, fade)
	if pop_combo > 1:
		var radius := 32.0 + 220.0 * pop_age
		draw_arc(pop_center, radius, 0.0, TAU, 48, Color(GILT, fade * 0.65), 5.0, true)

func show_first_move() -> bool:
	return (run.cut_count == 0 and not run.ended and save.stat("cells") == 0
		and input.pointer == InputManager.IDLE and return_slot < 0 and overlay.is_empty())

func draw_cut_caption(hint: Dictionary) -> void:
	if input.valid and not input.forecast.is_empty():
		var points: int = input.forecast.points
		panel(Rect2(212, 1749, 656, 67), Color("#e6efe4"), 29, Color("#b2d1bc"), 2)
		ink(tr("PREVIEW_POINTS") % group_int(points), Rect2(220, 1753, 640, 58), 31, TEAL)
		var completed: int = input.forecast.completed.size()
		var order: Dictionary = input.forecast.order
		if order.bonus > 0:
			ink(tr("ORDER_WILL_FINISH") % group_int(order.bonus), Rect2(76, 1824, 928, 42), 25, WARM)
		elif order.hit and run.order.clean and not order.clean:
			ink(tr("ORDER_OVER_EDGE"), Rect2(76, 1824, 928, 42), 25, WARM)
		elif completed > 0:
			var label := tr("PREVIEW_ONE_LINE") if completed == 1 else tr("PREVIEW_LINES") % completed
			ink(label, Rect2(76, 1824, 928, 42), 24, MUTED, HORIZONTAL_ALIGNMENT_CENTER, false)
	elif banner_seal >= 0 and banner_age < 1.65 and not run.ended:
		var progress := 1.0 if reduced else smoothstep(0.0, 0.20, banner_age)
		var alpha := 1.0 - smoothstep(1.39, 1.65, banner_age)
		var toast := Rect2(152, 1749 + (1.0 - progress) * 12, 776, 87)
		panel(toast, Color(ORDER_PAPER, alpha), 30)
		art.seal(self, banner_seal, toast.position + Vector2(56, 43), 65.0, Color(Color.WHITE, alpha))
		ink(banner, Rect2(toast.position + Vector2(104, 13), Vector2(636, 61)), 30,
			Color(WARM, alpha), HORIZONTAL_ALIGNMENT_LEFT)
	elif not hint.is_empty() or (run.cut_count < 4 and run.order.cells.is_empty() and not run.ended):
		var title := "FIRST_CUT_HINT" if not hint.is_empty() else "DRAG_HINT"
		ink(tr(title), Rect2(80, 1750, 920, 63), 32, INK)
		ink(tr("REFILL_HINT"), Rect2(76, 1813, 928, 42), 24, MUTED, HORIZONTAL_ALIGNMENT_CENTER, false)
	elif not run.order.cells.is_empty() and not run.ended:
		var reward := GameManager.BALANCE.clean_order_points if run.order.clean else GameManager.BALANCE.order_points
		ink(tr("ORDER_HINT"), Rect2(76, 1750, 928, 55), 31, INK)
		var label := "ORDER_EXACT_BONUS" if run.order.clean else "ORDER_BONUS"
		ink(tr(label) % group_int(reward), Rect2(76, 1812, 928, 42), 24, WARM, HORIZONTAL_ALIGNMENT_CENTER, false)

func draw_slot(slot: int, style: int, metal: Color) -> void:
	var area := slots[slot]
	var id: String = run.cutters.hand[slot]
	var empty := id == "" or slot == input.slot or slot == return_slot
	if empty:
		draw_line(area.get_center() - Vector2(18, 0), area.get_center() + Vector2(18, 0),
			Color("#a48f75"), 4.0, true)
		return
	var form := run.cutters.shape(slot)
	var unit := preview_unit(form, SLOT_PREVIEW.x, SLOT_PREVIEW.y)
	var tone := Color(Color.WHITE, 0.65) if run.ended else Color.WHITE
	var center := area.get_center()
	if animation.active and animation.change.get("dealt", false) and not reduced:
		var spring := clampf((animation.elapsed - slot * 0.065) / 0.36, 0, 1)
		unit *= lerpf(0.71, 1.0, ease(spring, -1.8))
		center.y += 27.0 * (1.0 - spring)
		tone.a *= smoothstep(0.03, 0.59, spring)
	draw_form(form, id, center, unit, style, Color(metal, tone.a), tone)

func preview_unit(form: Dictionary, width: float, height: float) -> float:
	var size: Vector2i = form.size
	return minf(width / size.x, height / size.y)

func draw_form(form: Dictionary, id: String, at: Vector2, unit: float, style: int, metal: Color, tint: Color) -> void:
	var start := at - Vector2(form.size) * unit / 2.0
	board.slab.piece(self, form.cells, Vector2i.ZERO, start, unit, style, tint, unit * 0.07)
	art.cutter(self, id, at, unit, metal)

func draw_drag(style: int, metal: Color) -> void:
	if input.slot >= 0:
		var id := run.cutters.hand[input.slot]
		var form := run.cutters.shape(input.slot)
		var drag_center := input.position - Vector2(0, UNIT * (1.02 if input.touchscreen else 0.29))
		if input.touched_board:
			drag_center = GRID.position + (Vector2(input.anchor) + Vector2(form.size) / 2.0) * UNIT
			var tint := BoardView.VALID if input.valid else BoardView.INVALID
			art.cutter(self, id, drag_center, UNIT, metal.lerp(tint, 0.46))
		else:
			draw_form(form, id, drag_center, UNIT, style, metal, Color.WHITE)
	elif return_slot >= 0:
		var id := run.cutters.hand[return_slot]
		var form := run.cutters.shape(return_slot)
		var progress := clampf(return_age / RETURN_DURATION, 0.0, 1.0)
		var easing := 1.0 - pow(1.0 - progress, 3.0)
		var target := slots[return_slot].get_center()
		var center := return_from.lerp(target, easing)
		center.y -= 22.0 * sin(progress * PI)
		var unit := lerpf(UNIT, preview_unit(form, SLOT_PREVIEW.x, SLOT_PREVIEW.y), easing)
		draw_form(form, id, center, unit, style, metal, Color.WHITE)

func draw_overlay() -> void:
	buttons.clear()
	disabled.clear()
	var entrance := 1.0 if reduced else smoothstep(0.0, 0.24, overlay_age)
	var slide := (1.0 - entrance) * 18.0
	draw_rect(Rect2(-DESIGN, DESIGN * 3), Color(0.09, 0.20, 0.16, lerpf(0.37, 0.64, entrance)))
	if overlay == "pause":
		card(Rect2(115, 625 + slide, 850, 677), PAPER)
		ink(tr("PAUSED"), Rect2(172, 681 + slide, 736, 112), 76)
		button("resume_game", Rect2(189, 851 + slide, 702, 111), tr("RESUME"), true)
		button("home", Rect2(189, 1000 + slide, 702, 105), tr("HOME"))
		button("pause_settings", Rect2(189, 1142 + slide, 702, 96), tr("SETTINGS"))
		return
	var daily := run.mode == GameManager.DAILY and DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD)
	var has_orders := run.order.completed > 0
	var extra := 94 if has_orders else 0
	var height := 764 + extra + (108 if daily else 0)
	var modal := Rect2(94, (DESIGN.y - height) / 2 + slide, 892, height)
	card(modal, PAPER)
	var top := modal.position.y
	art.seal(self, ClayArt.Seal.STAR, Vector2(540, top + 77), 113.0)
	ink(tr("GAME_OVER"), Rect2(143, top + 126, 794, 93), 66)
	panel(Rect2(167, top + 249, 746, 165), SCORE_PLATE, 34)
	draw_line(Vector2(540, top + 268), Vector2(540, top + 393), Color("#57776a"), 2.0, true)
	ink(tr("SCORE"), Rect2(184, top + 266, 340, 45), 27, SCORE_LABEL)
	ink(tr("BEST"), Rect2(555, top + 266, 340, 45), 27, GILT)
	ink(group_int(run.score), Rect2(184, top + 310, 340, 80), 58, PAPER)
	ink(group_int(save.best(run.mode, run.day, run.used_continue)), Rect2(555, top + 310, 340, 80), 58, PAPER)
	if has_orders:
		var summary := Rect2(168, top + 437, 744, 69)
		panel(summary, ORDER_PAPER, 26)
		art.seal(self, ClayArt.Seal.ORDER, Vector2(208, top + 471), 47)
		ink(tr("ORDERS_TOTAL"), Rect2(245, top + 444, 497, 55), 27, WARM, HORIZONTAL_ALIGNMENT_LEFT)
		ink(group_int(run.order.completed), Rect2(765, top + 444, 116, 55), 31, WARM, HORIZONTAL_ALIGNMENT_RIGHT)
	var action := top + 455 + extra
	button("again", Rect2(168, action, 744, 109), tr("PLAY_AGAIN"), true)
	button("home", Rect2(168, action + 131, 744, 89), tr("HOME"))
	if daily:
		var text := tr("DAILY_COPIED") if daily_result_copied else tr("COPY_DAILY")
		button("copy_daily", Rect2(168, action + 239, 744, 79), text, false, true)


func daily_result_text() -> String:
	return "%s %s · %s\n%s\n%s %s" % [tr("TITLE_TOP"), tr("TITLE_BOTTOM"), tr("DAILY"),
		run.day, tr("SCORE"), group_int(run.score)]

func copy_daily_result() -> void:
	if overlay == "over" and run.mode == GameManager.DAILY and DisplayServer.has_feature(DisplayServer.FEATURE_CLIPBOARD):
		DisplayServer.clipboard_set(daily_result_text())
		daily_result_copied = true

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.canceled:
			cancel_pointer(event.index)
		elif event.pressed:
			pointer_down(event.index, virtual(event.position))
		else:
			pointer_up(event.index, virtual(event.position))
	elif event is InputEventScreenDrag:
		pointer_move(event.index, virtual(event.position))
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pointer_down(InputManager.MOUSE, virtual(event.position))
		else:
			pointer_up(InputManager.MOUSE, virtual(event.position))
	elif event is InputEventMouseMotion:
		pointer_move(InputManager.MOUSE, virtual(event.position))
	elif event.is_action_pressed("ui_cancel") and not event.is_echo():
		escape()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		input.cancel()
		pointer_buttons.clear()
		reset_press()
		queue_redraw()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		escape()

func virtual(position: Vector2) -> Vector2:
	return (position - view_origin) / view_scale

func button_at(position: Vector2) -> String:
	for id: String in buttons:
		var area: Rect2 = buttons[id]
		if area.has_point(position) and not disabled.get(id, false):
			return id
	return ""

func pointer_down(id: int, at: Vector2) -> void:
	if overlay == "" and view == "game" and (input.pointer != InputManager.IDLE or animation.active or run.ended):
		return
	var target := button_at(at)
	if target != "" and pointer_buttons.is_empty():
		pointer_buttons[id] = target
		animate_press(target, true)
		return
	if not pointer_buttons.is_empty() or view != "game" or overlay != "":
		return
	for slot in slots.size():
		if slots[slot].has_point(at) and not run.cutters.shape(slot).is_empty():
			return_slot = -1
			input.begin(id, slot, at)
			queue_redraw()
			audio.effect("press", -3.0)
			audio.buzz(15)
			break

func pointer_move(id: int, at: Vector2) -> void:
	if input.pointer == id and input.slot >= 0:
		var form := run.cutters.shape(input.slot)
		var previous := input.anchor
		input.move(at, GRID, form.size, UNIT, run.board, form.cells)
		if input.valid:
			if input.forecast.is_empty() or previous != input.anchor:
				input.forecast = run.preview_move(input.slot, input.anchor)
		else:
			input.forecast.clear()
		queue_redraw()
	elif id == InputManager.MOUSE:
		var next := button_at(at)
		if next != hovered:
			hovered = next
			queue_redraw()

func pointer_up(id: int, at: Vector2) -> void:
	if pointer_buttons.has(id):
		var target: String = pointer_buttons[id]
		pointer_buttons.erase(id)
		animate_press(target, false)
		if target == button_at(at):
			audio.effect("tap")
			activate(target)
		queue_redraw()
		return
	if input.pointer != id or input.slot < 0 or view != "game" or overlay != "":
		return
	pointer_move(id, at)
	var slot := input.slot
	var anchor := input.anchor
	var valid := input.valid
	var up := UNIT * (1.02 if input.touchscreen else 0.29)
	return_from = at - Vector2(0, up)
	if input.touched_board:
		return_from = GRID.position + (Vector2(anchor) + Vector2(run.cutters.shape(slot).size) / 2.0) * UNIT
	input.cancel()
	if valid:
		cut(slot, anchor)
	else:
		if not reduced:
			return_slot = slot
			return_age = 0.0
		audio.effect("stretch", -8.0)
	queue_redraw()

func cancel_pointer(id: int) -> void:
	if input.pointer == id:
		input.cancel()
	if pointer_buttons.has(id):
		var target: String = pointer_buttons[id]
		pointer_buttons.erase(id)
		animate_press(target, false)
	queue_redraw()

func animate_press(target: String, down: bool) -> void:
	if press_tween != null:
		press_tween.kill()
	if target != pressed_button:
		press_depth = 0.0
	pressed_button = target
	var resting := 1.0 if down else 0.0
	if reduced:
		draw_press(resting)
		return
	press_tween = create_tween()
	press_tween.tween_method(draw_press, press_depth, resting, 0.085 if down else 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func draw_press(depth: float) -> void:
	press_depth = depth
	queue_redraw()

func reset_press() -> void:
	if press_tween != null:
		press_tween.kill()
	pressed_button = ""
	press_depth = 0.0

func cut(slot: int, anchor: Vector2i) -> void:
	var id := run.cutters.hand[slot]
	var palette := ThemeCatalog.active_palette(run, save)
	var style := ThemeCatalog.slab_style(run, save)
	var change := run.play(slot, anchor)
	if change.is_empty():
		return
	var changed_best := save.update_move(run, change.removed.size(), change.lines)
	if tutorial_active:
		if run.line_count > tutorial_start_lines or run.cut_count - tutorial_start_cells >= 20 or run.ended:
			tutorial_active = false
			save.set_setting("tutorial_complete", true)
		tutorial_hint = run.coaching_hint() if tutorial_active else {}
	var center := GRID.position + (Vector2(anchor) + Vector2(change.form.size) / 2.0) * UNIT
	pop_age = 0.0
	pop_points = change.points
	pop_center = center
	pop_combo = ComboManager.multiplier(run.streak, GameManager.BALANCE)
	start_animation(change, id, center, palette, style)
	audio.effect("stretch")
	audio.buzz(22)
	if score_tween != null:
		score_tween.kill()
	if reduced:
		score_face = run.score
	else:
		score_tween = create_tween()
		score_tween.tween_property(self, "score_face", float(run.score), 0.43).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if changed_best and not best_celebrated and (run.score >= 100 or run.ended):
		best_celebrated = true
		announce(tr("NEW_BEST"))
		audio.effect("best")
		if not reduced:
			accent.celebrate(center)
		particles.burst(center, 18 if reduced else 45, palette[0], GILT, true, 1.18)

func start_animation(change: Dictionary, stamp: String, center: Vector2, palette: Array, style: int) -> void:
	var effect := ThemeCatalog.unlocked_choice(save, "effect", ThemeCatalog.EFFECTS, save.stat("lines"))
	animation.start(change, stamp, center, palette, style, effect)
	if not change.refilled.is_empty():
		var middle := BoardManager.line_cell(change.refilled[0], floori(BoardManager.SIZE / 2.0))
		animation.refill_center = GRID.position + (Vector2(middle) + Vector2.ONE * 0.5) * UNIT

func escape() -> void:
	if view == "game" and overlay == "":
		activate("pause")
	elif view == "game" and overlay == "pause":
		activate("resume_game")
	elif view == "game":
		activate("home")
	elif view != "menu":
		activate("back")

func activate(id: String) -> void:
	match id:
		"tutorial":
			start(GameManager.ENDLESS, true)
			tutorial_active = not run.ended
			tutorial_hint = run.coaching_hint()
			tutorial_start_lines = run.line_count
			tutorial_start_cells = run.cut_count
		"skip_tutorial":
			tutorial_active = false
			tutorial_hint.clear()
			save.set_setting("tutorial_complete", true)
		"profile", "missions", "shop", "online":
			open(id)
		"online_refresh":
			online_board.refresh()
		"online_submit":
			online_board.submit(save)
		"play":
			start(GameManager.ENDLESS, true)
		"daily":
			start(GameManager.DAILY, true)
		"again":
			start(run.mode, false)
		"copy_daily":
			copy_daily_result()
		"pause":
			if not animation.active and not run.ended:
				input.cancel()
				overlay = "pause"
		"resume_game":
			overlay = ""
		"pause_settings":
			open("pause_settings")
		"back":
			if view == "pause_settings":
				open("game")
				overlay = "pause"
			else:
				open("menu")
		"home", "collection", "records", "settings":
			open("menu" if id == "home" else id)
		_:
			if id.begins_with("claim_"):
				refresh_day()
				Progression.claim(save, int(id.get_slice("_", 1)), day)
			elif id.begins_with("buy_"):
				Progression.buy(save, int(id.get_slice("_", 1)))
			else:
				pages.activate(self, id)
	queue_redraw()
