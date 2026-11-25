class_name ShapeGenerator
extends RefCounted

const EMPTY := ""

var shapes: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _init() -> void:
	for pattern: Array in ShapePatterns.PATTERNS:
		var points: Array[Vector2i] = []
		var layers: Array = pattern[2]
		for y in layers.size():
			var line: String = layers[y]
			for x in line.length():
				if line[x] == "#":
					points.append(Vector2i(x, y))
		var seen: Array[String] = []
		for rotation in 4:
			var normalized := normalize(points)
			var signature := str(normalized)
			if signature not in seen:
				seen.append(signature)
				var bounds := Vector2i.ONE
				for p in normalized:
					bounds = bounds.max(p + Vector2i.ONE)
				var id := "%s_%d" % [pattern[0], rotation]
				shapes[id] = {"cells": normalized, "size": bounds, "tier": pattern[1]}
			for i in points.size():
				points[i] = Vector2i(-points[i].y, points[i].x)

static func normalize(points: Array[Vector2i]) -> Array[Vector2i]:
	var top_left := points[0]
	for p in points:
		top_left = top_left.min(p)
	var result: Array[Vector2i] = []
	for p in points:
		result.append(p - top_left)
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y * 8 + a.x < b.y * 8 + b.x)
	return result

func draw_hand(board: BoardManager, tier: int) -> Array[String]:
	var pool: Array[String] = []
	var weights := PackedFloat32Array()
	for id: String in shapes:
		var form: Dictionary = shapes[id]
		var difficulty: int = form.tier
		if difficulty > tier:
			continue
		var weight := 1.7 if difficulty == tier else 0.8
		if tier > 0 and id == "single_0":
			weight = 0.42
		elif id.begins_with("stitch_"):
			weight = 0.09
		pool.append(id)
		weights.append(weight)
	var hand: Array[String] = []
	for slot in 3:
		hand.append(pool[rng.rand_weighted(weights)])
	if has_move(board, hand):
		return hand
	var feasible: Array[String] = []
	var feasible_weights := PackedFloat32Array()
	for i in pool.size():
		var form: Dictionary = shapes[pool[i]]
		if board.has_placement(form.cells, form.size):
			feasible.append(pool[i])
			feasible_weights.append(weights[i])
	if not feasible.is_empty():
		hand[rng.randi_range(0, 2)] = feasible[rng.rand_weighted(feasible_weights)]
	return hand

func has_move(board: BoardManager, hand: Array[String]) -> bool:
	for id in hand:
		if id != EMPTY and board.has_placement(shapes[id].cells, shapes[id].size):
			return true
	return false
