extends Node2D

const HERO := preload("res://assets/ui/hero.png")
const HERO_STAGE := Rect2(58, 435, 964, 657)
const NAVIGATION := [
	["collection", "COLLECTION", &"collection"],
	["records", "RECORDS", &"trophy"],
	["settings", "SETTINGS", &"settings"],
]

func render(app) -> void:
	var time: float = app.clock
	var best: int = app.save.best()
	var current: bool = app.save.has_active_run(GameManager.ENDLESS, app.day)
	var daily: bool = app.save.has_active_run(GameManager.DAILY, app.day)
	var floating := sin(time * 1.7) * 9.0 if not app.reduced else 0.0

	app.art.icon(app, &"collection", Vector2(110, 126), 106.0)
	var best_area := Rect2(683, 86, 335, 88)
	app.card(best_area, app.SUN)
	app.art.icon(app, &"trophy", Vector2(736, 130), 61.0)
	app.ink("%s  %s" % [tr("BEST").to_upper(), app.group_int(best)],
		Rect2(777, 92, 224, 76), 34, app.WARM, HORIZONTAL_ALIGNMENT_LEFT)

	var title := "%s %s" % [tr("TITLE_TOP"), tr("TITLE_BOTTOM")]
	app.ink(title, Rect2(64, 207, 952, 131), 125, app.INK, HORIZONTAL_ALIGNMENT_LEFT)
	app.ink(tr("ENDLESS"), Rect2(68, 336, 950, 58), 43, app.TEAL, HORIZONTAL_ALIGNMENT_LEFT)

	app.card(HERO_STAGE, app.LILAC)
	var hero_side := 715.0
	var hero_h := hero_side * float(HERO.get_height()) / float(HERO.get_width())
	app.draw_texture_rect(HERO, Rect2((1080.0 - hero_side) / 2, 406 + floating, hero_side, hero_h), false)
	app.art.icon(app, &"shine", Vector2(131, 630 - floating), 76.0)
	app.art.icon(app, &"shine", Vector2(949, 884 + floating), 92.0)

	app.button("play", Rect2(55, 1150, 970, 138), tr("RESUME") if current else tr("PLAY"), true, false, false, app.MINT)
	app.button("daily", Rect2(55, 1320, 970, 118), tr("DAILY"), false, false, false, app.PEACH)
	if daily:
		app.art.icon(app, &"clock", Vector2(957, 1378), 53.0)

	var paints: Array = [app.ROSE, app.SUN, app.SKY]
	for index in NAVIGATION.size():
		var entry: Array = NAVIGATION[index]
		var area := Rect2(55 + index * 330, 1483, 310, 248)
		app.button(entry[0], area, "", false, false, false, paints[index], false)
		var face: Rect2 = app.button_face(entry[0], area)
		app.art.icon(app, entry[2], face.position + Vector2(155, 92), 139.0)
		app.ink(tr(entry[1]), Rect2(face.position + Vector2(16, 166), Vector2(278, 57)), 35)
	app.draw_line(Vector2(70, 1784), Vector2(1010, 1784), app.EDGE, 2.0, true)
	app.ink(tr("CREDIT"), Rect2(60, 1821, 960, 45), 25, app.MUTED, HORIZONTAL_ALIGNMENT_CENTER, false)
