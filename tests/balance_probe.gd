extends SceneTree
# godot --headless --path . --script tests/balance_probe.gd
# Deterministic greedy bot: diagnostics, not human playtest data.
func _initialize() -> void:
	call_deferred("simulate")

func simulate() -> void:
	var scores: Array[int] = []
	var capped := 0
	for seed in 200:
		var run := GameManager.new()
		run.start(GameManager.ENDLESS, "", seed + 1)
		for move in 500:
			if run.ended:
				break
			var hint := run.coaching_hint()
			if hint.is_empty():
				break
			run.play(hint.slot, hint.origin)
		if not run.ended:
			capped += 1
		scores.append(run.score)
	scores.sort()
	print("Greedy 200 seeds / 500 move cap: median=", scores[100], " p90=", scores[180], " max=", scores[-1], " capped=", capped)
	quit()
