class_name CutterManager
extends RefCounted

const SHAPES := [
	[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]
]
const NAMES := ["CORNER", "LINE", "SQUARE"]

static func hits(board: BoardManager, cutter: Dictionary, origin: Vector2i) -> Array:
	if cutter.is_empty():
		return []
	var result: Array = []
	for offset in SHAPES[cutter.shape]:
		var p: Vector2i = origin + offset
		# The whole stamp must fit; a stamp can cover empty or other-colour cells.
		if not board.inside(p):
			return []
		if board.at(p) >= 0 and (cutter.color == -1 or board.at(p) == cutter.color):
			result.append(p)
	return result

static func placements(board: BoardManager, cutter: Dictionary) -> Array:
	var result: Array = []
	for y in BoardManager.HEIGHT:
		for x in BoardManager.WIDTH:
			var p := Vector2i(x, y)
			if hits(board, cutter, p).size() >= 2:
				result.append(p)
	return result

static func candidates(board: BoardManager) -> Array:
	var result: Array = []
	for shape in SHAPES.size():
		var cutter := {"shape": shape, "color": -1}
		if not placements(board, cutter).is_empty():
			result.append(cutter)
	return result

static func generate(board: BoardManager, rng: RandomNumberGenerator) -> Dictionary:
	var options := candidates(board)
	if options.is_empty():
		return {}
	return options[rng.randi_range(0, options.size() - 1)].duplicate()

static func refresh(board: BoardManager, tray: Array, rng: RandomNumberGenerator) -> Array:
	var options := candidates(board)
	if options.is_empty():
		return []
	var result: Array = []
	for i in 3:
		if i < tray.size() and not tray[i].is_empty() and not placements(board, tray[i]).is_empty():
			result.append(tray[i])
		else:
			result.append(options[rng.randi_range(0, options.size() - 1)].duplicate())
	return result

# A player taps a jelly, never a stamp's invisible top-left corner.
# Prefer the most matching cells, then the closest anchor. Stable iteration breaks ties.
static func target_map(board: BoardManager, cutter: Dictionary) -> Dictionary:
	var targets := {}
	var ranks := {}
	for origin in placements(board, cutter):
		var matching := hits(board, cutter, origin)
		for p in matching:
			var rank: int = matching.size() * 100 - p.distance_squared_to(origin)
			if not ranks.has(p) or rank > ranks[p]:
				ranks[p] = rank
				targets[p] = origin
	return targets

static func diverse_refresh(board: BoardManager, tray: Array, rng: RandomNumberGenerator) -> Array:
	var options := candidates(board)
	if options.is_empty():
		return []
	var result: Array = [{}, {}, {}]
	for i in 3:
		if i < tray.size() and not tray[i].is_empty():
			var cutter := {"shape": tray[i].shape, "color": -1}
			if not placements(board, cutter).is_empty() and not result.has(cutter):
				result[i] = cutter
	for i in 3:
		if not result[i].is_empty():
			continue
		var distinct := options.filter(func(c: Dictionary) -> bool: return not result.has(c))
		var pool: Array = distinct if not distinct.is_empty() else options
		result[i] = pool[rng.randi_range(0, pool.size() - 1)].duplicate()
	return result

# A hand is finite: order the three punches, then draw another hand. A punch
# that became unusable is discarded so an empty slot can never block play.
static func hand_refresh(board: BoardManager, tray: Array, rng: RandomNumberGenerator) -> Array:
	var result: Array = [{}, {}, {}]
	var remaining := false
	for i in mini(3, tray.size()):
		if tray[i].is_empty():
			continue
		var cutter := {"shape": tray[i].shape, "color": -1}
		if not placements(board, cutter).is_empty():
			result[i] = cutter
			remaining = true
	if remaining:
		return result
	var options := candidates(board)
	if options.is_empty():
		return []
	for i in range(options.size() - 1, 0, -1):
		var other := rng.randi_range(0, i)
		var held: Dictionary = options[i]
		options[i] = options[other]
		options[other] = held
	for i in options.size():
		result[i] = options[i].duplicate()
	return result
