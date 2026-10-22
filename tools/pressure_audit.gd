extends SceneTree

const EPISODES := 40
const CAP := 150

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var result := {"rules": "v5 single timed rise + recovery only + varied openings", "date": "2026-10-23", "episodes_per_policy": EPISODES, "cap": CAP, "cohorts": []}
	var began := Time.get_ticks_msec()
	for profile in [{"policy": "random", "think": 3.0}, {"policy": "greedy", "think": 3.0}, {"policy": "height_aware", "think": 3.0}, {"policy": "height_aware", "think": 0.0}, {"policy": "height_aware", "think": 6.0}]:
		var policy: String = profile.policy
		var sessions: Array = []
		for episode in EPISODES:
			var model := RoundModel.new()
			model.reset(20261022 + episode)
			var choices := RandomNumberGenerator.new()
			choices.seed = episode + 99
			var data := {"seed": episode, "turns": 0, "score": 0, "end": "cap", "chain_moves": 0, "best_chain": 0, "fresh_batches": 0, "stuck": false, "active_seconds": 0.0, "timed_rows": 0}
			for turn in CAP:
				var thinking: float = profile.think
				while thinking > 0 and not model.over:
					var spent := minf(thinking, model.rise_remaining)
					thinking -= spent
					if model.advance_clock(spent):
						model.expire_clock()
				if model.over:
					data.end = "overflow"
					break
				var actions: Array = []
				for slot in 3:
					var seen := {}
					for origin in CutterManager.target_map(model.board, model.tray[slot]).values():
						if not seen.has(origin):
							actions.append({"slot": slot, "origin": origin})
							seen[origin] = true
				if actions.is_empty():
					data.stuck = true
					break
				var chosen: Dictionary = actions[choices.randi_range(0, actions.size() - 1)]
				if policy != "random":
					var best_value := -1000000
					for action in actions:
						var prediction := model.forecast(action.slot, action.origin, policy == "height_aware")
						var value: int = prediction.score
						if policy == "height_aware":
							var trial := BoardManager.new()
							trial.cells = prediction.cells
							var tallest := 0
							var roughness := 0
							var previous := 0
							for x in 7:
								var h := SupplySystem.height(trial, x)
								tallest = maxi(tallest, h)
								if x > 0:
									roughness += absi(h - previous)
								previous = h
							value -= 80 * tallest + 20 * roughness
						if value > best_value:
							best_value = value
							chosen = action
				var events := model.play(chosen.slot, chosen.origin)
				if events.any(func(e: Dictionary) -> bool: return e.type == "pop" and e.wave >= 2):
					data.chain_moves += 1
				if model.over:
					data.end = "overflow"
					break
			data.active_seconds = model.active_seconds
			data.timed_rows = model.timed_rows
			data.turns = model.turns
			data.score = model.score
			data.best_chain = model.best_combo
			data.fresh_batches = model.fresh_batches
			sessions.append(data)
			if episode % 10 == 0:
				await process_frame
		var turns: Array = sessions.map(func(s: Dictionary) -> int: return s.turns)
		turns.sort()
		var total_turns := 0
		var total_score := 0
		var chain_moves := 0
		var chain_runs := 0
		var stuck := 0
		var capped := 0
		for s in sessions:
			total_turns += s.turns
			total_score += s.score
			chain_moves += s.chain_moves
			chain_runs += 1 if s.best_chain >= 2 else 0
			stuck += 1 if s.stuck else 0
			capped += 1 if s.end == "cap" else 0
		var cohort := {"policy": policy, "decision_seconds": profile.think, "median_moves": turns[EPISODES / 2], "p10_moves": turns[EPISODES / 10], "p90_moves": turns[EPISODES * 9 / 10], "mean_moves": float(total_turns) / EPISODES, "mean_score": float(total_score) / EPISODES, "chain_moves_per_100": float(chain_moves) / maxi(1, total_turns) * 100, "runs_with_chain": chain_runs, "stuck_runs": stuck, "capped_runs": capped, "sessions": sessions}
		result.cohorts.append(cohort)
		var summary := cohort.duplicate()
		summary.erase("sessions")
		print(JSON.stringify(summary))
	result.elapsed_seconds = (Time.get_ticks_msec() - began) / 1000.0
	var file := FileAccess.open("res://docs/v5-pressure-audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("Saved docs/v5-pressure-audit.json")
	quit()
