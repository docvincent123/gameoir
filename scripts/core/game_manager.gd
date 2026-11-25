class_name GameManager
extends RefCounted

const BALANCE: GameBalance = preload("res://resources/balance/default.tres")
const ENDLESS := "endless"
const DAILY := "daily"
const LEGACY_SIZE := 8

var board := BoardManager.new()
var cutters := CutterManager.new()
var order := CutOrder.new()
var mode := ENDLESS
var day := ""
var score := 0
var streak := 0
var max_streak := 0
var cut_count := 0
var line_count := 0
var used_continue := false
var ended := false
var recorded := false

func start(game_mode: String, challenge_day: String, seed_value: int) -> void:
	mode = game_mode
	day = challenge_day
	cutters.generator.rng.seed = seed_value
	cutters.deal(board, tier())

func tier() -> int:
	return DifficultyManager.tier(score, BALANCE)

func preview_move(slot: int, origin: Vector2i) -> Dictionary:
	if ended:
		return {}
	var form := cutters.shape(slot)
	if form.is_empty():
		return {}
	var change := board.preview_cut(form.cells, origin)
	if not change.is_empty():
		var next_streak := streak + 1 if not change.completed.is_empty() else 0
		change.order = order.preview(board, change.removed, BALANCE)
		change.points = cut_points(change, next_streak) + change.order.bonus
	return change

func first_move_hint() -> Dictionary:
	if cut_count > 0 or ended:
		return {}
	for slot in cutters.hand.size():
		var form := cutters.shape(slot)
		if form.is_empty():
			continue
		var origin := (Vector2i.ONE * BoardManager.SIZE - Vector2i(form.size)) / 2
		if board.can_cut(form.cells, origin):
			return {"slot": slot, "cells": form.cells, "origin": origin}
	return {}

func cut_points(change: Dictionary, combo: int) -> int:
	return ScoreManager.points(change.removed.size(), change.completed.size(), combo, change.full, BALANCE)

func play(slot: int, origin: Vector2i) -> Dictionary:
	if ended:
		return {}
	var form := cutters.shape(slot)
	if form.is_empty():
		return {}
	var change := board.cut(form.cells, origin)
	if change.is_empty():
		return {}
	var lines: int = change.completed.size()
	streak = streak + 1 if lines > 0 else 0
	max_streak = maxi(max_streak, streak)
	cut_count += change.removed.size()
	line_count += lines
	change.order = order.preview(board, change.removed, BALANCE)
	var points: int = cut_points(change, streak) + change.order.bonus
	order.apply(change.order)
	score += points
	change.merge(board.advance(change.completed, BALANCE.refill_delay(score)))
	change.dealt = cutters.hand.count(ShapeGenerator.EMPTY) == cutters.hand.size() - 1
	cutters.consume(slot, board, tier())
	refresh_availability()
	if not ended and order.cells.is_empty() and cut_count >= 3:
		order.issue(board, cutters)
	change.points = points
	change.lines = lines
	change.form = form
	change.origin = origin
	return change

func refresh_availability() -> void:
	ended = not cutters.has_move(board)

func snapshot() -> Dictionary:
	return {
		"mode": mode, "day": day, "score": score, "streak": streak, "max_streak": max_streak,
		"cut_count": cut_count, "line_count": line_count, "used_continue": used_continue,
		"ended": ended, "recorded": recorded, "cells": board.cells.duplicate(),
		"pending": board.pending.duplicate(), "hand": cutters.hand.duplicate(), "order": order.snapshot(),
		"rng_seed": cutters.generator.rng.seed, "rng_state": cutters.generator.rng.state,
	}

func restore(data: Dictionary) -> bool:
	var cells: Variant = data.get("cells")
	var hand: Variant = data.get("hand")
	if not cells is PackedByteArray:
		return false
	var legacy: bool = cells.size() == LEGACY_SIZE * LEGACY_SIZE
	if not legacy and cells.size() != BoardManager.COUNT:
		return false
	var pending: Variant = data.get("pending")
	if not legacy:
		if not pending is PackedInt32Array or pending.size() != BoardManager.LINE_COUNT:
			return false
		for remaining: int in pending:
			if remaining < 0:
				return false
	if not hand is Array or hand.size() != 3:
		return false
	for value: int in cells:
		if value != 0 and value != 1:
			return false
	for id: Variant in hand:
		if not id is String or (id != ShapeGenerator.EMPTY and not cutters.generator.shapes.has(id)):
			return false
	mode = data.get("mode", ENDLESS)
	day = data.get("day", "")
	score = maxi(0, data.get("score", 0))
	streak = maxi(0, data.get("streak", 0))
	max_streak = maxi(streak, data.get("max_streak", 0))
	cut_count = maxi(0, data.get("cut_count", 0))
	line_count = maxi(0, data.get("line_count", 0))
	used_continue = data.get("used_continue", false)
	ended = data.get("ended", false)
	recorded = data.get("recorded", false)
	if legacy:
		board.reset()
		for y in BoardManager.SIZE:
			for x in BoardManager.SIZE:
				board.cells[board.index(Vector2i(x, y))] = cells[y * LEGACY_SIZE + x]
		if not ended:
			board.advance(board.empty_lines(), BALANCE.refill_delay(score))
	else:
		board.cells = cells.duplicate()
		board.pending = pending.duplicate()
	cutters.hand.assign(hand)
	order.restore(data.get("order"), board)
	cutters.generator.rng.seed = data.get("rng_seed", 0)
	cutters.generator.rng.state = data.get("rng_state", 0)
	if not ended:
		refresh_availability()
	return true

# Deterministic coaching: prefer a line, then an order, then a larger cut.
func coaching_hint() -> Dictionary:
	if ended:
		return {}
	var best_hint: Dictionary = {}
	var best_value := -1
	for slot in cutters.hand.size():
		var form := cutters.shape(slot)
		if form.is_empty():
			continue
		for y in range(BoardManager.SIZE - form.size.y + 1):
			for x in range(BoardManager.SIZE - form.size.x + 1):
				var origin := Vector2i(x, y)
				var change := preview_move(slot, origin)
				if change.is_empty():
					continue
				var value: int = change.completed.size() * 100 + change.order.bonus + change.removed.size()
				if value > best_value:
					best_value = value
					best_hint = {"slot": slot, "cells": form.cells, "origin": origin}
	return best_hint
