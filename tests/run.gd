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
	test_delayed_refills()
	test_save()
	test_legacy_save()
	test_locales()
	test_visual_palette()
	test_cut_prediction()
	test_orders()
	await test_interface()
	reset_save()
	if failures.is_empty():
		print("PASS: %d checks across rules, persistence, localization, and mouse/touch UI." % probes)
		quit(0)
	else:
		print("FAIL: %d of %d checks." % [failures.size(), probes])
		quit(1)

func reset_save() -> void:
	for extension in ["", ".tmp", ".bak", ".v1", ".v1.tmp", ".v1.bak"]:
		var path: String = TEST_SAVE + extension
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func test_board() -> void:
	var board := BoardManager.new()
	var shapes := ShapeGenerator.new().shapes
	var art := ClayArt.new()
	check(BoardManager.COUNT == 49, "7 × 7 board")
	check(shapes.size() == 161 and shapes.has("pocket_0") and shapes.has("ladder_0"), "Expanded cutter catalog")
	check(shapes.size() == art.regions.size(), "Every cutter has an atlas region")
	var atlas := Rect2(Vector2.ZERO, ClayArt.CUTTERS.get_size())
	for id: String in shapes:
		var form: Dictionary = shapes[id]
		var region: Array = art.regions.get(id, [])
		check(region.size() == 5 and atlas.encloses(Rect2(region[0], region[1], region[2], region[3])),
			"Cutter sprite is within the atlas #%s" % id)
		board.reset()
		var corner := Vector2i(BoardManager.SIZE, BoardManager.SIZE) - Vector2i(form.size)
		check(board.can_cut(form.cells, corner), "Bottom/right edge %s" % id)
		check(not board.can_cut(form.cells, corner + Vector2i(1, 0)), "Outside right edge %s" % id)
		check(not board.can_cut(form.cells, Vector2i(0, -1)), "Outside top edge %s" % id)
		check(not board.cut(form.cells, corner).is_empty(), "Cut %s" % id)
		check(not board.can_cut(form.cells, corner), "Reject holes %s" % id)
	board.reset()
	var ladder: Dictionary = shapes.ladder_0
	var empty_center := Vector2i(1, 1)
	board.cells[board.index(empty_center)] = 0
	check(board.can_cut(ladder.cells, Vector2i.ZERO) and board.cut(ladder.cells, Vector2i.ZERO).removed.size() == 10,
		"An open-center cutter can go around an existing cavity")
	var center := Vector2i(3, 3)
	board.reset()
	for n in BoardManager.SIZE:
		board.cells[board.index(Vector2i(n, center.y))] = 0
		board.cells[board.index(Vector2i(center.x, n))] = 0
	board.cells[board.index(center)] = 1
	var cross := board.cut([Vector2i.ZERO], center)
	check(cross.completed == [3, BoardManager.SIZE + 3], "Row and column detected using same board state")
	var queued := board.advance(cross.completed, 3)
	check(queued.refill.is_empty() and board.soonest() == 3 and not board.filled(center), "Detection does not refill on the same move")
	check(board.advance([], 3).refill.is_empty() and board.soonest() == 2, "The first later move ticks both lines")
	check(board.advance([], 3).refill.is_empty() and board.soonest() == 1, "The second move leaves one tick")
	var restored := board.advance([], 3)
	check(restored.refilled == cross.completed and not board.has_pending(), "Both lines mature together")
	check(restored.refill.size() == BoardManager.SIZE * 2 - 1 and board.cells.count(1) == BoardManager.COUNT, "Intersection refilled exactly once")
	board.cells.fill(0)
	board.cells[board.index(center)] = 1
	var full := board.cut([Vector2i.ZERO], center)
	check(full.full and full.completed.size() == BoardManager.LINE_COUNT, "Full board detected before the refill")
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
		for x in range(1, BoardManager.SIZE):
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
	for y in BoardManager.SIZE:
		for x in BoardManager.SIZE:
			a.board.cells[a.board.index(Vector2i(x, y))] = int((x + y) % 2 == 0)
	for i in 120:
		var hand := a.cutters.generator.draw_hand(a.board, i % 5)
		check(a.cutters.generator.has_move(a.board, hand), "Fairness when only isolated cells remain")

func test_delayed_refills() -> void:
	var balance := GameManager.BALANCE
	for sample: Array in [[0, 3], [1499, 3], [1500, 2], [5999, 2], [6000, 1], [100000, 1]]:
		check(balance.refill_delay(sample[0]) == sample[1], "Delay at score %s" % sample[0])

	var run := GameManager.new()
	run.start(GameManager.ENDLESS, "", 124)
	run.score = 1390
	run.cutters.hand.assign(["single_0", "single_0", "single_0"])
	for x in range(1, BoardManager.SIZE):
		run.board.cells[run.board.index(Vector2i(x, 0))] = 0
	var clear := run.play(0, Vector2i.ZERO)
	check(clear.refilled.is_empty() and run.board.soonest() == 2 and run.score == 1500, "Delay uses the score awarded by the clearing move")
	check(run.play(1, Vector2i.ZERO).is_empty() and run.board.soonest() == 2, "Invalid move preserves the countdown")
	check(run.play(1, Vector2i(0, 1)).refilled.is_empty() and run.board.soonest() == 1, "Later cut spends one turn")
	check(run.play(2, Vector2i(0, 2)).refilled == [0] and run.board.filled(Vector2i.ZERO), "The due line refills during the second later cut")
	check(run.score == 1520 and run.line_count == 1, "Refill does not double-credit its line")

	run.board.reset()
	run.cutters.hand.assign(["single_0", "single_0", "single_0"])
	run.score = 5890
	for x in range(1, BoardManager.SIZE):
		run.board.cells[run.board.index(Vector2i(x, 0))] = 0
	check(run.play(0, Vector2i.ZERO).refill.is_empty() and run.board.soonest() == 1, "Fastest tier still keeps the line empty on its cut")
	check(run.play(1, Vector2i(1, 1)).refilled == [0], "Fastest tier refills on the next successful cut")

	var grid := BoardManager.new()
	for n in BoardManager.SIZE:
		grid.cells[grid.index(Vector2i(0, n))] = 0
		grid.cells[grid.index(Vector2i(n, 0))] = 0
	grid.pending[0] = 3
	grid.pending[BoardManager.SIZE] = 1
	grid.advance([], 3)
	check(grid.filled(Vector2i.ZERO) and grid.pending[0] == 2, "Crossing refill keeps the later row scheduled")
	var recut := grid.cut([Vector2i.ZERO], Vector2i.ZERO)
	check(recut.completed.is_empty(), "Re-cutting an intersection does not credit a queued line again")

	var blocked := GameManager.new()
	blocked.start(GameManager.ENDLESS, "", 125)
	set_blocked_fixture(blocked)
	blocked.play(0, Vector2i.ZERO)
	check(blocked.ended and blocked.board.soonest() == 3, "A blocked board loses even with a queued refill")
	check(blocked.play(1, Vector2i.ZERO).is_empty() and blocked.board.soonest() == 3, "A completed game cannot spend another turn")
	var saved := blocked.snapshot()
	saved.ended = false
	var reopened := GameManager.new()
	check(reopened.restore(saved) and reopened.ended and reopened.board.soonest() == 3,
		"An older run saved while blocked opens to the result")

	var due := GameManager.new()
	due.start(GameManager.ENDLESS, "", 126)
	set_blocked_fixture(due)
	due.board.pending[1] = 1
	check(due.play(0, Vector2i.ZERO).refilled == [1] and not due.ended, "A line due this turn can provide another move")

func set_blocked_fixture(run: GameManager) -> void:
	run.cutters.hand.assign(["single_0", "domino_0", "corner_0"])
	run.board.reset()
	run.board.cells.fill(0)
	for i in BoardManager.SIZE:
		run.board.cells[run.board.index(Vector2i(i, i))] = 1

func test_save() -> void:
	var storage := SaveManager.new(TEST_SAVE)
	var run := GameManager.new()
	run.start(GameManager.ENDLESS, "", 1234)
	run.cutters.hand.assign(["single_0", "single_0", "single_0"])
	run.board.pending[0] = 3
	for x in BoardManager.SIZE:
		run.board.cells[run.board.index(Vector2i(x, 0))] = 0
	var result := run.play(0, Vector2i(1, 1))
	storage.update_move(run, result.removed.size(), result.lines)
	storage.set_setting("language", "uk")
	storage.set_setting("music", false)
	var reopened := SaveManager.new(TEST_SAVE)
	var restored := reopened.get_run(GameManager.ENDLESS, "")
	check(restored != null, "Interrupted run reopens from disk")
	if restored != null:
		check(restored.snapshot() == run.snapshot(), "Board, score, hand, RNG, mode, and counters match")
		check(restored.play(1, Vector2i(2, 1)) == run.play(1, Vector2i(2, 1)), "Saved hand resumes")
		check(restored.play(2, Vector2i(BoardManager.SIZE - 1, 1)) == run.play(2, Vector2i(BoardManager.SIZE - 1, 1)), "Saved RNG deals identical next hand")
		check(restored.cutters.hand == run.cutters.hand, "Next hand remains deterministic")
	check(reopened.setting("language", "") == "uk" and not reopened.setting("music", true), "Settings persist")
	check(reopened.best() == 10 and reopened.stat("cells") == 1, "Best score and cut statistics persist")
	run.ended = true
	storage.record(run)
	storage.record(run)
	check(storage.stat("games") == 1 and storage.history().size() == 1, "Result is recorded only once")
	var previous_assisted := run.snapshot()
	previous_assisted.used_continue = true
	previous_assisted.recorded = false
	previous_assisted.score = 1000
	var assisted := GameManager.new()
	check(assisted.restore(previous_assisted), "Older assisted runs retain their category")
	storage.update_move(assisted, 0, 0)
	check(storage.best() == 10 and storage.best(GameManager.ENDLESS, "", true) == 1000, "Assisted record isolation")
	check(storage.stat("games") == 1 and storage.history()[0].assisted, "Assisted result is logged without counting a second game")
	var daily := GameManager.new()
	daily.start(GameManager.DAILY, "2026-11-25", 1)
	storage.store_run(daily)
	check(storage.get_run(GameManager.DAILY, "2026-11-26") == null, "Stale daily run expires")
	check(storage.get_run(GameManager.ENDLESS, "") != null, "Daily run does not replace endless slot")

func test_legacy_save() -> void:
	var path := TEST_SAVE + ".v1"
	var config := ConfigFile.new()
	var legacy_run := GameManager.new()
	legacy_run.start(GameManager.ENDLESS, "", 1239)
	var snapshot := legacy_run.snapshot()
	var old_size := GameManager.LEGACY_SIZE
	var cells := PackedByteArray()
	cells.resize(old_size * old_size)
	cells.fill(1)
	for x in BoardManager.SIZE:
		cells[x] = 0
	cells[4 * old_size + 5] = 0
	snapshot.cells = cells
	snapshot.score = 1800
	snapshot.erase("pending")
	config.set_value("format", "version", 1)
	config.set_value("runs", GameManager.ENDLESS, snapshot)
	config.set_value("best", GameManager.ENDLESS, 1950)
	config.set_value("settings", "music", false)
	check(config.save(path) == OK, "Legacy fixture written")
	var storage := SaveManager.new(path)
	var run := storage.get_run(GameManager.ENDLESS, "")
	check(run != null and storage.best() == 1950 and not storage.setting("music", true), "Existing settings and records preserved")
	if run == null:
		return
	check(run.board.cells.size() == BoardManager.COUNT and run.score == 1800, "Existing 8 × 8 run resumes on 7 × 7")
	check(not run.board.filled(Vector2i(5, 4)) and run.board.pending[0] == 2, "Migration keeps the top-left cells and queues the newly empty line")
	storage.store_run(run)
	var migrated := SaveManager.new(path)
	check(migrated.get_run(GameManager.ENDLESS, "").snapshot() == run.snapshot(), "Migrated run saves the queue in the new version")

func test_locales() -> void:
	var names := ["Play", "Грати", "Graj", "Spielen", "Jugar", "Jouer"]
	for index in names.size():
		LocalizationManager.apply(LocalizationManager.LANGUAGES[index + 1])
		check(TranslationServer.translate("PLAY") == names[index], "Locale asset %d" % index)

func test_visual_palette() -> void:
	var run := GameManager.new()
	var storage := SaveManager.new(TEST_SAVE)
	storage.data.set_value("settings", "material", -1)
	var studio_count := floori(float(ClayArt.STUDIO.get_height()) / ClayArt.TILE)
	var warm := ThemeCatalog.slab_style(run, storage)
	var palette := ThemeCatalog.active_palette(run, storage)
	for material: int in palette:
		check(material >= 0 and material < ThemeCatalog.STUDIO_START + studio_count, "Crumb palette has an atlas row")
	run.mode = GameManager.DAILY
	var cool := ThemeCatalog.slab_style(run, storage)
	check(cool != warm and ThemeCatalog.active_palette(run, storage) != palette, "Daily challenge uses cool clay")
	var art := SlabArt.new()
	var extent := Rect2(Vector2.ZERO, SlabArt.SHEET.get_size())
	check(extent.encloses(art.material_rect(warm)) and extent.encloses(art.material_rect(cool)), "Both slabs are present in the atlas")
	var full := BoardManager.new()
	check(SlabArt.exposed(full, full.cells, Vector2i(3, 3)) == 0, "Interior clay has no exposed seams")
	check(SlabArt.exposed(full, full.cells, Vector2i.ZERO) == 9, "Outside corners expose two edges")
	full.cells[full.index(Vector2i(3, 2))] = 0
	check(SlabArt.exposed(full, full.cells, Vector2i(3, 3)) == 1, "Removing a cell reveals the neighboring clay edge")
	storage.data.set_value("settings", "material", 0)
	check(ThemeCatalog.slab_style(run, storage) == 0 and ThemeCatalog.active_palette(run, storage) == [0],
		"Chosen material applies to the slab and crumbs")

func test_cut_prediction() -> void:
	var run := GameManager.new()
	run.start(GameManager.ENDLESS, "", 135)
	run.cutters.hand.assign(["single_0", "domino_0", "corner_0"])
	var hint := run.first_move_hint()
	check(hint.slot == 0 and run.board.can_cut(hint.cells, hint.origin), "First move highlights a valid footprint")
	for i in range(1, BoardManager.SIZE):
		run.board.cells[run.board.index(Vector2i(i, 0))] = 0
		run.board.cells[run.board.index(Vector2i(0, i))] = 0
	run.streak = 2
	var before := run.snapshot()
	var projection := run.preview_move(0, Vector2i.ZERO)
	check(projection.completed == [0, BoardManager.SIZE] and projection.points > 10, "Projected cut includes both lines and combo points")
	check(run.preview_move(0, Vector2i(-1, 0)).is_empty() and run.preview_move(0, Vector2i(1, 0)).is_empty(),
		"Invalid targets never receive a projection")
	check(run.snapshot() == before, "Preview does not spend moves or mutate saved state")
	var cut := run.play(0, Vector2i.ZERO)
	check(cut.points == projection.points and cut.completed == projection.completed, "Actual score matches the preview")
	check(run.first_move_hint().is_empty() and run.board.soonest() == 3, "Tutorial retires and the lines enter the normal queue")

func test_orders() -> void:
	var run := GameManager.new()
	run.start(GameManager.ENDLESS, "", 151)
	run.cutters.hand.assign(["single_0", "single_0", "single_0"])
	run.order.cells.assign([Vector2i(1, 1), Vector2i(2, 1)])
	var first := run.play(0, Vector2i(1, 1))
	check(first.order.bonus == 0 and run.order.remaining(run.board) == 1, "The marked contour can span two cuts")
	var snapshot := run.snapshot()
	var forecast := run.preview_move(1, Vector2i(2, 1))
	check(forecast.order.clean and forecast.order.bonus == GameManager.BALANCE.clean_order_points,
		"Forecast includes the precision bonus")
	check(run.snapshot() == snapshot, "Order preview leaves the game untouched")
	var restored := GameManager.new()
	check(restored.restore(snapshot) and restored.order.snapshot() == run.order.snapshot(), "Active order resumes from saved data")
	check(restored.play(1, Vector2i(2, 1)).points == forecast.points and restored.order.completed == 1,
		"Completing the restored order awards the forecast points once")

	var mixed := GameManager.new()
	mixed.start(GameManager.ENDLESS, "", 152)
	mixed.cutters.hand.assign(["domino_0", "single_0", "corner_0"])
	mixed.order.cells.assign([Vector2i(2, 2), Vector2i(2, 3)])
	mixed.play(0, Vector2i(2, 2))
	check(not mixed.order.clean and mixed.order.remaining(mixed.board) == 1, "Cutting over the edge forfeits the precision bonus")
	var finish := mixed.play(1, Vector2i(2, 3))
	check(finish.order.bonus == GameManager.BALANCE.order_points and mixed.order.completed == 1,
		"A mixed cut can still complete the order for the standard bonus")
	check(not mixed.order.cells.is_empty() and mixed.order.clean, "The next order starts with its own precision bonus")

	var generated := CutOrder.new()
	generated.completed = 1
	var board := BoardManager.new()
	var cutters := CutterManager.new()
	cutters.hand.assign(["corner_0", "domino_0", "single_0"])
	generated.issue(board, cutters)
	check(generated.cells.size() > 2 and generated.remaining(board) == generated.cells.size(),
		"Later orders can combine available cutters into one contour")
	var old_snapshot := run.snapshot()
	old_snapshot.erase("order")
	check(restored.restore(old_snapshot) and restored.order.cells.is_empty(), "Older saves can start issuing orders normally")


func test_interface() -> void:
	var app: Factory = MAIN.instantiate()
	app.save = SaveManager.new(TEST_SAVE)
	app.save.clear_run(GameManager.ENDLESS)
	app.save.set_setting("language", "en")
	app.save.data.set_value("stats", "cells", 150)
	root.add_child(app)
	await process_frame
	await process_frame

	for size in [Vector2i(540, 960), Vector2i(450, 1030), Vector2i(760, 920)]:
		if DisplayServer.get_name() != "headless":
			root.size = size
			await process_frame
		var center := app.view_origin + Factory.DESIGN * app.view_scale / 2
		check(app.virtual(center).is_equal_approx(Factory.DESIGN / 2), "Viewport coordinate scaling %s" % size)

	await click_button(app, "play")
	check(app.view == "game" and app.run != null, "Play button opens gameplay")
	if app.run == null:
		app.queue_free()
		return
	app.run.cutters.hand.assign(["single_0", "single_0", "single_0"])
	var left := app.slots[0].get_center()
	var first := Factory.GRID.position + Vector2(0.5, 0.5) * Factory.UNIT
	app.queue_redraw()
	await create_timer(0.35).timeout
	var pixel := left - Vector2(15, 20)
	var visible_before := await slot_pixel(app, pixel)
	await drag_mouse(app, left, first - Vector2(Factory.UNIT, -Factory.UNIT * 0.29))
	check(app.run.score == 0 and app.return_slot == 0, "Off-board drop returns without scoring")
	await create_timer(Factory.RETURN_DURATION + 0.15).timeout
	check(app.return_slot == -1 and app.run.cutters.hand[0] == "single_0", "Failed drop returns the original cutter")
	if DisplayServer.get_name() != "headless":
		var visible_after := await slot_pixel(app, pixel)
		check(visible_before.r > visible_before.g + 0.12,
			"The rendered sample is the colored cutter rather than its empty slot")
		check(visible_before.is_equal_approx(visible_after), "Returned cutter is drawn in its slot after the UI becomes idle")
	await drag_touch(app, app.slots[2].get_center(), Vector2(1018, 1768))
	await create_timer(Factory.RETURN_DURATION + 0.12).timeout
	check(app.return_slot == -1 and app.run.cutters.hand[2] == "single_0", "Touch drop below the board also returns its cutter")
	mouse_button(app, left, true)
	app.pointer_move(InputManager.MOUSE, first + Vector2(0, Factory.UNIT * 0.29))
	check(app.input.forecast.get("points") == 10 and app.run.score == 0, "Held cutter shows points without scoring")
	mouse_button(app, first + Vector2(0, Factory.UNIT * 0.29), false)
	await process_frame
	check(app.run.score == 10 and app.animation.active and app.input.forecast.is_empty(), "Mouse drag cuts and clears the forecast")
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
	await click_button(app, "play")
	check(app.run.score == 20 and app.run.cutters.hand.count("") == 2, "Resume button restores the saved cut")
	app.run.cutters.hand.assign(["single_0", "domino_0", "corner_0"])
	app.run.board.cells.fill(0)
	for i in BoardManager.SIZE:
		app.run.board.cells[app.run.board.index(Vector2i(i, i))] = 1
	app.run.board.cells[app.run.board.index(Vector2i(0, BoardManager.SIZE - 1))] = 1
	app.run.board.cells[app.run.board.index(Vector2i(BoardManager.SIZE - 1, 0))] = 1
	await drag_mouse(app, left, first + Vector2(0, Factory.UNIT * 0.29))
	await create_timer(0.81).timeout
	check(app.run.line_count == 0 and app.overlay == "over", "Results appear when all remaining cutters are blocked")
	await click_button(app, "again")
	check(not app.run.ended and app.overlay == "" and app.run.board.cells.count(1) == BoardManager.COUNT
		and app.run.score == 0, "Play again starts a fresh game from the result")
	set_blocked_fixture(app.run)
	await drag_mouse(app, left, first + Vector2(0, Factory.UNIT * 0.29))
	await create_timer(0.66).timeout
	check(app.run.ended and app.overlay == "over" and app.run.board.soonest() == 3,
		"A queued refill still leaves the player at game over")
	check(app.buttons.size() == 2 and app.buttons.has("again") and app.buttons.has("home"), "Only restart and home are available after losing")
	app.open("collection")
	await process_frame
	await click(app, Vector2(403, 265))
	check(app.collection_tab == 1, "Collection cutter tab")
	await click_button(app, "tab_3")
	await click_button(app, "option_1")
	check(app.pages.preview_index == 1 and app.save.setting("effect", 0) == 0, "Locked effect can be previewed")
	app.save.data.set_value("stats", "lines", 16)
	await click_button(app, "option_1")
	check(app.save.setting("effect", 0) == 1, "Unlocked effect can be applied")
	app.open("records")
	await process_frame
	app.open("settings")
	await process_frame
	await click(app, Vector2(770, 320))
	check(app.save.setting("music", false), "Settings toggle via main input route")
	app.start(GameManager.DAILY, false)
	app.run.score = 714
	var daily := app.daily_result_text()
	check(daily.contains("CLAY FACTORY") and daily.contains(app.run.day) and daily.contains("714"),
		"Daily share text identifies the game, date, and score")
	app.queue_free()
	await process_frame

func slot_pixel(app: Factory, stage: Vector2) -> Color:
	if DisplayServer.get_name() == "headless":
		return Color.TRANSPARENT
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var point := screen(app, stage) / app.get_viewport_rect().size * Vector2(image.get_size())
	return image.get_pixel(roundi(point.x), roundi(point.y))

func click_button(app: Factory, id: String) -> void:
	var area: Rect2 = app.buttons[id]
	await click(app, area.get_center())

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
