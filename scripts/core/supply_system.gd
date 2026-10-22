class_name SupplySystem
extends RefCounted

static func wave(turns: int) -> int:
	return mini(8, 1 + int(turns / 12))

static func pressure_level(turns: int, active_seconds: float) -> int:
	return mini(8, maxi(wave(turns), 1 + int(active_seconds / 20.0)))

static func rise_interval(turns: int, active_seconds: float) -> float:
	return maxf(3.5, 8.0 - (pressure_level(turns, active_seconds) - 1) * .75)

# Kept for older presentation/audit callers: the clock is the only pressure.
static func due_rows(_turns: int) -> int:
	return 0

static func moves_to_drop(_turns: int) -> int:
	return 0

static func height(board: BoardManager, x: int) -> int:
	var count := 0
	for y in BoardManager.HEIGHT:
		if board.at(Vector2i(x, y)) >= 0:
			count += 1
	return count

# Only used for recovery after the already-previewed row has landed.
# Choose a real row that leaves a playable board, rather than inventing a loss.
static func recovery_row(board: BoardManager, rng: RandomNumberGenerator, _turns: int) -> Array:
	return SpawnManager.pressure_row(board, rng)
