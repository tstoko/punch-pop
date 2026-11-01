extends SceneTree

var checks := 0
var failures := 0
var game_flow_completed := false

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + description)

func run() -> void:
	test_cutters()
	test_gravity()
	test_matches()
	test_combo()
	test_perfect_cuts()
	test_shape_punches_and_breathing()
	test_spawn()
	test_generation()
	test_round_model()
	test_clear_explanations()
	test_save_validation()
	test_pressure_model()
	test_punch_effort()
	await test_home_and_drag()
	await test_game_flow()
	await test_preview_clock_cache()
	await test_live_effort_debt()
	await test_live_pressure()
	check(game_flow_completed, "Controller suite reached cleanup without a script error")
	print("Punch Pop: %d checks, %d failures" % [checks, failures])
	quit(1 if failures > 0 else 0)

func test_cutters() -> void:
	var board := BoardManager.new()
	board.put(Vector2i(0, 8), 0)
	board.put(Vector2i(1, 8), 1)
	board.put(Vector2i(2, 8), 0)
	var cutter := {"shape": 1, "color": 0}
	var hits := CutterManager.hits(board, cutter, Vector2i(0, 8))
	check(hits.size() == 2, "Line hits matching colour only")
	board.remove(hits)
	check(board.at(Vector2i(1, 8)) == 1, "Other colour survives the cutter")
	check(board.occupied() == 1, "Only matching cells removed")
	check(CutterManager.hits(board, cutter, Vector2i(6, 8)).is_empty(), "Reject partially out-of-bounds stamp")
	check(CutterManager.hits(board, cutter, Vector2i(-1, 8)).is_empty(), "Reject negative stamp origin")
	for shape in 3:
		board.clear()
		var origin := Vector2i(2, 5)
		for offset in CutterManager.SHAPES[shape]:
			board.put(origin + offset, 2)
		var stamp := {"shape": shape, "color": 2}
		check(CutterManager.hits(board, stamp, origin).size() == CutterManager.SHAPES[shape].size(), "All offsets tested for shape %d" % shape)
		var targets := CutterManager.target_map(board, stamp)
		for offset in CutterManager.SHAPES[shape]:
			var p: Vector2i = origin + offset
			check(targets.has(p), "Every matching cell can be tapped, including non-anchor cells")
			check(CutterManager.hits(board, stamp, targets[p]).has(p), "Snapping always includes the tapped jelly")
		check(not targets.has(Vector2i(6, 0)), "Empty cells never snap to distant pairs")
	board.clear()
	board.put(Vector2i(0, 8), 0)
	check(CutterManager.placements(board, cutter).is_empty(), "Single jelly is never a valid cut")
	check(CutterManager.target_map(board, cutter).is_empty(), "Single jelly has no tappable target")
	board.put(Vector2i(1, 8), 0)
	board.put(Vector2i(2, 8), 0)
	var snapped := CutterManager.target_map(board, cutter)
	check(CutterManager.hits(board, cutter, snapped[Vector2i(1, 8)]).size() == 3, "Snap prefers three matching jellies over two")
	var before := board.snapshot()
	check(CutterManager.target_map(board, cutter) == snapped, "Snapping is deterministic")
	check(board.snapshot() == before, "Computing a preview never mutates the board")

func test_gravity() -> void:
	var board := BoardManager.new()
	board.put(Vector2i(0, 0), 0)
	board.put(Vector2i(0, 4), 1)
	board.put(Vector2i(0, 8), 2)
	var moves := GravitySystem.apply(board)
	check(board.at(Vector2i(0, 8)) == 2, "Bottom jelly stays in place")
	check(board.at(Vector2i(0, 7)) == 1 and board.at(Vector2i(0, 6)) == 0, "Gravity preserves vertical order")
	check(board.at(Vector2i(0, 0)) == -1 and board.at(Vector2i(0, 4)) == -1, "Gravity clears original cells")
	check(board.occupied() == 3 and moves.size() == 2, "Gravity conserves cells and records moves")
	check(GravitySystem.apply(board).is_empty(), "Settled gravity is idempotent")

func test_matches() -> void:
	var board := BoardManager.new()
	for p in [Vector2i(0, 8), Vector2i(1, 8), Vector2i(1, 7)]:
		board.put(p, 0)
	check(MatchSystem.groups(board).is_empty(), "Three matching neighbours do not pop")
	board.put(Vector2i(2, 7), 0)
	check(MatchSystem.groups(board).size() == 1, "Four connected jellies pop even in irregular shapes")
	board.put(Vector2i(3, 6), 0)
	check(MatchSystem.groups(board)[0].size() == 4, "Diagonal neighbours are excluded")
	for y in range(5, 9):
		board.put(Vector2i(6, y), 2)
	check(MatchSystem.groups(board).size() == 2, "Independent groups resolve in the same wave")

func test_combo() -> void:
	var board := BoardManager.new()
	for y in range(5, 9):
		board.put(Vector2i(0, y), 0)
	board.put(Vector2i(0, 3), 1)
	board.put(Vector2i(0, 4), 1)
	board.put(Vector2i(1, 7), 1)
	board.put(Vector2i(1, 8), 1)
	var result := ComboManager.resolve(board)
	check(result.waves.size() == 2, "Gravity creates a second cascade")
	check(result.score == 80 + 160, "Wave scoring is 20 per jelly times wave number")
	check(board.occupied() == 0, "Cascade resolves completely")
	check(ComboManager.cut_score(3) == 30, "Direct cutter scores 10 per jelly")
	check(ComboManager.resolve(board).score == 0, "Empty board awards no phantom points")

func test_perfect_cuts() -> void:
	check(ComboManager.perfect_bonus(2, 3) == 0 and ComboManager.perfect_bonus(3, 4) == 0, "Partial footprints never receive a perfect bonus")
	check(ComboManager.perfect_bonus(3, 3) == 15 and ComboManager.perfect_bonus(4, 4) == 20, "Full footprints receive a modest five points per block")
	for shape in [0, 1, 2]:
		var model := RoundModel.new()
		model.reset(600 + shape)
		model.board.clear()
		var origin := Vector2i(0, 8) if shape == 1 else Vector2i(0, 7)
		var count: int = CutterManager.SHAPES[shape].size()
		for i in count:
			model.board.put(origin + CutterManager.SHAPES[shape][i], i % 4)
		# Preserve another legal pair so the receipt contains only this cut.
		model.board.put(Vector2i(4, 8), 1)
		model.board.put(Vector2i(5, 8), 1)
		model.tray = [{"shape": shape, "color": -1}, {}, {}]
		var before := model.snapshot()
		var prediction := model.forecast(0, origin)
		check(prediction.perfect and prediction.bonus == count * 5 and prediction.score == count * 15, "Perfect cut forecast includes the complete bonus")
		check(model.snapshot() == before, "Perfect cut forecast is mutation-free")
		var events := model.play(0, origin)
		var receipt := TurnSummary.from_events(events)
		check(receipt.perfect and receipt.bonus == count * 5 and receipt.score == prediction.score and model.score == prediction.score, "Perfect forecast, events, receipt and awarded points agree")
		var after := model.snapshot()
		check(model.restore(before) and model.score == 0, "Restoring undo removes the perfect bonus with the cut")
		model.play(0, origin)
		check(model.snapshot() == after, "Perfect cut replay preserves score and random future")
		var clone := RoundModel.new()
		check(clone.restore(after) and clone.score == count * 15, "Perfect bonuses survive saving without additional checkpoint fields")
	check(TurnSummary.from_events([{"type": "pop", "points": [Vector2i.ZERO, Vector2i.ONE], "wave": 0, "earned": 20, "groups": []}]).bonus == 0, "Receipts accept older events without bonus metadata")

func test_shape_punches_and_breathing() -> void:
	check(SupplySystem.chain_time(0) == 0.0 and SupplySystem.chain_time(1) == 0.0, "No time reward is given without a multiwave chain")
	check(SupplySystem.chain_time(2) == .5 and SupplySystem.chain_time(3) == 1.0, "Real chains earn half a second per wave after the first")
	check(SupplySystem.chain_time(4) == 1.5 and SupplySystem.chain_time(20) == 1.5, "Long chains cannot exceed the one-and-a-half-second rescue cap")
	for lesson_index in [1, 2]:
		var training := RoundModel.new()
		training.reset(710, lesson_index)
		var unchanged := training.snapshot()
		var wrong: Vector2i = CutterManager.placements(training.board, training.tray[0]).filter(func(p: Vector2i) -> bool: return p != LessonBook.GOALS[lesson_index])[0]
		check(training.forecast(0, wrong).is_empty() and training.play(0, wrong).is_empty(), "Training rejects valid punches outside its authored teaching goal")
		check(training.snapshot() == unchanged and not training.lesson_complete, "A wrong training punch never mutates or completes the lesson")
	var board := BoardManager.new()
	for x in 3:
		board.put(Vector2i(x, 8), x)
	check(CutterManager.hits(board, {"shape": 1, "color": -1}, Vector2i(0, 8)).size() == 3, "Shape punches remove every occupied colour inside the footprint")
	check(CutterManager.hits(board, {"shape": 1, "color": 0}, Vector2i(0, 8)).size() == 1, "Historical explicit-colour cutter geometry remains compatible")
	var model := RoundModel.new()
	model.reset(700, 2)
	model.lesson = -1
	model.advance_clock(4.0)
	var prediction := model.forecast(0, Vector2i(0, 5))
	check(prediction.waves == 2 and prediction.matched >= 8 and prediction.time_bonus == .5, "A two-wave punch forecasts half a second of breathing time")
	var events := model.play(0, Vector2i(0, 5))
	var receipt := TurnSummary.from_events(events)
	check(receipt.time_bonus == prediction.time_bonus and is_equal_approx(model.rise_remaining, 8.5 - prediction.effort), "Cut-created chain credit and effort match the forecast")
	model.reset(700, 2)
	model.lesson = -1
	model.advance_clock(.25)
	prediction = model.forecast(0, Vector2i(0, 5))
	check(prediction.time_bonus == .5, "A chain can offset effort charged by the same cut")
	events = model.play(0, Vector2i(0, 5))
	check(TurnSummary.from_events(events).time_bonus == .5 and is_equal_approx(model.rise_remaining, model.rise_period - .25 + prediction.clock_delta), "Fast chains apply effort without banking time beyond one countdown")
	model.reset(700, 1)
	model.lesson = -1
	model.advance_clock(4.0)
	prediction = model.forecast(0, LessonBook.GOALS[1])
	check(prediction.waves == 1 and prediction.time_bonus == 0.0, "An ordinary one-wave match buys board space without granting extra thinking time")
	events = model.play(0, LessonBook.GOALS[1])
	check(TurnSummary.from_events(events).time_bonus == 0.0 and is_equal_approx(model.rise_remaining, 8.0 - prediction.effort), "Ordinary matches pay effort and grant no chain credit")
	model.reset(701)
	var legacy := model.snapshot()
	legacy.version = 3
	legacy.rise_period = 3.5
	legacy.rise_remaining = 2.25
	legacy.score = 1234
	var legacy_board := BoardManager.new()
	for x in 3:
		legacy_board.put(Vector2i(x, 8), 0)
	legacy_board.put(Vector2i(5, 8), 1)
	legacy_board.put(Vector2i(6, 8), 1)
	legacy.cells = legacy_board.snapshot()
	legacy.tray = [{"shape": 1, "color": 0}, {"shape": 0, "color": 0}, {"shape": 2, "color": 1}]
	legacy.selected = 0
	var clone := RoundModel.new()
	check(clone.restore(legacy) and clone.score == 1234 and clone.rise_period == 3.5 and clone.rise_remaining == 2.25, "Version-three saves preserve scores and shorter historical countdowns")
	check(str(clone.rng.state) == legacy.rng_state and clone.tray.all(func(c: Dictionary) -> bool: return c.is_empty() or c.color == -1), "Checkpoint migration preserves RNG and makes the tray shape-only")
	var old_lesson := legacy.duplicate(true)
	old_lesson.lesson = 2
	old_lesson.lesson_complete = true
	check(clone.restore(old_lesson) and clone.lesson == 2 and not clone.lesson_complete and clone.score == 0 and clone.turns == 0, "Legacy training restarts its corresponding lesson with the new shape-punch rules")
	check(clone.forecast(0, Vector2i(0, 5)).waves == 2 and RoundModel.valid(clone.snapshot()), "Migrated training has the correct new teaching layout and a valid checkpoint")
	model.reset(702)
	model.board.clear()
	for x in 7:
		for y in range(5, 9):
			model.board.put(Vector2i(x, y), (x + 2 * y) % 4)
	model.tray = [{"shape": 0, "color": -1}, {"shape": 1, "color": -1}, {"shape": 2, "color": -1}]
	model.play(0, Vector2i(0, 7))
	check(model.tray[0].is_empty() and not model.tray[1].is_empty() and not model.tray[2].is_empty(), "A used punch leaves an empty slot until the remaining hand is spent")
	check(model.selected != 0 and RoundModel.valid(model.snapshot()), "Selection advances to an available punch and a partial hand remains saveable")
	model.play(1, Vector2i(3, 8))
	check(model.tray[0].is_empty() and model.tray[1].is_empty() and not model.tray[2].is_empty(), "The second punch still does not replenish spent slots")
	model.play(2, Vector2i(4, 6))
	check(model.tray.all(func(c: Dictionary) -> bool: return not c.is_empty()) and model.tray[0] != model.tray[1] and model.tray[1] != model.tray[2], "Spending the final punch deals a fresh distinct hand")
	var multichain_openings := 0
	var unique := {}
	for seed_value in 20:
		model.reset(9000 + seed_value)
		unique[model.board.snapshot()] = true
		check(model.tray.all(func(c: Dictionary) -> bool: return not c.is_empty() and c.color == -1) and CutterManager.candidates(model.board).size() == 3, "New openings offer all three shape-only punches")
		check(LessonBook.has_cascade(model.board), "Every opening has a discoverable match opportunity")
		if LessonBook.has_cascade(model.board, 2):
			multichain_openings += 1
		for cutter in model.tray:
			var full := false
			for origin in CutterManager.placements(model.board, cutter):
				if CutterManager.hits(model.board, cutter, origin).size() == CutterManager.SHAPES[cutter.shape].size():
					full = true
					break
			check(full, "Every offered shape has a reachable perfect punch on normal settled terrain")
	check(unique.size() == 20 and multichain_openings > 0, "Openings vary by seed and include discoverable multiwave chains")

func test_spawn() -> void:
	var board := BoardManager.new()
	var colors := [0, 1, 2, 3, 0, 1, 2]
	check(SpawnManager.add_row(board, colors), "New row fits empty board")
	GravitySystem.apply(board)
	check(board.cells[8] == colors and board.occupied() == 7, "Incoming row falls into columns")
	board.put(Vector2i(4, 0), 2)
	var before := board.snapshot()
	check(not SpawnManager.add_row(board, colors), "One full column blocks the entire incoming row")
	check(board.snapshot() == before, "Overflow is atomic with no partial insertion")

func test_generation() -> void:
	var rng := RandomNumberGenerator.new()
	for seed_value in 25:
		rng.seed = seed_value
		var board := BoardManager.new()
		SpawnManager.seed_board(board, rng)
		check(MatchSystem.groups(board).is_empty(), "Seed %d starts settled" % seed_value)
		var tray := CutterManager.refresh(board, [], rng)
		check(tray.size() == 3, "Seed %d offers three cutters" % seed_value)
		for turn in 45:
			if tray.is_empty():
				check(CutterManager.candidates(board).is_empty(), "No-move ending reflects actual board")
				break
			for cutter in tray:
				check(not CutterManager.placements(board, cutter).is_empty(), "Generated cutter is always playable")
			var cutter: Dictionary = tray[0]
			var legal := CutterManager.placements(board, cutter)
			var p: Vector2i = legal[rng.randi_range(0, legal.size() - 1)]
			board.remove(CutterManager.hits(board, cutter, p))
			ComboManager.resolve(board)
			if (turn + 1) % 3 == 0:
				if not SpawnManager.add_row(board, SpawnManager.row(rng, turn)):
					break
				ComboManager.resolve(board)
			tray[0] = {}
			tray = CutterManager.refresh(board, tray, rng)
	var empty := BoardManager.new()
	check(CutterManager.generate(empty, rng).is_empty(), "No invented moves on empty board")

func test_home_and_drag() -> void:
	var path := "/private/tmp/punch_pop_v6_test_home_drag.cfg"
	DirAccess.remove_absolute(path)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save = SaveStore.new(path)
	root.add_child(game)
	await process_frame
	var initial: Dictionary = game.model.snapshot()
	game.tick_pressure(.25)
	check(game.overlay == "home" and not game.has_saved_round() and game.model.snapshot() == initial, "First launch opens a home menu with its clock frozen")
	game.overlay_press(Vector2(270, 816))
	check(game.overlay == "settings" and game.settings_return == "home", "Home settings remember the menu they came from")
	game.tick_pressure(.25)
	game.overlay_press(game.replay_rect.get_center())
	check(game.overlay == "home" and game.model.snapshot() == initial, "Returning from settings keeps the home clock and board unchanged")
	game.overlay_press(Vector2(270, 750))
	game.pressure_enabled = false
	check(game.overlay.is_empty() and game.model.lesson == 0, "Home training opens the first untimed lesson")
	var before: Dictionary = game.model.snapshot()
	var origin := Vector2i(2, 8)
	# The preview is lifted above the finger. Stay above the tray; nearby
	# snapping keeps the bottom row reachable.
	var pointer: Vector2 = game.BOARD_POS + (Vector2(origin) + Vector2(1.5, .5)) * game.CELL + Vector2(0, 70)
	var card := Vector2(126, 930)
	var card_top := Vector2(190, 880)
	game.press(card_top)
	game.release(card_top)
	check(game.model.snapshot() == before and not game.busy and not game.dragging, "Tapping the top of a cutter card only selects it and never cuts bottom-row blocks")
	game.press(Vector2(190, 866))
	game.release(Vector2(190, 858))
	check(game.model.snapshot() == before and not game.busy, "Small movements across the tray edge do not activate a card drag")
	game.press(card)
	check(game.dragging and game.drag_from_card and game.preview().is_empty(), "Card press begins a drag without a remote board preview")
	game.move_pointer(pointer)
	check(game.preview_origin() == origin and game.preview().hits.size() == 3, "Card drag previews the intended legal footprint above the finger")
	game.move_pointer(pointer + Vector2(3, 2))
	check(game.preview_origin() == origin and game.model.snapshot() == before, "Small finger movements preserve the preview without committing a cut")
	game.move_pointer(game.BOARD_POS + Vector2(120, 100))
	check(game.preview().is_empty(), "Dragging over empty space never snaps to a distant cut")
	game.move_pointer(pointer)
	game.release(Vector2(game.BOARD_POS.x - 40, pointer.y))
	check(not game.dragging and not game.drag_from_card and game.model.snapshot() == before, "Releasing outside the board cancels a card drag without spending a turn")
	game.press(card)
	game.move_pointer(pointer)
	game.move_pointer(Vector2(pointer.x, 880))
	check(game.preview().is_empty(), "Returning a dragged cutter to the tray removes the preview")
	game.release(Vector2(pointer.x, 880))
	check(game.model.snapshot() == before and not game.dragging, "Releasing a cutter back in its tray cancels the cut")
	game.press(card)
	game.move_pointer(pointer)
	game.release(Vector2(pointer.x, game.BOARD_POS.y + 660))
	check(game.model.snapshot() == before and not game.dragging, "Dragging back below the board cancels without cutting")
	game.press(card)
	game.move_pointer(pointer)
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(game.overlay == "pause" and not game.drag_from_card and game.preview().is_empty() and game.model.snapshot() == before, "Focus loss cancels a card drag and preserves the round")
	game.overlay = ""
	game.press(card)
	game.move_pointer(pointer)
	game.release(pointer)
	while game.busy:
		await process_frame
	check(game.model.turns == 1 and game.model.lesson_complete and game.overlay == "lesson", "Releasing a valid card drag commits exactly one complete cut")
	game.model.over = true
	game.sync_model()
	game.go_home()
	game.overlay_press(Vector2(270, 816))
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._input(escape)
	check(game.over and game.overlay == "home", "Escape returns from home settings even after game over")

	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)

func test_game_flow() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.save = SaveStore.new("/private/tmp/punch_pop_v5_test_punch_pop_v2.cfg")
	game.pressure_enabled = false
	root.add_child(game)
	await process_frame
	game.start_game(true)
	for sample in [{"score": 0, "target": 500, "progress": 0.0}, {"score": 499, "target": 500, "progress": .998}, {"score": 500, "target": 1000, "progress": 0.0}, {"score": 5000, "target": 7500, "progress": 0.0}, {"score": 7500, "target": 10000, "progress": 0.0}]:
		game.score = sample.score
		check(game.score_target() == sample.target and is_equal_approx(game.score_progress(), sample.progress), "Score milestones advance cleanly at %d" % sample.score)
	game.sync_model()
	game.effects.burst(Vector2(80, 300), 0)
	game.reset_transients()
	check(game.effects.particles.is_empty() and game.effects.rings.is_empty(), "Restart and undo remove stale visual effects")
	game.save.explain_clears = true
	game.overlay = "settings"
	await process_frame
	check(not game.effects.visible, "Particles cannot obscure help or pause menus")
	game.overlay_press(Vector2(270, 482))
	check(not game.save.explain_clears, "Settings control enables quick clears")
	game.overlay_press(Vector2(270, 482))
	check(game.save.explain_clears, "Settings control restores readable explanations")
	game.overlay = ""
	await process_frame
	game.phase_changed.connect(func(stage: String) -> void:
		if stage == "match":
			check(not game.match_groups.is_empty(), "Automatic clear is announced before removal")
			for group in game.match_groups:
				check(group.size() >= 4 and game.board.at(group[0]) >= 0, "Highlighted blocks still exist during the explanation")
	)
	for index in 3:
		check(game.model.lesson == index and game.tutorial == index + 1, "Authored lesson starts at the right step")
		check(RoundModel.valid(game.model.snapshot()), "Lesson checkpoint is valid and settled")
		var target: Vector2i = [Vector2i(2, 8), Vector2i(0, 7), Vector2i(0, 5)][index]
		game.precise = true
		game.press(game.cell_center(target))
		check(not game.busy and game.turns == 0, "Press previews without committing")
		game.release(game.cell_center(target))
		while game.busy:
			await process_frame
		check(game.overlay == "lesson" and game.model.lesson_complete, "Lesson shows a clear success state")
		check(game.combo >= index if index > 0 else game.score == 45, "Lessons demonstrate cut, match, then two-wave chain")
		game.next_lesson()
	check(game.tutorial == 0 and game.save.tutorial_done, "Finishing all lessons enters endless and saves completion")
	check(not game.targets.is_empty(), "Endless starts with usable cutters")
	check(game.tray_insights.all(func(value: int) -> bool: return value == 0), "Endless trays leave chain discovery to the player")
	# Chain animation is tested on authored terrain, independent of random openings.
	game.model.board.clear()
	LessonBook.chain_pocket(game.model.board)
	game.model.tray = CutterManager.diverse_refresh(game.model.board, [{"shape": 0, "color": -1}, {}, {}], game.model.rng)
	game.sync_model()
	game.checkpoint()
	var target := Vector2i(0, 5)
	game.precise = true
	var before: Dictionary = game.model.snapshot()
	var prediction: Dictionary = game.model.forecast(game.selected, target)
	check(prediction.waves >= 2, "Opening forecast predicts the two-wave chain")
	game.hover = target
	check(game.preview().score == prediction.score, "Displayed forecast uses the same resolver as play")
	game.press(game.cell_center(target))
	game.release(game.cell_center(target))
	check(game.busy, "A valid move enters atomic animation state")
	var interrupted := SaveStore.new("/private/tmp/punch_pop_v5_test_punch_pop_v2.cfg")
	interrupted.load_data()
	check(interrupted.round_data == before, "Closing mid-animation can recover the previous complete turn")
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	while game.busy:
		await process_frame
	check(game.overlay == "pause", "Losing focus during animation pauses after the turn")
	check(game.model.best_combo >= 2 and game.turns == 1, "The live opening produces the predicted chain")
	check(game.last_summary.matched >= 8 and game.last_clear_time > 0, "A readable explanation remains after the animation finishes")
	check(game.turn_trace.any(func(step: Dictionary) -> bool: return step.phase == "cut") and game.turn_trace.any(func(step: Dictionary) -> bool: return step.phase == "match"), "Live phases distinguish player action and auto matching")
	check(not game.undo_state.is_empty(), "Successful move exposes one-step undo")
	var after: Dictionary = game.model.snapshot()
	check(game.model.board.occupied() > 0 and not game.targets.is_empty(), "Sparse opening earns a fresh playable batch")
	game.undo_move()
	check(without_clock(game.model.snapshot()) == without_clock(before), "Undo restores the exact board, score, tray, turn and RNG state")
	check(is_equal_approx(game.model.rise_remaining, before.rise_remaining - prediction.effort), "Undo retains the first punch effort and removes its chain credit")
	check(game.undo_state.is_empty(), "Undo cannot rewind an unlimited history")
	game.precise = true
	game.hover = Vector2i(0, 5)
	check(game.preview_origin() == Vector2i(0, 5) and not game.preview().is_empty(), "Aim mode exposes exact legal stamp origins")
	await game.place_cutter(Vector2i(0, 5))
	check(without_clock(game.model.snapshot()) == without_clock(after), "Replaying after undo produces identical future cutters and rows")
	check(game.model.effort_seconds > after.effort_seconds, "Replaying after undo pays the punch effort again")
	after = game.model.snapshot()
	var loaded := SaveStore.new("/private/tmp/punch_pop_v5_test_punch_pop_v2.cfg")
	loaded.load_data()

	check(same_checkpoint(loaded.round_data, after) and not loaded.undo_data.is_empty(), "Settled round and undo are written to disk")
	var resumed = load("res://scenes/main.tscn").instantiate()
	resumed.save = loaded
	resumed.pressure_enabled = false
	root.add_child(resumed)
	await process_frame
	check(resumed.overlay == "home" and same_checkpoint(resumed.model.snapshot(), after), "A new game instance restores the exact checkpoint")
	resumed.overlay_press(Vector2(270, 602))
	check(resumed.overlay.is_empty(), "Continue returns to the saved board")
	resumed.undo_move()
	check(without_clock(resumed.model.snapshot()) == without_clock(before), "Undo also survives quitting and resuming")
	check(resumed.model.effort_seconds == after.effort_seconds, "Reloaded undo retains cumulative punch effort")
	# Invalid taps and canceled gestures cost nothing.
	var unchanged: Dictionary = resumed.model.snapshot()
	resumed.press(resumed.cell_center(Vector2i(6, 0)))
	resumed.release(resumed.cell_center(Vector2i(6, 0)))
	check(resumed.model.snapshot() == unchanged, "Invalid tap costs no score or turn")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = resumed.cell_center(resumed.targets.keys()[0]) + resumed.position
	resumed._input(touch)
	var other := InputEventScreenTouch.new()
	other.index = 1
	other.pressed = true
	other.position = Vector2(300, 910) + resumed.position
	resumed._input(other)
	check(resumed.touch_id == 0, "Second finger cannot steal a gesture")
	touch.pressed = false
	touch.canceled = true
	resumed._input(touch)
	check(resumed.model.snapshot() == unchanged and not resumed.dragging, "Canceled OS gesture cannot punch")
	resumed.press(resumed.cell_center(resumed.targets.keys()[0]))
	resumed.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not resumed.dragging and resumed.overlay == "pause", "Idle focus loss cancels held input and pauses")
	resumed.reset_transients()
	resumed.model.reset(55)
	resumed.model.board.clear()
	for y in 9:
		resumed.model.board.put(Vector2i(6, y), y % 4)
	resumed.model.board.put(Vector2i(0, 8), 0)
	resumed.model.board.put(Vector2i(1, 8), 0)
	resumed.model.tray = [{"shape": 1, "color": 0}, {}, {}]
	resumed.model.turns = 1
	resumed.sync_model()
	await resumed.place_cutter(Vector2i(0, 8))
	check(not resumed.over and not resumed.undo_state.is_empty(), "A full column can still be punched before the clock expires")
	resumed.model.rise_remaining = 0
	await resumed.rise_from_timer()
	check(resumed.over and resumed.overlay == "over" and resumed.undo_state.is_empty(), "Timed overflow displays game over and cannot be undone")
	resumed.queue_free()
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("/private/tmp/punch_pop_v5_test_punch_pop_v2.cfg")
	game_flow_completed = true

func test_round_model() -> void:
	var model := RoundModel.new()
	model.reset(12345)
	check(RoundModel.valid(model.snapshot()), "New endless round is a valid checkpoint")
	check(model.tray[0] != model.tray[1] and model.tray[0] != model.tray[2], "Opening chain cutter is distinct from the other offers")
	var corrupt := model.snapshot()
	corrupt.cells[0][0] = 55
	check(not model.restore(corrupt), "Invalid colour checkpoint is rejected")
	corrupt = model.snapshot()
	corrupt.rng_state = "bad"
	check(not RoundModel.valid(corrupt), "Corrupt RNG state is rejected")
	corrupt = model.snapshot()
	corrupt.cells[0][6] = 0
	check(not RoundModel.valid(corrupt), "Floating cells cannot enter a settled checkpoint")
	var diverse := CutterManager.diverse_refresh(model.board, [{}, {}, {}], model.rng)
	check(diverse[0] != diverse[1] and diverse[1] != diverse[2] and diverse[0] != diverse[2], "Tray offers distinct cutters when the board permits")
	corrupt = model.snapshot()
	corrupt.rng_state = "99999999999999999999999999999"
	check(not RoundModel.valid(corrupt), "Overflowed RNG strings are rejected")
	var stranded := BoardManager.new()
	stranded.put(Vector2i(0, 8), 0)
	stranded.put(Vector2i(6, 8), 1)
	check(CutterManager.candidates(stranded).is_empty(), "Recovery fixture has no legal cutter")
	var recovery := SupplySystem.recovery_row(stranded, model.rng, 10)
	SpawnManager.rise_row(stranded, recovery)
	ComboManager.resolve(stranded)
	check(not CutterManager.candidates(stranded).is_empty(), "Adversarial no-pair board receives a real playable row")
	var before := model.snapshot()
	check(model.play(0, Vector2i(-1, 0)).is_empty() and model.snapshot() == before, "Invalid model move is mutation-free")
	# A valid pair on an otherwise empty board is a reward, not a defeat.
	model.board.clear()
	model.board.put(Vector2i(0, 8), 0)
	model.board.put(Vector2i(1, 8), 0)
	model.tray = [{"shape": 1, "color": 0}, {}, {}]
	model.incoming = [0, 0, 1, 1, 2, 2, 3]
	var events := model.play(0, Vector2i(0, 8))
	check(not model.over and model.board.occupied() > 0, "Clearing the entire board earns fresh material")
	check(events.any(func(e: Dictionary) -> bool: return e.type == "fresh"), "Fresh-batch reward has a presentation event")
	check(model.tray.size() == 3 and RoundModel.valid(model.snapshot()), "Fresh batch restores three playable cutters")
	# Sparse terrain stays sparse when there is still a choice to make.
	model.reset(456)
	model.board.clear()
	for x in [0, 1]:
		model.board.put(Vector2i(x, 8), 0)
	for x in [4, 5]:
		model.board.put(Vector2i(x, 8), 1)
	model.tray = [{"shape": 1, "color": 0}, {}, {}]
	model.turns = 47
	var previewed := model.incoming.duplicate()
	var sparse_effort := model.punch_effort()
	events = model.play(0, Vector2i(0, 8))
	check(model.board.occupied() == 2 and model.turns == 48, "A good cut preserves breathing room even at late pressure levels")
	check(not events.any(func(e: Dictionary) -> bool: return e.type in ["row", "fresh"]), "A sparse playable board receives no surprise refill")
	check(model.incoming == previewed and is_equal_approx(model.rise_remaining, 12 - sparse_effort), "Cuts preserve the preview and pending countdown")
	check(RoundModel.valid(model.snapshot()), "Sparse boards retain a playable saved tray")
	# Overflow is still real and atomic.
	model.reset(55)
	model.board.clear()
	for y in 9:
		model.board.put(Vector2i(6, y), y % 4)
	model.board.put(Vector2i(0, 8), 0)
	model.board.put(Vector2i(1, 8), 0)
	model.tray = [{"shape": 1, "color": 0}, {}, {}]
	model.turns = 1
	model.play(0, Vector2i(0, 8))
	check(not model.over and SupplySystem.height(model.board, 6) == 9, "A full column remains punchable without a surprise recovery row")
	model.advance_clock(model.rise_remaining)
	model.expire_clock()
	check(model.over and model.end_reason == "timer", "A full column loses only when the pending timed row arrives")
	check(SupplySystem.due_rows(1) == 0 and SupplySystem.due_rows(2) == 0, "Cuts never schedule pressure rows")
	check(SupplySystem.due_rows(36) == 0 and SupplySystem.due_rows(48) == 0, "Late cuts never add hidden pressure rows")
	var openings := {}
	for seed_value in 15:
		model.reset(20261022 + seed_value)
		openings[str(model.board.snapshot())] = true
		check(RoundModel.valid(model.snapshot()), "Every randomized opening is settled and playable")
		for x in 7:
			check(SupplySystem.height(model.board, x) <= 5, "Fresh openings leave at least four rows of headroom")
		for turn in 70:
			while model.rise_remaining <= 0 and not model.over:
				model.expire_clock()
			if model.over:
				break
			var slot: int = model.selected
			var targets := CutterManager.target_map(model.board, model.tray[slot])
			check(not targets.is_empty(), "Every offered cutter remains usable")
			var origin: Vector2i = targets.values()[0]
			var checkpoint := model.snapshot()
			var clone := RoundModel.new()
			check(clone.restore(checkpoint), "Every settled turn can be restored")
			var live_events := model.play(slot, origin)
			clone.play(slot, origin)
			check(model.snapshot() == clone.snapshot(), "Save/restore preserves the complete random future")
			check(not live_events.is_empty(), "Valid simulated move creates presentation events")
			if not model.over:
				check(RoundModel.valid(model.snapshot()), "Live simulation preserves stable board and checkpoint invariants")
				check(not CutterManager.candidates(model.board).is_empty(), "Sparse recovery never leaves the game stuck")

	check(openings.size() == 15, "Seeded rounds have genuinely different opening terrain")

func test_save_validation() -> void:
	var path := "/private/tmp/punch_pop_v5_test_validation_v2.cfg"
	var config := ConfigFile.new()
	config.set_value("player", "best", 1234)
	config.set_value("player", "tutorial_done", true)
	config.set_value("settings", "sound", false)
	config.set_value("round", "checkpoint", {"version": 2, "cells": "corrupt"})
	config.set_value("round", "undo", {"version": -1})
	config.save(path)
	var store := SaveStore.new(path)
	store.load_data()
	check(store.best == 1234 and not store.sound, "Legacy records and preferences survive migration")
	check(not store.tutorial_done, "The upgraded teaching sequence is offered to legacy players")
	check(store.round_data.is_empty() and store.undo_data.is_empty(), "Malformed checkpoints safely fall back without erasing best score")
	store.tutorial_done = true
	store.reduced_motion = true
	store.high_contrast = true
	var model := RoundModel.new()
	model.reset(100)
	store.round_data = model.snapshot()
	check(store.save_data(), "Atomic save reports success")
	var reloaded := SaveStore.new(path)
	reloaded.load_data()
	check(reloaded.tutorial_done and reloaded.high_contrast and reloaded.reduced_motion, "New tutorial version and accessibility settings round-trip")
	check(reloaded.round_data == model.snapshot(), "ConfigFile preserves 64-bit RNG strings and board data exactly")
	DirAccess.remove_absolute(path)


func test_clear_explanations() -> void:
	var row := BoardManager.new()
	for x in 7:
		row.put(Vector2i(x, 8), x % 4)
	check(MatchSystem.groups(row).is_empty(), "A full multicolour row does not magically clear")
	var model := RoundModel.new()
	model.reset(20261022, 2)
	var shown := BoardManager.new()
	shown.cells = model.board.snapshot()
	var events := model.play(0, Vector2i(0, 5))
	var earned := 0
	for e in events:
		if e.type == "pop":
			earned += e.earned
			if e.wave == 0:
				check(e.source == "player" and e.groups.is_empty(), "Player cuts are distinct from automatic groups")
			else:
				check(e.groups == MatchSystem.groups(shown), "Highlighted automatic groups match the actual visible board")
				var count := 0
				for group in e.groups:
					check(group.size() >= 4, "Every labelled group meets the four-block rule")
					for p in group:
						check(shown.at(p) == shown.at(group[0]), "Highlighted group members share a colour")
					count += group.size()
				check(count == e.points.size(), "Group counts account for every auto-cleared block")
				check(e.source in ["cut", "new_row", "refill"], "Every automatic clear has an explicit cause")
			shown.remove(e.points)
		elif e.type == "fall" or e.type == "row":
			shown.cells = e.cells.duplicate(true)
	check(shown.snapshot() == model.board.snapshot(), "Presentation timeline reaches the calculated final board")
	var receipt := TurnSummary.from_events(events)
	check(receipt.cut >= 2 and receipt.matched >= 8 and receipt.chain >= 2, "Turn receipt separates direct cuts, automatic matches and chains")
	check(receipt.score == earned and receipt.score == model.score, "Receipt points equal the actual score gain")
	model.reset(123)
	model.board.clear()
	model.board.put(Vector2i(0, 8), 0)
	model.board.put(Vector2i(1, 8), 0)
	for y in [6, 7, 8]:
		model.board.put(Vector2i(3, y), 1)
	model.tray = [{"shape": 1, "color": 0}, {}, {}]
	model.turns = 1
	model.incoming = [0, 1, 2, 1, 3, 0, 2]
	model.advance_clock(model.rise_remaining)
	var drop_events := model.expire_clock()
	check(drop_events.any(func(e: Dictionary) -> bool: return e.type == "pop" and e.wave > 0 and e.source == "new_row"), "A row-created match is labelled as caused by incoming blocks")
	check(drop_events.any(func(e: Dictionary) -> bool: return e.type == "row" and e.reason == "timer"), "Timer drops are distinct from recovery refills")
	var store := SaveStore.new("/private/tmp/punch_pop_v5_test_clear_guide.cfg")
	check(not store.explain_clears, "Quick clear timing is the new-player default")
	store.explain_clears = false
	store.save_data()
	var loaded := SaveStore.new("/private/tmp/punch_pop_v5_test_clear_guide.cfg")
	loaded.load_data()
	check(not loaded.explain_clears, "Quick-clear preference survives a restart")
	DirAccess.remove_absolute(store.path)

func test_pressure_model() -> void:
	var near_match := BoardManager.new()
	for x in 7:
		near_match.put(Vector2i(x, 8), [0, 1, 0, 1, 2, 2, 3][x])
	var supply_rng := RandomNumberGenerator.new()
	supply_rng.seed = 703
	var opportunities := 0
	for sample in 20:
		var generated := SpawnManager.pressure_row(near_match, supply_rng)
		var raised := BoardManager.new()
		raised.cells = near_match.snapshot()
		SpawnManager.rise_row(raised, generated)
		check(MatchSystem.groups(raised).is_empty(), "Clustered supply creates no automatic match on arrival")
		opportunities += 1 if SpawnManager.row_has_cascade(raised) else 0
	check(opportunities > 0, "Clustered supply creates genuine punch-to-match opportunities on a sparse board")
	var board := BoardManager.new()
	for y in range(5, 9):
		for x in 7:
			board.put(Vector2i(x, y), (x + y) % 4)
	var old := board.snapshot()
	var colors := [0, 0, 1, 1, 2, 2, 3]
	check(SpawnManager.rise_row(board, colors), "Bottom row can lift a settled board")
	for y in range(8):
		check(board.cells[y] == old[y + 1], "Rising preserves every existing row and column")
	check(board.cells[8] == colors and board.occupied() == 35, "Exactly seven previewed blocks enter at the bottom")
	board.put(Vector2i(2, 0), 3)
	old = board.snapshot()
	check(not SpawnManager.rise_row(board, colors) and board.snapshot() == old, "Ceiling overflow cannot partially erase or shift blocks")
	var model := RoundModel.new()
	model.reset(20261022)
	check(not model.advance_clock(11.5) and is_equal_approx(model.rise_remaining, .5), "Countdown advances only by explicit active decision time")
	check(model.expire_clock().is_empty(), "A row cannot rise before the countdown expires")
	var before := model.snapshot()
	model.advance_clock(-1)
	model.advance_clock(NAN)
	check(model.snapshot() == before, "Invalid clock deltas do not corrupt a round")
	check(model.advance_clock(.5), "Exactly reaching zero triggers a rise")
	before = model.snapshot()
	check(model.play(0, Vector2i(0, 6)).is_empty() and model.snapshot() == before, "An expired clock cannot be bypassed by a last-instant cut")
	var events := model.expire_clock()
	check(events.any(func(e: Dictionary) -> bool: return e.type == "row" and e.reason == "timer" and e.direction == "up"), "Timer emits an explicitly labelled upward row")
	check(model.turns == 0 and model.timed_rows == 1 and model.rise_remaining > 0, "Timed rises are not player moves and rearm once")
	check(model.expire_clock().is_empty(), "One expiry cannot produce duplicate rises")
	model.reset(20261022)
	model.advance_clock(3)
	var chosen: Vector2i = CutterManager.placements(model.board, model.tray[0])[0]
	var clock_prediction := model.forecast(0, chosen)
	var time_earned: float = clock_prediction.time_bonus
	model.play(0, chosen)
	check(is_equal_approx(model.rise_remaining, 9 + time_earned - clock_prediction.effort) and model.active_seconds == 3, "Cuts preserve elapsed decision time and only earned chains extend the pending clock")
	check(SupplySystem.rise_interval(0, 0) == 12 and SupplySystem.rise_interval(70, 175) == 4.0, "Pressure accelerates from twelve seconds to four seconds while punch effort continues rising")
	check(SupplySystem.rise_interval(7, 24) == 12 and SupplySystem.rise_interval(8, 0) == 10 and SupplySystem.rise_interval(0, 25) == 10, "Pressure progresses each eight punches or twenty-five active seconds while keeping the initial opening")
	check(SupplySystem.due_rows(24) == 0 and SupplySystem.due_rows(48) == 0, "Only elapsed time creates pressure at every level")
	# Waiting must actually lose, without farming automatic free points.
	for seed_value in 30:
		model.reset(20261022 + seed_value)
		for pulse in 10:
			if model.over:
				break
			var previewed := model.incoming.duplicate()
			model.advance_clock(model.rise_remaining)
			events = model.expire_clock()
			if not model.over:
				check(events[0].colors == previewed, "A timed rise inserts exactly the colours shown in advance")
				check(RoundModel.valid(model.snapshot()), "Timed rows settle into valid, playable checkpoints")
		check(model.over and model.end_reason == "timer" and model.turns == 0, "An idle player reliably loses to the ceiling")
		check(model.score == 0, "Waiting does not farm automatic refill points")
	# Partial clocks and random futures survive saves; older boards migrate.
	model.reset(77)
	model.advance_clock(3.25)
	var clone := RoundModel.new()
	check(clone.restore(model.snapshot()), "A partly consumed clock is a valid saved round")
	model.advance_clock(8.75)
	clone.advance_clock(8.75)
	model.expire_clock()
	clone.expire_clock()
	check(model.snapshot() == clone.snapshot(), "Restoring a partial clock preserves the exact timed-row future")
	var late_round := model.snapshot()
	late_round.rise_period = 3.25
	late_round.rise_remaining = 2.0
	check(RoundModel.valid(late_round) and clone.restore(late_round), "A saved 3.25-second countdown remains a valid resumable round")
	check(clone.rise_period == 3.25 and clone.rise_remaining == 2.0 and clone.score == late_round.score, "Late-round resume preserves its exact period, remaining time and score")
	late_round.rise_period = 2.75
	late_round.rise_remaining = 1.5
	check(RoundModel.valid(late_round) and clone.restore(late_round) and clone.rise_period == 2.75 and clone.rise_remaining == 1.5, "The final 2.75-second pressure interval remains saveable and resumes exactly")
	late_round.rise_period = 2.5
	check(not RoundModel.valid(late_round), "Saved intervals below the difficulty floor are rejected")
	var previous_version := model.snapshot()
	previous_version.version = 3
	previous_version.rise_period = 8.0
	previous_version.rise_remaining = 2.75
	check(clone.restore(previous_version) and clone.rise_remaining == 2.75 and clone.rise_period == 8.0, "Existing version-three saves retain their partial eight-second countdown")
	var period := model.rise_period
	model.turns = 84
	model.advance_clock(.25)
	check(model.rise_period == period, "Difficulty changes never shorten a countdown already underway")
	var legacy := model.snapshot()
	legacy.version = 2
	legacy.turns = 80
	for key in ["active_seconds", "rise_remaining", "rise_period", "timed_rows", "end_reason"]:
		legacy.erase(key)
	check(clone.restore(legacy) and clone.board.snapshot() == legacy.cells and clone.score == legacy.score and str(clone.rng.state) == legacy.rng_state, "Version-two boards, scores and RNG migrate without resetting progress")
	check(clone.rise_remaining == 12 and clone.rise_period == 12, "Older long runs receive a full first countdown when upgraded")
	for bad in [-1.0, 13.0, INF, NAN]:
		var corrupt := model.snapshot()
		corrupt.rise_remaining = bad
		check(not RoundModel.valid(corrupt), "Invalid saved countdowns are rejected")
	model.reset(42, 0)
	before = model.snapshot()
	check(not model.advance_clock(100) and model.snapshot() == before, "Training has no countdown or timed rows")

func test_live_pressure() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.pressure_enabled = false
	game.save = SaveStore.new("/private/tmp/punch_pop_v5_test_punch_pop_pressure.cfg")
	root.add_child(game)
	await process_frame
	game.reset_transients()
	game.model.reset(20261022)
	game.sync_model()
	game.checkpoint()
	game.pressure_enabled = true
	for menu in ["home", "pause", "settings", "help", "resume"]:
		game.overlay = menu
		var seconds: float = game.model.rise_remaining
		game.tick_pressure(.25)
		check(game.model.rise_remaining == seconds, "Pressure pauses in the %s menu" % menu)
	game.overlay = ""
	game.busy = true
	var seconds: float = game.model.rise_remaining
	game.tick_pressure(.25)
	check(game.model.rise_remaining == seconds, "Explanations and animations cost no decision time")
	game.busy = false
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	game.tick_pressure(.25)
	check(game.overlay == "pause" and game.model.rise_remaining == seconds, "App switching pauses the countdown")
	game.overlay = ""
	game.model.rise_remaining = .1
	game.dragging = true
	game.touch_id = 0
	game.hover = Vector2i(0, 5)
	game.undo_state = game.model.snapshot()
	game.tick_pressure(.1)
	check(game.busy and not game.dragging and game.touch_id == -1, "Expiry cancels held input before the board moves")
	check(game.undo_state.is_empty(), "Elapsed-time rises cannot be undone into free thinking time")
	var interrupted := SaveStore.new("/private/tmp/punch_pop_v5_test_punch_pop_pressure.cfg")
	interrupted.load_data()
	check(interrupted.round_data.get("rise_remaining", -1) == 0 and interrupted.undo_data.is_empty(), "An interrupted rise preserves the expired clock rather than refunding time")
	game.pressure_enabled = false
	while game.busy:
		await process_frame
	check(game.turns == 0 and game.model.timed_rows == 1 and game.phase == "idle", "Live timer presents one complete rise without spending a move")
	check(game.board.snapshot() == game.model.board.snapshot(), "Animated rise ends on the authoritative board")
	var store := SaveStore.new("/private/tmp/punch_pop_v5_test_punch_pop_pressure.cfg")
	store.load_data()
	check(store.round_data == game.model.snapshot(), "Completed timed rise is checkpointed atomically")
	game.reset_transients()
	game.model.reset(20261022)
	game.sync_model()
	await game.place_cutter(CutterManager.placements(game.model.board, game.model.tray[game.selected])[0])
	game.model.advance_clock(2.5)
	game.undo_move()
	check(is_equal_approx(game.model.rise_remaining, 9.5 - game.model.effort_seconds) and game.model.active_seconds == 2.5, "Undo restores the move but never refunds thinking time")
	game.model.board.put(Vector2i(0, 0), 2)
	game.model.rise_remaining = 0
	await game.rise_from_timer()
	check(game.over and game.overlay == "over" and game.model.end_reason == "timer", "A timed ceiling collision shows the correct game-over reason")
	check(game.undo_state.is_empty(), "Timer death has no rewind that erases the pressure row")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("/private/tmp/punch_pop_v5_test_punch_pop_pressure.cfg")

func test_preview_clock_cache() -> void:
	var path := "/private/tmp/punch_pop_preview_clock_cache.cfg"
	DirAccess.remove_absolute(path)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save = SaveStore.new(path)
	game.pressure_enabled = false
	root.add_child(game)
	await process_frame
	game.model.reset(700, 2)
	game.model.lesson = -1
	game.model.rise_period = 2.75
	game.model.rise_remaining = 2.75
	game.sync_model()
	game.select_cutter(0)
	game.precise = true
	game.hover = Vector2i(0, 5)
	var before: Dictionary = game.model.snapshot()
	check(is_equal_approx(game.preview().time_bonus, .275), "A full countdown previews only chain credit that offsets effort")
	game.model.advance_clock(.1)
	check(is_equal_approx(game.preview().time_bonus, .375), "A stationary preview updates chain time as the clock changes")
	game.model.advance_clock(.75)
	check(game.preview().time_bonus == .5, "A stationary preview caps its clock reward at the chain value")
	check(game.forecast_cache.size() == 1, "Clock-only preview updates reuse the existing board simulation")
	var after: Dictionary = game.model.snapshot()
	before.active_seconds = after.active_seconds
	before.rise_remaining = after.rise_remaining
	check(before == after, "Repeated previews change no board, score, random future or hand")
	game.model.turns = 200
	game.model.rise_period = 4.0
	game.model.rise_remaining = 4.0
	check(game.preview().effort == game.model.punch_effort(), "A stationary preview reflects escalated punch effort")
	var initial_rows: int = game.preview().rows_due
	game.model.advance_clock(2.6)
	check(game.preview().rows_due > initial_rows and game.forecast_cache.size() == 1, "A stationary preview updates the owed row count without repeating board simulation")
	game.model.lesson = 2
	check(game.preview().time_bonus == 0.0, "Training previews never gain clock rewards")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)

# Clock accounting intentionally survives undo; random future and game content do not.
func without_clock(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	for key in ["active_seconds", "rise_remaining", "rise_period", "effort_seconds", "pending_effort"]:
		result.erase(key)
	return result

func same_checkpoint(a: Dictionary, b: Dictionary) -> bool:
	if a.keys().size() != b.keys().size():
		return false
	for key in b:
		if not a.has(key):
			return false
		if b[key] is float:
			if not is_equal_approx(float(a[key]), b[key]):
				return false
		elif a[key] != b[key]:
			return false
	return true

func test_punch_effort() -> void:
	var model := RoundModel.new()
	model.reset(700, 1)
	var training := model.snapshot()
	var forecast := model.forecast(0, LessonBook.GOALS[1])
	check(forecast.effort == 0 and forecast.clock_delta == 0, "Training forecasts charge no punch effort")
	model.play(0, LessonBook.GOALS[1])
	check(model.effort_seconds == 0 and model.rise_remaining == training.rise_remaining, "Training cuts preserve the full clock")
	model.reset(700, 1)
	model.lesson = -1
	model.turns = 200
	model.rise_period = 4.0
	model.rise_remaining = .1
	forecast = model.forecast(0, LessonBook.GOALS[1])
	var before := model.snapshot()
	var events := model.play(0, LessonBook.GOALS[1])
	check(not events.is_empty() and model.turns == 201, "A last-moment legal cut resolves before its owed rise")
	check(is_equal_approx(model.effort_seconds, forecast.effort), "Successful cuts record the complete forecast punch cost")
	check(model.rise_remaining == 0 and is_equal_approx(model.pending_effort, forecast.effort - forecast.time_bonus - .1), "Punch overshoot is retained as owed clock debt")
	check(RoundModel.valid(model.snapshot()), "An expired clock with owed effort remains a valid checkpoint")
	var clone := RoundModel.new()
	check(clone.restore(model.snapshot()), "Saving an owed rise preserves punch debt")
	var blocked := model.snapshot()
	check(model.play(model.selected, CutterManager.placements(model.board, model.tray[model.selected])[0]).is_empty() and model.snapshot() == blocked, "An owed rise cannot be bypassed by another fast punch")
	var rows := 0
	while model.rise_remaining <= 0 and not model.over:
		model.expire_clock()
		clone.expire_clock()
		rows += 1
	check(model.snapshot() == clone.snapshot(), "Saved effort debt produces the identical row and random future")
	check(rows >= 1 and model.pending_effort == 0, "Owed rises consume all overshoot instead of forgiving fast cuts")
	var old := before.duplicate(true)
	old.version = 4
	old.erase("effort_seconds")
	old.erase("pending_effort")
	check(clone.restore(old) and clone.effort_seconds == 0 and clone.pending_effort == 0, "Version-four rounds migrate with no invented past effort")
	check(clone.board.snapshot() == old.cells and clone.rise_remaining == old.rise_remaining and str(clone.rng.state) == old.rng_state, "Version-four migration preserves board, partial clock and random future")
	model.reset(700, 2)
	old = model.snapshot()
	old.version = 4
	old.erase("effort_seconds")
	old.erase("pending_effort")
	check(clone.restore(old) and clone.lesson == 2 and clone.board.snapshot() == old.cells, "Version-four training retains its existing correct lesson layout")
	# A four-wave credit can fund thinking after the punch. Undo removes that
	# credit too, so legitimate debt can exceed cumulative gross punch effort.
	model.reset(700)
	model.rise_remaining = .1
	var pre_chain := model.snapshot()
	var long_chain_receipt := model.clock_forecast(4)
	model.effort_seconds += long_chain_receipt.effort
	model.set_clock_balance(model.rise_remaining + long_chain_receipt.clock_delta)
	model.advance_clock(.3)
	check(model.restore_undo(pre_chain), "Undo accepts a chain-funded thinking checkpoint")
	check(is_equal_approx(model.pending_effort, 1.4) and model.pending_effort > model.effort_seconds, "Undo retains thinking previously funded by the reversed chain reward")
	check(RoundModel.valid(model.snapshot()), "Chain-funded thinking debt remains a valid checkpoint")
	var debt_path := "/private/tmp/punch_pop_chain_funded_undo.cfg"
	var debt_store := SaveStore.new(debt_path)
	debt_store.round_data = model.snapshot()
	check(debt_store.save_data(), "Undo debt saves successfully")
	var debt_reload := SaveStore.new(debt_path)
	debt_reload.load_data()
	check(clone.restore(debt_reload.round_data) and is_equal_approx(clone.pending_effort, 1.4), "Disk reload retains undo debt larger than gross effort")
	model.expire_clock()
	clone.expire_clock()
	check(same_checkpoint(model.snapshot(), clone.snapshot()), "Reloaded chain-funded debt settles the identical owed row")
	DirAccess.remove_absolute(debt_path)
	for key in ["effort_seconds", "pending_effort"]:
		for value in [-1.0, INF, NAN]:
			var corrupt := model.snapshot()
			corrupt[key] = value
			check(not RoundModel.valid(corrupt), "Invalid effort accounting is rejected")
	var corrupt := model.snapshot()
	corrupt.pending_effort = 1.0
	corrupt.effort_seconds = 1.0
	check(not RoundModel.valid(corrupt), "A positive live clock cannot also owe punch debt")

func test_live_effort_debt() -> void:
	var path := "/private/tmp/punch_pop_live_effort_debt.cfg"
	DirAccess.remove_absolute(path)
	var game = load("res://scenes/main.tscn").instantiate()
	game.save = SaveStore.new(path)
	game.pressure_enabled = false
	root.add_child(game)
	await process_frame
	game.round_available = true
	game.reset_transients()
	game.model.reset(700, 1)
	game.model.lesson = -1
	game.model.turns = 200
	game.model.rise_period = 4.0
	game.model.rise_remaining = .1
	game.sync_model()
	var predicted: Dictionary = game.model.forecast(0, LessonBook.GOALS[1])
	check(predicted.rows_due == 2, "A late shallow punch truthfully previews two owed rises")
	await game.place_cutter(LessonBook.GOALS[1])
	check(game.model.rise_remaining == 0 and game.model.pending_effort > 4, "Live cut keeps both owed rises after its animation")
	var disk := SaveStore.new(path)
	disk.load_data()
	check(disk.round_data.rise_remaining == 0 and is_equal_approx(disk.round_data.pending_effort, game.model.pending_effort), "Interruption preserves the expired clock and all owed punch effort")
	await game.rise_from_timer()
	check(game.model.timed_rows == 1 and game.model.rise_remaining == 0 and game.undo_state.is_empty(), "The first owed row clears undo and preserves the next owed rise")
	await game.rise_from_timer()
	check(game.model.timed_rows == 2 and game.model.rise_remaining > 0 and game.model.pending_effort == 0 and not game.busy, "Two owed rows finish sequentially and settle the full debt")
	check(game.board.snapshot() == game.model.board.snapshot(), "Consecutive owed row animations settle on the authoritative board")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute(path)
