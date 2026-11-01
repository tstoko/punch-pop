class_name LessonBook
extends RefCounted

const GOALS := [Vector2i(2, 8), Vector2i(0, 7), Vector2i(0, 5)]

const TITLES := ["PUNCH A SHAPE", "MAKE COLOURS MEET", "ONE FALL. ANOTHER MATCH."]
const HINTS := ["Every square of the shape must sit on a block. Colours can mix.", "Punch the middle row. Falling orange makes four connected.", "Punch the top corner. Watch two matches happen in sequence."]
const SUCCESS := ["CLEAN PUNCH", "FOUR CONNECTED = MATCH", "SECOND MATCH = CHAIN ×2"]
const EXPLANATIONS := ["The whole shape fit on blocks, so all of them popped.", "Four orange blocks touched sides after falling, so they matched.", "The first match opened space for a second. Chains refund punch time."]

static func build(board: BoardManager, lesson: int) -> Dictionary:
	board.clear()
	if lesson == 0:
		for x in range(2, 5):
			board.put(Vector2i(x, 8), x - 2)
		return {"shape": 1, "color": -1}
	if lesson == 1:
		board.put(Vector2i(0, 6), 1)
		board.put(Vector2i(0, 7), 1)
		board.put(Vector2i(0, 8), 0)
		for y in [5, 6, 8]:
			board.put(Vector2i(1, y), 0)
		board.put(Vector2i(1, 7), 1)
		# The line must land fully on blocks: a mixed-colour third cell.
		board.put(Vector2i(2, 7), 2)
		board.put(Vector2i(2, 8), 3)
		return {"shape": 1, "color": -1}
	chain_pocket(board)
	return {"shape": 0, "color": -1}

static func chain_pocket(board: BoardManager) -> void:
	# A settled five-row puzzle: corner at (0, 5) produces two automatic waves.
	var rows := [[-1, 1, 0], [0, 2, 0], [0, 0, 2], [2, 2, 0], [2, 1, 0]]
	for y in rows.size():
		for x in 3:
			board.put(Vector2i(x, y + 4), rows[y][x])

# Returns as soon as a discoverable chain exists; it never changes the board.
static func has_cascade(board: BoardManager, minimum_waves: int = 1) -> bool:
	for shape in CutterManager.shape_count:
		var cutter := {"shape": shape, "color": -1}
		for origin in CutterManager.placements(board, cutter):
			var trial := BoardManager.new()
			trial.cells = board.snapshot()
			trial.remove(CutterManager.legal_hits(trial, cutter, origin))
			if ComboManager.resolve(trial).waves.size() >= minimum_waves:
				return true
	return false

static func endless_opening(board: BoardManager, rng: RandomNumberGenerator) -> void:
	# Rejection-sample fresh settled terrain, keeping a real match opportunity.
	# Some openings seek two waves, but every accepted board has at least one.
	var desired_waves := 2 if rng.randf() < .25 else 1
	for attempt in 16:
		board.clear()
		for x in BoardManager.WIDTH:
			var depth := rng.randi_range(3, 5)
			for y in range(9 - depth, 9):
				var color := rng.randi_range(0, 3)
				for choice in 4:
					board.put(Vector2i(x, y), color)
					if MatchSystem.groups(board).is_empty():
						break
					color = (color + 1) % 4
		if MatchSystem.groups(board).is_empty() and has_cascade(board, desired_waves if attempt < 8 else 1):
			return
	# Bounded fallback moves and recolours a known settled puzzle. Remaining
	# columns vary independently behind an empty separator, preserving the chain.
	board.clear()
	var pocket := BoardManager.new()
	chain_pocket(pocket)
	var left := rng.randi_range(0, 4)
	var shift := rng.randi_range(0, 3)
	for y in BoardManager.HEIGHT:
		for x in 3:
			var color := pocket.at(Vector2i(x, y))
			if color >= 0:
				board.put(Vector2i(left + x, y), (color + shift) % 4)
	for x in BoardManager.WIDTH:
		if x >= left - 1 and x <= left + 3:
			continue
		for y in range(9 - rng.randi_range(2, 4), 9):
			board.put(Vector2i(x, y), (x + y + shift) % 4)
