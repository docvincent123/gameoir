class_name LeaderboardProvider
extends RefCounted

# A remote adapter can use these identifiers after configuring a service.
static func category(run: GameManager) -> String:
	if run.mode == GameManager.DAILY:
		return "daily/" + run.day
	return "assisted" if run.used_continue else "endless"

static func daily_seed(day: String) -> int:
	# ISO date is supplied in UTC. The numeric seed is stable across platforms.
	return 20261001 ^ int(day.replace("-", "")) ^ 0x43CF01

func submit(_category: String, _score: int, _snapshot: Dictionary) -> bool:
	return false
