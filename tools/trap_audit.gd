extends SceneTree

# Trap audit: at near-death moments, is the flashiest move (most blocks
# matched, i.e. the brightest preview glow) ever the wrong one?
# For each legal move we play it, then continue with a careful height-aware
# policy for HORIZON moves on a copy. The RNG is in the snapshot, so every
# rollout sees the same future rows and hands: survival is deterministic.
#   tools/run.sh --headless --script res://tools/trap_audit.gd -- --games=30
const HORIZON := 6
var games := 30

func _initialize() -> void:
	call_deferred("run")

func careful_value(model: RoundModel, slot: int, origin: Vector2i) -> float:
	var prediction := model.forecast(slot, origin, true)
	var trial := BoardManager.new()
	trial.cells = prediction.cells
	var tallest := 0
	var roughness := 0
	var previous := 0
	for x in BoardManager.WIDTH:
		var h := SupplySystem.height(trial, x)
		tallest = maxi(tallest, h)
		if x > 0:
			roughness += absi(h - previous)
		previous = h
	var value: float = prediction.score - 80 * tallest - 20 * roughness - 6 * trial.occupied()
	return value - (100000 if prediction.lethal else 0)

func moves(model: RoundModel) -> Array:
	var result: Array = []
	for slot in 3:
		if model.tray[slot].is_empty():
			continue
		for origin in CutterManager.placements(model.board, model.tray[slot]):
			result.append({"slot": slot, "origin": origin})
	return result

func careful_move(model: RoundModel) -> Dictionary:
	var best := {}
	var top := -1e12
	for move in moves(model):
		var value := careful_value(model, move.slot, move.origin)
		if value > top:
			top = value
			best = move
	return best

# Moves survived after this one (HORIZON means it survived the whole window).
func survival(snapshot: Dictionary, move: Dictionary) -> int:
	var trial := RoundModel.new()
	trial.restore(snapshot)
	trial.play(move.slot, move.origin)
	for step in HORIZON:
		if trial.over:
			return step
		var next := careful_move(trial)
		if next.is_empty():
			return step
		trial.play(next.slot, next.origin)
	return HORIZON if not trial.over else HORIZON - 1

func run() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--games="):
			games = int(argument.trim_prefix("--games="))
	CutterManager.full_footprint = true
	CutterManager.shape_count = 4
	var brink_states := 0
	var doomed := 0
	var tight := 0
	var tight_flashy_ok := 0
	var flashy_dies := 0
	var flashy_dies_with_matches := 0
	var flashy_lethal_flagged := 0
	var lethal_now := 0
	var any_match_states := 0
	var survivors_hist := {}
	for game in games:
		var model := RoundModel.new()
		model.reset(20261102 + game)
		for turn in 400:
			if model.over:
				break
			var options := moves(model)
			if options.is_empty():
				break
			if SupplySystem.tallest(model.board) >= BoardManager.HEIGHT - 1:
				brink_states += 1
				var snapshot := model.snapshot()
				var flashy := {}
				var flashy_key := Vector2i(-1, -1)
				var alive := 0
				var outcomes := {}
				for move in options:
					var forecast := model.forecast(move.slot, move.origin)
					var key := Vector2i(forecast.matched, forecast.score)
					if key.x > flashy_key.x or (key.x == flashy_key.x and key.y > flashy_key.y):
						flashy_key = key
						flashy = move
					var lived := survival(snapshot, move)
					outcomes[move] = lived
					if lived >= HORIZON:
						alive += 1
				var share := float(alive) / options.size()
				var bucket := "0" if alive == 0 else "1-2" if alive <= 2 else "<25%" if share < .25 else "<50%" if share < .5 else ">=50%"
				survivors_hist[bucket] = survivors_hist.get(bucket, 0) + 1
				if flashy_key.x > 0:
					any_match_states += 1
				if alive == 0:
					doomed += 1
				else:
					if alive <= 2 or share < .25:
						tight += 1
						if outcomes[flashy] >= HORIZON:
							tight_flashy_ok += 1
					if outcomes[flashy] < HORIZON:
						flashy_dies += 1
						if flashy_key.x > 0:
							flashy_dies_with_matches += 1
						if model.forecast(flashy.slot, flashy.origin).lethal:
							flashy_lethal_flagged += 1
							if outcomes[flashy] == 0:
								lethal_now += 1
			var chosen := careful_move(model)
			model.play(chosen.slot, chosen.origin)
		await process_frame
	print("Board %dx%d, %d games, horizon %d moves" % [BoardManager.WIDTH, BoardManager.HEIGHT, games, HORIZON])
	print("Brink states (a column one row from the top or at it): %d" % brink_states)
	print("  surviving-move share histogram: %s" % survivors_hist)
	print("  already doomed (no move survives the horizon): %d" % doomed)
	print("  tight (1-2 survivors or <25%% of moves): %d, flashiest move survives in %d" % [tight, tight_flashy_ok])
	print("  states with a match available: %d" % any_match_states)
	print("  flashiest move dies but another survives: %d (with a real match glow: %d)" % [flashy_dies, flashy_dies_with_matches])
	print("    of those, already flagged THIS PUNCH ENDS THE RUN: %d (immediate death %d)" % [flashy_lethal_flagged, lethal_now])
	print("Trap audit complete")
	quit()
