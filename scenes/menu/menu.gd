extends Node2D

const HERO := preload("res://assets/ui/hero.png")

func render(app) -> void:
	var t: float = app.clock
	var best: int = app.save.best()
	var current: bool = app.save.has_active_run(GameManager.ENDLESS, app.day)
	var daily: bool = app.save.has_active_run(GameManager.DAILY, app.day)
	var floating := sin(t * 1.8) * 9.0 if not app.reduced else 0.0
	app.draw_arc(Vector2(540, 805), 339, 0.0, TAU, 96, Color(0.77, 0.46, 0.95, 0.15), 2.0, true)
	app.draw_arc(Vector2(540, 805), 375, 0.12, PI - 0.08, 72, Color(0.77, 0.46, 0.95, 0.12), 2.0, true)
	app.art.sparkle(app, Vector2(168, 755 + floating), 15, Color("#d597ff"), PI / 15)
	app.art.sparkle(app, Vector2(880, 646 - floating), 13, Color("#f4c2ff"), PI / 10)
	app.art.sparkle(app, Vector2(844, 1006 + floating), 12, app.GILT, PI / 13)
	app.art.sparkle(app, Vector2(248, 1058 + floating), 9, Color("#ce84ec"))
	var hero_w := 804.0
	var hero_h := hero_w * float(HERO.get_height()) / float(HERO.get_width())
	app.draw_texture_rect(HERO, Rect2((1080.0 - hero_w) / 2, 458 + floating, hero_w, hero_h), false)

	app.ink(tr("TITLE_TOP"), Rect2(115, 100, 850, 165), 168, Color("#f5cbff"))
	app.ink(tr("TITLE_BOTTOM"), Rect2(64, 241, 952, 173), 166, app.WHITE)
	var subtitle := tr("ENDLESS").to_upper()
	app.ink(subtitle, Rect2(153, 427, 774, 50), 34, app.GILT)

	app.button("play", Rect2(98, 1200, 884, 132), tr("RESUME") if current else tr("PLAY"), true)
	app.button("daily", Rect2(98, 1380, 884, 106), tr("DAILY"))
	app.button("collection", Rect2(53, 1546, 310, 99), tr("COLLECTION"), false, true)
	app.button("records", Rect2(385, 1546, 310, 99), tr("RECORDS"), false, true)
	app.button("settings", Rect2(717, 1546, 310, 99), tr("SETTINGS"), false, true)
	if daily:
		app.art.sparkle(app, Vector2(917, 1432), 13, app.GILT)
	app.draw_line(Vector2(98, 1729), Vector2(982, 1729), Color("#593767"), 2.0, true)
	app.art.sparkle(app, Vector2(438, 1784), 17, app.GILT)
	app.ink("%s  %s" % [tr("BEST").to_upper(), app.group_int(best)],
		Rect2(469, 1749, 464, 67), 35, app.GILT, HORIZONTAL_ALIGNMENT_LEFT)
	app.ink(tr("CREDIT"), Rect2(100, 1840, 880, 41), 24, app.MUTED, HORIZONTAL_ALIGNMENT_CENTER, false)
