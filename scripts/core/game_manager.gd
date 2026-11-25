class_name GameManager
extends RefCounted

const BALANCE: GameBalance = preload("res://resources/balance/default.tres")
const ENDLESS := "endless"
const DAILY := "daily"

var board := BoardManager.new()
var cutters := CutterManager.new()
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

func play(slot: int, origin: Vector2i) -> Dictionary:
	if ended:
		return {}
	var form := cutters.shape(slot)
	if form.is_empty():
		return {}
	var change := board.cut(form.cells, origin)
	if change.is_empty():
		return {}
	var lines: int = change.rows.size() + change.columns.size()
	streak = streak + 1 if lines > 0 else 0
	max_streak = maxi(max_streak, streak)
	cut_count += change.removed.size()
	line_count += lines
	var points := ScoreManager.points(change.removed.size(), lines, streak, change.full, BALANCE)
	score += points
	cutters.consume(slot, board, tier())
	ended = not cutters.has_move(board)
	change.points = points
	change.lines = lines
	change.form = form
	return change

func can_continue() -> bool:
	return ended and mode == ENDLESS and not used_continue

func continue_run() -> bool:
	if not can_continue():
		return false
	used_continue = true
	recorded = false
	ended = false
	streak = 0
	board.reset()
	cutters.deal(board, tier())
	return true

func snapshot() -> Dictionary:
	return {
		"mode": mode, "day": day, "score": score, "streak": streak, "max_streak": max_streak,
		"cut_count": cut_count, "line_count": line_count, "used_continue": used_continue,
		"ended": ended, "recorded": recorded, "cells": board.cells, "hand": cutters.hand,
		"rng_seed": cutters.generator.rng.seed, "rng_state": cutters.generator.rng.state,
	}

func restore(data: Dictionary) -> bool:
	var cells: Variant = data.get("cells")
	var hand: Variant = data.get("hand")
	if not cells is PackedByteArray or cells.size() != BoardManager.COUNT:
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
	board.cells = cells.duplicate()
	cutters.hand.assign(hand)
	cutters.generator.rng.seed = data.get("rng_seed", 0)
	cutters.generator.rng.state = data.get("rng_state", 0)
	return true
