extends SceneTree

const EPISODES := 150
const MAX_TURNS := 150
var output: Dictionary = {"date": "2026-10-22", "engine": Engine.get_version_info().string, "episodes_per_cohort": EPISODES, "turn_cap": MAX_TURNS, "note": "Seeded simulated sessions, not human retention or competitor playtests.", "cohorts": []}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var began := Time.get_ticks_msec()
	var rescue := "--rescue-only" in OS.get_cmdline_user_args()
	for cadence in ([3] if rescue else [3, 2]):
		for policy in ["random", "greedy"]:
			var sessions: Array = []
			for episode in EPISODES:
				sessions.append(simulate(episode, cadence, policy, rescue))
			var summary := summarize(sessions)
			summary.cadence = cadence
			summary.rescue_experiment = rescue
			summary.policy = policy
			summary.sessions = sessions
			output.cohorts.append(summary)
			var display := summary.duplicate()
			display.erase("sessions")
			print(JSON.stringify(display))
			await process_frame
	output.elapsed_seconds = (Time.get_ticks_msec() - began) / 1000.0
	var path := "res://docs/balance-rescue-experiment.json" if rescue else "res://docs/balance-audit.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(output, "\t"))
	print("Saved %s in %.1f seconds" % [path, output.elapsed_seconds])
	quit()

func simulate(episode: int, cadence: int, policy: String, rescue: bool = false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261022 + episode
	var choice_rng := RandomNumberGenerator.new()
	choice_rng.seed = 99 + episode
	var board := BoardManager.new()
	SpawnManager.seed_board(board, rng)
	var tray := CutterManager.refresh(board, [], rng)
	var incoming := SpawnManager.row(rng, 0)
	var data := {"seed": episode, "turns": 0, "score": 0, "ending": "cap", "start_cells": board.occupied(), "end_cells": 0, "cut_cells": 0, "match_cells": 0, "spawn_cells": 0, "rescue_rows": 0, "chain_moves": 0, "max_chain": 0, "raw_choices": 0, "tap_choices": 0, "shape_uses": [0, 0, 0]}
	for turn in MAX_TURNS:
		var actions: Array = []
		for i in tray.size():
			var seen := {}
			var raw := CutterManager.placements(board, tray[i])
			data.raw_choices += raw.size()
			for origin in CutterManager.target_map(board, tray[i]).values():
				if seen.has(origin):
					continue
				seen[origin] = true
				actions.append({"slot": i, "origin": origin})
			data.tap_choices += seen.size()
		if actions.is_empty():
			data.ending = "no_moves"
			break
		var chosen: Dictionary = actions[choice_rng.randi_range(0, actions.size() - 1)]
		if policy == "greedy":
			var best_value := -1
			for action in actions:
				var trial := BoardManager.new()
				trial.cells = board.snapshot()
				var hits := CutterManager.hits(trial, tray[action.slot], action.origin)
				trial.remove(hits)
				var result := ComboManager.resolve(trial)
				var value: int = ComboManager.cut_score(hits.size()) + result.score
				if value > best_value:
					best_value = value
					chosen = action
		var cutter: Dictionary = tray[chosen.slot]
		data.shape_uses[cutter.shape] += 1
		var hits := CutterManager.hits(board, cutter, chosen.origin)
		board.remove(hits)
		data.cut_cells += hits.size()
		data.score += ComboManager.cut_score(hits.size())
		var result := ComboManager.resolve(board)
		record_waves(data, result)
		data.turns += 1
		if data.turns % cadence == 0:
			if not SpawnManager.add_row(board, incoming):
				data.ending = "overflow"
				break
			data.spawn_cells += 7
			incoming = SpawnManager.row(rng, data.turns)
			record_waves(data, ComboManager.resolve(board))
		tray[chosen.slot] = {}
		tray = CutterManager.refresh(board, tray, rng)
		if tray.is_empty() and rescue:
			# An offline hypothesis only: a sparse board earns fresh jellies.
			for attempt in 3:
				if not SpawnManager.add_row(board, incoming):
					break
				data.spawn_cells += 7
				data.rescue_rows += 1
				incoming = SpawnManager.row(rng, data.turns)
				record_waves(data, ComboManager.resolve(board))
				tray = CutterManager.refresh(board, [], rng)
				if not tray.is_empty():
					break
		if tray.is_empty():
			data.ending = "no_moves"
			break
	data.end_cells = board.occupied()
	return data

func record_waves(data: Dictionary, result: Dictionary) -> void:
	data.score += result.score
	if result.waves.size() > 1:
		data.chain_moves += 1
	data.max_chain = maxi(data.max_chain, result.waves.size())
	for wave in result.waves:
		data.match_cells += wave.cells.size()

func summarize(sessions: Array) -> Dictionary:
	var turns: Array = sessions.map(func(s: Dictionary) -> int: return s.turns)
	turns.sort()
	var totals := {"no_moves": 0, "overflow": 0, "cap": 0, "turns": 0, "score": 0, "start_cells": 0, "end_cells": 0, "cut_cells": 0, "match_cells": 0, "spawn_cells": 0, "rescue_rows": 0, "chain_moves": 0, "raw_choices": 0, "tap_choices": 0}
	for s in sessions:
		totals[s.ending] += 1
		for key in ["turns", "score", "start_cells", "end_cells", "cut_cells", "match_cells", "spawn_cells", "rescue_rows", "chain_moves", "raw_choices", "tap_choices"]:
			totals[key] += s[key]
	return {"median_turns": turns[int(turns.size() / 2)], "p10_turns": turns[int(turns.size() * .1)], "p90_turns": turns[int(turns.size() * .9)], "mean_turns": float(totals.turns) / sessions.size(), "mean_score": float(totals.score) / sessions.size(), "mean_rescue_rows": float(totals.rescue_rows) / sessions.size(), "no_moves": totals.no_moves, "overflow": totals.overflow, "cap": totals.cap, "mean_end_cells": float(totals.end_cells) / sessions.size(), "cut_per_move": float(totals.cut_cells) / maxi(1, totals.turns), "matched_per_move": float(totals.match_cells) / maxi(1, totals.turns), "spawned_per_move": float(totals.spawn_cells) / maxi(1, totals.turns), "chain_events_per_move": float(totals.chain_moves) / maxi(1, totals.turns), "reachable_stamp_fraction": float(totals.tap_choices) / maxi(1, totals.raw_choices)}
