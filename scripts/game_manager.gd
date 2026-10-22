extends Node2D

signal phase_changed(stage: String)

const COLORS := UIManager.COLORS
const COLOR_NAMES := UIManager.COLOR_NAMES
const ACCENT := UIManager.ACCENT
const BOARD_POS := UIManager.BOARD_POS
const CELL := UIManager.CELL
const BASE_SIZE := Vector2(540, 1080)

var model := RoundModel.new()
var board := BoardManager.new()
var rng: RandomNumberGenerator:
	get: return model.rng
var save := SaveStore.new()
var effects: EffectsManager
var ui: UIManager
var tray: Array = []
var incoming: Array = []
var selected := 0
var targets: Dictionary = {}
var aim_targets: Dictionary = {}
var tray_insights: Array = []
var hover := Vector2i(-99, -99)
var precise := false
var forecast_cache: Dictionary = {}
var undo_state: Dictionary = {}
var dragging := false
var pause_after_move := false
var touch_id := -1
var busy := false
var over := false
var overlay := ""
var score := 0
var turns := 0
var combo := 0
var best_combo := 0
var tutorial := 0
var notice := ""
var notice_time := 0.0
var floaters: Array = []
var elapsed := 0.0
var movements: Array = []
var shrinking: Array = []
var landing: Array = []
var landing_time := 0.0
var anticipating: Array = []
var anim_t := 1.0
var shake := 0.0
var celebration := ""
var celebration_time := 0.0
var screen_board_offset := Vector2.ZERO
var phase := "idle"
var phase_title := ""
var phase_detail := ""
var match_groups: Array = []
var active_wave := 0
var last_summary: Dictionary = {}
var last_clear_title := ""
var last_clear_detail := ""
var last_clear_time := 0.0
var turn_trace: Array = []
# Harnesses can step decision time explicitly; the live game always enables it.
var pressure_enabled := true
var row_rising := false
var rise_t := 0.0
var rising_colors: Array = []
var replay_rect := Rect2(95, 698, 350, 60)

func _ready() -> void:
	save.load_data()
	ui = UIManager.new()
	ui.game = self
	add_child(ui)
	effects = EffectsManager.new()
	add_child(effects)
	_sync_settings()
	if not save.round_data.is_empty() and model.restore(save.round_data):
		undo_state = save.undo_data.duplicate(true)
		sync_model()
		overlay = "resume"
	else:
		start_game()
	var args := OS.get_cmdline_user_args()
	if "--screenshot" in args:
		await get_tree().create_timer(.5).timeout
		var index := args.find("--screenshot")
		var path := args[index + 1] if index + 1 < args.size() else "/tmp/punch-pop.png"
		get_viewport().get_texture().get_image().save_png(path)
		get_tree().quit()

func start_game(force_tutorial: bool = false) -> void:
	reset_transients()
	model.reset(-1, 0 if force_tutorial or not save.tutorial_done else -1)
	undo_state = {}
	sync_model()
	checkpoint()

func reset_transients() -> void:
	busy = false
	dragging = false
	pause_after_move = false
	touch_id = -1
	overlay = ""
	precise = false
	hover = Vector2i(-99, -99)
	movements.clear()
	shrinking.clear()
	anticipating.clear()
	match_groups.clear()
	last_summary.clear()
	last_clear_title = ""
	last_clear_detail = ""
	last_clear_time = 0
	turn_trace.clear()
	phase = "idle"
	phase_title = ""
	phase_detail = ""
	active_wave = 0
	row_rising = false
	rising_colors.clear()
	landing.clear()
	landing_time = 0
	floaters.clear()
	celebration = ""
	celebration_time = 0
	shake = 0
	notice_time = 0
	if is_instance_valid(effects):
		effects.particles.clear()
		effects.rings.clear()

func sync_model() -> void:
	board.cells = model.board.snapshot()
	tray = model.tray.duplicate(true)
	incoming = model.incoming.duplicate()
	score = model.score
	turns = model.turns
	combo = model.combo
	best_combo = model.best_combo
	over = model.over
	tutorial = model.lesson + 1
	tray_insights.clear()
	for slot in tray.size():
		var best := 0
		if not tray[slot].is_empty() and not over:
			for origin in CutterManager.placements(model.board, tray[slot]):
				best = maxi(best, model.forecast(slot, origin).get("waves", 0))
		tray_insights.append(best)
	select_cutter(model.selected)

func checkpoint() -> void:
	save.best = maxi(save.best, model.score if model.lesson < 0 else 0)
	save.round_data = {} if model.over else model.snapshot()
	save.undo_data = undo_state.duplicate(true)
	if not save.save_data():
		message("Save failed. Keep this game open and free storage.", 6)

func _sync_settings() -> void:
	effects.sound_enabled = save.sound
	effects.haptics_enabled = save.haptics
	effects.reduced_motion = save.reduced_motion

func message(value: String, duration: float = 2.5) -> void:
	notice = value
	notice_time = duration

func _process(delta: float) -> void:
	elapsed += delta
	position = (get_viewport_rect().size - BASE_SIZE) / 2.0
	notice_time = maxf(0, notice_time - delta)
	last_clear_time = maxf(0, last_clear_time - delta)
	landing_time = maxf(0, landing_time - delta)
	celebration_time = maxf(0, celebration_time - delta)
	shake = maxf(0, shake - delta * 18)
	screen_board_offset = Vector2.ZERO if save.reduced_motion else Vector2(sin(elapsed * 83), cos(elapsed * 71)) * shake
	for f in floaters:
		f.life -= delta
		f.p.y -= delta * (12 if save.reduced_motion else 32)
	floaters = floaters.filter(func(f: Dictionary) -> bool: return f.life > 0)
	tick_pressure(delta)
	effects.visible = overlay.is_empty()
	ui.queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Disk contains the last settled round even during an animation.
		if is_instance_valid(ui) and not busy:
			checkpoint()
		return
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT:
		return
	dragging = false
	touch_id = -1
	hover = Vector2i(-99, -99)
	if is_instance_valid(ui) and not over:
		if busy:
			pause_after_move = true
		else:
			checkpoint()
			if overlay.is_empty():
				overlay = "pause"

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and not over and not busy:
			overlay = "pause" if overlay.is_empty() else ("lesson" if model.lesson_complete else "")
			dragging = false
		if not busy and event.keycode == KEY_Z:
			undo_move()
		if not busy and overlay.is_empty() and event.keycode == KEY_A:
			precise = not precise
			hover = Vector2i(-99, -99)
		if event.keycode == KEY_M:
			save.sound = not save.sound
			save.save_data()
			_sync_settings()
		return
	if event is InputEventScreenTouch:
		if event.pressed and touch_id == -1:
			touch_id = event.index
			press(event.position - position)
		elif not event.pressed and event.index == touch_id:
			if not event.canceled:
				release(event.position - position)
			else:
				dragging = false
				hover = Vector2i(-99, -99)
			touch_id = -1
	elif event is InputEventScreenDrag and event.index == touch_id:
		move_pointer(event.position - position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			press(event.position - position)
		else:
			release(event.position - position)
	elif event is InputEventMouseMotion:
		move_pointer(event.position - position)

func cell_at(p: Vector2) -> Vector2i:
	return Vector2i(floor((p.x - BOARD_POS.x) / CELL), floor((p.y - BOARD_POS.y) / CELL))

func press(p: Vector2) -> void:
	if not overlay.is_empty():
		overlay_press(p)
		return
	if busy or over:
		return
	if Rect2(432, 26, 52, 60).has_point(p):
		overlay = "pause"
		return
	if Rect2(376, 26, 52, 60).has_point(p):
		overlay = "help"
		return
	if Rect2(60, 1014, 132, 44).has_point(p):
		if tutorial > 0:
			finish_tutorial()
		else:
			undo_move()
		return
	if Rect2(204, 1014, 132, 44).has_point(p) and tutorial == 0:
		precise = not precise
		hover = Vector2i(-99, -99)
		message("Aim: tap the stamp's top-left cell" if precise else "Easy tap: choose an outlined block")
		return
	for i in tray.size():
		if not tray[i].is_empty() and Rect2(60 + i * 144, 862, 132, 136).has_point(p):
			select_cutter(i)
			checkpoint()
			dragging = true
			return
	if Rect2(BOARD_POS, Vector2(420, 540)).has_point(p):
		dragging = true
		hover = cell_at(p)

func select_cutter(index: int) -> void:
	selected = index
	model.selected = index
	hover = Vector2i(-99, -99)
	forecast_cache.clear()
	aim_targets.clear()
	if index >= 0 and index < tray.size() and not tray[index].is_empty():
		for origin in CutterManager.placements(board, tray[index]):
			aim_targets[origin] = true
	targets = CutterManager.target_map(board, tray[index]) if index >= 0 and index < tray.size() and not tray[index].is_empty() else {}

func preview_origin() -> Vector2i:
	return hover if precise else targets.get(hover, Vector2i(-99, -99))

func preview() -> Dictionary:
	if busy or over or selected < 0 or selected >= tray.size() or tray[selected].is_empty():
		return {}
	var origin := preview_origin()
	if not forecast_cache.has(origin):
		forecast_cache[origin] = model.forecast(selected, origin)
	return forecast_cache[origin]

func move_pointer(p: Vector2) -> void:
	if busy or not overlay.is_empty():
		return
	hover = cell_at(p)

func release(p: Vector2) -> void:
	if dragging and not busy and not over and overlay.is_empty():
		hover = cell_at(p)
		if Rect2(BOARD_POS, Vector2(420, 540)).has_point(p):
			var origin := preview_origin()
			if CutterManager.hits(board, tray[selected], origin).size() >= 2:
				place_cutter(origin)
			else:
				message("Cover two of your cutter's colour" if precise else "Tap an outlined %s block" % COLOR_NAMES[tray[selected].color].to_lower())
	dragging = false

func tick_pressure(delta: float) -> void:
	if not pressure_enabled or busy or over or tutorial > 0 or not overlay.is_empty():
		return
	var previous := model.rise_remaining
	if model.advance_clock(minf(delta, .25)):
		rise_from_timer()
	elif previous > 2 and model.rise_remaining <= 2:
		effects.sound("warning")

func rise_from_timer() -> void:
	if busy or over or tutorial > 0 or model.rise_remaining > 0:
		return
	# Persist the expired clock before resolution; interrupted rises are replayed.
	undo_state = {}
	checkpoint()
	var before := model.snapshot()
	var old_level := SupplySystem.pressure_level(turns, model.active_seconds)
	var old_best := save.best
	var events := model.expire_clock()
	if not events.is_empty():
		await present_events(events, before, old_level, old_best)

func place_cutter(origin: Vector2i) -> void:
	if busy or over or model.lesson_complete:
		return
	var before := model.snapshot()
	# Preserve both the completed board and its current clock during animation.
	checkpoint()
	var old_level := SupplySystem.pressure_level(turns, model.active_seconds)
	var old_best := save.best
	var events := model.play(selected, origin)
	if events.is_empty():
		return
	undo_state = before if tutorial == 0 else {}
	await present_events(events, before, old_level, old_best)

func present_events(events: Array, before: Dictionary, old_level: int, old_best: int) -> void:
	busy = true
	dragging = false
	touch_id = -1
	hover = Vector2i(-99, -99)
	combo = 0
	turn_trace.clear()
	last_summary.clear()
	# Keep the pre-turn checkpoint until every calculated step is presented.
	for event in events:
		match event.type:
			"pop":
				active_wave = event.wave
				anticipating = event.points.duplicate()
				match_groups = event.groups.duplicate(true)
				if event.wave == 0:
					var name: String = COLOR_NAMES[board.at(event.points[0])]
					set_phase("cut", "YOU CUT %d %s" % [event.points.size(), name], "Only the cutter's colour is removed.")
				else:
					var title := "%d GROUPS OF 4+ CONNECTED" % event.groups.size()
					if event.groups.size() == 1:
						var group: Array = event.groups[0]
						title = "%d %s CONNECTED" % [group.size(), COLOR_NAMES[board.at(group[0])]]
					if event.wave > 1:
						title = "CHAIN ×%d: " % event.wave + title
					var reason := "Same colour + touching sides = automatic clear."
					if event.wave > 1:
						reason = "Another fall made a new group. That's a chain."
					elif event.source == "new_row":
						reason = "New blocks completed this group. Same 4+ rule."
					elif event.source == "refill":
						reason = "Restocking completed this group. Same 4+ rule."
					set_phase("match", title, reason)
				var hold := ((.70 if event.wave == 1 else .50) if event.wave > 0 else .07) if save.explain_clears else (.12 if event.wave > 0 else .0)
				if hold > 0:
					await get_tree().create_timer(hold).timeout
				score += event.earned
				combo = maxi(combo, event.wave)
				add_floater("+%d" % event.earned, cell_center(event.points[0]), ACCENT)
				await pop_cells(event.points, event.wave)
				anticipating.clear()
				match_groups.clear()
			"fall":
				set_phase("fall", "BLOCKS FALL INTO THE GAPS", "A fall can connect four or more of one colour.")
				board.cells = event.cells.duplicate(true)
				movements = event.moves
				anim_t = 0
				var tween := create_tween()
				tween.tween_property(self, "anim_t", 1.0, .10 if save.reduced_motion else .23).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				await tween.finished
				landing = event.moves.map(func(m: Dictionary) -> Vector2i: return m.to)
				landing_time = .22 if not save.reduced_motion else 0.0
				movements.clear()
				effects.sound("land", 0)
			"row":
				var title := "TIME UP — ROW RISES" if event.reason == "timer" else "BOTTOM ROW RISES" if event.reason == "scheduled" else "LOW BOARD — RESTOCK"
				var detail := "Everything moves up one. Keep below the ceiling."
				if event.reason == "scheduled":
					detail = "Move pressure: the previewed row pushes up."
				elif event.reason == "refill":
					detail = "Fresh blocks keep the board playable."
				set_phase("supply", title, detail)
				incoming = event.colors.duplicate()
				await get_tree().create_timer(.16 if save.explain_clears else .06).timeout
				row_rising = true
				rising_colors = event.colors.duplicate()
				rise_t = 0
				effects.sound("supply", 0)
				var lift := create_tween()
				lift.tween_property(self, "rise_t", 1.0, .12 if save.reduced_motion else .32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
				await lift.finished
				board.cells = event.cells.duplicate(true)
				row_rising = false
				rising_colors.clear()
				incoming = event.next.duplicate()
			"fresh":
				set_phase("supply", "LOW BOARD → RESTOCK", "Clearing earned fresh blocks. This is not a penalty.")
				await get_tree().create_timer(.20 if save.explain_clears else .05).timeout
	last_summary = TurnSummary.from_events(events)
	last_clear_time = 3.5 if last_summary.matched > 0 else 0.0
	sync_model()
	busy = false
	set_phase("idle", "", "")
	if model.lesson_complete:
		overlay = "lesson"
	elif over:
		notice = "The rising board crossed the ceiling."
		overlay = "over"
	elif SupplySystem.pressure_level(turns, model.active_seconds) > old_level:
		celebrate("PRESSURE %d" % SupplySystem.pressure_level(turns, model.active_seconds))
	elif old_best > 0 and score > old_best and before.score <= old_best:
		celebrate("NEW BEST!")
	if pause_after_move and overlay.is_empty():
		overlay = "pause"
	pause_after_move = false
	checkpoint()

func set_phase(stage: String, title: String, detail: String) -> void:
	phase = stage
	phase_title = title
	phase_detail = detail
	if stage == "match":
		last_clear_title = title
		last_clear_detail = detail
	turn_trace.append({"phase": stage, "title": title, "groups": match_groups.duplicate(true)})
	phase_changed.emit(stage)

func pop_cells(points: Array, wave: int) -> void:
	shrinking = points.duplicate()
	anim_t = 0
	effects.sound("cut" if wave == 0 else "chain" if wave > 1 else "match", wave)
	for p in points:
		effects.burst(cell_center(p), board.at(p), 5 if save.reduced_motion else 8 + wave * 3)
	if wave > 0:
		shake = minf(3.5, 1 + wave)
	var tween := create_tween()
	tween.tween_property(self, "anim_t", 1.0, .09 if save.reduced_motion else .14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	board.remove(points)
	shrinking.clear()

func undo_move() -> void:
	if busy or undo_state.is_empty():
		return
	var previous := undo_state.duplicate(true)
	var seconds := model.active_seconds
	var remaining := model.rise_remaining
	reset_transients()
	if model.restore(previous):
		model.active_seconds = maxf(seconds, model.active_seconds)
		model.rise_remaining = minf(remaining, model.rise_remaining)
		undo_state = {}
		sync_model()
		checkpoint()
		message("Move undone. The pressure clock keeps its time.")

func next_lesson() -> void:
	var index := model.lesson + 1
	if index >= 3:
		finish_tutorial()
		return
	reset_transients()
	model.reset(-1, index)
	sync_model()
	checkpoint()

func finish_tutorial() -> void:
	save.tutorial_done = true
	save.save_data()
	start_game()
	message("Cut 2+. Match 4+. Beat the rising rows.", 4)

func celebrate(value: String) -> void:
	celebration = value
	celebration_time = 1.6

func add_floater(value: String, at: Vector2, color: Color) -> void:
	floaters.append({"text": value, "p": at, "color": color, "life": .9})

func cell_center(p: Vector2i) -> Vector2:
	return BOARD_POS + Vector2(p) * CELL + Vector2.ONE * CELL / 2

func overlay_press(p: Vector2) -> void:
	if busy:
		return
	if overlay == "lesson":
		if replay_rect.has_point(p):
			next_lesson()
		return
	if overlay == "over":
		if Rect2(95, 625, 350, 50).has_point(p):
			undo_move()
		elif replay_rect.has_point(p):
			start_game()
		return
	if overlay == "resume":
		if Rect2(95, 625, 350, 50).has_point(p):
			start_game()
		elif replay_rect.has_point(p):
			overlay = "lesson" if model.lesson_complete else ""
		return
	if replay_rect.has_point(p):
		overlay = "lesson" if model.lesson_complete else ""
		return
	if overlay == "pause":
		if Rect2(95, 407, 169, 45).has_point(p):
			save.sound = not save.sound
		elif Rect2(276, 407, 169, 45).has_point(p):
			save.haptics = not save.haptics
		elif Rect2(95, 460, 350, 45).has_point(p):
			save.explain_clears = not save.explain_clears
		elif Rect2(95, 513, 350, 45).has_point(p):
			save.reduced_motion = not save.reduced_motion
		elif Rect2(95, 566, 350, 45).has_point(p):
			save.high_contrast = not save.high_contrast
		elif Rect2(95, 625, 169, 50).has_point(p):
			start_game()
		elif Rect2(276, 625, 169, 50).has_point(p):
			start_game(true)
		save.save_data()
		_sync_settings()
