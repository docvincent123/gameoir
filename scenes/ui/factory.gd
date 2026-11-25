class_name Factory
extends Node2D

const DESIGN := Vector2(1080, 1920)
const WEIGHT_TAG := 0x77676874 # OpenType wght axis.
const FONT := preload("res://assets/ui/fonts/Nunito.ttf")
const BACKDROP := preload("res://assets/shaders/workshop.gdshader")
const HABITAT := preload("res://scenes/gameplay/gameplay.tscn")
const WORKSHOP := preload("res://scenes/menu/menu.tscn")
const PAGES := preload("res://scenes/ui/screens.tscn")

const WHITE := Color("#fff3ff")
const SOFT := Color("#d6bade")
const MUTED := Color("#bf9bcd")
const GILT := Color("#ffdc91")
const CARD := Color("#2a163b")
const CARD_EDGE := Color("#59376c")
const GRID := Rect2(88, 489, 904, 904)
const TRAY := Rect2(62, 1500, 956, 234)
const UNIT := GRID.size.x / 8.0

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
var workshop := Color("#4b2762")
var buttons: Dictionary = {}
var disabled: Dictionary = {}
var pointer_buttons: Dictionary = {}
var clicked := ""
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
var return_age := 2.0
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
	backdrop.set_shader_parameter("accent", workshop.lightened(0.078))
	audio.configure(save)

func refresh_day() -> void:
	day = Time.get_date_string_from_system(true)

func open(screen: String) -> void:
	view = screen
	accent.clear()
	overlay = ""
	fade_age = 0.0
	buttons.clear()
	disabled.clear()
	pointer_buttons.clear()
	clicked = ""
	hovered = ""
	input.cancel()
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
	return_slot = -1

func _process(delta: float) -> void:
	accent.visible = view == "game" and overlay == "" and not reduced
	clock += delta
	if clock >= 600.0:
		clock -= 600.0
	var needs_redraw := fade_age < 0.3 or (view == "menu" and not reduced)
	fade_age = minf(0.3, fade_age + delta)
	if view == "game" and overlay != "pause":
		var particles_moving := particles.tick(delta)
		needs_redraw = needs_redraw or particles_moving or animation.active or banner_age < 1.65 			or return_slot >= 0 or (run.ended and over_age < 1.0)
		banner_age += delta
		return_age += delta
		if animation.active:
			advance_cut(delta)
		if run.ended:
			over_age = minf(1.0, over_age + delta * (1.15 if animation.active else 2.7))
	if needs_redraw:
		queue_redraw()

func advance_cut(delta: float) -> void:
	animation.step(delta)
	if animation.elapsed >= AnimationManager.PRESS and not animation.raised:
		animation.raised = true
		audio.effect("cut")
		audio.effect("separate", -5.0)
		burst_cut()
	if animation.elapsed >= AnimationManager.REFILL and not animation.glowing:
		animation.glowing = true
		audio.effect("land", -4.0)
		if animation.change.lines > 0:
			audio.effect("refill")
			if not reduced:
				accent.refill(animation.stamp_center)
			audio.buzz(40 + mini(85, run.streak * 9))
			var line := tr("LINE_REFILL") if animation.change.lines == 1 else tr("MULTI_REFILL") % animation.change.lines
			if animation.change.full:
				line = tr("FULL_BOARD")
			elif run.streak >= 2:
				line = "%s ×%d" % [tr(ComboManager.caption(run.streak)), ComboManager.multiplier(run.streak, GameManager.BALANCE)]
			if banner != tr("NEW_BEST") or banner_age >= 1.65:
				announce(line)
			if run.streak >= 2 or animation.change.lines >= 2:
				audio.effect("combo")
				particles.burst(animation.stamp_center, 7 if reduced else 23, animation.material, GILT, true, 1.05)
	if not animation.active and run.ended:
		overlay = "over"
		audio.effect("over")
		pointer_buttons.clear()
		clicked = ""

func burst_cut() -> void:
	var fx := ThemeCatalog.unlocked_choice(save, "effect", ThemeCatalog.EFFECTS, save.stat("lines"))
	var tint: Color = ThemeCatalog.EFFECTS[fx][2]
	for cell: Vector2i in animation.change.removed:
		var center := GRID.position + (Vector2(cell) + Vector2(0.5, 0.35)) * UNIT
		particles.burst(center, 2 if reduced else 5, animation.material, tint, false, 0.72)
		if fx > 0:
			particles.burst(center, 1 if reduced else 3, animation.material, tint, true, 0.74)

func announce(caption: String) -> void:
	banner = caption
	banner_age = 0.0

func ink(value: String, area: Rect2, size: int, color := WHITE, align := HORIZONTAL_ALIGNMENT_CENTER, bold := true) -> void:
	var typeface := heading if bold else font
	var pixels := size
	var measured := typeface.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, pixels).x
	if measured > area.size.x:
		pixels = maxi(16, int(float(size) * area.size.x / measured))
	var baseline := area.get_center().y + (typeface.get_ascent(pixels) - typeface.get_descent(pixels)) / 2.0
	draw_string(typeface, Vector2(area.position.x, baseline), value, align, area.size.x, pixels, color)

func panel(area: Rect2, color: Color, radius: int, edge := Color.TRANSPARENT, border := 2) -> void:
	art.panel(self, area, color, radius, edge, border)

func button(id: String, area: Rect2, caption: String, primary := false, small := false, locked := false) -> void:
	buttons[id] = area
	disabled[id] = locked
	var held := clicked == id
	var hover := hovered == id and not locked
	var y := 5.0 if held else 0.0
	var pressed := Rect2(area.position + Vector2(0, y), area.size)
	var fill := Color("#9954df") if primary else CARD
	var rim := Color("#dca9ff") if primary else CARD_EDGE
	var shade := Color("#60258f") if primary else Color("#1c0c29")
	if locked:
		fill = CARD.darkened(0.12)
	if hover:
		fill = fill.lightened(0.10)
	panel(Rect2(area.position + Vector2(0, 9), area.size), shade, 35)
	panel(pressed, fill, 35, rim, 3)
	if primary:
		panel(Rect2(pressed.position + Vector2(17, 11), Vector2(pressed.size.x - 34, pressed.size.y * 0.31)),
			Color(1.0, 0.91, 1.0, 0.11), 24)
	ink(caption, pressed.grow(-13), 32 if small else 43, MUTED if locked else WHITE)

func header(key: StringName) -> void:
	button("back", Rect2(55, 78, 157, 78), "‹  " + tr("BACK"), false, true)
	ink(tr(key), Rect2(223, 68, 802, 98), 57, WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	draw_line(Vector2(59, 187), Vector2(1021, 187), Color("#57346a"), 2.0, true)

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
		draw_rect(Rect2(Vector2.ZERO, DESIGN), Color(0.08, 0.037, 0.134, (1.0 - fade_age / 0.23) * 0.65))

func draw_game() -> void:
	var material := ThemeCatalog.active_material(run, save)
	var active_metal := ThemeCatalog.unlocked_choice(save, "metal", ThemeCatalog.CUTTERS, save.stat("cells"))
	var metal: Color = ThemeCatalog.CUTTERS[active_metal][2]
	var title := tr("TITLE_TOP") + " " + tr("TITLE_BOTTOM")
	ink(title, Rect2(64, 72, 629, 67), 38, WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	var mode := tr("DAILY") if run.mode == GameManager.DAILY else tr("ENDLESS")
	if run.used_continue:
		mode = tr("ASSISTED")
	ink(mode, Rect2(65, 139, 623, 43), 26, MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	button("pause", Rect2(915, 76, 97, 90), "")
	var guides := 5.0 if clicked == "pause" else 0.0
	panel(Rect2(948, 105 + guides, 10, 33), WHITE, 5)
	panel(Rect2(968, 105 + guides, 10, 33), WHITE, 5)

	panel(Rect2(61, 227, 958, 178), CARD, 38, CARD_EDGE, 2)
	draw_line(Vector2(634, 257), Vector2(634, 371), CARD_EDGE, 2.0, true)
	ink(tr("SCORE").to_upper(), Rect2(100, 246, 501, 38), 28, MUTED, HORIZONTAL_ALIGNMENT_LEFT)
	ink(group_int(roundi(score_face)), Rect2(96, 280, 506, 104), 82, WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	art.sparkle(self, Vector2(689, 294), 21, GILT)
	ink(tr("BEST").to_upper(), Rect2(729, 251, 260, 39), 27, SOFT, HORIZONTAL_ALIGNMENT_LEFT)
	ink(group_int(save.best(run.mode, run.day, run.used_continue)), Rect2(727, 291, 257, 76), 52, GILT, HORIZONTAL_ALIGNMENT_LEFT)

	board.render(self, art, run, GRID, material, animation, input, metal, over_age, reduced, workshop)
	ink(tr(DifficultyManager.RANKS[run.tier()]), Rect2(76, 420, 707, 35), 26, SOFT, HORIZONTAL_ALIGNMENT_LEFT)
	if run.streak > 0:
		ink("%s ×%d" % [tr("COMBO"), ComboManager.multiplier(run.streak, GameManager.BALANCE)],
			Rect2(768, 418, 231, 37), 27, GILT, HORIZONTAL_ALIGNMENT_RIGHT)
	if banner_age < 1.65:
		var opacity := 1.0 - smoothstep(1.30, 1.65, banner_age)
		var area := Rect2(246, 448 - sin(minf(banner_age * 3.5, PI)) * 12, 588, 62)
		panel(area, Color("#482658", opacity), 28, Color(GILT, opacity * 0.62), 2)
		ink(banner, area.grow(-12), 35, Color(GILT, opacity))
	panel(TRAY, CARD, 44, CARD_EDGE, 2)
	for slot in slots.size():
		draw_slot(slot, material, metal)
	ink(tr("DRAG_HINT") if run.cut_count < 4 else tr("CUTTERS"), Rect2(80, 1760, 920, 53), 32, WHITE)
	ink(tr("REFILL_HINT") if run.cut_count < 4 else "", Rect2(76, 1813, 928, 42), 24, SOFT, HORIZONTAL_ALIGNMENT_CENTER, false)
	draw_drag(metal)
	particles.render(self, art)
	if overlay != "":
		draw_overlay()

func draw_slot(slot: int, material: int, metal: Color) -> void:
	var area := slots[slot]
	var id: String = run.cutters.hand[slot]
	var empty := id == "" or slot == input.slot or slot == return_slot
	panel(area, Color("#1d0e2c") if empty else Color("#352049"), 29, Color("#492e5d"), 2)
	if empty:
		draw_line(area.get_center() - Vector2(18, 0), area.get_center() + Vector2(18, 0),
			Color("#633d77"), 4.0, true)
		return
	var form := run.cutters.shape(slot)
	var unit := preview_unit(form, 224, 129)
	var tone := Color(WHITE, 0.6) if run.ended else WHITE
	draw_form(form, id, area.get_center(), unit, material, Color(metal, tone.a), Color(tone, 0.56))

func preview_unit(form: Dictionary, width: float, height: float) -> float:
	var size: Vector2i = form.size
	return minf(width / size.x, height / size.y)

func draw_form(form: Dictionary, id: String, at: Vector2, unit: float, material: int, metal: Color, tint: Color) -> void:
	var start := at - Vector2(form.size) * unit / 2.0
	for cell: Vector2i in form.cells:
		art.cell(self, Rect2(start + Vector2(cell) * unit, Vector2.ONE * unit), material, 0, tint)
	art.cutter(self, id, at, unit, metal)

func draw_drag(metal: Color) -> void:
	if input.slot >= 0:
		var id := run.cutters.hand[input.slot]
		var form := run.cutters.shape(input.slot)
		var drag_center := input.position - Vector2(0, UNIT * (1.02 if input.touchscreen else 0.29))
		if input.touched_board:
			drag_center = GRID.position + (Vector2(input.anchor) + Vector2(form.size) / 2.0) * UNIT
		var tint := BoardView.VALID if input.valid else BoardView.INVALID
		art.cutter(self, id, drag_center, UNIT, metal.lerp(tint, 0.41) if input.touched_board else metal)
	elif return_slot >= 0 and return_age < 0.29:
		var id := run.cutters.hand[return_slot]
		var form := run.cutters.shape(return_slot)
		var amount := ease(clampf(return_age / 0.29, 0.0, 1.0), 0.29)
		var target := slots[return_slot].get_center()
		var unit := lerpf(UNIT, preview_unit(form, 224, 129), amount)
		art.cutter(self, id, return_from.lerp(target, amount), unit, metal)
	elif return_slot >= 0:
		return_slot = -1

func draw_overlay() -> void:
	buttons.clear()
	disabled.clear()
	draw_rect(Rect2(-DESIGN, DESIGN * 3), Color(0.09, 0.04, 0.13, 0.81))
	if overlay == "pause":
		panel(Rect2(115, 625, 850, 677), CARD, 57, CARD_EDGE.lightened(0.17), 3)
		ink(tr("PAUSED"), Rect2(172, 681, 736, 112), 76)
		button("resume_game", Rect2(189, 851, 702, 111), tr("RESUME"), true)
		button("home", Rect2(189, 1000, 702, 105), tr("HOME"))
		button("pause_settings", Rect2(189, 1142, 702, 96), tr("SETTINGS"))
		return
	var can_continue := run.can_continue()
	var modal := Rect2(94, 501 if can_continue else 597, 892, 924 if can_continue else 727)
	panel(modal, CARD, 57, CARD_EDGE.lightened(0.17), 3)
	var top := modal.position.y
	art.sparkle(self, Vector2(540, top + 68), 25.0, GILT, PI / 18)
	ink(tr("GAME_OVER"), Rect2(143, top + 112, 794, 104), 68)
	var score_area := Rect2(168, top + 242, 744, 176)
	panel(score_area, Color("#1e102e"), 35, CARD_EDGE)
	draw_line(Vector2(540, top + 269), Vector2(540, top + 390), CARD_EDGE, 2.0, true)
	ink(tr("SCORE"), Rect2(184, top + 266, 340, 47), 28, SOFT)
	ink(tr("BEST"), Rect2(555, top + 266, 340, 47), 28, SOFT)
	ink(group_int(run.score), Rect2(184, top + 313, 340, 78), 58)
	ink(group_int(save.best(run.mode, run.day, run.used_continue)), Rect2(555, top + 313, 340, 78), 58, GILT)
	button("again", Rect2(168, top + 460, 744, 111), tr("PLAY_AGAIN"), true)
	button("home", Rect2(168, top + 605, 744, 90), tr("HOME"))
	if can_continue:
		button("continue", Rect2(168, top + 728, 744, 97), tr("CONTINUE"))
		ink(tr("ASSISTED_NOTE"), Rect2(166, top + 838, 748, 57), 25, SOFT, HORIZONTAL_ALIGNMENT_CENTER, false)

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
		clicked = ""
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
		clicked = target
		queue_redraw()
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
		clicked = ""
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
		return_slot = slot
		return_age = 0.0
		audio.effect("stretch", -8.0)
	queue_redraw()

func cancel_pointer(id: int) -> void:
	if input.pointer == id:
		input.cancel()
	pointer_buttons.erase(id)
	clicked = ""
	queue_redraw()

func cut(slot: int, anchor: Vector2i) -> void:
	var id := run.cutters.hand[slot]
	var material := ThemeCatalog.active_material(run, save)
	var change := run.play(slot, anchor)
	if change.is_empty():
		return
	var changed_best := save.update_move(run, change.removed.size(), change.lines)
	var center := GRID.position + (Vector2(anchor) + Vector2(change.form.size) / 2.0) * UNIT
	animation.start(change, id, center, UNIT, material)
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
		particles.burst(center, 18 if reduced else 45, material, GILT, true, 1.18)

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
		"continue":
			if run.continue_run():
				best_celebrated = false
				overlay = ""
				over_age = 0.0
				save.store_run(run)
				announce(tr("ASSISTED"))
				audio.effect("refill")
		_:
			pages.activate(self, id)
	queue_redraw()
