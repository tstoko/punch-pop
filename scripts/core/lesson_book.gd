class_name LessonBook
extends RefCounted

const TITLES := ["CUT THE SELECTED COLOUR", "FOUR CONNECTED CLEAR", "FALL AGAIN. CHAIN AGAIN."]
const HINTS := ["Tap orange. The green block stays.", "Cut orange. Blue falls into a connected group of four.", "Cut violet. Orange clears, then falling blue clears."]
const SUCCESS := ["CUT COMPLETE", "FOUR CONNECTED = CLEAR", "SECOND MATCH = CHAIN ×2"]
const EXPLANATIONS := ["Green stayed. Only orange was cut.", "Four blue blocks touched sides, so they cleared.", "Orange cleared first. Then blue formed a new match."]

static func build(board: BoardManager, lesson: int) -> Dictionary:
	board.clear()
	if lesson == 0:
		board.put(Vector2i(2, 8), 0)
		board.put(Vector2i(3, 8), 0)
		board.put(Vector2i(4, 8), 2)
		return {"shape": 1, "color": 0}
	if lesson == 1:
		for y in [7, 8]:
			board.put(Vector2i(2, y), 0)
			board.put(Vector2i(3, y), 1)
		for y in [5, 6]:
			board.put(Vector2i(2, y), 1)
		return {"shape": 0, "color": 0}
	chain_pocket(board)
	return {"shape": 1, "color": 3}

static func chain_pocket(board: BoardManager) -> void:
	# A stable arrangement: removing gold makes four pink, then four purple.
	for y in [4, 5, 7, 8]:
		board.put(Vector2i(0, y), 0)
	for y in [2, 3]:
		board.put(Vector2i(0, y), 1)
	for y in [7, 8]:
		board.put(Vector2i(1, y), 1)
	board.put(Vector2i(0, 6), 3)
	board.put(Vector2i(1, 6), 3)

static func endless_opening(board: BoardManager, rng: RandomNumberGenerator) -> void:
	# Fresh terrain every round, with four rows of ceiling headroom. The authored
	# two-wave pocket belongs to training, so repeat play rewards reading the board.
	for attempt in 32:
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
		if MatchSystem.groups(board).is_empty() and CutterManager.candidates(board).size() >= 3:
			return
	# Bounded fallback for pathological seeds; still settled and playable.
	SpawnManager.seed_board(board, rng)
