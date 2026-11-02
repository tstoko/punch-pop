class_name UIManager
extends Node2D

# v0.9 presentation: night-candy gradients, glossy jelly blocks and loud,
# readable feedback. Hit areas match GameManager's input rectangles exactly.
const COLORS := EffectsManager.COLORS
const COLOR_NAMES := ["ORANGE", "BLUE", "GREEN", "VIOLET"]
const INK := Color("ffffff")
const MUTED := Color("b9b3e6")
const ACCENT := Color("ffd45c")
const MINT := Color("7ff0c8")
const DANGER := Color("ff5d7a")
const BG_TOP := Color("1c1850")
const BG_BOTTOM := Color("461a6b")
const PANEL := Color(1, 1, 1, .08)
const EDGE := Color(1, 1, 1, .16)
const CELL := 60.0
# 8 × 8 at 60 px fills 480 of the 540 design width. The board sits right
# under the score; the incoming row (which doubles as the row meter) is below.
const BOARD_POS := Vector2(30, 236)
const NEON := Color("39ff14")
static var BOARD_SIZE: Vector2:
	get: return Vector2(BoardManager.WIDTH, BoardManager.HEIGHT) * CELL
var game: Node2D
var font = ThemeDB.fallback_font
var display_font: Font = preload("res://assets/fonts/BarlowCondensed-Bold.ttf")
var style_cache: Dictionary = {}
var time := 0.0

func _process(delta: float) -> void:
	time += delta

# Cached rounded boxes. Shadows double as soft glows.
func box(rect: Rect2, color: Color, radius: int = 8, border: Color = Color.TRANSPARENT, width: int = 0, glow: Color = Color.TRANSPARENT, glow_size: int = 0, glow_offset: Vector2 = Vector2.ZERO) -> void:
	var key = "%s:%s:%s:%s:%s:%s:%s" % [color.to_rgba32(), radius, border.to_rgba32(), width, glow.to_rgba32(), glow_size, glow_offset]
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
		style.shadow_color = glow
		style.shadow_size = glow_size
		style.shadow_offset = glow_offset
		style.anti_aliasing = true
	style_cache[key] = style
	if style_cache.size() > 512:
		style_cache.erase(style_cache.keys()[0])
	draw_style_box(style, rect)

func gradient(rect: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]), PackedColorArray([top, top, bottom, bottom]))

func text_line(value: String, at: Vector2, size: int, color: Color, align: int, typeface: Font, outline: int = 0, outline_color: Color = Color(0, 0, 0, .45)) -> void:
	var width = typeface.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var start := Vector2(at.x - width * float(align) / 2, at.y)
	if outline > 0:
		draw_string_outline(typeface, start, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, outline_color)
	draw_string(typeface, start, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func label(value: String, at: Vector2, size: int, color: Color = INK, align: int = 0) -> void:
	text_line(value, at, size, color, align, font)

func head(value: String, at: Vector2, size: int, color: Color = INK, align: int = 0, outline: int = 0, outline_color: Color = Color(0, 0, 0, .45)) -> void:
	text_line(value, at, size, color, align, display_font, outline, outline_color)

func fit_size(value: String, size: int, width: float, typeface: Font) -> int:
	var measured: float = typeface.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	return size if measured <= width else maxi(10, int(size * width / measured))

func block_color(index: int) -> Color:
	if index < 0 or index >= COLORS.size():
		return INK
	return [Color("ffa25c"), Color("6cc0ff"), Color("4ff0b3"), Color("c19bff")][index] if game.save.high_contrast else COLORS[index]

# A glossy jelly: dark rim, saturated face, broad top gloss and a specular
# dot. High contrast adds colour symbols for colour-blind players.
func block(rect: Rect2, index: int, small: bool = false, alpha: float = 1, lift: float = 0) -> void:
	if rect.size.x < 3:
		return
	var color = block_color(index)
	var r = 5 if small else 12
	if not small:
		box(Rect2(rect.position + Vector2(0, 4 + lift), rect.size), Color(0, 0, 0, alpha * .30), r)
	rect.position.y -= lift
	box(rect, Color(color.darkened(.42), alpha), r)
	var face = Rect2(rect.position + Vector2(2, 1), rect.size - Vector2(4, 5 if not small else 3))
	box(face, Color(color, alpha), maxi(3, r - 2))
	box(Rect2(face.position + Vector2(face.size.x * .1, face.size.y * .62), Vector2(face.size.x * .8, face.size.y * .26)), Color(color.lightened(.18), alpha * .55), maxi(2, r - 5))
	box(Rect2(face.position + Vector2(3, 2), Vector2(face.size.x - 6, face.size.y * .40)), Color(1, 1, 1, alpha * .30), maxi(2, r - 4))
	if not small:
		draw_circle(face.position + Vector2(9, 8), 2.6, Color(1, 1, 1, alpha * .85), true, -1, true)
		draw_circle(face.position + Vector2(15, 7), 1.3, Color(1, 1, 1, alpha * .55), true, -1, true)
	if game.save.high_contrast and not small and rect.size.x > 30:
		var mark = rect.get_center() + Vector2(0, 3)
		var tint = Color(1, 1, 1, alpha * .9)
		match index:
			0: draw_circle(mark, 4.5, tint, true, -1, true)
			1: draw_rect(Rect2(mark - Vector2(5, 5), Vector2(10, 10)), tint, false, 2.2)
			2:
				draw_line(mark - Vector2(5, 0), mark + Vector2(5, 0), tint, 2.6, true)
				draw_line(mark - Vector2(0, 5), mark + Vector2(0, 5), tint, 2.6, true)
			3: draw_colored_polygon(PackedVector2Array([mark + Vector2(0, -6), mark + Vector2(5, 0), mark + Vector2(0, 6), mark + Vector2(-5, 0)]), tint)

func draw_backdrop() -> void:
	var full := Rect2(-game.position - Vector2(100, 100), get_viewport_rect().size + Vector2(200, 200))
	gradient(full, BG_TOP, BG_BOTTOM)
	# Slow, soft bokeh adds depth without competing with the board.
	for i in 7:
		var drift := Vector2(sin(time * .15 + i * 1.7) * 18, cos(time * .12 + i) * 14)
		var at := Vector2([40, 500, 120, 470, 30, 300, 520][i], [140, 260, 760, 980, 520, 1040, 640][i]) + drift
		var tint: Color = [Color(.45, .35, 1, .07), Color(1, .4, .8, .06), Color(.3, .8, 1, .05)][i % 3]
		for k in 3:
			draw_circle(at, 70.0 + k * 34 + i * 6, Color(tint, tint.a * (1.0 - k * .3)), true, -1, true)

func _draw() -> void:
	draw_backdrop()
	if game.overlay == "home":
		draw_home()
		return
	draw_peril_vignette()
	draw_header()
	draw_instruction()
	draw_flow()
	draw_board()
	draw_incoming()
	for i in game.tray.size():
		draw_cutter(i)
	draw_footer()
	if game.drag_from_card and game.overlay.is_empty():
		draw_drag_ghost()
	draw_praise()
	for f in game.floaters:
		var a = minf(1, f.life * 2.2)
		head(f.text, f.p + Vector2(0, -12), 26, Color(f.color, a), 1, 6, Color(0, 0, 0, .4 * a))
	if not game.overlay.is_empty():
		draw_overlay()

func round_button(center: Vector2, radius: float) -> void:
	draw_circle(center + Vector2(0, 3), radius, Color(0, 0, 0, .25), true, -1, true)
	draw_circle(center, radius, Color(1, 1, 1, .12), true, -1, true)
	draw_arc(center, radius, 0, TAU, 32, Color(1, 1, 1, .22), 1.5, true)

func draw_header() -> void:
	head("PUNCH", Vector2(60, 64), 34, INK, 0, 5, Color(0, 0, 0, .3))
	head("POP", Vector2(146, 64), 34, ACCENT, 0, 5, Color(0, 0, 0, .3))
	round_button(Vector2(404, 52), 22)
	head("?", Vector2(404, 62), 26, INK, 1)
	round_button(Vector2(458, 52), 22)
	for x in [452, 461]:
		box(Rect2(x, 43, 5, 18), INK, 2)
	# Best with a small crown and a big centred score. Difficulty climbs
	# silently: there is no level display, like Block Blast.
	draw_crown(Vector2(70, 102))
	head(str(game.save.best), Vector2(84, 109), 22, ACCENT, 0)
	draw_best_chase()
	if game.tutorial > 0:
		head("LEARN %d/3" % game.tutorial, Vector2(480, 109), 20, MINT, 2)
	var shown := int(round(game.shown_score))
	var size := 64 if shown < 1000000 else 48
	var bump: float = 1.0 + .12 * clampf((game.score - game.shown_score) / 300.0, 0, 1)
	head(str(shown), Vector2(270, 158), int(size * bump), INK, 1, 8, Color(0, 0, 0, .35))
	if game.streak >= 2 and game.tutorial == 0:
		var pulse: float = game.streak_pulse
		var pill := Rect2(200, 168, 140, 28).grow(pulse * 4)
		var aimed: Dictionary = game.preview() if not game.busy and game.overlay.is_empty() else {}
		if not aimed.is_empty() and aimed.get("streak", 0) == 0:
			# Aiming a punch with no match: show what it would cost.
			var throb := .5 + .5 * sin(time * 9)
			box(pill, Color("5a1a2e"), 15, Color(DANGER, .6 + .4 * throb), 2, Color(DANGER, .35 * throb), 10)
			head("LOSE ×%d" % ComboManager.streak_multiplier(game.streak), pill.get_center() + Vector2(0, 8), 21, Color("ffb3c0"), 1, 4, Color(.3, 0, .1, .5))
		else:
			box(pill, Color("ff7a3d"), 15, Color("ffd45c"), 2, Color(1, .55, .2, .45 + pulse * .3), int(8 + pulse * 10))
			head("STREAK ×%d" % ComboManager.streak_multiplier(game.streak), pill.get_center() + Vector2(0, 8), 21, INK, 1, 4, Color(.5, .1, 0, .5))

# Goal gradient: once a run is within reach of the record, count down to it.
# After it falls, the crown line simply becomes the new record.
func draw_best_chase() -> void:
	var record: int = game.run_best
	if game.tutorial > 0 or record <= 0:
		return
	if game.score > record:
		head("NEW RECORD", Vector2(60, 131), 15, Color(ACCENT, .75 + .25 * sin(time * 5)), 0)
	elif game.score >= record * .5:
		var gap: int = record - game.score
		var close: float = clampf(float(game.score) / record, 0, 1)
		var tint := MUTED.lerp(ACCENT, clampf((close - .5) * 2.0, 0, 1))
		head("%d TO BEAT" % gap, Vector2(60, 131), 15, tint, 0)

# Edges of the screen breathe red with the heartbeat when the stack is
# within a row of the ceiling. Reduced motion holds a steady tint.
func draw_peril_vignette() -> void:
	var peril: int = game.peril
	if peril < 2 or game.over:
		return
	var beat := 1.0 if game.save.reduced_motion else .55 + .45 * absf(sin(time * (5.1 if peril >= 3 else 3.1)))
	var strength := (.30 if peril >= 3 else .17) * beat
	var view := Rect2(-game.position, get_viewport_rect().size)
	var red := Color(DANGER, strength)
	var clear := Color(DANGER, 0)
	var depth := 90.0 if peril >= 3 else 60.0
	gradient(Rect2(view.position, Vector2(view.size.x, depth)), red, clear)
	gradient(Rect2(Vector2(view.position.x, view.end.y - depth), Vector2(view.size.x, depth)), clear, red)
	draw_polygon(PackedVector2Array([view.position, view.position + Vector2(depth, 0), Vector2(view.position.x + depth, view.end.y), Vector2(view.position.x, view.end.y)]), PackedColorArray([red, clear, clear, red]))
	draw_polygon(PackedVector2Array([Vector2(view.end.x - depth, view.position.y), Vector2(view.end.x, view.position.y), view.end, Vector2(view.end.x - depth, view.end.y)]), PackedColorArray([clear, red, red, clear]))

func draw_crown(at: Vector2) -> void:
	var points := PackedVector2Array([at + Vector2(-9, 6), at + Vector2(-9, -4), at + Vector2(-4, 1), at + Vector2(0, -7), at + Vector2(4, 1), at + Vector2(9, -4), at + Vector2(9, 6)])
	draw_colored_polygon(points, ACCENT)

# Arcade play has no commentary line: warnings live on the drag outline, the
# streak badge and the incoming row. Lessons keep their title and hint, drawn
# where the incoming row sits in arcade play. Rare notices (save failure,
# undo) still appear briefly above the board.
func draw_instruction() -> void:
	if game.tutorial > 0:
		head(LessonBook.TITLES[game.model.lesson], Vector2(270, 770), 26, INK, 1, 5)
		var hint: String = LessonBook.HINTS[game.model.lesson]
		label(hint, Vector2(270, 796), fit_size(hint, 14, 470, font), MUTED, 1)
		return
	if game.notice_time > 0 and not game.busy:
		head(game.notice, Vector2(270, 214), fit_size(game.notice, 18, 470, display_font), INK, 1, 4, Color(0, 0, 0, .3))

func draw_flow() -> void:
	if game.tutorial == 0:
		return
	var stages = ["cut", "fall", "match"]
	var captions = ["1  FIT SHAPE", "2  BLOCKS FALL", "3  MATCH 4+"]
	for i in 3:
		var active = game.phase == stages[i] or (game.phase == "idle" and i == 0)
		var rect = Rect2(60 + i * 142, 182, 136, 26)
		box(rect, Color(1, 1, 1, .16) if active else Color(1, 1, 1, .05), 13, Color(MINT, .6) if active else Color.TRANSPARENT, 1 if active else 0)
		head(captions[i], Vector2(rect.get_center().x, 201), 16, INK if active else MUTED, 1)



func draw_board() -> void:
	var origin = BOARD_POS + game.screen_board_offset
	var frame := Color(1, 1, 1, .14)
	if game.peril >= 2 and not game.over:
		frame = Color(DANGER, .45 + .4 * absf(sin(time * (5.1 if game.peril >= 3 else 3.1))))
	box(Rect2(origin - Vector2(12, 12), BOARD_SIZE + Vector2(24, 24)), Color(.06, .04, .2, .55), 22, frame, 2 if game.peril < 2 else 3, Color(0, 0, 0, .35), 18, Vector2(0, 8))
	var moving = {}
	for movement in game.movements:
		moving[movement.to] = true
	var interactive = not game.busy and not game.over and game.overlay.is_empty()
	var prediction: Dictionary = game.preview() if interactive else {}
	var preview_hits: Array = prediction.get("hits", [])
	var match_cells := {}
	for p in prediction.get("match_cells", []):
		match_cells[p] = true
	# Matched cells are where blocks will be after the punch has fallen; mark
	# the board cells whose blocks end up in a match by replaying gravity.
	var lit := lit_cells(preview_hits, match_cells) if not preview_hits.is_empty() else {}
	for y in BoardManager.HEIGHT:
		for x in BoardManager.WIDTH:
			var p = Vector2i(x, y)
			var rect = Rect2(origin + Vector2(p) * CELL + Vector2(3, 3), Vector2(54, 54))
			box(rect, Color(1, 1, 1, .045 if (x + y) % 2 == 0 else .03), 10)
	var pulse := .5 + .5 * sin(time * 8)
	for y in BoardManager.HEIGHT:
		for x in BoardManager.WIDTH:
			var p = Vector2i(x, y)
			var rect = Rect2(origin + Vector2(p) * CELL + Vector2(3, 3), Vector2(54, 54))
			if game.board.at(p) < 0 or moving.has(p):
				continue
			var tile = rect
			if game.row_rising:
				tile.position.y -= CELL * game.rise_t
			var opacity := 1.0
			var lift := 0.0
			if game.shrinking.has(p):
				tile = rect.grow(rect.size.x * game.anim_t * .18 - rect.size.x * game.anim_t * game.anim_t * .6)
				opacity = 1 - game.anim_t
			if game.landing_time > 0 and game.landing.has(p) and not game.save.reduced_motion:
				var s = sin((1 - game.landing_time / .22) * TAU) * .06 * game.landing_time / .22
				tile.position.x -= 27 * s
				tile.size.x += 54 * s
				tile.position.y += 54 * s
				tile.size.y -= 54 * s
			if lit.has(p):
				var glow: Color = block_color(game.board.at(p))
				box(rect.grow(2), Color(glow, .18 + .22 * pulse), 13, Color(1, 1, 1, .5 + .4 * pulse), 2, Color(glow, .8), int(8 + 6 * pulse))
				lift = 3.0 * pulse
			block(tile, game.board.at(p), false, opacity, lift)
			if preview_hits.has(p) or (game.phase == "cut" and game.anticipating.has(p)):
				box(rect.grow(1), Color(1, 1, 1, .32 + .12 * pulse), 12, Color.WHITE, 3)
			if interactive and game.precise and game.aim_targets.has(p):
				draw_circle(rect.position + Vector2(8, 8), 4, Color.WHITE, true, -1, true)
	if game.row_rising:
		var visible_height = clampf(CELL * game.rise_t - 3, 0, 54)
		for x in BoardManager.WIDTH:
			block(Rect2(origin + Vector2(x * CELL + 3, BOARD_SIZE.y - CELL * game.rise_t + 3), Vector2(54, visible_height)), game.rising_colors[x])
	for movement in game.movements:
		var at = origin + Vector2(movement.from).lerp(Vector2(movement.to), game.anim_t) * CELL + Vector2(3, 3)
		block(Rect2(at, Vector2(54, 54)), movement.color)
	if interactive and game.tutorial > 0:
		draw_training_goal(origin)
	if interactive and not game.drag_from_card and not preview_hits.is_empty():
		for offset in CutterManager.SHAPES[game.tray[game.selected].shape]:
			var p: Vector2i = game.preview_origin() + offset
			box(Rect2(origin + Vector2(p) * CELL + Vector2(1, 1), Vector2(58, 58)), Color.TRANSPARENT, 12, INK, 2)
	if game.phase == "match":
		draw_match_groups(origin)
	if game.flash > 0:
		box(Rect2(origin - Vector2(8, 8), BOARD_SIZE + Vector2(16, 16)), Color(1, 1, 1, game.flash * .22), 18)
	draw_danger(origin)

# Map predicted post-fall match cells back to the blocks currently on the
# board, so the player sees exactly which blocks will pop together.
func lit_cells(hits: Array, match_cells: Dictionary) -> Dictionary:
	var result := {}
	if match_cells.is_empty():
		return result
	var removed := {}
	for p in hits:
		removed[p] = true
	for x in BoardManager.WIDTH:
		var target := BoardManager.HEIGHT - 1
		for y in range(BoardManager.HEIGHT - 1, -1, -1):
			var p := Vector2i(x, y)
			if game.board.at(p) < 0 or removed.has(p):
				continue
			if match_cells.has(Vector2i(x, target)):
				result[p] = true
			target -= 1
	return result

func draw_danger(origin: Vector2) -> void:
	for x in BoardManager.WIDTH:
		var h = SupplySystem.height(game.board, x)
		if h >= BoardManager.HEIGHT - 2:
			var top: bool = h >= BoardManager.HEIGHT - 1
			var tint = DANGER if top else Color("ffb36b")
			var a := .55 + .45 * sin(time * (10 if top else 6))
			box(Rect2(origin + Vector2(x * CELL + 4, -8), Vector2(52, 5)), Color(tint, a), 2, Color.TRANSPARENT, 0, Color(tint, .6 * a), 8)

func draw_training_goal(origin: Vector2) -> void:
	if game.tray[game.selected].is_empty():
		return
	var goal: Vector2i = LessonBook.goal(game.model.lesson)
	var a := .6 + .4 * sin(time * 6)
	for offset in CutterManager.SHAPES[game.tray[game.selected].shape]:
		var rect := Rect2(origin + Vector2(goal + offset) * CELL + Vector2(1, 1), Vector2(58, 58))
		box(rect, Color(MINT, .12 * a), 12, Color(MINT, a), 3)

func draw_match_groups(origin: Vector2) -> void:
	for group in game.match_groups:
		var color = block_color(game.board.at(group[0])) if game.board.at(group[0]) >= 0 else ACCENT
		var center = Vector2.ZERO
		for p in group:
			center += origin + Vector2(p) * CELL + Vector2(30, 30)
			box(Rect2(origin + Vector2(p) * CELL + Vector2(1, 1), Vector2(58, 58)), Color(color, .18), 12, Color.WHITE, 3, Color(color, .9), 12)
		center /= group.size()
		if game.save.explain_clears or game.tutorial > 0:
			box(Rect2(center - Vector2(19, 19), Vector2(38, 38)), Color(0, 0, 0, .5), 19, Color.WHITE, 2)
			head(str(group.size()), center + Vector2(0, 10), 28, Color.WHITE, 1)

# The incoming row IS the row meter: its blocks light up left to right as
# punches fill it, and fully lit it pushes into the board. It shows only the
# current fill. It never previews the aimed punch or predicts a loss; the
# player has to read that from the board.
func draw_incoming() -> void:
	if game.tutorial > 0:
		return
	var filled: float = clampf(game.meter_shown / game.model.meter_capacity(), 0, 1)
	var left := BOARD_POS.x
	box(Rect2(left - 8, 744, BOARD_SIZE.x + 16, 44), Color(0, 0, 0, .30), 12, Color(1, 1, 1, .10), 1)
	for x in BoardManager.WIDTH:
		var lit := clampf(filled * BoardManager.WIDTH - x, 0, 1)
		block(Rect2(Vector2(left + x * CELL + 5, 751), Vector2(CELL - 10, 30)), game.incoming[x], true, .28 + .72 * lit)
	head("NEXT ROW", Vector2(270, 812), 16, MUTED, 1)

func draw_cutter(i: int) -> void:
	var cutter: Dictionary = game.tray[i]
	var rect := Rect2(60 + i * 144, 866, 132, 128)
	if cutter.is_empty():
		box(rect, Color(1, 1, 1, .03), 20, Color(1, 1, 1, .07), 1)
		return
	var active: bool = game.selected == i
	var dragging_this: bool = active and game.drag_from_card and game.drag_active
	if active:
		box(rect, Color(1, 1, 1, .16), 20, Color(ACCENT, .9), 2, Color(ACCENT, .35), 14)
	else:
		box(rect, Color(1, 1, 1, .08), 20, Color(1, 1, 1, .14), 1, Color(0, 0, 0, .2), 6, Vector2(0, 4))
	var shape: Array = CutterManager.SHAPES[cutter.shape]
	var bounds := Vector2.ONE
	for cell in shape:
		bounds = bounds.max(Vector2(cell) + Vector2.ONE)
	var tile_size := 28.0
	# No name label: the shape alone sits centred in its card.
	var start := rect.position + (rect.size - bounds * tile_size) / 2
	var alpha := .35 if dragging_this else 1.0
	for cell in shape:
		gold_tile(Rect2(start + Vector2(cell) * tile_size, Vector2(tile_size - 2, tile_size - 2)), active, alpha)

func gold_tile(rect: Rect2, bright: bool, alpha: float = 1.0) -> void:
	var base := Color("ffd45c") if bright else Color("cfc6ff")
	box(Rect2(rect.position + Vector2(0, 2), rect.size), Color(0, 0, 0, .25 * alpha), 6)
	box(rect, Color(base.darkened(.35), alpha), 6)
	box(Rect2(rect.position + Vector2(1.5, 1), rect.size - Vector2(3, 4)), Color(base, alpha), 5)
	box(Rect2(rect.position + Vector2(3, 2), Vector2(rect.size.x - 6, rect.size.y * .38)), Color(1, 1, 1, .35 * alpha), 3)

# Arcade play keeps the footer empty: no undo button and no hint text.
func draw_footer() -> void:
	if game.tutorial == 0:
		return
	var rect := Rect2(60, 1014, 132, 44)
	box(rect, Color(1, 1, 1, .10), 22, Color(1, 1, 1, .16), 1)
	head("SKIP LESSONS", rect.get_center() + Vector2(0, 7), 18, INK, 1)
	label("Lessons have no rows. Take your time.", Vector2(480, 1041), 12, MUTED, 2)

func draw_praise() -> void:
	if game.praise_time <= 0 or not game.overlay.is_empty():
		return
	var age: float = maxf(0.0, 1.25 - game.praise_time)
	var grow := clampf(age / .18, 0.0, 1.0)
	var scale: float = 1.0 if game.save.reduced_motion else lerpf(.4, 1.0, ease_out_back(grow))
	var a := clampf(game.praise_time / .3, 0, 1)
	var size := maxi(12, int(64 * scale))
	var at := Vector2(270, 520 - age * 22)
	var tint: Color = game.praise_tint
	head(game.praise, at, size, Color(tint, a), 1, 12, Color(.15, .05, .3, .75 * a))

func ease_out_back(t: float) -> float:
	var c := 1.70158
	return 1 + (c + 1) * pow(t - 1, 3) + c * pow(t - 1, 2)

# Bright neon pill for the game-over undo. TODO(ads): this becomes a
# rewarded-ad "second chance"; keep its rect in sync with GameManager.
func neon_button(rect: Rect2, value: String) -> void:
	var pulse := .5 + .5 * sin(time * 4)
	box(rect, NEON, int(rect.size.y / 2), Color("d6ffc9"), 2, Color(NEON, .45 + .3 * pulse), int(12 + 8 * pulse))
	box(Rect2(rect.position + Vector2(8, 3), Vector2(rect.size.x - 16, rect.size.y * .40)), Color(1, 1, 1, .35), int(rect.size.y / 3))
	head(value, rect.get_center() + Vector2(0, 9), 25, Color("0b3d00"), 1)

func button(rect: Rect2, value: String, primary: bool = false) -> void:
	if primary:
		var pulse := .5 + .5 * sin(time * 3)
		box(rect, Color("ffb627"), int(rect.size.y / 2), Color("fff1b0"), 2, Color(1, .7, .2, .35 + .2 * pulse), int(10 + 6 * pulse), Vector2(0, 2))
		box(Rect2(rect.position + Vector2(6, 3), Vector2(rect.size.x - 12, rect.size.y * .42)), Color(1, 1, 1, .28), int(rect.size.y / 3))
		head(value, rect.get_center() + Vector2(0, 9), 26, Color("4a2300"), 1)
	else:
		box(rect, Color(1, 1, 1, .12), int(rect.size.y / 2), Color(1, 1, 1, .2), 1)
		head(value, rect.get_center() + Vector2(0, 8), 22, INK, 1)

func draw_overlay() -> void:
	draw_rect(Rect2(-game.position - Vector2(100, 100), get_viewport_rect().size + Vector2(200, 200)), Color(.05, .02, .15, .78))
	var panel_height := 584 if game.overlay == "over" else 518
	var panel := Rect2(65, 278, 410, panel_height)
	box(panel, Color("2a2266"), 28, Color(1, 1, 1, .18), 2, Color(0, 0, 0, .4), 24, Vector2(0, 10))
	gradient(Rect2(panel.position + Vector2(28, 0), Vector2(panel.size.x - 56, 4)), ACCENT, ACCENT)
	match game.overlay:
		"help":
			draw_help()
		"lesson":
			head(LessonBook.SUCCESS[game.model.lesson], Vector2(270, 352), 34, ACCENT, 1, 6)
			var text: String = LessonBook.EXPLANATIONS[game.model.lesson]
			label(text, Vector2(270, 388), fit_size(text, 14, 380, font), MUTED, 1)
			var indices = [0, 1, 1]
			block(Rect2(237, 427, 66, 66), indices[game.model.lesson])
			head("+%d" % game.score, Vector2(270, 572), 56, INK, 1, 6)
			label("READY FOR YOUR FIRST RUN" if game.model.lesson == 2 else "LESSON %d OF 3 COMPLETE" % game.tutorial, Vector2(270, 615), 12, MUTED, 1)
			button(game.replay_rect, "PLAY!" if game.model.lesson == 2 else "NEXT LESSON", true)
		"over":
			var best: bool = game.score > game.run_best
			head("NEW BEST!" if best else "GAME OVER", Vector2(270, 350), 44, ACCENT if best else INK, 1, 7)
			var gap: int = game.run_best - game.score
			var tagline := "The stack reached the top."
			if best and game.run_best > 0:
				tagline = "+%d over your old best." % (game.score - game.run_best)
			elif game.run_best > 0 and gap <= maxi(150, int(game.run_best * .12)):
				# Near-miss framing: a small gap is the strongest "one more go" prompt.
				tagline = "SO CLOSE! Only %d short of your best." % gap
			label(tagline, Vector2(270, 380), 14, ACCENT if best or tagline.begins_with("SO CLOSE") else MUTED, 1)
			head(str(game.score), Vector2(270, 470), 80, INK, 1, 8)
			if not best and game.run_best > 0:
				var share := clampf(float(game.score) / game.run_best, 0, 1)
				var bar := Rect2(125, 492, 290, 12)
				box(bar, Color(0, 0, 0, .3), 6)
				box(Rect2(bar.position, Vector2(bar.size.x * share, bar.size.y)), ACCENT, 6)
				label("%d%% of your best (%d)" % [int(share * 100), game.run_best], Vector2(270, 526), 13, MUTED, 1)
			else:
				label("POINTS", Vector2(270, 506), 12, MUTED, 1)
			var stats := "%d PUNCHES   ·   BEST CHAIN ×%d   ·   BEST STREAK ×%d" % [game.turns, game.best_combo, game.model.best_streak]
			label(stats, Vector2(270, 570), fit_size(stats, 13, 380, font), INK, 1)
			if not game.undo_state.is_empty():
				neon_button(Rect2(95, 625, 350, 50), "↶ UNDO LAST MOVE")
			button(game.replay_rect, "PLAY AGAIN", true)
			button(Rect2(95, 775, 350, 50), "MAIN MENU")
		"settings":
			head("SETTINGS", Vector2(270, 350), 40, INK, 1, 6)
			label("Saved automatically.", Vector2(270, 381), 13, MUTED, 1)
			button(Rect2(95, 407, 169, 45), "SOUND: %s" % ("ON" if game.save.sound else "OFF"))
			button(Rect2(276, 407, 169, 45), "HAPTICS: %s" % ("ON" if game.save.haptics else "OFF"))
			button(Rect2(95, 460, 350, 45), "CLEAR DETAILS: %s" % ("ON" if game.save.explain_clears else "QUICK"))
			button(Rect2(95, 513, 350, 45), "REDUCED MOTION: %s" % ("ON" if game.save.reduced_motion else "OFF"))
			button(Rect2(95, 566, 350, 45), "COLOUR SYMBOLS: %s" % ("ON" if game.save.high_contrast else "OFF"))
			button(game.replay_rect, "DONE", true)
		_:
			head("PAUSED", Vector2(270, 350), 44, INK, 1, 6)
			label("Your game is saved.", Vector2(270, 381), 13, MUTED, 1)
			button(Rect2(95, 407, 350, 50), "SETTINGS")
			button(Rect2(95, 469, 350, 50), "NEW RUN")
			button(Rect2(95, 531, 350, 50), "TRAINING")
			button(Rect2(95, 593, 350, 50), "MAIN MENU")
			button(Rect2(95, 655, 350, 34), "PRECISE AIM: %s" % ("ON" if game.precise else "OFF"))
			button(game.replay_rect, "RESUME", true)

func draw_home() -> void:
	var bob := sin(time * 2.0) * 6
	head("PUNCH", Vector2(270, 205 + bob), 108, INK, 1, 14, Color(.1, .05, .3, .6))
	head("POP!", Vector2(270, 300 - bob), 116, ACCENT, 1, 14, Color(.45, .15, 0, .6))
	var tiles = [Vector3(0, 2, 0), Vector3(1, 1, 0), Vector3(1, 2, 1), Vector3(2, 1, 2), Vector3(2, 2, 2), Vector3(2, 0, 3), Vector3(3, 2, 3), Vector3(3, 1, 1), Vector3(4, 2, 0)]
	for i in tiles.size():
		var tile: Vector3 = tiles[i]
		var hop := maxf(0, sin(time * 3.0 - i * .6)) * 8
		block(Rect2(112 + tile.x * 64, 322 + tile.y * 54 - hop, 57, 57), int(tile.z))
	if game.save.best > 0:
		box(Rect2(160, 520, 220, 36), Color(1, 1, 1, .1), 18)
		draw_crown(Vector2(190, 537))
		head("BEST  %s" % str(game.save.best), Vector2(285, 546), 22, ACCENT, 1)
	var saved: bool = game.has_saved_round()
	button(Rect2(95, 570, 350, 64), "CONTINUE" if saved else "PLAY", true)
	if saved:
		button(Rect2(95, 650, 350, 56), "NEW RUN")
	button(Rect2(95, 724, 350, 52), "HOW TO PLAY")
	button(Rect2(95, 790, 350, 52), "SETTINGS")

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
		# Snap exactly where release will punch, at the board's physical scale.
		start = BOARD_POS + Vector2(game.drag_origin) * CELL + game.screen_board_offset
		for cell in shape:
			box(Rect2(start + Vector2(cell) * CELL + Vector2(2, 2), Vector2(56, 56)), Color(1, 1, 1, .12), 12, Color.WHITE, 3, Color(1, 1, 1, .45), 10)
	else:
		for cell in shape:
			gold_tile(Rect2(start + Vector2(cell) * CELL + Vector2(4, 4), Vector2(52, 52)), true, .8)

func draw_help() -> void:
	head("HOW TO PLAY", Vector2(270, 346), 38, INK, 1, 6)
	box(Rect2(95, 368, 350, 104), Color(1, 1, 1, .07), 16)
	head("1  FIT A SHAPE ON BLOCKS", Vector2(111, 398), 22, ACCENT)
	for i in 3:
		block(Rect2(112 + i * 30, 412, 27, 27), [0, 2, 1][i], true)
	label("Every square must sit on a block.", Vector2(214, 431), 12)
	label("Any colours. They all pop.", Vector2(214, 452), 12, MUTED)
	box(Rect2(95, 482, 350, 104), Color(1, 1, 1, .07), 16)
	head("2  MATCH 4+ OF ONE COLOUR", Vector2(111, 512), 22, MINT)
	for p in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		block(Rect2(Vector2(112, 524) + p * 24, Vector2(22, 22)), 1, true)
	label("Falling blocks that touch sides", Vector2(180, 545), 12)
	label("clear. More falls = chains.", Vector2(180, 566), 12, MUTED)
	box(Rect2(95, 596, 350, 90), Color(1, 1, 1, .07), 16)
	head("3  HOLD BACK THE ROWS", Vector2(111, 626), 22, Color("ff9f43"))
	label("The row under the board lights up as you punch.", Vector2(111, 650), 12)
	label("Fully lit, it pushes in. Matches light it less; chains least.", Vector2(111, 672), 12, MUTED)
	button(game.replay_rect, "GOT IT", true)
