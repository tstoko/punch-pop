class_name UIManager
extends Node2D

const COLORS := EffectsManager.COLORS
const COLOR_NAMES := ["ORANGE", "BLUE", "GREEN", "VIOLET"]
const INK := Color("f3f5ff")
const MUTED := Color("99a8c4")
const ACCENT := Color("8ceacb")
const BG := Color("11152d")
const PANEL := Color("202740")
const EDGE := Color("30405d")
const BOARD_POS := Vector2(60, 276)
const CELL := 60.0
var game: Node2D
var font = ThemeDB.fallback_font
var display_font: Font = preload("res://assets/fonts/BarlowCondensed-Bold.ttf")
var style_cache: Dictionary = {}

func box(rect: Rect2, color: Color, radius: int = 8, border: Color = Color.TRANSPARENT, width: int = 0) -> void:
	var key = "%s:%s:%s:%s" % [color.to_rgba32(), radius, border.to_rgba32(), width]
	var style: StyleBoxFlat
	if style_cache.has(key):
		style = style_cache[key]
		style_cache.erase(key)
	else:
		style = StyleBoxFlat.new()
		style.bg_color = color
		style.set_corner_radius_all(radius)
		style.border_color = border
		style.set_border_width_all(width)
		style.anti_aliasing = true
	style_cache[key] = style
	if style_cache.size() > 384:
		style_cache.erase(style_cache.keys()[0])
	draw_style_box(style, rect)

func text_line(value: String, at: Vector2, size: int, color: Color, align: int, typeface: Font) -> void:
	var width = typeface.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(typeface, Vector2(at.x - width * float(align) / 2, at.y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func label(value: String, at: Vector2, size: int, color: Color = INK, align: int = 0) -> void:
	text_line(value, at, size, color, align, font)

func head(value: String, at: Vector2, size: int, color: Color = INK, align: int = 0) -> void:
	text_line(value, at, size, color, align, display_font)

func block_color(index: int) -> Color:
	if index < 0 or index >= COLORS.size():
		return INK
	return [Color("ffae65"), Color("78c0ff"), Color("62e8b7"), Color("c4a8ff")][index] if game.save.high_contrast else COLORS[index]

# Soft, tactile tiles with a recessed base and a crisp lit face. Corners identify colours independently of hue.
func block(rect: Rect2, index: int, small: bool = false, alpha: float = 1) -> void:
	if rect.size.x < 3:
		return
	var color = block_color(index)
	color.a = alpha
	var r = 4 if small else 10
	box(Rect2(rect.position + Vector2(0, 3), rect.size), Color(0, 0, 0, alpha * .23), r)
	box(rect, color.darkened(.48), r)
	var face = Rect2(rect.position + Vector2(2, 1), rect.size - Vector2(4, 5 if not small else 3))
	box(face, color, maxi(2, r - 2))
	var lift = 3 if small else 5
	box(Rect2(face.position + Vector2(1, 1), Vector2(face.size.x - 2, lift)), Color(1, 1, 1, alpha * .33), 2)
	draw_line(face.position + Vector2(1, lift), face.position + Vector2(1, face.size.y - 2), Color(1, 1, 1, alpha * .15), 1, true)
	draw_line(face.end - Vector2(1, 2), face.position + Vector2(face.size.x - 1, lift), Color(0, 0, 0, alpha * .12), 2, true)
	if not small and rect.size.x > 30:
		var mark = rect.position + Vector2(11, 11)
		var tint = Color(1, 1, 1, alpha * (.9 if game.save.high_contrast else .6))
		match index:
			0: draw_circle(mark, 2.6, tint, true, -1, true)
			1: draw_rect(Rect2(mark - Vector2(3, 3), Vector2(6, 6)), tint, false, 1.5)
			2:
				draw_line(mark - Vector2(3, 0), mark + Vector2(3, 0), tint, 1.8, true)
				draw_line(mark - Vector2(0, 3), mark + Vector2(0, 3), tint, 1.8, true)
			3: draw_colored_polygon(PackedVector2Array([mark + Vector2(0, -4), mark + Vector2(3.5, 0), mark + Vector2(0, 4), mark + Vector2(-3.5, 0)]), tint)

func draw_backdrop() -> void:
	draw_rect(Rect2(-game.position - Vector2(100, 100), get_viewport_rect().size + Vector2(200, 200)), BG)
	# Broad, static ambient pools give depth without competing with the puzzle.
	for i in range(7, 0, -1):
		draw_circle(Vector2(65, 260), float(i * 55), Color(.22, .28, .62, .015), true, -1, true)
		draw_circle(Vector2(510, 890), float(i * 42), Color(.12, .40, .51, .012), true, -1, true)
	for y in range(114, 1060, 30):
		draw_circle(Vector2(27, y), 1, Color(ACCENT, .10), true, -1, true)
		draw_circle(Vector2(513, y), 1, Color(ACCENT, .10), true, -1, true)

func _draw() -> void:
	draw_backdrop()
	if game.overlay == "home":
		draw_home()
		return
	head("PUNCH", Vector2(60, 67), 39)
	head("POP", Vector2(157, 67), 39, ACCENT)
	for x in [382, 436]:
		box(Rect2(x, 30, 44, 44), PANEL, 9, EDGE, 1)
	head("?", Vector2(404, 60), 25, MUTED, 1)
	for x in [451, 461]:
		box(Rect2(x, 43, 4, 18), INK, 1)

	label("SCORE", Vector2(60, 111), 9, MUTED)
	head(str(game.score), Vector2(58, 155), 55 if game.score < 10000000 else 40)
	if game.tutorial > 0:
		head("LEARN %d/3" % game.tutorial, Vector2(294, 140), 17, ACCENT, 1)
	label("BEST", Vector2(480, 111), 9, MUTED, 2)
	head(str(game.save.best), Vector2(480, 148), 32 if game.save.best < 1000000000 else 24, Color("ffbd65"), 2)
	draw_line(Vector2(60, 166), Vector2(480, 166), EDGE, 1, true)
	draw_instruction()
	draw_flow()
	draw_board()
	draw_incoming()
	draw_tray_caption()
	for i in game.tray.size():
		draw_cutter(i)
	draw_footer()
	if game.drag_from_card and game.overlay.is_empty():
		draw_drag_ghost()
	for f in game.floaters:
		var a = minf(1, f.life * 2)
		head(f.text, f.p + Vector2(0, -12), 25, Color(INK, a), 1)
	if game.celebration_time > 0 and game.phase == "idle" and game.overlay.is_empty():
		var a = minf(1, game.celebration_time * 3)
		label(game.celebration, Vector2(60, 1078), 10, Color(ACCENT, a))
	if not game.overlay.is_empty():
		draw_overlay()

func draw_instruction() -> void:
	if game.tutorial > 0:
		head(LessonBook.TITLES[game.model.lesson], Vector2(60, 192), 23)
		label(LessonBook.HINTS[game.model.lesson], Vector2(60, 210), 13, MUTED)
		return
	var prediction: Dictionary = game.preview()
	var outcome := ""
	var tint := MUTED
	if not prediction.is_empty():
		if prediction.waves > 1:
			outcome = "CHAIN ×%d   ·   +%d" % [prediction.waves, prediction.score]
		else:
			outcome = "Punch %d" % prediction.hits.size()
			if prediction.get("matched", 0) > 0:
				outcome += "   ·   Match %d" % prediction.matched
			outcome += "   ·   +%d" % prediction.score
		if prediction.get("time_bonus", 0.0) > 0:
			outcome += "   ·   +%.1fs" % prediction.time_bonus
		tint = ACCENT
	elif game.busy:
		if game.phase == "match":
			outcome = "Pop!"
		elif game.phase == "row":
			outcome = "New row"
	elif game.notice_time > 0:
		outcome = game.notice
	else:
		outcome = "Drag a shape onto the board"
	var outcome_width: float = font.get_string_size(outcome, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
	var outcome_size := 15 if outcome_width <= 420 else maxi(10, int(15 * 420 / outcome_width))
	label(outcome, Vector2(270, 207), outcome_size, tint, 1)

func draw_flow() -> void:
	if game.tutorial == 0:
		return
	var stages = ["cut", "fall", "match"]
	var captions = ["1  CUT 2+", "2  BLOCKS FALL", "3  MATCH 4+"]
	for i in 3:
		var active = game.phase == stages[i] or (game.phase == "idle" and i == 0)
		var rect = Rect2(60 + i * 142, 221, 136, 23)
		box(rect, Color("21374e") if active else Color("131e34"), 6, Color(ACCENT, .35) if active else Color.TRANSPARENT, 1 if active else 0)
		head(captions[i], Vector2(rect.get_center().x, 237), 14, INK if active else MUTED, 1)

func draw_board() -> void:
	var origin = BOARD_POS + game.screen_board_offset
	box(Rect2(origin - Vector2(14, 4), Vector2(448, 564)), Color(0, 0, 0, .28), 20)
	box(Rect2(origin - Vector2(11, 11), Vector2(442, 562)), Color("1e304b"), 16, Color("40516c"), 1)
	box(Rect2(origin - Vector2(7, 7), Vector2(434, 554)), Color("0a1022"), 12)
	draw_line(origin + Vector2(9, -10), origin + Vector2(411, -10), Color(ACCENT, .22), 1, true)
	var moving = {}
	for movement in game.movements:
		moving[movement.to] = true
	var interactive = not game.busy and not game.over and game.overlay.is_empty()
	var preview_hits: Array = game.preview().get("hits", []) if interactive else []
	for y in 9:
		for x in 7:
			var p = Vector2i(x, y)
			var rect = Rect2(origin + Vector2(p) * CELL + Vector2(3, 3), Vector2(54, 54))
			box(rect, Color("142139") if (x + y) % 2 == 0 else Color("121e34"), 9)
			if game.board.at(p) >= 0 and not moving.has(p):
				var tile = rect
				if game.row_rising:
					tile.position.y -= CELL * game.rise_t
				var opacity := 1.0
				if game.shrinking.has(p):
					tile = rect.grow(-rect.size.x * game.anim_t * .45)
					opacity = 1 - game.anim_t
				if game.landing_time > 0 and game.landing.has(p) and not game.save.reduced_motion:
					var s = sin((1 - game.landing_time / .22) * TAU) * .045 * game.landing_time / .22
					tile.position.x -= 27 * s
					tile.size.x += 54 * s
					tile.position.y += 54 * s
					tile.size.y -= 54 * s
				block(tile, game.board.at(p), false, opacity)
				if preview_hits.has(p) or (game.phase == "cut" and game.anticipating.has(p)):
					box(rect.grow(1), Color(1, 1, 1, .12), 8, Color.TRANSPARENT if game.drag_from_card else Color.WHITE, 0 if game.drag_from_card else 2)
			if interactive and game.precise and game.aim_targets.has(p):
				draw_circle(rect.position + Vector2(7, 7), 4, Color.WHITE, true, -1, true)
	if game.row_rising:
		var visible_height = clampf(CELL * game.rise_t - 3, 0, 54)
		for x in 7:
			block(Rect2(origin + Vector2(x * CELL + 3, 540 - CELL * game.rise_t + 3), Vector2(54, visible_height)), game.rising_colors[x])
	for movement in game.movements:
		var at = origin + Vector2(movement.from).lerp(Vector2(movement.to), game.anim_t) * CELL + Vector2(3, 3)
		block(Rect2(at, Vector2(54, 54)), movement.color)
	if interactive and game.tutorial > 0:
		draw_training_goal(origin)
	if interactive and not game.drag_from_card and not preview_hits.is_empty():
		for offset in CutterManager.SHAPES[game.tray[game.selected].shape]:
			var p: Vector2i = game.preview_origin() + offset
			box(Rect2(origin + Vector2(p) * CELL + Vector2(1, 1), Vector2(58, 58)), Color.TRANSPARENT, 8, INK, 1)
	if game.phase == "match":
		draw_match_groups(origin)
	if game.phase == "fall":
		var columns = {}
		for movement in game.movements:
			if columns.has(movement.from.x):
				continue
			columns[movement.from.x] = true
			var at = origin + Vector2(movement.from) * CELL + Vector2(30, 14)
			draw_line(at, at + Vector2(0, 22), Color(ACCENT, .6), 2, true)
			draw_line(at + Vector2(0, 22), at + Vector2(-4, 17), Color(ACCENT, .6), 2, true)
			draw_line(at + Vector2(0, 22), at + Vector2(4, 17), Color(ACCENT, .6), 2, true)

func draw_training_goal(origin: Vector2) -> void:
	if game.tray[game.selected].is_empty():
		return
	var goal: Vector2i = LessonBook.GOALS[game.model.lesson]
	for offset in CutterManager.SHAPES[game.tray[game.selected].shape]:
		var rect := Rect2(origin + Vector2(goal + offset) * CELL + Vector2(2, 2), Vector2(56, 56))
		for corner in [Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]:
			var at: Vector2 = rect.position + corner * rect.size
			var direction := Vector2(1 if corner.x == 0 else -1, 1 if corner.y == 0 else -1)
			draw_line(at, at + Vector2(direction.x * 9, 0), Color(ACCENT, .8), 2, true)
			draw_line(at, at + Vector2(0, direction.y * 9), Color(ACCENT, .8), 2, true)

func draw_check(at: Vector2) -> void:
	draw_circle(at, 6, Color("10233a"), true, -1, true)
	draw_line(at + Vector2(-3, 0), at + Vector2(-1, 2), Color.WHITE, 1.7, true)
	draw_line(at + Vector2(-1, 2), at + Vector2(3, -2), Color.WHITE, 1.7, true)

func draw_match_groups(origin: Vector2) -> void:
	for group in game.match_groups:
		var members = {}
		var center = Vector2.ZERO
		var color = block_color(game.board.at(group[0])) if game.board.at(group[0]) >= 0 else ACCENT
		for p in group:
			members[p] = true
			center += origin + Vector2(p) * CELL + Vector2(30, 30)
			box(Rect2(origin + Vector2(p) * CELL + Vector2(1, 1), Vector2(58, 58)), Color(color, .1), 8, Color.WHITE, 2)
		for p in group:
			for step in [Vector2i.RIGHT, Vector2i.DOWN]:
				if members.has(p + step):
					var at = origin + Vector2(p) * CELL + Vector2(30, 30)
					draw_line(at, at + Vector2(step) * CELL, Color.WHITE, 2, true)
		center /= group.size()
		box(Rect2(center - Vector2(17, 17), Vector2(34, 34)), Color("102239"), 7, Color.WHITE, 2)
		head(str(group.size()), center + Vector2(0, 9), 27, Color.WHITE, 1)

func draw_incoming() -> void:
	if game.tutorial > 0:
		return
	var remaining = game.model.rise_remaining
	var urgency = Color("ff676f") if remaining <= 1.5 else Color("ffbd65") if remaining <= 3 else ACCENT
	var active = not game.busy and game.overlay.is_empty() and not game.over
	label("RISE IN", Vector2(60, 260), 10, MUTED)
	box(Rect2(152, 252, 240, 6), Color("263d59"), 3)
	box(Rect2(152, 252, 240 * clampf(remaining / game.model.rise_period, 0, 1), 6), urgency if active else MUTED, 3)
	head("%.1fs" % remaining, Vector2(480, 262), 20, urgency if active else MUTED, 2)
	box(Rect2(50, 821, 440, 21), Color("172b40"), 5, urgency if remaining <= 3 else EDGE, 1)
	head("↑", Vector2(501, 838), 22, urgency, 1)
	var danger := false
	for x in 7:
		var h = SupplySystem.height(game.board, x)
		var at = Vector2(BOARD_POS.x + x * CELL + 20, 823)
		block(Rect2(at, Vector2(20, 16)), game.incoming[x], true)
		if h >= 7:
			danger = true
			var tint = Color("ff676f") if h >= 8 else Color("ffbd65")
			draw_line(Vector2(BOARD_POS.x + x * CELL + 3, BOARD_POS.y - 2), Vector2(BOARD_POS.x + x * CELL + 57, BOARD_POS.y - 2), tint, 3, true)
	if danger:
		head("!", Vector2(40, BOARD_POS.y + 16), 22, Color("ff676f"), 1)

func draw_tray_caption() -> void:
	if game.tutorial > 0:
		label("CHOOSE A SHAPE", Vector2(60, 855), 10, MUTED)

func draw_cutter(i: int) -> void:
	var cutter: Dictionary = game.tray[i]
	var rect := Rect2(60 + i * 144, 862, 132, 136)
	if cutter.is_empty():
		box(rect, Color(PANEL, .28), 16, Color(EDGE, .5), 1)
		var center := rect.get_center()
		var completed := Color(MUTED, .5)
		draw_line(center + Vector2(-6, 0), center + Vector2(-1, 5), completed, 2, true)
		draw_line(center + Vector2(-1, 5), center + Vector2(8, -6), completed, 2, true)
		return
	var active: bool = game.selected == i
	box(Rect2(rect.position + Vector2(0, 4), rect.size), Color(0, 0, 0, .2), 16)
	box(rect, Color("27364a") if active else PANEL, 16, ACCENT if active else EDGE, 2 if active else 1)
	var shape: Array = CutterManager.SHAPES[cutter.shape]
	var bounds := Vector2.ONE
	for cell in shape:
		bounds = bounds.max(Vector2(cell) + Vector2.ONE)
	var start := rect.position + Vector2((132 - bounds.x * 27) / 2, 18 + (66 - bounds.y * 27) / 2)
	for cell in shape:
		var tile := Rect2(start + Vector2(cell) * 27, Vector2(25, 25))
		box(tile, Color("e3eee9") if active else Color("a7b7ca"), 5)
		box(tile.grow(-4), Color("33465a") if active else PANEL, 2)
	head(CutterManager.NAMES[cutter.shape], Vector2(rect.get_center().x, 973), 20, INK if active else MUTED, 1)

func draw_footer() -> void:
	var lessons: bool = game.tutorial > 0
	var can_undo: bool = not game.busy and not game.undo_state.is_empty()
	box(Rect2(60, 1014, 132, 44), PANEL, 9, EDGE, 1)
	head("SKIP LESSONS" if lessons else "UNDO", Vector2(126, 1042), 17, INK if can_undo or lessons else MUTED, 1)
	if lessons:
		label("No clock. Take your time.", Vector2(480, 1040), 11, MUTED, 2)

func button(rect: Rect2, value: String, primary: bool = false) -> void:
	box(Rect2(rect.position + Vector2(0, 4), rect.size), Color("215069") if primary else Color("0b1427"), 10)
	box(rect, ACCENT if primary else Color("26364f"), 10, Color("bcecff") if primary else EDGE, 1)
	if primary:
		draw_line(rect.position + Vector2(12, 2), rect.position + Vector2(rect.size.x - 12, 2), Color(1, 1, 1, .4), 1, true)
	head(value, rect.position + Vector2(rect.size.x / 2, rect.size.y / 2 + 7), 22, Color("0a1a2f") if primary else INK, 1)

func draw_overlay() -> void:
	draw_rect(Rect2(-game.position - Vector2(100, 100), get_viewport_rect().size + Vector2(200, 200)), Color(.02, .05, .10, .86))
	var panel_height := 584 if game.overlay == "over" else 518
	box(Rect2(59, 284, 422, panel_height + 6), Color(0, 0, 0, .30), 23)
	box(Rect2(65, 278, 410, panel_height), Color("17243b"), 20, Color("405373"), 1)
	box(Rect2(86, 278, 64, 3), ACCENT, 1)
	match game.overlay:
		"help":
			draw_help()
		"lesson":
			head(LessonBook.SUCCESS[game.model.lesson], Vector2(270, 349), 30, INK, 1)
			label(LessonBook.EXPLANATIONS[game.model.lesson], Vector2(270, 385), 12, MUTED, 1)
			var indices = [0, 1, 1]
			block(Rect2(237, 427, 66, 66), indices[game.model.lesson])
			head("+%d" % game.score, Vector2(270, 566), 51, ACCENT, 1)
			label("READY FOR YOUR FIRST RUN" if game.model.lesson == 2 else "LESSON %d OF 3 COMPLETE" % game.tutorial, Vector2(270, 611), 10, MUTED, 1)
			button(game.replay_rect, "PLAY ENDLESS" if game.model.lesson == 2 else "NEXT LESSON", true)
		"resume":
			head("BACK IN THE GAME", Vector2(95, 349), 37)
			label("Rows rise from below. Beat the pressure clock.", Vector2(95, 384), 14, MUTED)
			head(str(game.score), Vector2(270, 492), 72 if game.score < 1000000000 else 50, INK, 1)
			label("TRAINING %d" % game.tutorial if game.tutorial > 0 else "LEVEL %d  /  MOVE %d" % [SupplySystem.pressure_level(game.turns, game.model.active_seconds), game.turns], Vector2(270, 540), 12, MUTED, 1)
			button(Rect2(95, 625, 350, 50), "START FRESH")
			button(game.replay_rect, "CONTINUE", true)
		"over":
			head("NEW PERSONAL BEST" if game.score > game.run_best else "NICE RUN", Vector2(95, 349), 37)
			label("The stack reached the ceiling. Go again?", Vector2(95, 384), 13, MUTED)
			head(str(game.score), Vector2(270, 488), 72 if game.score < 1000000000 else 50, ACCENT, 1)
			label("POINTS", Vector2(270, 517), 11, MUTED, 1)
			label("LEVEL %d  /  %d MOVES  /  CHAIN ×%d" % [SupplySystem.pressure_level(game.turns, game.model.active_seconds), game.turns, game.best_combo], Vector2(270, 565), 11, INK, 1)
			if not game.undo_state.is_empty():
				button(Rect2(95, 625, 350, 50), "UNDO LAST MOVE")
			button(game.replay_rect, "PLAY AGAIN", true)
			button(Rect2(95, 775, 350, 50), "MAIN MENU")
		"settings":
			head("MAKE IT YOURS", Vector2(95, 347), 39)
			label("A few little comforts for your next big chain.", Vector2(95, 381), 12, MUTED)
			button(Rect2(95, 407, 169, 45), "SOUND: %s" % ("ON" if game.save.sound else "OFF"))
			button(Rect2(276, 407, 169, 45), "HAPTICS: %s" % ("ON" if game.save.haptics else "OFF"))
			button(Rect2(95, 460, 350, 45), "CLEAR DETAILS: %s" % ("ON" if game.save.explain_clears else "QUICK"))
			button(Rect2(95, 513, 350, 45), "REDUCED MOTION: %s" % ("ON" if game.save.reduced_motion else "OFF"))
			button(Rect2(95, 566, 350, 45), "HIGH CONTRAST: %s" % ("ON" if game.save.high_contrast else "OFF"))
			label("Your preferences are saved automatically.", Vector2(270, 652), 12, MUTED, 1)
			button(game.replay_rect, "DONE", true)
		_:
			head("TAKE A BREATHER", Vector2(95, 347), 39)
			label("Your game is saved. Pick up when you're ready.", Vector2(95, 381), 12, MUTED)
			button(Rect2(95, 407, 350, 50), "SETTINGS")
			button(Rect2(95, 469, 350, 50), "NEW RUN")
			button(Rect2(95, 531, 350, 50), "TRAINING")
			button(Rect2(95, 593, 350, 50), "MAIN MENU")
			button(Rect2(95, 655, 350, 34), "PRECISE AIM: %s" % ("ON" if game.precise else "OFF"))
			button(game.replay_rect, "KEEP PLAYING", true)

func draw_home() -> void:
	# One clear action, with the puzzle's four colours doing the decorating.
	head("PUNCH", Vector2(270, 202), 104, INK, 1)
	head("POP", Vector2(270, 286), 111, ACCENT, 1)
	var tiles = [Vector3(0, 2, 0), Vector3(1, 1, 0), Vector3(1, 2, 1), Vector3(2, 1, 2), Vector3(2, 2, 2), Vector3(2, 0, 3), Vector3(3, 2, 3), Vector3(3, 1, 1), Vector3(4, 2, 0)]
	for tile in tiles:
		block(Rect2(112 + tile.x * 64, 310 + tile.y * 54, 57, 57), int(tile.z))
	draw_circle(Vector2(112, 332), 5, block_color(0), true, -1, true)
	draw_circle(Vector2(435, 382), 4, ACCENT, true, -1, true)
	draw_line(Vector2(415, 321), Vector2(415, 337), block_color(3), 3, true)
	draw_line(Vector2(407, 329), Vector2(423, 329), block_color(3), 3, true)
	label("Punch. Match. Make room.", Vector2(270, 494), 14, MUTED, 1)
	if game.save.best > 0:
		box(Rect2(167, 515, 206, 32), Color("2a2943"), 16)
		head("PERSONAL BEST  %s" % str(game.save.best), Vector2(270, 538), 17, Color("ffce80"), 1)
	var saved: bool = game.has_saved_round()
	button(Rect2(95, 570, 350, 64), "CONTINUE" if saved else "LET'S PLAY", true)
	if saved:
		button(Rect2(95, 650, 350, 56), "NEW RUN")
	button(Rect2(95, 724, 350, 52), "LEARN TO PLAY")
	button(Rect2(95, 790, 350, 52), "SETTINGS")
	for i in 4:
		draw_circle(Vector2(246 + i * 16, 911), 3.5, block_color(i), true, -1, true)

func draw_drag_ghost() -> void:
	if not game.drag_active:
		return
	var cutter: Dictionary = game.tray[game.selected]
	if cutter.is_empty():
		return
	var shape: Array = CutterManager.SHAPES[cutter.shape]
	var bounds := Vector2.ONE
	for cell in shape:
		bounds = bounds.max(Vector2(cell) + Vector2.ONE)
	var extent: Vector2 = bounds * CELL
	var valid: bool = not game.preview().is_empty()
	var start: Vector2 = game.card_drag_center(game.pointer_pos) - extent / 2
	if valid:
		# Draw exactly where release will punch, at the board's physical scale.
		start = BOARD_POS + Vector2(game.drag_origin) * CELL + game.screen_board_offset
	for cell in shape:
		var tile := Rect2(start + Vector2(cell) * CELL + Vector2(2, 2), Vector2(56, 56))
		box(tile, Color(ACCENT, .10) if valid else Color(INK, .06), 10, ACCENT if valid else Color(INK, .6), 3)

func draw_help() -> void:
	head("WHY BLOCKS CLEAR", Vector2(95, 346), 36)
	box(Rect2(95, 368, 350, 116), PANEL, 8)
	head("1 / PUNCH A SHAPE", Vector2(111, 398), 22, COLORS[0])
	for i in 3:
		block(Rect2(112 + i * 28, 417, 24, 26), 0 if i < 2 else 2, true)
	label("2+ blocks inside", Vector2(211, 434), 12)
	label("Every colour inside the shape gets punched.", Vector2(112, 466), 11, MUTED)
	box(Rect2(95, 498, 350, 115), PANEL, 8)
	head("2 / AUTOMATIC MATCH", Vector2(111, 528), 22, COLORS[1])
	for p in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		block(Rect2(Vector2(112, 540) + p * 23, Vector2(20, 21)), 1, true)
	label("4+ same colour", Vector2(180, 556), 13)
	label("touching sides, in any shape", Vector2(180, 578), 12, MUTED)
	label("Diagonals and full rows have no special rule.", Vector2(112, 602), 10, MUTED)
	label("Use your shapes to get a fresh set.", Vector2(95, 630), 12, INK)
	label("Rows rise. Keep blocks below the ceiling.", Vector2(95, 654), 13, MUTED)
	label("Chains buy back a little time.", Vector2(95, 678), 13, MUTED)
	button(game.replay_rect, "GOT IT", true)
