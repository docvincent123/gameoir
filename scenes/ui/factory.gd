class_name Factory
extends Node2D

const DESIGN := Vector2(1080, 1920)
const WEIGHT_TAG := 0x77676874 # OpenType wght axis.
const FONT := preload("res://assets/ui/fonts/Nunito.ttf")
const BACKDROP := preload("res://assets/shaders/workshop.gdshader")
const HABITAT := preload("res://scenes/gameplay/gameplay.tscn")
const WORKSHOP := preload("res://scenes/menu/menu.tscn")
const PAGES := preload("res://scenes/ui/screens.tscn")

const INK := Color("#263b35")
const MUTED := Color("#51655e")
const TEAL := Color("#176658")
const WARM := Color("#86502d")
const PAPER := Color("#fffbee")
const MINT := Color("#ade5cb")
const ROSE := Color("#fac6cc")
const SKY := Color("#c6e5f4")
const LILAC := Color("#e1d7f3")
const SUN := Color("#ffe2a1")
const PEACH := Color("#ffd8bc")
const GILT := Color("#ffe093")
const EDGE := Color("#c0d5c9")
const SHADOW := Color(0.26, 0.34, 0.22, 0.15)
const GRID := Rect2(88, 507, 904, 904)
const TRAY := Rect2(62, 1500, 956, 234)
const UNIT := GRID.size.x / BoardManager.SIZE
const RETURN_DURATION := 0.30
const SLOT_PREVIEW := Vector2(224, 129)
const BUTTON_ICONS := {
	"play": &"play", "daily": &"calendar", "collection": &"collection",
	"records": &"trophy", "settings": &"settings", "pause": &"pause", "back": &"back",
	"resume_game": &"play", "again": &"restart", "home": &"home",
	"pause_settings": &"settings",
	"tab_0": &"collection", "tab_1": &"cutter", "tab_2": &"home", "tab_3": &"shine",
}

var view := "menu"
var overlay := ""
var day := ""
var save := SaveManager.new()
var run: GameManager
var art := ClayArt.new()
var input := InputManager.new()
var animation := AnimationManager.new()
var particles := ParticleManager.new()
var accent := AccentEffects.new()
var audio := AudioManager.new()
var board: BoardView
var menu
var pages
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
var score_tween: Tween
var fade_age := 1.0
var over_age := 0.0
var banner := ""
var banner_age := 2.1
var best_celebrated := false
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
	font.base_font = FONT
	font.variation_opentype = {WEIGHT_TAG: 660}
	heading.base_font = FONT
	heading.variation_opentype = {WEIGHT_TAG: 930}
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
	view_scale = minf(extent.x / DESIGN.x, extent.y / DESIGN.y)
	view_origin = (extent - DESIGN * view_scale) * 0.5
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
	pages.reset_effect_preview()
	fade_age = 0.0
	buttons.clear()
	disabled.clear()
	pointer_buttons.clear()
	reset_press()
	hovered = ""
	input.cancel()
	return_slot = -1
	if screen == "menu":
		refresh_day()
	if screen == "records":
		history_page = 0
	if screen == "collection":
		collection_tab = 0
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
	score_face = run.score
	over_age = 1.0 if run.ended else 0.0
	if run.ended:
		overlay = "over"
	banner_age = 2.1
	best_celebrated = run.score >= 100 and run.score == save.best(run.mode, run.day, run.used_continue)

func _process(delta: float) -> void:
	accent.visible = view == "game" and overlay == "" and not reduced
	clock += delta
	if clock >= 600.0:
		clock -= 600.0
	var needs_redraw := fade_age < 0.3 or (view == "menu" and not reduced)
	fade_age = minf(0.3, fade_age + delta)
	if view == "game" and return_slot >= 0:
		return_age += delta
		if return_age >= RETURN_DURATION:
			return_slot = -1
		needs_redraw = true
	if view == "game" and overlay != "pause":
		var particles_moving := particles.tick(delta)
		needs_redraw = (needs_redraw or particles_moving or animation.active or banner_age < 1.65
			or (run.ended and over_age < 1.0))
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
		if animation.change.lines > 0:
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
	var line := tr("LINE_QUEUED") if animation.change.lines == 1 else tr("MULTI_QUEUED") % animation.change.lines
	if animation.change.full:
		line = tr("FULL_BOARD")
	elif run.streak >= 2:
		line = "%s ×%d" % [tr(ComboManager.caption(run.streak)), ComboManager.multiplier(run.streak, GameManager.BALANCE)]
	if banner != tr("NEW_BEST") or banner_age >= 1.65:
		announce(line)
	if run.streak >= 2 or animation.change.lines >= 2:
		audio.effect("combo")
		particles.burst(animation.stamp_center, 7 if reduced else 23, animation.palette[0], GILT, true, 1.05)

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
		particles.burst(center, 2 if reduced else 5, material, Color.WHITE, false, 0.72)
		if not reduced:
			var sprite: ClayArt.Effect = [ClayArt.Effect.CHIP, ClayArt.Effect.GLINT, ClayArt.Effect.DROP][fx]
			particles.burst(center, 1 if fx == 0 else 3, material, Color.WHITE.lerp(color, 0.22), fx > 0, 0.81, sprite)

func announce(caption: String) -> void:
	banner = caption
	banner_age = 0.0

func ink(value: String, area: Rect2, size: int, color := INK, align := HORIZONTAL_ALIGNMENT_CENTER, bold := true) -> void:
	var typeface := heading if bold else font
	var pixels := size
	var measured := typeface.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	if measured > area.size.x:
		pixels = maxi(16, int(float(size) * area.size.x / measured))
	var baseline := area.get_center().y + (typeface.get_ascent(pixels) - typeface.get_descent(pixels)) / 2.0
	draw_string(typeface, Vector2(area.position.x, baseline), value, align, area.size.x, pixels, color)

func panel(area: Rect2, color: Color, radius: int, edge := Color.TRANSPARENT, border := 2) -> void:
	art.panel(self, area, color, radius, edge, border)

func card(area: Rect2, tint := PAPER) -> void:
	panel(Rect2(area.position + Vector2(0, 8), area.size).grow(-3), SHADOW, 32)
	art.skin(self, area, &"raised", tint)

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
	panel(Rect2(area.position + Vector2(0, 9), area.size).grow(-2), SHADOW, 34)
	art.skin(self, pressed, &"raised", tint)
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
		ink(caption, label, 32 if small else 44, MUTED if locked else INK)

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
		_:
			pages.render(self)
	if fade_age < 0.23 and not reduced:
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color(1.0, 0.964, 0.91, (1.0 - fade_age / 0.23) * 0.72))

func draw_game() -> void:
	var palette := ThemeCatalog.active_palette(run, save)
	var active_metal := ThemeCatalog.unlocked_choice(save, "metal", ThemeCatalog.CUTTERS, save.stat("cells"))
	var metal: Color = ThemeCatalog.CUTTERS[active_metal][2]
	var title := tr("TITLE_TOP") + " " + tr("TITLE_BOTTOM")
	ink(title, Rect2(145, 64, 726, 72), 49, INK, HORIZONTAL_ALIGNMENT_LEFT)
	var mode := tr("DAILY") if run.mode == GameManager.DAILY else tr("ENDLESS")
	if run.used_continue:
		mode = tr("ASSISTED")
	ink(mode, Rect2(147, 137, 689, 43), 26, MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	button("pause", Rect2(917, 73, 98, 95), "", false, false, false, PAPER)
	art.icon(self, &"cutter", Vector2(91, 119), 76.0, TEAL)
	card(Rect2(60, 216, 558, 184), Color("#e6efe4"))
	card(Rect2(637, 216, 382, 184), Color("#f7ead4"))
	ink(tr("SCORE").to_upper(), Rect2(96, 235, 498, 45), 27, TEAL, HORIZONTAL_ALIGNMENT_LEFT)
	ink(group_int(roundi(score_face)), Rect2(91, 280, 491, 100), 83, INK, HORIZONTAL_ALIGNMENT_LEFT)
	art.icon(self, &"trophy", Vector2(700, 308), 71.0)
	ink(tr("BEST").to_upper(), Rect2(753, 242, 231, 40), 27, WARM, HORIZONTAL_ALIGNMENT_LEFT)
	ink(group_int(save.best(run.mode, run.day, run.used_continue)), Rect2(749, 285, 236, 78), 58, INK, HORIZONTAL_ALIGNMENT_LEFT)

	board.render(self, art, run, GRID, palette, animation, input, metal, over_age, reduced, workshop, heading)
	panel(Rect2(67, 419, 458, 38), Color("#e0f2df"), 18)
	ink(tr(DifficultyManager.RANKS[run.tier()]), Rect2(85, 420, 422, 35), 24, TEAL, HORIZONTAL_ALIGNMENT_LEFT)
	var soonest := run.board.soonest()
	var refill_label := tr("REFILL_DELAY") % GameManager.BALANCE.refill_delay(run.score)
	if soonest == 1:
		refill_label = tr("REFILL_NEXT")
	elif soonest > 1:
		refill_label = tr("REFILL_IN") % soonest
	panel(Rect2(590, 418, 420, 42), Color("#fff0cc"), 19)
	art.icon(self, &"clock", Vector2(620, 438), 39.0)
	ink(refill_label, Rect2(646, 418, 353, 41), 24, WARM, HORIZONTAL_ALIGNMENT_LEFT)
	if run.streak > 1:
		ink("%s ×%d" % [tr("COMBO"), ComboManager.multiplier(run.streak, GameManager.BALANCE)],
			Rect2(373, 236, 214, 42), 25, TEAL, HORIZONTAL_ALIGNMENT_RIGHT)
	if banner_age < 1.65:
		var opacity := 1.0 - smoothstep(1.30, 1.65, banner_age)
		var area := Rect2(236, 180 + sin(minf(banner_age * 3.5, PI)) * 3, 608, 40)
		panel(area, Color("#f4d7e7", opacity), 20, Color("#dcabc4", opacity * 0.6), 2)
		ink(banner, area.grow(-8), 28, Color("#81375f", opacity))
	art.skin(self, TRAY, &"recess", Color("#e4d6be"))
	for slot in slots.size():
		draw_slot(slot, palette[slot % palette.size()], metal)
	if run.cut_count < 4 and not run.ended:
		ink(tr("DRAG_HINT"), Rect2(80, 1760, 920, 53), 32, INK)
		ink(tr("REFILL_HINT"), Rect2(76, 1813, 928, 42), 24, MUTED, HORIZONTAL_ALIGNMENT_CENTER, false)
	draw_drag(palette, metal)
	particles.render(self, art)
	if overlay != "":
		draw_overlay()

func draw_slot(slot: int, material: int, metal: Color) -> void:
	var area := slots[slot]
	var id: String = run.cutters.hand[slot]
	var empty := id == "" or slot == input.slot or slot == return_slot
	art.skin(self, area, &"recess", Color("#eee3cf"))
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
	draw_form(form, id, center, unit, material, Color(metal, tone.a), Color(tone, tone.a * 0.91))

func preview_unit(form: Dictionary, width: float, height: float) -> float:
	var size: Vector2i = form.size
	return minf(width / size.x, height / size.y)

func draw_form(form: Dictionary, id: String, at: Vector2, unit: float, material: int, metal: Color, tint: Color) -> void:
	var start := at - Vector2(form.size) * unit / 2.0
	for cell: Vector2i in form.cells:
		art.cell(self, Rect2(start + Vector2(cell) * unit, Vector2.ONE * unit), material, (cell.x * 3 + cell.y * 5) % ClayArt.VARIANTS, tint)
	art.cutter(self, id, at, unit, metal)

func draw_drag(palette: Array, metal: Color) -> void:
	if input.slot >= 0:
		var id := run.cutters.hand[input.slot]
		var form := run.cutters.shape(input.slot)
		var drag_center := input.position - Vector2(0, UNIT * (1.02 if input.touchscreen else 0.29))
		if input.touched_board:
			drag_center = GRID.position + (Vector2(input.anchor) + Vector2(form.size) / 2.0) * UNIT
			var tint := BoardView.VALID if input.valid else BoardView.INVALID
			art.cutter(self, id, drag_center, UNIT, metal.lerp(tint, 0.46))
		else:
			draw_form(form, id, drag_center, UNIT, palette[input.slot % palette.size()], metal, Color.WHITE)
	elif return_slot >= 0:
		var id := run.cutters.hand[return_slot]
		var form := run.cutters.shape(return_slot)
		var progress := clampf(return_age / RETURN_DURATION, 0.0, 1.0)
		var easing := 1.0 - pow(1.0 - progress, 3.0)
		var target := slots[return_slot].get_center()
		var center := return_from.lerp(target, easing)
		center.y -= 22.0 * sin(progress * PI)
		var unit := lerpf(UNIT, preview_unit(form, SLOT_PREVIEW.x, SLOT_PREVIEW.y), easing)
		draw_form(form, id, center, unit, palette[return_slot % palette.size()], metal, Color.WHITE)

func draw_overlay() -> void:
	buttons.clear()
	disabled.clear()
	draw_rect(Rect2(-DESIGN, DESIGN * 3), Color(0.13, 0.24, 0.20, 0.57))
	if overlay == "pause":
		card(Rect2(115, 625, 850, 677), PAPER)
		ink(tr("PAUSED"), Rect2(172, 681, 736, 112), 76)
		button("resume_game", Rect2(189, 851, 702, 111), tr("RESUME"), true)
		button("home", Rect2(189, 1000, 702, 105), tr("HOME"))
		button("pause_settings", Rect2(189, 1142, 702, 96), tr("SETTINGS"))
		return
	var modal := Rect2(94, 597, 892, 727)
	card(modal, PAPER)
	var top := modal.position.y
	art.icon(self, &"trophy", Vector2(540, top + 73), 110.0)
	ink(tr("GAME_OVER"), Rect2(143, top + 112, 794, 104), 68)
	var score_area := Rect2(168, top + 242, 744, 176)
	art.skin(self, score_area, &"recess", PEACH)
	draw_line(Vector2(540, top + 269), Vector2(540, top + 390), EDGE, 2.0, true)
	ink(tr("SCORE"), Rect2(184, top + 266, 340, 47), 28, MUTED)
	ink(tr("BEST"), Rect2(555, top + 266, 340, 47), 28, MUTED)
	ink(group_int(run.score), Rect2(184, top + 313, 340, 78), 58)
	ink(group_int(save.best(run.mode, run.day, run.used_continue)), Rect2(555, top + 313, 340, 78), 58, WARM)
	button("again", Rect2(168, top + 460, 744, 111), tr("PLAY_AGAIN"), true)
	button("home", Rect2(168, top + 605, 744, 90), tr("HOME"))

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
		input.move(at, GRID, form.size, UNIT, run.board, form.cells)
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
	var change := run.play(slot, anchor)
	if change.is_empty():
		return
	var changed_best := save.update_move(run, change.removed.size(), change.lines)
	var center := GRID.position + (Vector2(anchor) + Vector2(change.form.size) / 2.0) * UNIT
	start_animation(change, id, center, palette)
	audio.effect("stretch")
	audio.buzz(22)
	if score_tween != null:
		score_tween.kill()
	score_tween = create_tween()
	score_tween.tween_property(self, "score_face", float(run.score), 0.43).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if changed_best and not best_celebrated and (run.score >= 100 or run.ended):
		best_celebrated = true
		announce(tr("NEW_BEST"))
		audio.effect("best")
		if not reduced:
			accent.celebrate(center)
		particles.burst(center, 18 if reduced else 45, palette[0], GILT, true, 1.18)

func start_animation(change: Dictionary, stamp: String, center: Vector2, palette: Array) -> void:
	var effect := ThemeCatalog.unlocked_choice(save, "effect", ThemeCatalog.EFFECTS, save.stat("lines"))
	animation.start(change, stamp, center, palette, effect)
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
		"play":
			start(GameManager.ENDLESS, true)
		"daily":
			start(GameManager.DAILY, true)
		"again":
			start(run.mode, false)
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
			pages.activate(self, id)
	queue_redraw()
