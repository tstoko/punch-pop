extends SceneTree

var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func verify(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func run() -> void:
	var save_path := "user://test_real_clock_%d.cfg" % Time.get_ticks_usec()
	var began := Time.get_ticks_msec()
	var game = load("res://scenes/main.tscn").instantiate()
	game.save = SaveStore.new(save_path)
	game.pressure_enabled = false
	root.add_child(game)
	await process_frame
	game.reset_transients()
	game.model.reset(20261022)
	game.sync_model()
	game.checkpoint()
	game.pressure_enabled = true
	# Let the actual _process delta drive expiry. No manual clock stepping.
	while (game.model.timed_rows < 1 or game.busy) and Time.get_ticks_msec() - began < 15000:
		await process_frame
	verify(game.model.timed_rows == 1 and not game.busy, "Actual frame clock presents its first timed rise")
	verify(game.turns == 0 and game.score == 0, "Waiting spends no moves and farms no points")
	verify(game.board.snapshot() == game.model.board.snapshot(), "Live upward animation settles on the calculated board")
	game.overlay = "pause"
	var paused: float = game.model.rise_remaining
	await create_timer(.65).timeout
	verify(is_equal_approx(game.model.rise_remaining, paused), "Actual frame processing leaves a paused clock unchanged")
	game.overlay = ""
	await create_timer(1.1).timeout
	game.overlay = "pause"
	game.checkpoint()
	var saved: Dictionary = game.model.snapshot()
	verify(saved.rise_remaining < paused and saved.rise_remaining > 0, "Resuming consumes real decision time")
	game.queue_free()
	await process_frame
	var resumed = load("res://scenes/main.tscn").instantiate()
	resumed.save = SaveStore.new(save_path)
	root.add_child(resumed)
	await process_frame
	verify(resumed.overlay == "resume", "Cold reload waits for Continue")
	verify(resumed.board.snapshot() == saved.cells and str(resumed.model.rng.state) == saved.rng_state, "Cold reload preserves board and RNG")
	verify(is_equal_approx(resumed.model.rise_remaining, saved.rise_remaining), "Partial real-time countdown survives disk serialization")
	await create_timer(.5).timeout
	verify(is_equal_approx(resumed.model.rise_remaining, saved.rise_remaining), "Resume screen does not charge offline or menu time")
	resumed.overlay_press(resumed.replay_rect.get_center())
	while not resumed.over and Time.get_ticks_msec() - began < 45000:
		await process_frame
	verify(resumed.over and resumed.overlay == "over" and resumed.model.end_reason == "timer", "Unattended real-time play reaches a timer ceiling loss")
	verify(resumed.model.timed_rows == 3 and resumed.turns == 0 and resumed.score == 0, "Three timer expiries defeat the untouched opening without free score")
	verify(is_equal_approx(resumed.model.active_seconds, 24), "Only 24 seconds of decision time were charged across pause and reload")
	var disk := SaveStore.new(save_path)
	disk.load_data()
	verify(disk.round_data.is_empty(), "Completed timer death clears the resumable round")
	var report := {"date": "2026-10-22", "scope": "Headless real frame clock; no desktop window or renderer measurement", "checks": checks, "failures": failures, "wall_seconds": (Time.get_ticks_msec() - began) / 1000.0, "active_seconds": resumed.model.active_seconds, "timed_expiries": resumed.model.timed_rows, "score": resumed.score, "turns": resumed.turns, "end_reason": resumed.model.end_reason}
	var file := FileAccess.open("res://docs/v4-runtime-smoke.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	resumed.queue_free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(save_path)
	print("Punch Pop real clock: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)
