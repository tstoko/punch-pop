extends SceneTree

const EPISODES := 40
const CAP := 150

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var result := {"rules": "v0.7.1 faster pressure + restricted multi-wave credit", "date": "2026-10-23", "action_space": "all legal drag placements, including deliberate partial punches", "episodes_per_policy": EPISODES, "cap": CAP, "cohorts": [], "opening_affordances": opening_affordances()}
	var began := Time.get_ticks_msec()
	for profile in [{"policy": "random", "think": 3.0}, {"policy": "greedy", "think": 3.0}, {"policy": "height_aware", "think": 3.0}, {"policy": "height_aware", "think": 0.0}, {"policy": "height_aware", "think": 6.0}, {"policy": "height_aware", "think": 1.5}]:
		var policy: String = profile.policy
		var sessions: Array = []
		for episode in EPISODES:
			var model := RoundModel.new()
			model.reset(20261022 + episode)
			var choices := RandomNumberGenerator.new()
			choices.seed = episode + 99
			var data := {"seed": episode, "turns": 0, "score": 0, "end": "cap", "chain_moves": 0, "match_moves": 0, "timer_match_waves": 0, "refill_match_waves": 0, "earned_seconds": 0.0, "best_chain": 0, "fresh_batches": 0, "stuck": false, "active_seconds": 0.0, "timed_rows": 0}
			for turn in CAP:
				var thinking: float = profile.think
				while thinking > 0 and not model.over:
					var spent := minf(thinking, model.rise_remaining)
					thinking -= spent
					if model.advance_clock(spent):
						for event in model.expire_clock():
							if event.type == "pop" and event.wave > 0:
								if event.source == "new_row":
									data.timer_match_waves += 1
								elif event.source == "refill":
									data.refill_match_waves += 1
				if model.over:
					data.end = "overflow"
					break
				var actions: Array = []
				for slot in 3:
					if model.tray[slot].is_empty():
						continue
					for origin in CutterManager.placements(model.board, model.tray[slot]):
						actions.append({"slot": slot, "origin": origin})
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
				if events.any(func(e: Dictionary) -> bool: return e.type == "pop" and e.wave >= 1 and e.source == "cut"):
					data.match_moves += 1
				if events.any(func(e: Dictionary) -> bool: return e.type == "pop" and e.wave >= 2 and e.source == "cut"):
					data.chain_moves += 1
				for event in events:
					if event.type == "pop" and event.wave > 0 and event.source == "refill":
						data.refill_match_waves += 1
					elif event.type == "breathing":
						data.earned_seconds += event.seconds
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
		var match_moves := 0
		var timer_waves := 0
		var refill_waves := 0
		var earned_seconds := 0.0
		var chain_runs := 0
		var stuck := 0
		var capped := 0
		for s in sessions:
			total_turns += s.turns
			total_score += s.score
			chain_moves += s.chain_moves
			match_moves += s.match_moves
			timer_waves += s.timer_match_waves
			refill_waves += s.refill_match_waves
			earned_seconds += s.earned_seconds
			chain_runs += 1 if s.chain_moves > 0 else 0
			stuck += 1 if s.stuck else 0
			capped += 1 if s.end == "cap" else 0
		var cohort := {"policy": policy, "decision_seconds": profile.think, "median_moves": turns[EPISODES / 2], "p10_moves": turns[EPISODES / 10], "p90_moves": turns[EPISODES * 9 / 10], "mean_moves": float(total_turns) / EPISODES, "mean_score": float(total_score) / EPISODES, "cut_match_moves_per_100": float(match_moves) / maxi(1, total_turns) * 100, "timer_match_waves": timer_waves, "refill_match_waves": refill_waves, "earned_seconds": earned_seconds, "chain_moves_per_100": float(chain_moves) / maxi(1, total_turns) * 100, "runs_with_cut_chain": chain_runs, "stuck_runs": stuck, "capped_runs": capped, "sessions": sessions}
		var uncapped: Array = sessions.filter(func(s: Dictionary) -> bool: return s.end != "cap").map(func(s: Dictionary) -> int: return s.turns)
		uncapped.sort()
		cohort.uncapped_runs = uncapped.size()
		cohort.uncapped_median_moves = uncapped[uncapped.size() / 2] if not uncapped.is_empty() else null
		result.cohorts.append(cohort)
		var summary := cohort.duplicate()
		summary.erase("sessions")
		print(JSON.stringify(summary))
	result.elapsed_seconds = (Time.get_ticks_msec() - began) / 1000.0
	var file := FileAccess.open("res://docs/v7-1-pressure-audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print("Saved docs/v7-1-pressure-audit.json")
	quit()

# Count available opening choices independently of any bot decision policy.
func opening_affordances() -> Dictionary:
	var report := {"seeds": 100, "all_three_shapes": 0, "seeds_with_perfect": 0, "seeds_with_match": 0, "seeds_with_multiwave": 0, "minimum_legal_placements": 100000}
	var reset_ms: Array = []
	for seed_value in 100:
		var model := RoundModel.new()
		var began := Time.get_ticks_usec()
		model.reset(20261022 + seed_value)
		reset_ms.append((Time.get_ticks_usec() - began) / 1000.0)
		var shapes := {}
		var has_perfect := false
		var has_match := false
		var has_chain := false
		var count := 0
		for slot in model.tray.size():
			if model.tray[slot].is_empty():
				continue
			shapes[model.tray[slot].shape] = true
			for origin in CutterManager.placements(model.board, model.tray[slot]):
				count += 1
				var forecast := model.forecast(slot, origin)
				has_perfect = has_perfect or forecast.get("perfect", false)
				has_match = has_match or forecast.waves >= 1
				has_chain = has_chain or forecast.waves >= 2
		report.all_three_shapes += int(shapes.size() == 3)
		report.seeds_with_perfect += int(has_perfect)
		report.seeds_with_match += int(has_match)
		report.seeds_with_multiwave += int(has_chain)
		report.minimum_legal_placements = mini(report.minimum_legal_placements, count)
	reset_ms.sort()
	report.reset_ms = {"median": reset_ms[50], "p95": reset_ms[95], "maximum": reset_ms.back(), "samples": reset_ms.size()}
	return report
