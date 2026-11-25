class_name GameBalance
extends Resource

@export var cell_points: int = 10
@export var line_points := PackedInt32Array([0, 100, 300, 600, 1200])
@export var extra_line_points: int = 600
@export var full_board_points: int = 5000
@export var streak_multipliers := PackedInt32Array([1, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
@export var difficulty_scores := PackedInt32Array([0, 5000, 20000, 50000, 100000])
