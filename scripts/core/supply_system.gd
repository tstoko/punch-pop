class_name SupplySystem
extends RefCounted

const INITIAL_INTERVAL := 12.0
# Retain the historical minimum for checkpoint validation. New rounds stop
# accelerating at four seconds; late pressure comes from costly punches.
const MIN_INTERVAL := 2.75
const RISE_INTERVALS := [12.0, 10.0, 8.5, 7.0, 6.0, 5.0, 4.5, 4.0]
const MAX_EFFORT_RATIO := 1.5

static func wave(turns: int) -> int:
	return 1 + int(turns / 8)

static func pressure_level(turns: int, active_seconds: float) -> int:
	return maxi(wave(turns), 1 + int(active_seconds / 25.0))

static func rise_interval(turns: int, active_seconds: float) -> float:
	return RISE_INTERVALS[mini(RISE_INTERVALS.size(), pressure_level(turns, active_seconds)) - 1]

# Effort uses the same visible countdown. Instant shallow tapping cannot
# bypass supply; efficient gravity clears buy more space for the same cost.
static func punch_effort(turns: int, active_seconds: float, period: float) -> float:
	var ratio := minf(MAX_EFFORT_RATIO, .10 + .10 * float(pressure_level(turns, active_seconds) - 1))
	return period * ratio

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
