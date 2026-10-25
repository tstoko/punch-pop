class_name SupplySystem
extends RefCounted

const INITIAL_INTERVAL := 12.0
const MIN_INTERVAL := 2.75
const RISE_INTERVALS := [12.0, 9.5, 8.0, 6.5, 5.5, 4.5, 3.25, 2.75]

static func wave(turns: int) -> int:
	return mini(8, 1 + int(turns / 10))

static func pressure_level(turns: int, active_seconds: float) -> int:
	return mini(8, maxi(wave(turns), 1 + int(active_seconds / 20.0)))

static func rise_interval(turns: int, active_seconds: float) -> float:
	return RISE_INTERVALS[pressure_level(turns, active_seconds) - 1]

# Kept for older presentation/audit callers: the clock is the only pressure.
static func due_rows(_turns: int) -> int:
	return 0

static func moves_to_drop(_turns: int) -> int:
	return 0

# Clearing one group already earns space. Reserve clock rescue for a real
# multi-wave chain so routine matches cannot neutralize the pressure curve.
static func chain_time(waves: int) -> float:
	return minf(1.5, maxf(0.0, float(waves - 1) * .5))

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
