extends SceneTree

# v0.10 tension features: one-shot NEW BEST, resumable run record, honest
# lethal forecasts, peril state and the danger/game-over presentation.
#   tools/test.sh --stress
var checks := 0
var failures := 0
var temp_path := "/private/tmp/punch-pop-stress-%d.cfg" % Time.get_ticks_usec()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func _initialize() -> void:
	call_deferred("run")

func best_move(game) -> Dictionary:
	var chosen := {}
	var top := -1
	for slot in game.tray.size():
		if game.tray[slot].is_empty():
			continue
		for origin in CutterManager.placements(game.model.board, game.tray[slot]):
			var value: int = game.model.forecast(slot, origin).score
			if value > top:
				top = value
				chosen = {"slot": slot, "origin": origin}
	return chosen

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.save = SaveStore.new(temp_path)
	game.pressure_enabled = false
	root.add_child(game)
	await process_frame
	game.save.best = 150
	game.start_game()
	check(game.run_best == 150 and game.save.run_start_best == 150, "A run remembers the record it is chasing")

	# Play greedy punches past the record; NEW BEST must fire on one punch only.
	var announcements := 0
	var resumed_checked := false
	for turn in 40:
		if game.over:
			break
		var move := best_move(game)
		if move.is_empty():
			break
		game.celebration = ""
		game.select_cutter(move.slot)
		await game.place_cutter(move.origin)
		if game.celebration == "NEW BEST!":
			announcements += 1
		if game.score > 150 and not resumed_checked:
			resumed_checked = true
			# Reopening mid-run keeps the original record, although save.best rose.
			var reopened := SaveStore.new(temp_path)
			reopened.load_data()
			check(reopened.best == game.score, "The live record is saved at each checkpoint")
			check(reopened.run_start_best == 150, "The run's starting record survives a reopen")
		if game.score > 600 and announcements > 0:
			break
	check(game.score > 150, "Greedy play passes a small record")
	check(announcements == 1, "NEW BEST is announced exactly once per run (got %d)" % announcements)
	check(game.score > game.run_best, "The game-over card can still report a new best")

	# Peril: a column reaching the top row, with a row due on the next punch.
	var model: RoundModel = game.model
	model.board.clear()
	for y in BoardManager.HEIGHT:
		model.board.put(Vector2i(0, y), y % 4)
	for y in range(BoardManager.HEIGHT - 3, BoardManager.HEIGHT):
		for x in range(1, BoardManager.WIDTH):
			model.board.put(Vector2i(x, y), (x + y) % 4)
	model.meter = model.meter_capacity() - 1
	model.streak = 3
	model.tray = CutterManager.hand_refresh(model.board, [], model.rng)
	game.reset_transients()
	game.sync_model()
	check(game.peril == 3, "A filled top row is the highest peril")
	var lethal_seen := 0
	var safe_seen := 0
	var snapshot := model.snapshot()
	for slot in model.tray.size():
		if model.tray[slot].is_empty():
			continue
		for origin in CutterManager.placements(model.board, model.tray[slot]):
			var forecast := model.forecast(slot, origin)
			var trial := RoundModel.new()
			trial.restore(snapshot)
			trial.play(slot, origin)
			check(forecast.lethal == trial.over, "Lethal forecast matches the real outcome at %s" % origin)
			if forecast.lethal:
				lethal_seen += 1
			else:
				safe_seen += 1
	check(lethal_seen > 0 and safe_seen > 0, "The test board offers both fatal and escaping punches")
	game.tick_heartbeat(2.0)
	check(game.heartbeat_time > 0, "The heartbeat runs in peril")
	# Draw the peril HUD, aiming preview and near-miss game over.
	game.overlay = ""
	for frame in 3:
		await process_frame
	check(not game.ui.style_cache.is_empty(), "The HUD is drawn headlessly")
	# Lessons are anchored to the board bottom at any size.
	for lesson in 3:
		game.reset_transients()
		model.reset(5, lesson)
		game.sync_model()
		var goal := LessonBook.goal(lesson)
		check(BoardManager.new().inside(goal), "Lesson %d goal is on the board" % lesson)
		check(not model.forecast(0, goal).is_empty(), "Lesson %d teaching punch is legal" % lesson)
	var chain := model.forecast(0, LessonBook.goal(2))
	check(chain.waves >= 2, "The chain lesson still chains")
	game.run_best = game.score + 40
	game.overlay = "over"
	for frame in 3:
		await process_frame
	game.reset_transients()
	model.reset(99)
	game.sync_model()
	check(game.peril == 0 and not game.brink, "A fresh board is calm")
	game.queue_free()
	DirAccess.remove_absolute(temp_path)
	print("Punch Pop stress: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
