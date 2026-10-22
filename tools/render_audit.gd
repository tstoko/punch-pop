extends SceneTree

var game: Node2D
var report := {"date": "2026-10-22", "rules": "v4 timed bottom rise", "scope": "Desktop Compatibility renderer on this Mac; not Android FPS or physical touch validation.", "viewports": [], "move_seconds": []}

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	game.save = SaveStore.new("/private/tmp/punch-pop-render-test.cfg")
	game.pressure_enabled = false
	root.add_child(game)
	await process_frame
	game.save.tutorial_done = true
	game.reset_transients()
	game.undo_state = {}
	game.model.reset(20261022)
	game.sync_model()
	for size in [Vector2i(360, 640), Vector2i(390, 844), Vector2i(768, 1024)]:
		DisplayServer.window_set_size(size)
		for i in 15:
			await process_frame
		game.overlay = ""
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/audit-%dx%d.png" % [size.x, size.y])
		var visible := root.get_visible_rect().size
		var board_rect := Rect2(game.position + game.BOARD_POS, Vector2(420, 540))
		var tray_rect := Rect2(game.position + Vector2(60, 862), Vector2(420, 136))
		report.viewports.append({"window": [size.x, size.y], "viewport": [visible.x, visible.y], "board_inside": Rect2(Vector2.ZERO, visible).encloses(board_rect), "tray_inside": Rect2(Vector2.ZERO, visible).encloses(tray_rect)})
	DisplayServer.window_set_size(Vector2i(450, 900))
	for i in 30:
		await process_frame
	game.overlay = ""
	var frame_ms: Array = []
	for i in 180:
		await process_frame
		frame_ms.append(game.get_process_delta_time() * 1000)
	frame_ms.sort()
	report.idle_frame_ms = {"median": frame_ms[90], "p95": frame_ms[171], "maximum": frame_ms.back(), "samples": frame_ms.size()}
	for i in 12:
		if game.over:
			break
		game.overlay = ""
		if i == 3:
			game.model.advance_clock(game.model.rise_remaining)
			await game.rise_from_timer()
			if game.over:
				break
		var target: Vector2i = game.targets.keys()[0]
		var began := Time.get_ticks_usec()
		game.press(game.cell_center(target))
		game.release(game.cell_center(target))
		while game.busy:
			await process_frame
		report.move_seconds.append((Time.get_ticks_usec() - began) / 1000000.0)
	report.timer_rows = game.model.timed_rows
	report.last_score = game.score
	report.last_turns = game.turns
	report.ui_style_cache_entries = game.ui.style_cache.size()
	report.game_over = game.over
	report.ending_message = game.notice
	game.overlay = "over" if game.over else ""
	await create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/audit-after-play.png")
	var file := FileAccess.open("res://docs/render-audit.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	print(JSON.stringify(report))
	quit()
