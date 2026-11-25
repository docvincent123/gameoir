class_name CutterManager
extends RefCounted

var generator := ShapeGenerator.new()
var hand: Array[String] = [ShapeGenerator.EMPTY, ShapeGenerator.EMPTY, ShapeGenerator.EMPTY]

func deal(board: BoardManager, tier: int) -> void:
	hand = generator.draw_hand(board, tier)

func consume(slot: int, board: BoardManager, tier: int) -> void:
	hand[slot] = ShapeGenerator.EMPTY
	if hand.count(ShapeGenerator.EMPTY) == hand.size():
		deal(board, tier)

func has_move(board: BoardManager) -> bool:
	return generator.has_move(board, hand)

func shape(slot: int) -> Dictionary:
	if slot < 0 or slot >= hand.size():
		return {}
	return generator.shapes.get(hand[slot], {})
