extends SceneTree

var checks := 0
var failures := 0
var temp_path := "/private/tmp/punch-pop-v7-flow-%d.cfg" % Time.get_ticks_usec()

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.save = SaveStore.new(temp_path)
	game.pressure_enabled = false
	root.add_child(game)
	await process_frame
	check(game.overlay == "home", "Launch presents the starting menu")
	var initial_time: float = game.model.rise_remaining
	game.tick_pressure(5)
	check(is_equal_approx(game.model.rise_remaining, initial_time), "Home spends no decision time")
	game.overlay_press(Vector2(270, 816))
	check(game.overlay == "settings", "Home opens settings")
	game.overlay_press(game.replay_rect.get_center())
	check(game.overlay == "home", "Settings return to their opening menu")
	game.overlay_press(Vector2(270, 602))
	check(game.model.lesson == -1 and game.overlay.is_empty(), "Main Play starts arcade directly")
	check(not game.save.explain_clears, "Fresh installs default to fast presentation")
	var boards := {}
	for seed_value in 24:
		game.reset_transients()
		game.model.reset(7300 + seed_value)
		game.sync_model()
		boards[hash(game.board.snapshot())] = true
		var shapes := {}
		for slot in game.tray.size():
			var cutter: Dictionary = game.tray[slot]
			check(not cutter.is_empty() and cutter.color == -1, "Opening punch ignores colour")
			if cutter.is_empty():
				continue
			shapes[cutter.shape] = true
			game.select_cutter(slot)
			var reachable := false
			var perfect := false
			for origin in game.aim_targets:
				var pointer := pointer_for(game, origin, cutter)
				if game.card_drag_origin(pointer) == origin:
					reachable = true
					perfect = perfect or game.model.forecast(slot, origin).get("perfect", false)
			check(reachable, "Every offered shape has a reachable drag placement")
			check(perfect, "Every offered shape can make a reachable perfect punch")
		check(shapes.size() == 3, "Opening offers all three different shapes")
	check(boards.size() >= 20, "Opening terrain varies across seeded rounds")
	# Exercise the actual press/move/release path on a mixed-colour full stamp.
	game.reset_transients()
	game.model.reset(7300)
	game.model.board.clear()
	for x in 7:
		game.model.board.put(Vector2i(x, 8), x % 4)
	game.model.tray = [{"shape": 1, "color": -1}, {"shape": 0, "color": -1}, {"shape": 2, "color": -1}]
	game.model.selected = 0
	game.sync_model()
	var target := Vector2i(1, 8)
	var predicted: Dictionary = game.model.forecast(0, target)
	check(predicted.get("hits", []).size() == 3, "Mixed colours are all directly punched")
	var pointer := pointer_for(game, target, game.tray[0])
	game.press(Vector2(126, 925))
	game.move_pointer(pointer)
	check(game.drag_origin == target, "Above-finger preview reaches the bottom-row stamp")
	game.release(pointer)
	await settle(game)
	check(game.turns == 1, "Releasing a wildcard drag commits exactly one turn")
	check(game.tray[0].is_empty(), "A spent punch stays empty while the hand has other legal shapes")
	check(not game.tray[game.selected].is_empty(), "Selection advances to an available punch after spending a card")
	check(RoundModel.valid(game.model.snapshot()), "A partial hand checkpoints with a valid selected punch")
	check(game.score >= predicted.score, "Live score includes the previewed wildcard perfect cut")
	# Follow a continuous downward drag: hysteresis must not strand a line above
	# the bottom row while the finger remains safely above the card tray.
	game.reset_transients()
	game.model.reset(7301)
	game.model.board.clear()
	for y in [7, 8]:
		for x in 7:
			game.model.board.put(Vector2i(x, y), (x + y) % 4)
	game.model.tray = [{"shape": 1, "color": -1}, {"shape": 0, "color": -1}, {"shape": 2, "color": -1}]
	game.model.selected = 0
	game.sync_model()
	var upper_pointer := pointer_for(game, Vector2i(1, 7), game.tray[0])
	var lower_pointer := pointer_for(game, Vector2i(1, 8), game.tray[0])
	game.press(Vector2(126, 925))
	game.move_pointer(upper_pointer)
	check(game.drag_origin == Vector2i(1, 7), "A line drag first acquires the penultimate row")
	for y in range(int(upper_pointer.y), int(lower_pointer.y) + 1, 2):
		game.move_pointer(Vector2(lower_pointer.x, y))
	game.move_pointer(lower_pointer)
	check(game.drag_origin == Vector2i(1, 8) and lower_pointer.y < 862, "Continuous drag reaches the bottom row before returning to the tray")
	game.cancel_gesture()
	# A real chain earns time; undo must remove its bonus and retain time spent.
	var found_chain := false
	for seed_value in 100:
		game.reset_transients()
		game.model.reset(8100 + seed_value)
		game.model.rise_remaining = 3.0
		game.sync_model()
		var slot_found := -1
		var origin_found := Vector2i.ZERO
		var forecast: Dictionary = {}
		for slot in game.tray.size():
			for origin in CutterManager.placements(game.board, game.tray[slot]):
				var next: Dictionary = game.model.forecast(slot, origin)
				if next.get("time_bonus", 0.0) > 0:
					slot_found = slot
					origin_found = origin
					forecast = next
					break
			if slot_found >= 0:
				break
		if slot_found < 0:
			continue
		found_chain = true
		game.select_cutter(slot_found)
		var before: Dictionary = game.model.snapshot()
		await game.place_cutter(origin_found)
		check(is_equal_approx(game.model.rise_remaining, 3.0 + forecast.time_bonus), "A live cut grants the predicted breathing time")
		game.model.advance_clock(.5)
		game.checkpoint()
		var reloaded := SaveStore.new(temp_path)
		reloaded.load_data()
		check(is_equal_approx(reloaded.round_data.rise_remaining, game.model.rise_remaining), "Disk checkpoint keeps earned time and elapsed thinking")
		var resumed = load("res://scenes/main.tscn").instantiate()
		resumed.save = SaveStore.new(temp_path)
		resumed.pressure_enabled = false
		root.add_child(resumed)
		await process_frame
		check(resumed.overlay == "home" and resumed.has_saved_round(), "Reloaded chain checkpoint waits on the Continue menu")
		resumed.undo_move()
		check(resumed.model.board.snapshot() == before.cells, "Reloaded undo restores the pre-chain board")
		check(is_equal_approx(resumed.model.rise_remaining, 2.5), "Reloaded undo strips time credit and retains thinking time")
		resumed.queue_free()
		await process_frame
		game.undo_move()
		check(game.model.board.snapshot() == before.cells and game.model.score == before.score, "Undo restores the chain's original board and score")
		check(is_equal_approx(game.model.rise_remaining, 2.5), "Undo removes earned breathing time without refunding thinking")
		check(is_equal_approx(game.model.active_seconds, .5), "Undo preserves active decision time")
		break
	check(found_chain, "Seeded openings contain a rewarding chain opportunity")
	# A legacy fast-clock endless save migrates to punches without restarting it.
	var legacy := RoundModel.new()
	legacy.reset(9100)
	legacy.board.clear()
	var old_row := [0, 1, 0, 2, 3, 2, 1]
	for x in old_row.size():
		legacy.board.put(Vector2i(x, 8), old_row[x])
	legacy.tray = [{"shape": 1, "color": 0}, {"shape": 0, "color": 0}, {"shape": 2, "color": 0}]
	legacy.selected = 0
	legacy.score = 1234
	legacy.active_seconds = 87.5
	legacy.rise_period = 3.5
	legacy.rise_remaining = 1.25
	var old_save: Dictionary = legacy.snapshot()
	old_save.version = 3
	var migrated := RoundModel.new()
	check(migrated.restore(old_save), "A valid v3 coloured save with a 3.5-second period still loads")
	check(migrated.tray[0].color == -1 and migrated.score == 1234 and migrated.board.snapshot() == old_save.cells, "Migration preserves the endless board and score while replacing coloured tools")
	check(str(migrated.rng.state) == old_save.rng_state, "Migrating a v3 hand consumes no RNG")
	check(is_equal_approx(migrated.rise_remaining, 1.25) and is_equal_approx(migrated.active_seconds, 87.5), "Legacy migration does not refund its clock")
	game.go_home()
	var home_time: float = game.model.rise_remaining
	game.tick_pressure(8)
	check(game.overlay == "home" and is_equal_approx(game.model.rise_remaining, home_time), "Returning home checkpoints without spending clock time")
	game.queue_free()
	await process_frame
	await process_frame
	DirAccess.remove_absolute(temp_path)
	print("Punch Pop flow: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func pointer_for(game: Node2D, origin: Vector2i, cutter: Dictionary) -> Vector2:
	var extent := Vector2.ZERO
	for offset in CutterManager.SHAPES[cutter.shape]:
		extent.x = maxf(extent.x, offset.x + 1)
		extent.y = maxf(extent.y, offset.y + 1)
	var desired_center: Vector2 = game.BOARD_POS + (Vector2(origin) + extent / 2.0) * game.CELL
	var pointer := Vector2(desired_center.x, 276)
	var smallest := INF
	# Invert the actual preview-centre helper rather than duplicating its lift.
	for y in range(276, 862):
		var candidate := Vector2(desired_center.x, y)
		var distance: float = game.card_drag_center(candidate).distance_squared_to(desired_center)
		if distance < smallest:
			smallest = distance
			pointer = candidate
	return pointer

func settle(game: Node2D) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while game.busy and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not game.busy, "Live presentation settles within ten seconds")
