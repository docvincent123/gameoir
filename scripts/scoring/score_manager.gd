class_name ScoreManager
extends RefCounted

static func points(cells: int, lines: int, streak: int, full_board: bool, balance: GameBalance) -> int:
	var last_index := balance.line_points.size() - 1
	var line_bonus := balance.line_points[mini(lines, last_index)]
	line_bonus += maxi(0, lines - last_index) * balance.extra_line_points
	var score := cells * balance.cell_points + line_bonus * ComboManager.multiplier(streak, balance)
	return score + (balance.full_board_points if full_board else 0)
