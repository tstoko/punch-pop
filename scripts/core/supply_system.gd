class_name SupplySystem
extends RefCounted

const MIN_CELLS := 14

static func wave(turns: int) -> int:
	return mini(8, 1 + int(turns / 12))

static func pressure_level(turns: int, active_seconds: float) -> int:
	return mini(8, maxi(wave(turns), 1 + int(active_seconds / 20.0)))

static func rise_interval(turns: int, active_seconds: float) -> float:
	return maxf(3.5, 8.0 - (pressure_level(turns, active_seconds) - 1) * .75)

static func due_rows(turns: int) -> int:
	if turns < 24:
		return 1 if turns % 2 == 0 else 0
	if turns < 48:
		return 1
	return 2 if turns % 3 == 0 else 1

static func moves_to_drop(turns: int) -> int:
	for ahead in range(1, 4):
		if due_rows(turns + ahead) > 0:
			return ahead
	return 1

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
