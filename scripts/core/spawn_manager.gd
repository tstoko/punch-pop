class_name SpawnManager
extends RefCounted

static func can_spawn(board: BoardManager) -> bool:
	for x in BoardManager.WIDTH:
		if board.at(Vector2i(x, 0)) != BoardManager.EMPTY:
			return false
	return true

# Atomic: overflow leaves the entire board untouched.
static func add_row(board: BoardManager, colors: Array) -> bool:
	assert(colors.size() == BoardManager.WIDTH)
	if not can_spawn(board):
		return false
	for x in BoardManager.WIDTH:
		board.put(Vector2i(x, 0), colors[x])
	return true

static func row(rng: RandomNumberGenerator, turns: int) -> Array:
	var result: Array = []
	for x in BoardManager.WIDTH:
		# Early rows have more pairs, later rows are uniformly random.
		if turns < 18 and x % 2 == 1 and rng.randf() < 0.65:
			result.append(result[x - 1])
		else:
			result.append(rng.randi_range(0, 3))
	return result

static func seed_board(board: BoardManager, rng: RandomNumberGenerator) -> void:
	board.clear()
	# Bottom five rows, with horizontal pairs but no pre-existing matches.
	for y in range(BoardManager.HEIGHT - int(SupplySystem.knob("seed_rows", BoardManager.HEIGHT - 4)), BoardManager.HEIGHT):
		for x in BoardManager.WIDTH:
			var color := rng.randi_range(0, 3)
			for attempt in 4:
				board.put(Vector2i(x, y), color)
				if MatchSystem.groups(board).is_empty():
					break
				color = (color + 1) % 4
			board.put(Vector2i(x, y), color)
	# A reliable first move, also used by the tutorial.
	board.put(Vector2i(2, BoardManager.HEIGHT - 1), 0)
	board.put(Vector2i(3, BoardManager.HEIGHT - 1), 0)
	ComboManager.resolve(board)
	if CutterManager.candidates(board).is_empty():
		board.put(Vector2i(2, 8), 0)
		board.put(Vector2i(3, 8), 0)

# Atomic bottom insertion: every existing block shifts up exactly one cell.
static func rise_row(board: BoardManager, colors: Array) -> bool:
	assert(colors.size() == BoardManager.WIDTH)
	if not can_spawn(board):
		return false
	for y in range(BoardManager.HEIGHT - 1):
		board.cells[y] = board.cells[y + 1].duplicate()
	board.cells[BoardManager.HEIGHT - 1] = colors.duplicate()
	return true

# Preview once and keep it. Favour small colour clusters that can be joined
# by a deliberate punch, without awarding an automatic clear on arrival.
# Generosity is the chance this row is searched for a punch-and-match setup.
# Later levels deal plainer rows so board-reading skill, not speed, decides runs.
static func pressure_row(board: BoardManager, rng: RandomNumberGenerator, generosity: float = 1.0) -> Array:
	var colors: Array = []
	var best: Array = []
	var best_links := -1
	var tested := 0
	var curated := generosity >= 1.0 or rng.randf() < generosity
	for attempt in 64:
		colors = clustered_row(rng)
		var trial := BoardManager.new()
		trial.cells = board.snapshot()
		if not rise_row(trial, colors):
			return colors.duplicate()
		if not MatchSystem.groups(trial).is_empty():
			continue
		if not curated:
			return colors.duplicate()
		tested += 1
		if row_has_cascade(trial):
			return colors.duplicate()
		var links := 0
		for x in BoardManager.WIDTH:
			if trial.at(Vector2i(x, BoardManager.HEIGHT - 2)) == colors[x]:
				links += 2
			if x > 0 and colors[x] == colors[x - 1]:
				links += 1
		if links > best_links:
			best_links = links
			best = colors.duplicate()
		if tested >= 8:
			break
	if not best.is_empty():
		return best
	# Guaranteed fallback: pairs, no vertical attachment and no run of four.
	colors.clear()
	for color in 4:
		if color != board.at(Vector2i(0, BoardManager.HEIGHT - 1)) and color != board.at(Vector2i(1, BoardManager.HEIGHT - 1)):
			colors.append_array([color, color])
			break
	for x in range(2, BoardManager.WIDTH):
		var choices: Array = []
		for color in 4:
			if color == board.at(Vector2i(x, BoardManager.HEIGHT - 1)):
				continue
			if colors[x - 1] == color and colors[x - 2] == color:
				continue
			choices.append(color)
		colors.append(choices[rng.randi_range(0, choices.size() - 1)])
	return colors

static func clustered_row(rng: RandomNumberGenerator) -> Array:
	var result: Array = []
	if rng.randf() < .2:
		for x in BoardManager.WIDTH:
			result.append(rng.randi_range(0, 3))
		return result
	while result.size() < BoardManager.WIDTH:
		var color := rng.randi_range(0, 3)
		if not result.is_empty() and color == result.back():
			color = (color + rng.randi_range(1, 3)) % 4
		var length := mini(BoardManager.WIDTH - result.size(), rng.randi_range(2, 3))
		for cell in length:
			result.append(color)
	return result

# Only the lower three rows changed their relationship to new supply. Search
# that small region rather than forecasting every placement on a tall board.
static func row_has_cascade(board: BoardManager) -> bool:
	var upper_blocks := false
	for x in BoardManager.WIDTH:
		if board.at(Vector2i(x, BoardManager.HEIGHT - 2)) >= 0:
			upper_blocks = true
			break
	if not upper_blocks:
		return false
	for shape in CutterManager.shape_count:
		var cutter := {"shape": shape, "color": -1}
		for y in range(BoardManager.HEIGHT - 3, BoardManager.HEIGHT):
			for x in BoardManager.WIDTH:
				var origin := Vector2i(x, y)
				var hits := CutterManager.legal_hits(board, cutter, origin)
				if hits.is_empty():
					continue
				var trial := BoardManager.new()
				trial.cells = board.snapshot()
				trial.remove(hits)
				if not ComboManager.resolve(trial).waves.is_empty():
					return true
	return false
