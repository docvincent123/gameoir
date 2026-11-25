class_name Progression
extends RefCounted

const TASKS := [
	["daily_cells", "TASK_CELLS", "cells", 40, 30],
	["daily_lines", "TASK_LINES", "lines", 5, 50],
	["weekly_cells", "TASK_CELLS", "cells", 300, 160],
	["weekly_orders", "TASK_ORDERS", "orders", 12, 220],
]
# Existing achievements remain valid. Coins only unlock cosmetics.
const SHOP := [
	["material", 2, 300], ["material", 3, 600],
	["material", 7, 180], ["material", 15, 400],
	["metal", 1, 180], ["metal", 2, 420],
]

static func xp(save) -> int:
	return save.stat("cells") + save.stat("lines") * 8 + save.stat("orders") * 15

static func level(save) -> int:
	return 1 + xp(save) / 250

static func coins(save) -> int:
	return maxi(0, int(save.data.get_value("progression", "coins", 100)))

static func owns(save, kind: String, index: int) -> bool:
	return bool(save.data.get_value("inventory", "%s_%d" % [kind, index], false))

static func unlocked(save, kind: String, index: int) -> bool:
	if owns(save, kind, index):
		return true
	if kind == "material":
		return save.best() >= int(ThemeCatalog.MATERIALS[index][1])
	return save.stat("cells") >= int(ThemeCatalog.CUTTERS[index][1])

static func buy(save, offer: int) -> bool:
	if offer < 0 or offer >= SHOP.size():
		return false
	var item: Array = SHOP[offer]
	if unlocked(save, item[0], item[1]) or coins(save) < item[2]:
		return false
	save.data.set_value("inventory", "%s_%d" % [item[0], item[1]], true)
	save.data.set_value("progression", "coins", coins(save) - item[2])
	return save.flush() == OK

static func period(day: String, weekly: bool) -> String:
	if not weekly:
		return day
	var days := floori(Time.get_unix_time_from_datetime_string(day + "T00:00:00") / 86400.0)
	return str(days - posmod(days + 3, 7))

static func task_key(task: Array, day: String) -> String:
	return task[0] + "_" + period(day, String(task[0]).begins_with("weekly"))

static func progress(save, task: Array, day: String) -> int:
	return mini(task[3], int(save.data.get_value("missions", task_key(task, day), 0)))

static func claimed(save, task: Array, day: String) -> bool:
	return bool(save.data.get_value("claims", task_key(task, day), false))

static func claim(save, index: int, day: String) -> bool:
	if index < 0 or index >= TASKS.size():
		return false
	var task: Array = TASKS[index]
	if claimed(save, task, day) or progress(save, task, day) < task[3]:
		return false
	save.data.set_value("claims", task_key(task, day), true)
	save.data.set_value("progression", "coins", coins(save) + task[4])
	return save.flush() == OK

static func on_move(save, cells: int, lines: int, orders: int) -> void:
	var day := Time.get_date_string_from_system(true)
	var increments := {"cells": cells, "lines": lines, "orders": orders}
	save.data.set_value("progression", "coins", coins(save) + lines * 2 + orders * 3)
	for task: Array in TASKS:
		var key := task_key(task, day)
		save.data.set_value("missions", key, mini(task[3], progress(save, task, day) + int(increments[task[2]])))
