extends Node2D

const HERO := PremiumArt.FACTORY
const PLAY_AREA := Rect2(102, 1070, 876, 154)
const DAILY_AREA := Rect2(165, 1251, 750, 110)
const NAVIGATION := [
	["collection", "COLLECTION", &"collection"],
	["records", "RECORDS", &"trophy"],
	["settings", "SETTINGS", &"settings"],
]

func render(app) -> void:
	var current: bool = app.save.has_active_run(GameManager.ENDLESS, app.day)
	var floating: float = sin(app.clock * 1.6) * 9.0 if not app.reduced else 0.0
	app.draw_texture_rect(PremiumArt.EMBLEM, Rect2(58, 55, 106, 106), false)
	app.register_button("profile", Rect2(55, 52, 465, 112))
	app.ink(tr("LEVEL") % Progression.level(app.save), Rect2(177, 65, 345, 90), 40, app.INK, HORIZONTAL_ALIGNMENT_LEFT)
	app.studio.wallet(app, Rect2(675, 63, 345, 94))
	app.brand(Rect2(70, 188, 940, 290), false)
	app.ink(tr("ENDLESS"), Rect2(190, 489, 700, 58), 40, app.MUTED)
	app.draw_texture_rect(HERO, Rect2(100, 539 + floating, 880, 490), false)
	app.register_button("play", PLAY_AREA)
	var play: Rect2 = app.button_face("play", PLAY_AREA)
	app.premium.button(app, play, true)
	app.ink(tr("RESUME") if current else tr("PLAY"), play.grow(-32), 66, app.PAPER)
	app.art.icon(app, &"next", play.end - Vector2(66, play.size.y / 2), 52, app.PAPER)
	app.button("daily", DAILY_AREA, tr("DAILY"), false)
	var best: int = app.save.best()
	if best > 0:
		app.ink("%s  %s" % [tr("BEST"), app.group_int(best)], Rect2(100, 1383, 880, 58), 38, app.MUTED)
	var quick: Array = [["missions", "MISSIONS"], ["shop", "SHOP"], ["online", "ONLINE"]]
	for i in quick.size():
		var entry: Array = quick[i]
		app.studio.tile(app, entry[0], Rect2(64 + 320 * i, 1460, 308, 154), tr(entry[1]))
	app.panel(Rect2(43, 1655, 994, 205), app.PAPER, 52)
	for i in NAVIGATION.size():
		var entry: Array = NAVIGATION[i]
		var area := Rect2(65 + i * 322, 1670, 306, 173)
		app.register_button(entry[0], area)
		var face: Rect2 = app.button_face(entry[0], area)
		app.art.icon(app, entry[2], face.position + Vector2(153, 58), 75.0)
		app.ink(tr(entry[1]), Rect2(face.position + Vector2(10, 102), Vector2(286, 55)), 34, app.INK)
