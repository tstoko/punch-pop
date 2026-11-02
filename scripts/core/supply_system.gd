class_name SupplySystem
extends RefCounted

# --- Turn-based pressure (v0.9) -------------------------------------------
# No clock: think as long as you like. The row meter holds METER_CAPACITY
# units (one row). A plain punch costs PLAIN_COST for its level, a matching
# punch two thirds of that, and a chain a quarter (free before CHAIN_FREE_UNTIL).
# A full meter raises the previewed row, so clever matches keep the stack low.
const LEVEL_PUNCHES := 8
const METER_CAPACITY := 12
const PLAIN_COST := [8, 9, 11, 12, 13, 14, 16, 17, 18, 20, 22, 24]
const MATCH_SHARE := .67
# Plain-cost growth per level once the table above runs out.
const LATE_GROWTH := 3
const CHAIN_FREE_UNTIL := 5
# Incoming rows are searched for punch-and-match setups less often each level.
const MIN_GENEROSITY := .25
# Mercy: once any column is within this many rows of the ceiling, every
# incoming row is searched for an escape setup. Pressure squeezes the board;
# skill (not luck) gets you out.
const MERCY_GAP := 2

# --- Legacy pressure clock (checkpoint versions 3-5) ----------------------
# Retained so older saves validate and their clock fields remain readable.
const INITIAL_INTERVAL := 12.0
const MIN_INTERVAL := 2.75
const RISE_INTERVALS := [12.0, 10.0, 8.5, 7.0, 6.0, 5.0, 4.5, 4.0]
const MAX_EFFORT_RATIO := 2.5

# Lab-only overrides for balance sweeps. Always empty in the shipped game.
static var tuning := {}

static func knob(key: String, fallback: Variant) -> Variant:
	return tuning.get(key, fallback)

static func play_level(turns: int) -> int:
	return 1 + int(turns / int(knob("level_punches", LEVEL_PUNCHES)))

static func meter_capacity(_turns: int = 0) -> int:
	return METER_CAPACITY

static func meter_cost(waves: int, turns: int = 0) -> int:
	var table: Array = knob("plain", PLAIN_COST)
	var level := play_level(turns)
	var plain: int = table[mini(table.size(), level) - 1]
	# No plateau: beyond the table, every level keeps tightening the screw so
	# a strong player is always eventually pushed to the edge.
	if level > table.size():
		plain += int(knob("late_growth", LATE_GROWTH)) * (level - table.size())
	if waves <= 0:
		return plain
	if waves == 1:
		return int(ceil(plain * float(knob("match_share", MATCH_SHARE))))
	return 0 if level < int(knob("chain_free_until", CHAIN_FREE_UNTIL)) else int(plain / 4)

static func generosity(turns: int, _active_seconds: float = 0.0) -> float:
	if tuning.has("generosity"):
		var table: Array = tuning.generosity
		return float(table[mini(table.size(), play_level(turns)) - 1])
	return maxf(MIN_GENEROSITY, 1.0 - .06 * (play_level(turns) - 1))

static func tallest(board: BoardManager) -> int:
	var result := 0
	for x in BoardManager.WIDTH:
		result = maxi(result, height(board, x))
	return result

# Generosity for the row about to be previewed, given the board it will meet.
static func row_generosity(board: BoardManager, turns: int, active_seconds: float = 0.0) -> float:
	if tallest(board) >= int(knob("mercy_height", BoardManager.HEIGHT - MERCY_GAP)):
		return 1.0
	return generosity(turns, active_seconds)

# Legacy clock helpers. The live game no longer advances the clock.
static func wave(turns: int) -> int:
	return 1 + int(turns / 8)

static func pressure_level(turns: int, active_seconds: float = 0.0) -> int:
	return maxi(play_level(turns), 1 + int(active_seconds / 25.0)) if active_seconds > 0 else play_level(turns)

static func rise_interval(turns: int, active_seconds: float) -> float:
	return RISE_INTERVALS[mini(RISE_INTERVALS.size(), maxi(wave(turns), 1 + int(active_seconds / 25.0))) - 1]

static func punch_effort(_turns: int, _active_seconds: float, _period: float) -> float:
	return 0.0

static func chain_credit(_waves: int, _effort: float) -> float:
	return 0.0

static func chain_time(_waves: int) -> float:
	return 0.0

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
