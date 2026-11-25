extends Node2D

const HERO := preload("res://assets/ui/hero.png")
const PLAY_AREA := Rect2(177, 1118, 726, 136)
const DAILY_AREA := Rect2(224, 1286, 632, 104)
const NAVIGATION := [
	["collection", "COLLECTION", &"collection"],
	["records", "RECORDS", &"trophy"],
	["settings", "SETTINGS", &"settings"],
]

func render(app) -> void:
	var current: bool = app.save.has_active_run(GameManager.ENDLESS, app.day)
	var floating: float = sin(app.clock * 1.45) * 6.0 if not app.reduced else 0.0
	var scale := minf(650.0 / HERO.get_width(), 510.0 / HERO.get_height())
	var size := HERO.get_size() * scale
	app.draw_texture_rect(HERO, Rect2(Vector2((1080.0 - size.x) / 2.0, 498.0 - size.y / 2.0 + floating), size), false)

	var title := "%s %s" % [tr("TITLE_TOP"), tr("TITLE_BOTTOM")]
	app.ink(title, Rect2(100, 782, 880, 138), 102)
	app.ink(tr("ENDLESS"), Rect2(126, 917, 828, 61), 35, app.MUTED, HORIZONTAL_ALIGNMENT_CENTER, false)

	app.register_button("play", PLAY_AREA)
	var play: Rect2 = app.button_face("play", PLAY_AREA)
	var green: Color = app.SCORE_PLATE.lightened(0.12) if app.hovered == "play" else app.SCORE_PLATE
	app.panel(Rect2(PLAY_AREA.position + Vector2(0, 8), PLAY_AREA.size), Color("#173c31"), 42)
	app.panel(play, green, 42)
	app.ink(tr("RESUME") if current else tr("PLAY"), play.grow(-18), 48, app.PAPER)

	app.register_button("daily", DAILY_AREA)
	var daily: Rect2 = app.button_face("daily", DAILY_AREA)
	app.panel(daily, Color("#f2eddf") if app.hovered == "daily" else Color("#fffbee"), 33, Color("#c9d4c9"), 2)
	app.ink(tr("DAILY"), daily.grow(-19), 34)
	if app.save.has_active_run(GameManager.DAILY, app.day):
		app.art.icon(app, &"clock", daily.position + Vector2(46, 51), 36)

	app.draw_line(Vector2(82, 1513), Vector2(998, 1513), app.EDGE, 2.0, true)
	for index in NAVIGATION.size():
		var entry: Array = NAVIGATION[index]
		var area := Rect2(72 + index * 316, 1542, 304, 146)
		app.register_button(entry[0], area)
		var face: Rect2 = app.button_face(entry[0], area)
		if app.hovered == entry[0]:
			app.panel(face, Color("#f1eadc"), 32)
		app.art.icon(app, entry[2], face.position + Vector2(152, 47), 68)
		app.ink(tr(entry[1]), Rect2(face.position + Vector2(12, 86), Vector2(280, 50)), 30)

	var best: int = app.save.best()
	if best > 0:
		app.ink("%s  %s" % [tr("BEST"), app.group_int(best)], Rect2(100, 1752, 880, 42), 29, app.TEAL)
	app.ink(tr("CREDIT"), Rect2(72, 1824, 936, 42), 25, app.MUTED, HORIZONTAL_ALIGNMENT_CENTER, false)
