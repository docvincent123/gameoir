extends Node2D

const HERO := PremiumArt.FACTORY
const PLAY_AREA := Rect2(116, 960, 848, 146)
const DAILY_AREA := Rect2(160, 1130, 760, 108)
const NAVIGATION := [
	["collection", "COLLECTION", &"collection"],
	["records", "RECORDS", &"trophy"],
	["settings", "SETTINGS", &"settings"],
]

func render(app) -> void:
	var current: bool = app.save.has_active_run(GameManager.ENDLESS, app.day)
	var floating: float = sin(app.clock * 1.45) * 6.0 if not app.reduced else 0.0
	app.studio.wallet(app, Rect2(650, 72, 365, 83))
	app.ink(tr("LEVEL") % Progression.level(app.save), Rect2(65, 72, 550, 83), 36, app.TEAL, HORIZONTAL_ALIGNMENT_LEFT)
	app.draw_texture_rect(PremiumArt.EMBLEM, Rect2(420, 170, 240, 240), false)
	app.brand(Rect2(120, 422, 840, 235), false)
	app.ink(tr("ENDLESS"), Rect2(126, 666, 828, 57), 39, app.WARM)
	app.draw_texture_rect(HERO, Rect2(285, 713 + floating, 510, 242), false)
	if not app.reduced:
		PremiumArt.sparkle(app, Vector2(385, 257), 80, 0.65 + sin(app.clock * 2.0) * 0.25)
		PremiumArt.sparkle(app, Vector2(727, 600), 61, 0.6 + sin(app.clock * 2.6) * 0.2)

	app.register_button("play", PLAY_AREA)
	var play: Rect2 = app.button_face("play", PLAY_AREA)
	app.premium.button(app, play, true)
	app.embossed(tr("RESUME") if current else tr("PLAY"), Rect2(play.position + Vector2(46, 0), Vector2(play.size.x - 110, play.size.y)), 64, app.PAPER, Color("#174a31"))
	app.art.icon(app, &"next", play.end - Vector2(65, play.size.y / 2), 42.0, app.PAPER)

	app.register_button("daily", DAILY_AREA)
	var daily: Rect2 = app.button_face("daily", DAILY_AREA)
	app.premium.button(app, daily, false)
	app.ink(tr("DAILY"), daily.grow(-19), 44)
	var daily_icon := &"clock" if app.save.has_active_run(GameManager.DAILY, app.day) else &"calendar"
	app.art.icon(app, daily_icon, daily.position + Vector2(62, 51), 43)

	for i in 4:
		var entry: Array = [["profile", "PROFILE"], ["missions", "MISSIONS"], ["shop", "SHOP"], ["online", "ONLINE"]][i]
		app.studio.tile(app, entry[0], Rect2(55 + 246 * i, 1300, 232, 143), tr(entry[1]))
	app.premium.button(app, Rect2(55, 1490, 970, 177), false)
	for index in NAVIGATION.size():
		var entry: Array = NAVIGATION[index]
		var area := Rect2(72 + index * 316, 1513, 304, 146)
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
