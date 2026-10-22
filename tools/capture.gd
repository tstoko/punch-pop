extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	game.save = SaveStore.new("/private/tmp/punch-pop-preview-v4.cfg")
	game.pressure_enabled = false
	root.add_child(game)
	await process_frame
	game.start_game(true)
	await snap("lesson-one")
	game.model.reset(20261022, 2)
	game.sync_model()
	game.hover = Vector2i(0, 6)
	await snap("lesson-chain")
	game.place_cutter(Vector2i(0, 6))
	while game.busy and not (game.phase == "match" and game.active_wave == 1):
		await process_frame
	await snap("auto-match-preview")
	while game.busy and not (game.phase == "match" and game.active_wave == 2):
		await process_frame
	await snap("chain-explanation")
	while game.busy:
		await process_frame
	await snap("lesson-success")
	game.finish_tutorial()
	game.model.reset(20261022)
	game.reset_transients()
	game.sync_model()
	game.hover = Vector2i(0, 6)
	await snap("preview")
	await snap("placement-preview")
	game.precise = true
	await snap("aim-preview")
	game.precise = false
	game.overlay = "help"
	await snap("help-preview")
	game.overlay = "pause"
	await snap("settings-preview")
	game.overlay = ""
	game.save.high_contrast = true
	await snap("contrast-preview")
	game.save.high_contrast = false
	await game.place_cutter(Vector2i(0, 6))
	await create_timer(1).timeout
	await snap("after-chain")
	game.overlay = "resume"
	await snap("resume-preview")
	game.overlay = ""
	game.model.rise_remaining = 1.4
	game.hover = Vector2i(-99, -99)
	await snap("timer-warning")
	game.model.advance_clock(1.4)
	game.rise_from_timer()
	var guard := 0
	while game.busy and not (game.row_rising and game.rise_t >= .3) and guard < 300:
		guard += 1
		await process_frame
	if not game.row_rising:
		push_error("Timed-rise capture missed the animated stage")
		quit(1)
		return
	await snap("timer-rise")
	while game.busy:
		await process_frame
	await snap("timer-after")
	game.reset_transients()
	game.model.reset(123)
	game.model.board.clear()
	game.model.board.put(Vector2i(0, 8), 0)
	game.model.board.put(Vector2i(1, 8), 0)
	for y in [6, 7, 8]:
		game.model.board.put(Vector2i(3, y), 1)
	game.model.tray = [{"shape": 1, "color": 0}, {}, {}]
	game.model.turns = 1
	game.model.incoming = [0, 1, 2, 1, 3, 0, 2]
	game.sync_model()
	game.place_cutter(Vector2i(0, 8))
	while game.busy and game.phase != "match":
		await process_frame
	await snap("row-match-preview")
	while game.busy:
		await process_frame
	for y in 9:
		game.model.board.put(Vector2i(6, y), y % 4)
	game.sync_model()
	game.model.rise_remaining = 0
	await game.rise_from_timer()
	await snap("timer-over")
	game.queue_free()
	await process_frame
	await process_frame
	quit()

func snap(name: String) -> void:
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/%s.png" % name)
