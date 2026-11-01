class_name ComboManager
extends RefCounted

static func cut_score(count: int) -> int:
	return count * (15 if CutterManager.full_footprint else 10)

# Partial-punch rules reward a filled footprint. Under the full-footprint rule
# every punch is full, so its value is already in the base score.
static func perfect_bonus(count: int, footprint: int) -> int:
	if CutterManager.full_footprint:
		return 0
	return count * 5 if count >= 3 and count == footprint else 0

# Consecutive matching punches multiply that punch's points.
static func streak_multiplier(streak: int) -> int:
	return clampi(streak, 1, 10)

static func match_score(count: int, wave: int) -> int:
	return count * 20 * wave

# The headless resolver and live game use these same primitives and scoring rules.
static func resolve(board: BoardManager) -> Dictionary:
	var waves: Array = []
	var score := 0
	GravitySystem.apply(board)
	var matches := MatchSystem.groups(board)
	while not matches.is_empty():
		var removed: Array = []
		for group in matches:
			removed.append_array(group)
		var wave := waves.size() + 1
		var points := match_score(removed.size(), wave)
		score += points
		waves.append({"cells": removed.duplicate(), "score": points, "multiplier": wave})
		board.remove(removed)
		GravitySystem.apply(board)
		matches = MatchSystem.groups(board)
	return {"score": score, "waves": waves}
