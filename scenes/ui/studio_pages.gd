extends Node2D

const ICONS := {
	"profile": preload("res://assets/ui/studio/profile.svg"),
	"missions": preload("res://assets/ui/studio/missions.svg"),
	"shop": preload("res://assets/ui/studio/shop.svg"),
	"online": preload("res://assets/ui/studio/online.svg"),
	"coin": preload("res://assets/ui/studio/coin.svg"),
}

func icon(app, key: String, center: Vector2, size: float) -> void:
	var texture: Texture2D = ICONS[key]
	app.draw_texture_rect(texture, Rect2(center - Vector2.ONE * size * 0.5, Vector2.ONE * size), false)

func tile(app, key: String, area: Rect2, label: String) -> void:
	app.button(key, area, "", false, true)
	var face: Rect2 = app.button_face(key, area)
	icon(app, key, face.get_center() - Vector2(0, 22), 64)
	app.ink(label, Rect2(face.position + Vector2(8, 73), Vector2(face.size.x - 16, 42)), 27)

func wallet(app, area: Rect2) -> void:
	app.panel(area, app.SUN, 24)
	icon(app, "coin", area.position + Vector2(40, area.size.y / 2), 54)
	app.ink(app.group_int(Progression.coins(app.save)), Rect2(area.position + Vector2(74, 0), Vector2(area.size.x - 85, area.size.y)), 36, app.WARM)

func render(app) -> void:
	match app.view:
		"profile": profile(app)
		"missions": missions(app)
		"shop": shop(app)
		"online": online(app)

func profile(app) -> void:
	app.header("PROFILE")
	app.card(Rect2(65, 245, 950, 440))
	icon(app, "profile", Vector2(540, 352), 140)
	app.ink(tr("LEVEL") % Progression.level(app.save), Rect2(105, 437, 870, 84), 67)
	var current := Progression.xp(app.save) % 250
	app.progress_bar(Rect2(130, 548, 820, 24), current / 250.0, app.EDGE, app.TEAL)
	app.ink("%d / 250 XP" % current, Rect2(120, 580, 840, 54), 32, app.MUTED)
	wallet(app, Rect2(270, 729, 540, 88))
	app.button("missions", Rect2(90, 880, 900, 120), tr("MISSIONS"), true)
	app.button("shop", Rect2(90, 1030, 900, 120), tr("SHOP"))
	app.button("online", Rect2(90, 1180, 900, 120), tr("ONLINE"))
	app.button("tutorial", Rect2(90, 1330, 900, 120), tr("TUTORIAL"))

func missions(app) -> void:
	app.header("MISSIONS")
	wallet(app, Rect2(560, 225, 440, 77))
	for i in Progression.TASKS.size():
		var task: Array = Progression.TASKS[i]
		var area := Rect2(65, 345 + i * 315, 950, 282)
		app.card(area)
		var value := Progression.progress(app.save, task, app.day)
		var done := Progression.claimed(app.save, task, app.day)
		app.ink(tr("DAILY_TASK" if i < 2 else "WEEKLY_TASK"), Rect2(area.position + Vector2(28, 10), Vector2(560, 43)), 26, app.TEAL, HORIZONTAL_ALIGNMENT_LEFT)
		app.ink(tr(task[1]) % task[3], Rect2(area.position + Vector2(28, 60), Vector2(885, 65)), 42, app.INK, HORIZONTAL_ALIGNMENT_LEFT)
		app.progress_bar(Rect2(area.position + Vector2(30, 139), Vector2(550, 18)), float(value) / task[3], app.EDGE, app.TEAL)
		app.ink("%d / %d" % [value, task[3]], Rect2(area.position + Vector2(30, 171), Vector2(300, 55)), 28, app.MUTED, HORIZONTAL_ALIGNMENT_LEFT)
		app.button("claim_%d" % i, Rect2(area.position + Vector2(600, 160), Vector2(315, 91)), tr("CLAIMED") if done else "%s +%d" % [tr("CLAIM"), task[4]], true, true, done or value < task[3])

func shop(app) -> void:
	app.header("SHOP")
	wallet(app, Rect2(560, 225, 440, 77))
	for i in Progression.SHOP.size():
		var item: Array = Progression.SHOP[i]
		var area := Rect2(62 + (i % 2) * 486, 340 + floori(i / 2.0) * 465, 470, 430)
		app.card(area)
		var owned := Progression.unlocked(app.save, item[0], item[1])
		var key: StringName = ThemeCatalog.MATERIALS[item[1]][0] if item[0] == "material" else ThemeCatalog.CUTTERS[item[1]][0]
		if item[0] == "material":
			app.board.slab.swatch(app, Rect2(area.position + Vector2(92, 35), Vector2(286, 190)), item[1])
		else:
			app.art.cutter(app, "t_0", area.position + Vector2(235, 132), 75, ThemeCatalog.CUTTERS[item[1]][2])
		app.ink(tr(key), Rect2(area.position + Vector2(12, 236), Vector2(446, 63)), 36)
		app.button("buy_%d" % i, Rect2(area.position + Vector2(30, 317), Vector2(410, 82)), tr("OWNED") if owned else "%s %d" % [tr("BUY"), item[2]], true, true, owned or Progression.coins(app.save) < item[2])

func online(app) -> void:
	app.header("ONLINE")
	app.ink(tr("ONLINE_NOTE"), Rect2(70, 210, 940, 96), 28, app.MUTED)
	app.button("online_refresh", Rect2(65, 340, 460, 100), tr("REFRESH"), true, true, not app.online_board.configured() or app.online_board.busy)
	app.button("online_submit", Rect2(555, 340, 460, 100), tr("SUBMIT_BEST"), false, true, not app.online_board.configured() or app.online_board.busy or app.save.best() <= 0)
	app.ink(tr(app.online_board.status), Rect2(65, 455, 950, 90), 30, app.MUTED)
	for i in mini(app.online_board.rows.size(), 10):
		var entry: Dictionary = app.online_board.rows[i]
		var area := Rect2(65, 570 + 112 * i, 950, 96)
		app.card(area)
		app.ink("#%d" % (i + 1), Rect2(area.position + Vector2(20, 0), Vector2(140, 96)), 35, app.TEAL)
		app.ink(str(entry.get("name", "Clay")), Rect2(area.position + Vector2(170, 0), Vector2(430, 96)), 34, app.INK, HORIZONTAL_ALIGNMENT_LEFT)
		app.ink(app.group_int(int(entry.get("score", 0))), Rect2(area.position + Vector2(610, 0), Vector2(310, 96)), 38, app.INK, HORIZONTAL_ALIGNMENT_RIGHT)
