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
var drag_from_card := false
var drag_active := false
var drag_start_pos := Vector2.ZERO
var pointer_pos := Vector2.ZERO
var drag_origin := Vector2i(-99, -99)
var round_available := false
var settings_return := "home"
var pause_after_move := false
var touch_id := -1
var busy := false
var over := false
var overlay := ""
var score := 0
var turns := 0
var combo := 0
var best_combo := 0
var run_best := 0
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
	run_best = save.best
	ui = UIManager.new()
	ui.game = self
	add_child(ui)
	effects = EffectsManager.new()
	add_child(effects)
	_sync_settings()
	if not save.round_data.is_empty() and model.restore(save.round_data):
		undo_state = save.undo_data.duplicate(true)
		if save.round_data.get("version", 0) < RoundModel.VERSION and model.lesson >= 0:
			undo_state = {}
		sync_model()
		round_available = true
		overlay = "home"
	else:
		model.reset(-1, -1)
		sync_model()
		overlay = "home"
	var args := OS.get_cmdline_user_args()
	if "--screenshot" in args:
		await get_tree().create_timer(.5).timeout
		var index := args.find("--screenshot")
		var path := args[index + 1] if index + 1 < args.size() else "/tmp/punch-pop.png"
		get_viewport().get_texture().get_image().save_png(path)
		get_tree().quit()

func has_saved_round() -> bool:
	return round_available and not model.over

func go_home() -> void:
	cancel_gesture()
	if round_available:
		checkpoint()
	overlay = "home"

func cancel_gesture() -> void:
	dragging = false
	drag_from_card = false
	drag_active = false
	drag_origin = Vector2i(-99, -99)
	hover = Vector2i(-99, -99)
	touch_id = -1

func start_game(force_tutorial: bool = false) -> void:
	round_available = true
	run_best = save.best
	reset_transients()
	model.reset(-1, 0 if force_tutorial else -1)
	undo_state = {}
	sync_model()
	checkpoint()

func reset_transients() -> void:
	busy = false
	cancel_gesture()
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
		if tutorial > 0 and not tray[slot].is_empty() and not over:
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
		if is_instance_valid(ui) and not busy and round_available:
			checkpoint()
		return
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT:
		return
	cancel_gesture()
	if is_instance_valid(ui) and not over:
		if busy:
			pause_after_move = true
		else:
			if round_available:
				checkpoint()
			if overlay.is_empty():
				overlay = "pause"

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and not busy:
			if overlay == "settings":
				overlay = settings_return
			elif not over and overlay != "home":
				overlay = "pause" if overlay.is_empty() else ("lesson" if model.lesson_complete else "")
			cancel_gesture()
		if not busy and overlay in ["", "over"] and event.keycode == KEY_Z:
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
				cancel_gesture()
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
	pointer_pos = p
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
	for i in tray.size():
		if not tray[i].is_empty() and Rect2(60 + i * 144, 862, 132, 136).has_point(p):
			select_cutter(i)
			checkpoint()
			dragging = true
			drag_from_card = true
			drag_active = false
			drag_start_pos = p
			drag_origin = Vector2i(-99, -99)
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
	if tutorial > 0 and not model.lesson_complete and index >= 0 and index < tray.size() and not tray[index].is_empty():
		# An authored lesson teaches a specific outcome, never a false success
		# from another legal punch. Endless placement remains unrestricted.
		var goal: Vector2i = LessonBook.GOALS[model.lesson]
		aim_targets = {goal: true}
		targets.clear()
		for point in CutterManager.hits(board, tray[index], goal):
			targets[point] = goal

func preview_origin() -> Vector2i:
	if drag_from_card:
		return drag_origin
	return hover if precise else targets.get(hover, Vector2i(-99, -99))

func preview() -> Dictionary:
	if busy or over or selected < 0 or selected >= tray.size() or tray[selected].is_empty():
		return {}
	var origin := preview_origin()
	if not forecast_cache.has(origin):
		forecast_cache[origin] = model.forecast(selected, origin)
	var prediction: Dictionary = forecast_cache[origin]
	if not prediction.is_empty():
		# Keep the expensive board resolution cached while aiming. Clock credit
		# and punch effort depend on decision time, even at the same origin.
		prediction.merge(model.clock_forecast(prediction.waves), true)
	return prediction

# Card drags track the stamp centre above the finger. Snap only nearby legal
# placements and retain the current choice until another is clearly closer.
func move_pointer(p: Vector2) -> void:
	pointer_pos = p
	if busy or not overlay.is_empty():
		return
	hover = cell_at(p)
	if not drag_from_card:
		return
	drag_active = drag_active or p.distance_to(drag_start_pos) >= 12
	drag_origin = card_drag_origin(p) if drag_active else Vector2i(-99, -99)

# Ease the lift near the lower edge so the bottom row remains easy to reach
# without dragging back into the tray (which always cancels).
func card_drag_center(p: Vector2) -> Vector2:
	var lower_edge := clampf((p.y - (BOARD_POS.y + 420.0)) / 160.0, 0.0, 1.0)
	return p - Vector2(0, lerpf(100.0, 40.0, lower_edge))

func card_drag_origin(p: Vector2) -> Vector2i:
	if selected < 0 or selected >= tray.size() or tray[selected].is_empty():
		return Vector2i(-99, -99)
	# Leaving the board horizontally or dragging back to the cards cancels.
	if not Rect2(BOARD_POS - Vector2(18, 0), Vector2(456, 586)).has_point(p):
		return Vector2i(-99, -99)
	var extent := Vector2.ZERO
	for offset in CutterManager.SHAPES[tray[selected].shape]:
		extent.x = maxf(extent.x, offset.x + 1)
		extent.y = maxf(extent.y, offset.y + 1)
	var desired := (card_drag_center(p) - BOARD_POS) / CELL - extent / 2.0
	var chosen := Vector2i(-99, -99)
	var distance := 1.15 * 1.15
	for origin in aim_targets:
		var candidate_distance := desired.distance_squared_to(Vector2(origin))
		if origin == drag_origin:
			candidate_distance -= .18
		if candidate_distance < distance:
			distance = candidate_distance
			chosen = origin
	return chosen

func release(p: Vector2) -> void:
	if dragging and not busy and not over and overlay.is_empty():
		move_pointer(p)
		var origin := preview_origin()
		var allowed := (drag_from_card and drag_active) or (not drag_from_card and Rect2(BOARD_POS, Vector2(420, 540)).has_point(p))
		if allowed and selected >= 0 and selected < tray.size():
			if CutterManager.hits(board, tray[selected], origin).size() >= 2:
				place_cutter(origin)
			elif drag_from_card:
				message("Drag over 2+ blocks. Release to punch.")
			else:
				message("Cover at least two blocks. Colours can mix.")
	cancel_gesture()

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
	cancel_gesture()
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
					if event.get("perfect", false):
						set_phase("cut", "PERFECT CUT!", "Full cutter · +%d bonus points" % event.get("bonus", 0))
						celebrate("PERFECT CUT +%d" % event.get("bonus", 0))
					else:
						set_phase("cut", "PUNCH %d" % event.points.size(), "Every block inside the shape pops.")
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
				var teaching := tutorial > 0
				var hold := (.34 if teaching else .19 if save.explain_clears else .07) if event.wave > 0 else .0
				if hold > 0:
					await get_tree().create_timer(hold).timeout
				score += event.earned
				combo = maxi(combo, event.wave)
				var center := Vector2.ZERO
				for point in event.points:
					center += cell_center(point)
				center /= event.points.size()
				add_floater("+%d" % event.earned, center, ACCENT)
				if event.wave > 1:
					celebrate("%s ×%d" % ["SUPER CHAIN" if event.wave > 2 else "CHAIN", event.wave])
				await pop_cells(event.points, event.wave)
				anticipating.clear()
				match_groups.clear()
			"fall":
				set_phase("fall", "BLOCKS FALL INTO THE GAPS", "A fall can connect four or more of one colour.")
				board.cells = event.cells.duplicate(true)
				movements = event.moves
				anim_t = 0
				var tween := create_tween()
				tween.tween_property(self, "anim_t", 1.0, .08 if save.reduced_motion else .16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
				await tween.finished
				landing = event.moves.map(func(m: Dictionary) -> Vector2i: return m.to)
				landing_time = .22 if not save.reduced_motion else 0.0
				movements.clear()
				effects.sound("land", 0)
			"row":
				var title := "TIME UP — ROW RISES" if event.reason == "timer" else "BOTTOM ROW RISES" if event.reason == "scheduled" else "NO CUTS — NEW ROW"
				var detail := "Everything moves up one. Keep below the ceiling."
				if event.reason == "scheduled":
					detail = "Move pressure: the previewed row pushes up."
				elif event.reason == "refill":
					detail = "Fresh blocks keep the board playable."
				set_phase("supply", title, detail)
				incoming = event.colors.duplicate()
				await get_tree().create_timer(.10 if tutorial > 0 else .04).timeout
				row_rising = true
				rising_colors = event.colors.duplicate()
				rise_t = 0
				effects.sound("supply", 0)
				var lift := create_tween()
				lift.tween_property(self, "rise_t", 1.0, .10 if save.reduced_motion else .24).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
				await lift.finished
				board.cells = event.cells.duplicate(true)
				row_rising = false
				rising_colors.clear()
				incoming = event.next.duplicate()
			"breathing":
				if event.get("seconds", 0.0) > 0:
					add_floater("+%.1fs" % event.seconds, Vector2(434, 252), ACCENT)
			"fresh":
				set_phase("supply", "FRESH CHANCE", "No legal cut remains. Fresh blocks keep you playing.")
				await get_tree().create_timer(.08).timeout
	last_summary = TurnSummary.from_events(events)
	last_clear_time = 1.4 if last_summary.matched > 0 else 0.0
	sync_model()
	busy = false
	set_phase("idle", "", "")
	if model.lesson_complete:
		overlay = "lesson"
	elif over:
		notice = "The rising board crossed the ceiling."
		overlay = "over"
	elif old_best > 0 and score > old_best and before.score <= old_best:
		celebrate("NEW BEST!")
	elif tutorial == 0 and score >= target_after(int(before.score)):
		celebrate("%s POINTS!" % target_after(int(before.score)))
	elif SupplySystem.pressure_level(turns, model.active_seconds) > old_level:
		message("Level %d · punch cost −%.1fs" % [SupplySystem.pressure_level(turns, model.active_seconds), model.punch_effort()])
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
		effects.burst(cell_center(p), board.at(p), 5 if save.reduced_motion else 8 + wave * 3, wave)
	if wave > 0:
		shake = minf(3.5, 1 + wave)
	var tween := create_tween()
	tween.tween_property(self, "anim_t", 1.0, .07 if save.reduced_motion else (.08 if wave == 0 else .12 if wave == 1 else .16)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	board.remove(points)
	shrinking.clear()

func undo_move() -> void:
	if busy or undo_state.is_empty():
		return
	var previous := undo_state.duplicate(true)
	reset_transients()
	if model.restore_undo(previous):
		undo_state = {}
		sync_model()
		checkpoint()
		message("Move undone. Time and punch cost stay spent.")

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
	message("Punch blocks. Match 4. Make chains.", 3)

# Targets are presentation only: undo and resumed rounds derive them from score.
func target_after(value: int) -> int:
	for target in [500, 1000, 2000, 3500, 5000]:
		if value < target:
			return target
	return 5000 + (int((value - 5000) / 2500.0) + 1) * 2500

func score_target() -> int:
	return target_after(score)

func score_progress() -> float:
	var target := score_target()
	var lower := 0
	for milestone in [500, 1000, 2000, 3500, 5000]:
		if score >= milestone:
			lower = milestone
	if score >= 5000:
		lower = target - 2500
	return clampf(float(score - lower) / float(target - lower), 0.0, 1.0)

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
	if overlay == "home":
		if Rect2(95, 570, 350, 64).has_point(p):
			if has_saved_round():
				overlay = "lesson" if model.lesson_complete else ""
			else:
				start_game()
		elif has_saved_round() and Rect2(95, 650, 350, 56).has_point(p):
			start_game()
		elif Rect2(95, 724, 350, 52).has_point(p):
			start_game(true)
		elif Rect2(95, 790, 350, 52).has_point(p):
			settings_return = "home"
			overlay = "settings"
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
		elif Rect2(95, 775, 350, 50).has_point(p):
			go_home()
		return
	if overlay == "pause":
		if replay_rect.has_point(p):
			overlay = "lesson" if model.lesson_complete else ""
		elif Rect2(95, 407, 350, 50).has_point(p):
			settings_return = "pause"
			overlay = "settings"
		elif Rect2(95, 469, 350, 50).has_point(p):
			start_game()
		elif Rect2(95, 531, 350, 50).has_point(p):
			start_game(true)
		elif Rect2(95, 593, 350, 50).has_point(p):
			go_home()
		elif Rect2(95, 655, 350, 34).has_point(p):
			precise = not precise
			hover = Vector2i(-99, -99)
			overlay = ""
		return
	if replay_rect.has_point(p):
		overlay = settings_return if overlay == "settings" else ("lesson" if model.lesson_complete else "")
		return
	if overlay == "settings":
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
		save.save_data()
		_sync_settings()
