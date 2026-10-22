extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func outcome(board: BoardManager, cutter: Dictionary, origin: Vector2i) -> String:
	var trial := BoardManager.new()
	trial.cells = board.snapshot()
	var hits := CutterManager.hits(trial, cutter, origin)
	trial.remove(hits)
	var score: int = ComboManager.cut_score(hits.size()) + ComboManager.resolve(trial).score
	return JSON.stringify(trial.cells) + ":" + str(score)

func run() -> void:
	var raw_count := 0
	var accessible_count := 0
	var positions := 0
	var affected := 0
	var example := {}
	for seed_value in 60:
		var rng := RandomNumberGenerator.new()
		rng.seed = 20261022 + seed_value
		var board := BoardManager.new()
		SpawnManager.seed_board(board, rng)
		var tray := CutterManager.refresh(board, [], rng)
		var incoming := SpawnManager.row(rng, 0)
		for turn in 20:
			if tray.is_empty():
				break
			for cutter in tray:
				var raw := {}
				var reachable := {}
				for origin in CutterManager.placements(board, cutter):
					raw[outcome(board, cutter, origin)] = origin
				for origin in CutterManager.target_map(board, cutter).values():
					reachable[outcome(board, cutter, origin)] = origin
				raw_count += raw.size()
				accessible_count += reachable.size()
				positions += 1
				if raw.size() > reachable.size():
					affected += 1
					if example.is_empty():
						for key in raw:
							if not reachable.has(key):
								var origin: Vector2i = raw[key]
								example = {"seed": seed_value, "turn": turn, "board": board.snapshot(), "cutter": cutter, "inaccessible_origin": [origin.x, origin.y], "distinct_results": raw.size(), "reachable_results": reachable.size()}
								break
			var cutter: Dictionary = tray[0]
			var targets := CutterManager.target_map(board, cutter)
			var origins := targets.values()
			var origin: Vector2i = origins[rng.randi_range(0, origins.size() - 1)]
			board.remove(CutterManager.hits(board, cutter, origin))
			ComboManager.resolve(board)
			if (turn + 1) % 3 == 0:
				if not SpawnManager.add_row(board, incoming):
					break
				incoming = SpawnManager.row(rng, turn + 1)
				ComboManager.resolve(board)
			tray[0] = {}
			tray = CutterManager.refresh(board, tray, rng)
	var result := {"date": "2026-10-22", "seeds": 60, "max_turns": 20, "cutter_positions_examined": positions, "distinct_board_and_score_results": raw_count, "reachable_distinct_results": accessible_count, "reachable_fraction": float(accessible_count) / maxi(1, raw_count), "positions_with_hidden_results": affected, "example": example, "note": "Distinct results compare the settled board plus score for a single cutter before the incoming row. This is not a measure of player skill or enjoyment."}
	var file := FileAccess.open("res://docs/choice-audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "\t"))
	print(JSON.stringify(result))
	quit()
