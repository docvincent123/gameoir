class_name ComboManager
extends RefCounted

static func multiplier(streak: int, balance: GameBalance) -> int:
	return balance.streak_multipliers[clampi(streak, 0, balance.streak_multipliers.size() - 1)]

static func caption(streak: int) -> StringName:
	if streak >= 10:
		return &"COMBO_LEGENDARY"
	if streak >= 8:
		return &"COMBO_MEGA"
	if streak >= 6:
		return &"COMBO_SUPER"
	return &"COMBO"
