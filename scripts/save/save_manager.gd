class_name SaveManager
extends RefCounted

const VERSION := 2
const SAVE := "user://clay_factory.cfg"

var path := SAVE
var data := ConfigFile.new()

func _init(save_path: String = SAVE) -> void:
	path = save_path
	for candidate in [path, path + ".bak"]:
		var loaded := ConfigFile.new()
		if loaded.load(candidate) != OK:
			continue
		var version: int = loaded.get_value("format", "version", -1)
		if version >= 1 and version <= VERSION:
			data = loaded
			break

func flush() -> Error:
	data.set_value("format", "version", VERSION)
	var pending := path + ".tmp"
	var error := data.save(pending)
	if error != OK:
		return error
	# POSIX/mobile can replace atomically. A backup covers platforms that reject replacement.
	error = DirAccess.rename_absolute(pending, path)
	if error == OK:
		return OK
	if FileAccess.file_exists(path):
		error = DirAccess.rename_absolute(path, path + ".bak")
		if error != OK:
			return error
	return DirAccess.rename_absolute(pending, path)

func setting(key: String, fallback: Variant) -> Variant:
	return data.get_value("settings", key, fallback)

func set_setting(key: String, value: Variant) -> void:
	data.set_value("settings", key, value)
	flush()

func has_active_run(mode: String, day: String) -> bool:
	var snapshot: Dictionary = data.get_value("runs", mode, {})
	return not snapshot.is_empty() and not snapshot.get("ended", false) and (mode != GameManager.DAILY or snapshot.get("day") == day)

func get_run(mode: String, day: String) -> GameManager:
	var snapshot: Dictionary = data.get_value("runs", mode, {})
	if snapshot.is_empty() or (mode == GameManager.DAILY and snapshot.get("day") != day):
		return null
	var result := GameManager.new()
	if result.restore(snapshot):
		return result
	return null

func store_run(run: GameManager) -> void:
	data.set_value("runs", run.mode, run.snapshot())
	flush()

func clear_run(mode: String) -> void:
	if data.has_section_key("runs", mode):
		data.erase_section_key("runs", mode)
		flush()

func best(mode: String = GameManager.ENDLESS, day: String = "", assisted := false) -> int:
	var key := mode
	if mode == GameManager.DAILY:
		key += "_" + day
	elif assisted:
		key += "_assisted"
	return data.get_value("best", key, 0)

func stat(key: String) -> int:
	return data.get_value("stats", key, 0)

func history() -> Array:
	return data.get_value("stats", "history", [])

func update_move(run: GameManager, cells: int, lines: int) -> bool:
	var previous := best(run.mode, run.day, run.used_continue)
	if run.score > previous:
		var key := run.mode
		if run.mode == GameManager.DAILY:
			key += "_" + run.day
		elif run.used_continue:
			key += "_assisted"
		data.set_value("best", key, run.score)
	data.set_value("stats", "cells", stat("cells") + cells)
	data.set_value("stats", "lines", stat("lines") + lines)
	data.set_value("stats", "combo", maxi(stat("combo"), run.max_streak))
	if run.ended:
		record(run)
	store_run(run)
	return run.score > previous

func record(run: GameManager) -> void:
	if run.recorded:
		return
	run.recorded = true
	if not run.used_continue:
		data.set_value("stats", "games", stat("games") + 1)
	var games := history()
	games.push_front({"score": run.score, "mode": run.mode, "day": run.day, "assisted": run.used_continue})
	games.resize(mini(games.size(), 12))
	data.set_value("stats", "history", games)
