extends SceneTree

const MAIN := preload("res://scenes/main.tscn")
const TEST_SAVE := "user://clay_factory_test.cfg"

var failures: Array[String] = []
var probes := 0

func _initialize() -> void:
	call_deferred("run_tests")

func check(condition: bool, message: String) -> void:
	probes += 1
	if not condition:
		failures.append(message)
		push_error(message)

func run_tests() -> void:
	reset_save()
	test_board()
	test_moves()
	test_save()
	test_locales()
	await test_interface()
	reset_save()
	if failures.is_empty():
		print("PASS: %d checks across rules, persistence, localization, and mouse/touch UI." % probes)
		quit(0)
	else:
		print("FAIL: %d of %d checks." % [failures.size(), probes])
		quit(1)

func reset_save() -> void:
	for extension in ["", ".tmp", ".bak"]:
		var path: String = TEST_SAVE + extension
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func test_board() -> void:
	var board := BoardManager.new()
	var shapes := ShapeGenerator.new().shapes
	var art := ClayArt.new()
	check(shapes.size() >= 30, "Cutter catalog size")
	check(shapes.size() == art.regions.size(), "Every cutter has an atlas region")
	for id: String in shapes:
		var form: Dictionary = shapes[id]
		board.reset()
		var corner := Vector2i(BoardManager.SIZE, BoardManager.SIZE) - Vector2i(form.size)
		check(board.can_cut(form.cells, corner), "Bottom/right edge %s" % id)
		check(not board.can_cut(form.cells, corner + Vector2i(1, 0)), "Outside right edge %s" % id)
		check(not board.can_cut(form.cells, Vector2i(0, -1)), "Outside top edge %s" % id)
		check(not board.cut(form.cells, corner).is_empty(), "Cut %s" % id)
		check(not board.can_cut(form.cells, corner), "Reject holes %s" % id)
	var center := Vector2i(3, 3)
	board.reset()
	for n in BoardManager.SIZE:
		board.cells[board.index(Vector2i(n, center.y))] = 0
		board.cells[board.index(Vector2i(center.x, n))] = 0
	board.cells[board.index(center)] = 1
	var cross := board.cut([Vector2i.ZERO], center)
	check(cross.rows == [3] and cross.columns == [3], "Row and column detected using same board state")
	check(cross.refill.size() == 15 and board.cells.count(1) == 64, "Intersection refilled exactly once")
	board.cells.fill(0)
	board.cells[board.index(center)] = 1
	var full := board.cut([Vector2i.ZERO], center)
	check(full.full and full.refill.size() == 64, "Full board detected before the refill")
	board.cells.fill(0)
	var stitch: Dictionary = shapes.stitch_0
	for cell: Vector2i in stitch.cells:
		board.cells[board.index(cell)] = 1
	check(board.cut(stitch.cells, Vector2i.ZERO).full, "Rare cutter can earn the full-board bonus")

func test_moves() -> void:
	var a := GameManager.new()
	var b := GameManager.new()
	var date := "2026-11-25"
	a.start(GameManager.DAILY, date, LeaderboardProvider.daily_seed(date))
	b.start(GameManager.DAILY, date, LeaderboardProvider.daily_seed(date))
	check(a.cutters.hand == b.cutters.hand, "Daily seed is deterministic")
	check(LeaderboardProvider.category(a) == "daily/2026-11-25", "Daily leaderboard category")
	check(ScoreManager.points(1, 2, 3, false, GameManager.BALANCE) == 910, "Multiplier applies to line bonus only")
	check(ScoreManager.points(2, 5, 1, false, GameManager.BALANCE) == 1820, "Scaled bonus after four lines")
	check(ScoreManager.points(1, 0, 0, true, GameManager.BALANCE) == 5010, "Full board bonus")
	check(ComboManager.multiplier(13, GameManager.BALANCE) == 10, "Combo cap")
	check(DifficultyManager.tier(4999, GameManager.BALANCE) == 0, "Tier before boundary")
	check(DifficultyManager.tier(5000, GameManager.BALANCE) == 1, "Tier at boundary")
	check(DifficultyManager.tier(100000, GameManager.BALANCE) == 4, "Final tier")
	a.cutters.hand.assign(["single_0", "single_0", "single_0"])
	for y in 2:
		for x in range(1, 8):
			a.board.cells[a.board.index(Vector2i(x, y))] = 0
	check(a.play(0, Vector2i.ZERO).points == 110, "First line score")
	check(a.play(1, Vector2i(0, 1)).points == 210 and a.streak == 2, "Consecutive row doubles bonus")
	check(a.play(2, Vector2i(4, 4)).points == 10 and a.streak == 0, "Move without lines resets streak")
	check(a.cutters.hand.count("") == 0, "New hand after three cuts")
	a.board.reset()
	a.cutters.hand.assign(["single_0", "domino_0", "corner_0"])
	for y in BoardManager.SIZE:
		for x in BoardManager.SIZE:
			a.board.cells[a.board.index(Vector2i(x, y))] = int((x + y) % 2 == 0)
	check(not a.play(0, Vector2i(1, 1)).is_empty() and a.ended, "No move detection with remaining cutters")
	check(a.play(1, Vector2i.ZERO).is_empty(), "Ended run rejects further moves")
	check(not a.continue_run(), "Daily mode excludes assisted scores")
	a.mode = GameManager.ENDLESS
	check(a.continue_run() and not a.ended and a.board.cells.count(1) == 64, "Single assisted continue")
	check(LeaderboardProvider.category(a) == "assisted" and not a.can_continue(), "Assisted separation")
	for y in BoardManager.SIZE:
		for x in BoardManager.SIZE:
			a.board.cells[a.board.index(Vector2i(x, y))] = int((x + y) % 2 == 0)
	for i in 120:
		var hand := a.cutters.generator.draw_hand(a.board, i % 5)
		check(a.cutters.generator.has_move(a.board, hand), "Fairness when only isolated cells remain")

func test_save() -> void:
	var storage := SaveManager.new(TEST_SAVE)
	var run := GameManager.new()
	run.start(GameManager.ENDLESS, "", 1234)
	run.cutters.hand.assign(["single_0", "single_0", "single_0"])
	var result := run.play(0, Vector2i(1, 1))
	storage.update_move(run, result.removed.size(), result.lines)
	storage.set_setting("language", "uk")
	storage.set_setting("music", false)
	var reopened := SaveManager.new(TEST_SAVE)
	var restored := reopened.get_run(GameManager.ENDLESS, "")
	check(restored != null, "Interrupted run reopens from disk")
	if restored != null:
		check(restored.snapshot() == run.snapshot(), "Board, score, hand, RNG, mode, and counters match")
		check(restored.play(1, Vector2i.ZERO) == run.play(1, Vector2i.ZERO), "Saved hand resumes")
		check(restored.play(2, Vector2i(7, 0)) == run.play(2, Vector2i(7, 0)), "Saved RNG deals identical next hand")
		check(restored.cutters.hand == run.cutters.hand, "Next hand remains deterministic")
	check(reopened.setting("language", "") == "uk" and not reopened.setting("music", true), "Settings persist")
	check(reopened.best() == 10 and reopened.stat("cells") == 1, "Best score and cut statistics persist")
	run.ended = true
	storage.record(run)
	storage.record(run)
	check(storage.stat("games") == 1 and storage.history().size() == 1, "Result is recorded only once")
	check(run.continue_run(), "Assisted run starts after result")
	run.score = 1000
	storage.update_move(run, 0, 0)
	check(storage.best() == 10 and storage.best(GameManager.ENDLESS, "", true) == 1000, "Assisted record isolation")
	run.ended = true
	storage.record(run)
	check(storage.stat("games") == 1 and storage.history()[0].assisted, "Assisted result is logged without counting a second game")
	var daily := GameManager.new()
	daily.start(GameManager.DAILY, "2026-11-25", 1)
	storage.store_run(daily)
	check(storage.get_run(GameManager.DAILY, "2026-11-26") == null, "Stale daily run expires")
	check(storage.get_run(GameManager.ENDLESS, "") != null, "Daily run does not replace endless slot")

func test_locales() -> void:
	var names := ["Play", "Грати", "Graj", "Spielen", "Jugar", "Jouer"]
	for index in names.size():
		LocalizationManager.apply(LocalizationManager.LANGUAGES[index + 1])
		check(TranslationServer.translate("PLAY") == names[index], "Locale asset %d" % index)

func test_interface() -> void:
	var app: Factory = MAIN.instantiate()
	app.save = SaveManager.new(TEST_SAVE)
	app.save.clear_run(GameManager.ENDLESS)
	app.save.set_setting("language", "en")
	root.add_child(app)
	await process_frame
	await process_frame

	for size in [Vector2i(540, 960), Vector2i(450, 1030), Vector2i(760, 920)]:
		if DisplayServer.get_name() != "headless":
			root.size = size
			await process_frame
		var center := app.view_origin + Factory.DESIGN * app.view_scale / 2
		check(app.virtual(center).is_equal_approx(Factory.DESIGN / 2), "Viewport coordinate scaling %s" % size)

	await click(app, Vector2(540, 1267))
	check(app.view == "game" and app.run != null, "Play button opens gameplay")
	if app.run == null:
		app.queue_free()
		return
	app.run.cutters.hand.assign(["single_0", "single_0", "single_0"])
	var left := app.slots[0].get_center()
	var first := Factory.GRID.position + Vector2(0.5, 0.5) * Factory.UNIT
	await drag_mouse(app, left, first - Vector2(Factory.UNIT, -Factory.UNIT * 0.29))
	check(app.run.score == 0 and app.return_slot == 0, "Off-board drop returns without scoring")
	await drag_mouse(app, left, first + Vector2(0, Factory.UNIT * 0.29))
	check(app.run.score == 10 and app.animation.active, "Mouse drag cuts then locks")
	await drag_mouse(app, app.slots[1].get_center(), first + Vector2(Factory.UNIT, Factory.UNIT * 0.29))
	check(app.run.score == 10 and app.run.cutters.hand[1] == "single_0", "Repeated drag during animation cannot double cut")
	await create_timer(0.57).timeout
	await drag_mouse(app, app.slots[1].get_center(), first + Vector2(0, Factory.UNIT * 0.29))
	check(app.run.score == 10, "Dropping over hole is rejected by the interface")
	await drag_touch(app, app.slots[1].get_center(), first + Vector2(Factory.UNIT, Factory.UNIT * 1.02))
	check(app.run.score == 20 and not app.run.board.filled(Vector2i(1, 0)), "Touch drag accounts for lift")
	await create_timer(0.57).timeout
	await click(app, Vector2(960, 122))
	check(app.overlay == "pause", "Pause modal opens")
	await click(app, Vector2(540, 1053))
	check(app.view == "menu", "Home from pause")
	await click(app, Vector2(540, 1267))
	check(app.run.score == 20 and app.run.cutters.hand.count("") == 2, "Resume button restores the saved cut")
	app.run.cutters.hand.assign(["single_0", "domino_0", "corner_0"])
	app.run.board.cells.fill(0)
	for i in BoardManager.SIZE:
		app.run.board.cells[app.run.board.index(Vector2i(i, i))] = 1
	app.run.board.cells[app.run.board.index(Vector2i(0, 7))] = 1
	app.run.board.cells[app.run.board.index(Vector2i(7, 0))] = 1
	await drag_mouse(app, left, first + Vector2(0, Factory.UNIT * 0.29))
	await create_timer(0.81).timeout
	check(app.run.line_count == 0 and app.overlay == "over", "Results appear when all remaining cutters are blocked")
	await click(app, Vector2(540, 1276))
	check(app.run.used_continue and app.overlay == "" and app.run.board.cells.count(1) == 64, "One-time offline continue works through the modal")
	app.open("collection")
	await process_frame
	await click(app, Vector2(403, 265))
	check(app.collection_tab == 1, "Collection cutter tab")
	app.open("records")
	await process_frame
	app.open("settings")
	await process_frame
	await click(app, Vector2(770, 320))
	check(app.save.setting("music", false), "Settings toggle via main input route")
	app.queue_free()
	await process_frame

func click(app: Factory, position: Vector2) -> void:
	mouse_button(app, position, true)
	mouse_button(app, position, false)
	await process_frame
	await process_frame

func drag_mouse(app: Factory, from: Vector2, to: Vector2) -> void:
	mouse_button(app, from, true)
	var motion := InputEventMouseMotion.new()
	motion.position = screen(app, to)
	root.push_input(motion, true)
	mouse_button(app, to, false)
	await process_frame

func drag_touch(app: Factory, from: Vector2, to: Vector2) -> void:
	var down := InputEventScreenTouch.new()
	down.index = 2
	down.pressed = true
	down.position = screen(app, from)
	root.push_input(down, true)
	var motion := InputEventScreenDrag.new()
	motion.index = 2
	motion.position = screen(app, to)
	root.push_input(motion, true)
	var up := InputEventScreenTouch.new()
	up.index = 2
	up.position = screen(app, to)
	root.push_input(up, true)
	await process_frame

func mouse_button(app: Factory, at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = screen(app, at)
	event.pressed = pressed
	root.push_input(event, true)

func screen(app: Factory, at: Vector2) -> Vector2:
	return app.view_origin + at * app.view_scale
