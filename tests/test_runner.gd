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
	test_spawn()
	test_generation()
	test_round_model()
	test_clear_explanations()
	test_save_validation()
	test_pressure_model()
	await test_game_flow()
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
	game.overlay = "pause"
	await process_frame
	check(not game.effects.visible, "Particles cannot obscure help or pause menus")
	game.overlay_press(Vector2(270, 482))
	check(not game.save.explain_clears, "Pause control enables quick clears")
	game.overlay_press(Vector2(270, 482))
	check(game.save.explain_clears, "Pause control restores readable explanations")
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
		var target: Vector2i = game.targets.keys()[0]
		game.press(game.cell_center(target))
		check(not game.busy and game.turns == 0, "Press previews without committing")
		game.release(game.cell_center(target))
		while game.busy:
			await process_frame
		check(game.overlay == "lesson" and game.model.lesson_complete, "Lesson shows a clear success state")
		check(game.combo >= index if index > 0 else game.score == 20, "Lessons demonstrate cut, match, then two-wave chain")
		game.next_lesson()
	check(game.tutorial == 0 and game.save.tutorial_done, "Finishing all lessons enters endless and saves completion")
	check(not game.targets.is_empty(), "Endless starts with usable cutters")
	check(game.tray_insights.all(func(value: int) -> bool: return value == 0), "Endless trays leave chain discovery to the player")
	# Chain animation is tested on authored terrain, independent of random openings.
	game.model.board.clear()
	LessonBook.chain_pocket(game.model.board)
	game.model.tray = CutterManager.diverse_refresh(game.model.board, [{"shape": 1, "color": 3}, {}, {}], game.model.rng)
	game.sync_model()
	game.checkpoint()
	var target := Vector2i(0, 6)
	var before: Dictionary = game.model.snapshot()
	var prediction: Dictionary = game.model.forecast(game.selected, game.targets[target])
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
	check(game.model.snapshot() == before, "Undo restores the exact board, score, tray, turn and RNG state")
	check(game.undo_state.is_empty(), "Undo cannot rewind an unlimited history")
	game.precise = true
	game.hover = Vector2i(0, 6)
	check(game.preview_origin() == Vector2i(0, 6) and not game.preview().is_empty(), "Aim mode exposes exact legal stamp origins")
	await game.place_cutter(Vector2i(0, 6))
	check(game.model.snapshot() == after, "Replaying after undo produces identical future cutters and rows")
	var loaded := SaveStore.new("/private/tmp/punch_pop_v5_test_punch_pop_v2.cfg")
	loaded.load_data()
	check(loaded.round_data == after and not loaded.undo_data.is_empty(), "Settled round and undo are written to disk")
	var resumed = load("res://scenes/main.tscn").instantiate()
	resumed.save = loaded
	resumed.pressure_enabled = false
	root.add_child(resumed)
	await process_frame
	check(resumed.overlay == "resume" and resumed.model.snapshot() == after, "A new game instance restores the exact checkpoint")
	resumed.overlay_press(Vector2(270, 730))
	check(resumed.overlay.is_empty(), "Continue returns to the saved board")
	resumed.undo_move()
	check(resumed.model.snapshot() == before, "Undo also survives quitting and resuming")
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
	check(resumed.over and resumed.overlay == "over", "Live overflow displays the game-over state")
	resumed.undo_move()
	check(not resumed.over and resumed.turns == 1 and resumed.score == 0, "Undo can recover from game over")
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
	for y in range(6, 9):
		for x in 7:
			stranded.put(Vector2i(x, y), (x + 2 * y) % 4)
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
	events = model.play(0, Vector2i(0, 8))
	check(model.board.occupied() == 2 and model.turns == 48, "A good cut preserves breathing room even at late pressure levels")
	check(not events.any(func(e: Dictionary) -> bool: return e.type in ["row", "fresh"]), "A sparse playable board receives no surprise refill")
	check(model.incoming == previewed and model.rise_remaining == 8, "Cuts preserve the preview and pending countdown")
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
	check(model.over and SupplySystem.height(model.board, 6) == 9, "A stranded full column blocks recovery without partial insertion")
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
			if model.over:
				break
			var slot := turn % 3
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
	var events := model.play(0, Vector2i(0, 6))
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
	check(store.explain_clears, "Readable clear explanations are enabled by default")
	store.explain_clears = false
	store.save_data()
	var loaded := SaveStore.new("/private/tmp/punch_pop_v5_test_clear_guide.cfg")
	loaded.load_data()
	check(not loaded.explain_clears, "Quick-clear preference survives a restart")
	DirAccess.remove_absolute(store.path)

func test_pressure_model() -> void:
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
	check(not model.advance_clock(7.5) and is_equal_approx(model.rise_remaining, .5), "Countdown advances only by explicit active decision time")
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
	model.play(0, CutterManager.placements(model.board, model.tray[0])[0])
	check(model.rise_remaining == 5 and model.active_seconds == 3, "Cuts and chains never reset the pressure clock")
	check(SupplySystem.rise_interval(0, 0) == 8 and SupplySystem.rise_interval(84, 160) == 3.5, "Pressure accelerates from eight seconds to a bounded 3.5 seconds")
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
	model.advance_clock(4.75)
	clone.advance_clock(4.75)
	model.expire_clock()
	clone.expire_clock()
	check(model.snapshot() == clone.snapshot(), "Restoring a partial clock preserves the exact timed-row future")
	var legacy := model.snapshot()
	legacy.version = 2
	legacy.turns = 80
	for key in ["active_seconds", "rise_remaining", "rise_period", "timed_rows", "end_reason"]:
		legacy.erase(key)
	check(clone.restore(legacy) and clone.board.snapshot() == legacy.cells and clone.score == legacy.score and str(clone.rng.state) == legacy.rng_state, "Version-two boards, scores and RNG migrate without resetting progress")
	check(clone.rise_remaining == 8 and clone.rise_period == 8, "Older long runs receive a full first countdown when upgraded")
	for bad in [-1.0, 9.0, INF, NAN]:
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
	for menu in ["pause", "help", "resume"]:
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
	game.hover = Vector2i(0, 6)
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
	check(game.model.rise_remaining == 5.5 and game.model.active_seconds == 2.5, "Undo restores the move but never refunds thinking time")
	game.model.board.put(Vector2i(0, 0), 2)
	game.model.rise_remaining = 0
	await game.rise_from_timer()
	check(game.over and game.overlay == "over" and game.model.end_reason == "timer", "A timed ceiling collision shows the correct game-over reason")
	check(game.undo_state.is_empty(), "Timer death has no rewind that erases the pressure row")
	game.queue_free()
	await process_frame
	DirAccess.remove_absolute("/private/tmp/punch_pop_v5_test_punch_pop_pressure.cfg")
