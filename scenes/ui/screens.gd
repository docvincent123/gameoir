extends Node2D

const TABS := ["MATERIALS", "CUTTERS", "STYLES", "EFFECTS"]
const HISTORY_PAGE_SIZE := 5
const SETTINGS_ICONS := [&"sound", &"sound", &"flag", &"shine", &"settings"]

func render(app) -> void:
	match app.view:
		"collection":
			collection(app)
		"records":
			records(app)
		_:
			settings(app)

func collection(app) -> void:
	app.header("COLLECTION")
	for i in TABS.size():
		app.button("tab_%d" % i, Rect2(55 + 246 * i, 221, 226, 82), tr(TABS[i]), i == app.collection_tab, true)
	if app.collection_tab == 0:
		materials(app)
		return

	var key := tab_key(app.collection_tab)
	var variants := tab_options(app.collection_tab)
	var tally: int = app.save.stat("lines" if key == "effect" else "cells")
	var active := ThemeCatalog.unlocked_choice(app.save, key, variants, tally)
	for i in variants.size():
		var option: Array = variants[i]
		var card := Rect2(76, 390 + i * 287, 928, 243)
		var unlocked := tally >= int(option[1])
		app.button("option_%d" % i, card, "", active == i, false, not unlocked)
		var tint: Color = option[2]
		if key == "metal":
			app.art.cutter(app, "t_0", card.position + Vector2(125, 117), 56, tint)
		elif key == "effect":
			app.art.sparkle(app, card.position + Vector2(126, 120), 49, tint)
			app.art.sparkle(app, card.position + Vector2(170, 79), 14, tint)
		else:
			app.panel(Rect2(card.position + Vector2(60, 54), Vector2(132, 132)), tint, 29, tint.lightened(0.28), 3)
			app.art.cell(app, Rect2(card.position + Vector2(91, 84), Vector2(69, 69)), 0, 0)
		app.ink(tr(option[0]), Rect2(card.position + Vector2(239, 62), Vector2(642, 62)), 42,
			app.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		var status := tr("SELECTED") if active == i else ""
		if not unlocked:
			status = tr("UNLOCK_LINES" if key == "effect" else "UNLOCK_CELLS") % app.group_int(option[1])
		app.ink(status, Rect2(card.position + Vector2(239, 127), Vector2(642, 51)), 28,
			app.GILT if active == i else app.SOFT, HORIZONTAL_ALIGNMENT_LEFT)

func materials(app) -> void:
	var selected: int = app.save.setting("material", -1)
	app.button("theme_auto", Rect2(66, 348, 948, 95), tr("AUTO_THEME"), selected < 0, true)
	for skin in ThemeCatalog.MATERIALS.size():
		var item: Array = ThemeCatalog.MATERIALS[skin]
		var col := skin % 4
		var row := floori(float(skin) / 4.0)
		var card := Rect2(53 + 246 * col, 484 + 325 * row, 236, 282)
		var unlocked: bool = app.save.best() >= int(item[1])
		app.button("skin_%d" % skin, card, "", selected == skin, false, not unlocked)
		app.art.cell(app, Rect2(card.position + Vector2(54, 29), Vector2(128, 128)), skin, 0,
			Color.WHITE if unlocked else Color(0.77, 0.70, 0.79, 0.61))
		app.ink(tr(item[0]), Rect2(card.position + Vector2(12, 169), Vector2(212, 47)), 33)
		var status := tr("SELECTED") if selected == skin else ""
		if not unlocked:
			status = tr("UNLOCK_BEST") % app.group_int(item[1])
		app.ink(status, Rect2(card.position + Vector2(12, 220), Vector2(212, 40)), 23, app.GILT if unlocked else app.SOFT)
		if selected == skin:
			app.art.icon(app, &"check", card.position + Vector2(200, 36), 37.0, app.GILT)

func records(app) -> void:
	app.refresh_day()
	app.header("RECORDS")
	var keys := ["BEST", "DAILY_BEST", "ASSISTED_BEST"]
	var scores: Array[int] = [app.save.best(), app.save.best(GameManager.DAILY, app.day), app.save.best(GameManager.ENDLESS, "", true)]
	for i in keys.size():
		var card := Rect2(56 + 328 * i, 228, 312, 174)
		app.card(card, i == 0)
		app.ink(tr(keys[i]), Rect2(card.position + Vector2(16, 19), Vector2(280, 49)), 30, app.SOFT)
		app.ink(app.group_int(scores[i]), Rect2(card.position + Vector2(16, 75), Vector2(280, 76)), 54, app.GILT)
	var stats := [["CELLS_TOTAL", "cells"], ["LINES_TOTAL", "lines"], ["MAX_COMBO", "combo"], ["GAMES_TOTAL", "games"]]
	for i in stats.size():
		var stat: Array = stats[i]
		var card := Rect2(56 + 493 * (i % 2), 435 + 112 * floori(float(i) / 2.0), 475, 97)
		app.card(card)
		app.ink(tr(stat[0]), Rect2(card.position + Vector2(23, 9), Vector2(273, 79)), 28,
			app.SOFT, HORIZONTAL_ALIGNMENT_LEFT)
		app.ink(app.group_int(app.save.stat(stat[1])), Rect2(card.position + Vector2(305, 9), Vector2(146, 79)),
			34, app.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)

	app.ink(tr("ACHIEVEMENTS"), Rect2(62, 685, 955, 70), 43, app.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	for i in ThemeCatalog.ACHIEVEMENTS.size():
		var achievement: Array = ThemeCatalog.ACHIEVEMENTS[i]
		var card := Rect2(56 + 493 * (i % 2), 780 + 114 * floori(float(i) / 2.0), 475, 96)
		var progress := mini(app.save.stat(achievement[1]), int(achievement[2]))
		var done := progress >= int(achievement[2])
		app.card(card, done)
		app.art.icon(app, &"star", card.position + Vector2(49, 48), 49.0, Color.WHITE if done else Color("#936a89"))
		app.ink(tr(achievement[0]), Rect2(card.position + Vector2(88, 13), Vector2(355, 36)), 29,
			app.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		app.ink("%s / %s" % [app.group_int(progress), app.group_int(achievement[2])],
			Rect2(card.position + Vector2(88, 52), Vector2(355, 30)), 22, app.SOFT, HORIZONTAL_ALIGNMENT_LEFT)
	app.ink(tr("HISTORY"), Rect2(62, 1047, 955, 67), 43, app.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	var history: Array = app.save.history()
	if history.is_empty():
		app.ink(tr("NO_HISTORY"), Rect2(64, 1141, 947, 66), 34, app.SOFT, HORIZONTAL_ALIGNMENT_LEFT, false)
		return
	var page: int = app.history_page
	var start := page * HISTORY_PAGE_SIZE
	var last := mini(start + HISTORY_PAGE_SIZE, history.size())
	for i in range(start, last):
		var entry: Dictionary = history[i]
		var row := Rect2(55, 1140 + 111 * (i - start), 970, 92)
		var mode := tr("ENDLESS")
		if entry.mode == GameManager.DAILY:
			mode = "%s  ·  %s" % [tr("DAILY"), entry.day]
		elif entry.assisted:
			mode = tr("ASSISTED")
		app.card(row)
		app.ink(mode, Rect2(row.position + Vector2(29, 8), Vector2(642, 76)), 30,
			app.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		app.ink(app.group_int(entry.score), Rect2(row.position + Vector2(694, 8), Vector2(241, 76)),
			36, app.GILT, HORIZONTAL_ALIGNMENT_RIGHT)
	if history.size() > HISTORY_PAGE_SIZE:
		app.button("history_prev", Rect2(55, 1746, 145, 83), "‹", false, true, page == 0)
		app.button("history_next", Rect2(880, 1746, 145, 83), "›", false, true, last == history.size())
		app.ink("%d / %d" % [page + 1, ceili(float(history.size()) / HISTORY_PAGE_SIZE)],
			Rect2(224, 1747, 632, 82), 30, app.SOFT)

func settings(app) -> void:
	app.header("SETTINGS")
	var choices := [["MUSIC", "music"], ["SOUND", "sound"], ["HAPTICS", "haptics"], ["QUALITY", "reduced"], ["LANGUAGE", "language"]]
	for i in choices.size():
		var option: Array = choices[i]
		var row := Rect2(58, 254 + 181 * i, 964, 143)
		app.card(row)
		app.art.icon(app, SETTINGS_ICONS[i], row.position + Vector2(52, 71), 64, app.GILT)
		app.ink(tr(option[0]), Rect2(row.position + Vector2(103, 20), Vector2(395, 103)), 43,
			app.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
		var text := ""
		var active := false
		if option[1] == "language":
			var idx := maxi(0, LocalizationManager.LANGUAGES.find(app.save.setting("language", "auto")))
			text = tr("AUTOMATIC") if idx == 0 else LocalizationManager.LABELS[idx]
			text += "  ›"
		elif option[1] == "reduced":
			text = tr("REDUCED") if app.reduced else tr("HIGH")
		else:
			active = app.save.setting(option[1], true)
			text = tr("ON") if active else tr("OFF")
		app.button("setting_" + option[1], Rect2(row.position + Vector2(531, 27), Vector2(397, 84)),
			text, active, true)

func activate(app, id: String) -> void:
	if id.begins_with("tab_"):
		app.collection_tab = int(id.get_slice("_", 1))
	elif id == "theme_auto":
		app.save.set_setting("material", -1)
	elif id.begins_with("skin_"):
		app.save.set_setting("material", int(id.get_slice("_", 1)))
	elif id.begins_with("option_"):
		app.save.set_setting(tab_key(app.collection_tab), int(id.get_slice("_", 1)))
		app.apply_settings()
	elif id == "history_prev" or id == "history_next":
		app.history_page += 1 if id == "history_next" else -1
	elif id.begins_with("setting_"):
		var key := id.get_slice("_", 1)
		if key == "language":
			var idx := LocalizationManager.LANGUAGES.find(app.save.setting("language", "auto"))
			var next := (idx + 1) % LocalizationManager.LANGUAGES.size()
			app.save.set_setting(key, LocalizationManager.LANGUAGES[next])
		else:
			app.save.set_setting(key, not app.save.setting(key, key != "reduced"))
		app.apply_settings()

func tab_key(tab: int) -> String:
	return ["material", "metal", "workshop", "effect"][tab]

func tab_options(tab: int) -> Array:
	return [ThemeCatalog.MATERIALS, ThemeCatalog.CUTTERS, ThemeCatalog.STYLES, ThemeCatalog.EFFECTS][tab]
