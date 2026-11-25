class_name DifficultyManager
extends RefCounted

const RANKS := [&"RANK_BEGINNER", &"RANK_MASTER", &"RANK_LEGEND", &"RANK_GOD", &"RANK_INFINITE"]
const MATERIALS := [0, 1, 2, 3, 4]

static func tier(score: int, balance: GameBalance) -> int:
	for rank in range(balance.difficulty_scores.size() - 1, 0, -1):
		if score >= balance.difficulty_scores[rank]:
			return rank
	return 0
