class_name ComboManager
extends RefCounted

static func cut_score(count: int) -> int:
	return count * 10

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
