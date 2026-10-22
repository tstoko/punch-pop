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
	for y in range(4, BoardManager.HEIGHT):
		for x in BoardManager.WIDTH:
			var color := rng.randi_range(0, 3)
			for attempt in 4:
				board.put(Vector2i(x, y), color)
				if MatchSystem.groups(board).is_empty():
					break
				color = (color + 1) % 4
			board.put(Vector2i(x, y), color)
	# A reliable first move, also used by the tutorial.
	board.put(Vector2i(2, 8), 0)
	board.put(Vector2i(3, 8), 0)
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

# Preview once and keep it. Avoid rows that clear themselves on the current board.
static func pressure_row(board: BoardManager, rng: RandomNumberGenerator) -> Array:
	var colors: Array = []
	for attempt in 64:
		colors.clear()
		for x in 7:
			colors.append(rng.randi_range(0, 3))
		var trial := BoardManager.new()
		trial.cells = board.snapshot()
		if not rise_row(trial, colors):
			return colors.duplicate()
		if MatchSystem.groups(trial).is_empty() and not CutterManager.candidates(trial).is_empty():
			return colors.duplicate()
	# Guaranteed fallback: a horizontal pair, no vertical attachment, and no
	# horizontal run longer than three. It is playable and cannot auto-clear.
	colors.clear()
	for color in 4:
		if color != board.at(Vector2i(0, 8)) and color != board.at(Vector2i(1, 8)):
			colors.append_array([color, color])
			break
	for x in range(2, 7):
		var choices: Array = []
		for color in 4:
			if color == board.at(Vector2i(x, 8)):
				continue
			if colors[x - 1] == color and colors[x - 2] == color:
				continue
			choices.append(color)
		colors.append(choices[rng.randi_range(0, choices.size() - 1)])
	return colors
