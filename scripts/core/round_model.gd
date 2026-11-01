class_name RoundModel
extends RefCounted

const VERSION := 5
var board := BoardManager.new()
var rng := RandomNumberGenerator.new()
var tray: Array = []
var incoming: Array = []
var score := 0
var turns := 0
var combo := 0
var best_combo := 0
var selected := 0
var lesson := -1
var lesson_complete := false
var over := false
var fresh_batches := 0
var cleared := 0
var active_seconds := 0.0
var rise_remaining := SupplySystem.INITIAL_INTERVAL
var rise_period := SupplySystem.INITIAL_INTERVAL
# Gross effort never rewinds with undo. The small pending balance carries a
# punch's overshoot into the next clock instead of granting free effort.
var effort_seconds := 0.0
var pending_effort := 0.0
var timed_rows := 0
var end_reason := ""

func reset(seed_value: int = -1, lesson_index: int = -1) -> void:
	if seed_value == -1:
		rng.randomize()
	else:
		rng.seed = seed_value
	score = 0
	turns = 0
	combo = 0
	best_combo = 0
	selected = 0
	lesson = lesson_index
	lesson_complete = false
	over = false
	fresh_batches = 0
	cleared = 0
	active_seconds = 0
	rise_remaining = SupplySystem.INITIAL_INTERVAL
	rise_period = SupplySystem.INITIAL_INTERVAL
	effort_seconds = 0.0
	pending_effort = 0.0
	timed_rows = 0
	end_reason = ""
	if lesson >= 0:
		tray = [LessonBook.build(board, lesson), {}, {}]
	else:
		LessonBook.endless_opening(board, rng)
		tray = CutterManager.hand_refresh(board, [{}, {}, {}], rng)
	incoming = SpawnManager.pressure_row(board, rng)

func snapshot() -> Dictionary:
	return {"version": VERSION, "cells": board.snapshot(), "tray": tray.duplicate(true), "incoming": incoming.duplicate(), "score": score, "turns": turns, "combo": combo, "best_combo": best_combo, "selected": selected, "lesson": lesson, "lesson_complete": lesson_complete, "over": over, "fresh_batches": fresh_batches, "cleared": cleared, "active_seconds": active_seconds, "rise_remaining": rise_remaining, "rise_period": rise_period, "effort_seconds": effort_seconds, "pending_effort": pending_effort, "timed_rows": timed_rows, "end_reason": end_reason, "rng_seed": str(rng.seed), "rng_state": str(rng.state)}

static func valid(data: Dictionary) -> bool:
	if data.get("version") not in [2, 3, 4, VERSION] or not data.get("cells") is Array or data.cells.size() != 9:
		return false
	for row in data.cells:
		if not row is Array or row.size() != 7:
			return false
		for value in row:
			if not value is int or value < -1 or value > 3:
				return false
	if not data.get("tray") is Array or data.tray.size() != 3 or not data.get("incoming") is Array or data.incoming.size() != 7:
		return false
	for color in data.incoming:
		if not color is int or color < 0 or color > 3:
			return false
	for cutter in data.tray:
		if not cutter is Dictionary:
			return false
		if cutter.is_empty():
			continue
		if not cutter.get("shape") is int or not cutter.get("color") is int or cutter.shape < 0 or cutter.shape > 2 or cutter.color < -1 or cutter.color > 3:
			return false
	for key in ["score", "turns", "combo", "best_combo", "selected", "lesson", "fresh_batches", "cleared"]:
		if not data.get(key) is int:
			return false
	if data.score < 0 or data.turns < 0 or data.combo < 0 or data.best_combo < 0 or data.fresh_batches < 0 or data.cleared < 0 or data.selected < 0 or data.selected > 2 or data.lesson < -1 or data.lesson > 2:
		return false
	if not data.get("lesson_complete") is bool or not data.get("over") is bool:
		return false
	if not data.get("rng_seed") is String or not data.get("rng_state") is String or not data.rng_seed.is_valid_int() or not data.rng_state.is_valid_int():
		return false
	if not valid_i64(data.rng_state) or not valid_i64(data.rng_seed):
		return false
	if data.version >= 3:
		for key in ["active_seconds", "rise_remaining", "rise_period"]:
			if not (data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])):
				return false
		if data.active_seconds < 0 or data.rise_remaining < 0 or data.rise_remaining > SupplySystem.INITIAL_INTERVAL or data.rise_period < SupplySystem.MIN_INTERVAL or data.rise_period > SupplySystem.INITIAL_INTERVAL or data.rise_remaining > data.rise_period:
			return false
		if not data.get("timed_rows") is int or data.timed_rows < 0 or data.get("end_reason") not in ["", "timer", "scheduled", "refill"]:
			return false
	if data.version >= 5:
		for key in ["effort_seconds", "pending_effort"]:
			if not (data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])) or data[key] < 0:
				return false
		if data.pending_effort > SupplySystem.INITIAL_INTERVAL * SupplySystem.MAX_EFFORT_RATIO or (data.pending_effort > 0 and data.rise_remaining > 0):
			return false
	# Round checkpoints must be settled, including authored lesson layouts.
	var trial := BoardManager.new()
	trial.cells = data.cells.duplicate(true)
	if not GravitySystem.apply(trial).is_empty() or not MatchSystem.groups(trial).is_empty():
		return false
	if not data.over and not data.lesson_complete:
		if data.tray[data.selected].is_empty() or CutterManager.placements(trial, data.tray[data.selected]).is_empty():
			return false
	return true

static func valid_i64(value: String) -> bool:
	if not value.is_valid_int():
		return false
	var negative := value.begins_with("-")
	var digits := value.substr(1) if negative else value
	var limit := "9223372036854775808" if negative else "9223372036854775807"
	if digits.length() > 19 or (digits.length() == 19 and digits > limit):
		return false
	return str(int(value)) == value

func restore(data: Dictionary) -> bool:
	if not valid(data):
		return false
	board.cells = data.cells.duplicate(true)
	tray = data.tray.duplicate(true)
	if data.version < 4:
		for cutter in tray:
			if not cutter.is_empty():
				cutter.color = -1
	incoming = data.incoming.duplicate()
	score = data.score
	turns = data.turns
	combo = data.combo
	best_combo = data.best_combo
	selected = data.selected
	lesson = data.lesson
	lesson_complete = data.lesson_complete
	over = data.over
	fresh_batches = data.fresh_batches
	cleared = data.cleared
	active_seconds = float(data.active_seconds) if data.version >= 3 else 0.0
	rise_remaining = float(data.rise_remaining) if data.version >= 3 else SupplySystem.INITIAL_INTERVAL
	rise_period = float(data.rise_period) if data.version >= 3 else SupplySystem.INITIAL_INTERVAL
	effort_seconds = float(data.effort_seconds) if data.version >= 5 else 0.0
	pending_effort = float(data.pending_effort) if data.version >= 5 else 0.0
	timed_rows = data.timed_rows if data.version >= 3 else 0
	end_reason = data.end_reason if data.version >= 3 else ""
	if data.version < 4 and lesson >= 0:
		# Old lessons depended on colour-selective punches. Restart only that
		# lesson with its matching new layout; endless progress is untouched.
		tray = [LessonBook.build(board, lesson), {}, {}]
		selected = 0
		score = 0
		turns = 0
		combo = 0
		best_combo = 0
		cleared = 0
		fresh_batches = 0
		lesson_complete = false
		over = false
		active_seconds = 0
		rise_remaining = SupplySystem.INITIAL_INTERVAL
		rise_period = SupplySystem.INITIAL_INTERVAL
		timed_rows = 0
		end_reason = ""
	rng.seed = int(data.rng_seed)
	rng.state = int(data.rng_state)
	return true

func punch_effort() -> float:
	return SupplySystem.punch_effort(turns, active_seconds, rise_period) if lesson < 0 else 0.0

# One shared receipt keeps previews and actual settlement identical. Rewards
# offset effort before expiry, including a chain played at the last moment.
func clock_forecast(waves: int) -> Dictionary:
	var effort := punch_effort()
	var reward := SupplySystem.chain_time(waves) if lesson < 0 else 0.0
	reward = minf(reward, maxf(0, rise_period - rise_remaining + pending_effort + effort))
	var balance := rise_remaining - pending_effort + reward - effort
	var owed_rows := 0
	# Predict the same expiries the controller will present after the cut.
	var next_period := SupplySystem.rise_interval(turns + 1, active_seconds)
	while lesson < 0 and balance <= 0:
		owed_rows += 1
		balance += next_period
	return {"effort": effort, "time_bonus": reward, "clock_delta": reward - effort, "rows_due": owed_rows}

func set_clock_balance(balance: float) -> void:
	rise_remaining = maxf(0, balance)
	pending_effort = maxf(0, -balance)

# Restore the decision, but never refund either thinking time or punch effort.
# Timed rises invalidate undo in the controller, so no row can be rewound.
func restore_undo(data: Dictionary) -> bool:
	var seconds := active_seconds
	var effort := effort_seconds
	if not restore(data):
		return false
	var elapsed := maxf(0, seconds - active_seconds)
	var spent := maxf(0, effort - effort_seconds)
	set_clock_balance(rise_remaining - pending_effort - elapsed - spent)
	active_seconds = maxf(seconds, active_seconds)
	effort_seconds = maxf(effort, effort_seconds)
	return true

func forecast(slot: int, origin: Vector2i, include_board: bool = false) -> Dictionary:
	if lesson >= 0 and origin != LessonBook.GOALS[lesson]:
		return {}
	if slot < 0 or slot >= tray.size() or tray[slot].is_empty():
		return {}
	var trial := BoardManager.new()
	trial.cells = board.snapshot()
	var hits := CutterManager.hits(trial, tray[slot], origin)
	if hits.size() < 2:
		return {}
	trial.remove(hits)
	var result := ComboManager.resolve(trial)
	var bonus := ComboManager.perfect_bonus(hits.size(), CutterManager.SHAPES[tray[slot].shape].size())
	var matched := 0
	for wave in result.waves:
		matched += wave.cells.size()
	var prediction := {"hits": hits, "waves": result.waves.size(), "matched": matched, "score": ComboManager.cut_score(hits.size()) + bonus + result.score, "perfect": bonus > 0, "bonus": bonus}
	prediction.merge(clock_forecast(result.waves.size()))
	if include_board:
		prediction.cells = trial.snapshot()
	return prediction

func play(slot: int, origin: Vector2i) -> Array:
	if lesson >= 0 and origin != LessonBook.GOALS[lesson]:
		return []
	if over or lesson_complete or (lesson < 0 and rise_remaining <= 0) or slot < 0 or slot >= tray.size() or tray[slot].is_empty():
		return []
	var hits := CutterManager.hits(board, tray[slot], origin)
	if hits.size() < 2:
		return []
	var events: Array = []
	combo = 0
	var bonus := ComboManager.perfect_bonus(hits.size(), CutterManager.SHAPES[tray[slot].shape].size())
	remove_event(events, hits, 0, [], "player", bonus)
	resolve_events(events)
	if lesson < 0:
		var receipt := clock_forecast(combo)
		effort_seconds += receipt.effort
		set_clock_balance(rise_remaining - pending_effort + receipt.clock_delta)
		events.append({"type": "effort", "seconds": receipt.effort, "pending": pending_effort})
		if receipt.time_bonus > 0:
			events.append({"type": "breathing", "seconds": receipt.time_bonus})
	turns += 1
	if lesson >= 0:
		lesson_complete = true
		return events
	if not replenish(events, slot):
		return events
	if not tray[slot].is_empty():
		selected = slot
	return events

# Only decision time advances this clock. Menus/animations never call this.
func advance_clock(delta: float) -> bool:
	if over or lesson >= 0 or delta < 0 or not is_finite(delta):
		return false
	var spent := minf(delta, rise_remaining)
	active_seconds += spent
	rise_remaining = maxf(0, rise_remaining - spent)
	return rise_remaining <= 0

func expire_clock() -> Array:
	if over or lesson >= 0 or rise_remaining > 0:
		return []
	var events: Array = []
	timed_rows += 1
	rise_period = SupplySystem.rise_interval(turns, active_seconds)
	set_clock_balance(rise_period - pending_effort)
	combo = 0
	if drop(events, "timer"):
		replenish(events)
	else:
		rise_remaining = 0
	return events

func replenish(events: Array, used_slot: int = -1) -> bool:
	var refills := 0
	# A successful cut buys real space. Only restore supply when play stops.
	while CutterManager.candidates(board).is_empty():
		if refills == 0:
			fresh_batches += 1
			events.append({"type": "fresh"})
		if not drop(events, "refill"):
			return false
		refills += 1
		# Hard bound protects against pathological all-clear loops, without losing.
		if refills >= 8:
			break
	if used_slot >= 0:
		tray[used_slot] = {}
	tray = CutterManager.hand_refresh(board, tray, rng)
	if tray.is_empty():
		# A rare regenerated sparse board gets an explicit, guaranteed playable batch.
		incoming = SupplySystem.recovery_row(board, rng, turns)
		if not drop(events, "refill"):
			return false
		tray = CutterManager.hand_refresh(board, [], rng)
		assert(not tray.is_empty(), "Recovery row must leave a playable board")
	if selected < 0 or selected >= tray.size() or tray[selected].is_empty():
		for i in tray.size():
			if not tray[i].is_empty():
				selected = i
				break
	return true

func drop(events: Array, reason: String = "scheduled") -> bool:
	if not SpawnManager.rise_row(board, incoming):
		over = true
		end_reason = reason
		events.append({"type": "overflow", "reason": reason})
		return false
	var colors := incoming.duplicate()
	var row_event := {"type": "row", "colors": colors, "next": [], "cells": board.snapshot(), "reason": reason, "direction": "up"}
	events.append(row_event)
	resolve_events(events, "refill" if reason == "refill" else "new_row")
	incoming = SpawnManager.pressure_row(board, rng)
	row_event.next = incoming.duplicate()
	return true

func remove_event(events: Array, points: Array, wave: int, groups: Array = [], source: String = "player", bonus: int = 0) -> void:
	var earned := ComboManager.cut_score(points.size()) if wave == 0 else ComboManager.match_score(points.size(), wave)
	earned += bonus
	score += earned
	cleared += points.size()
	combo = maxi(combo, wave)
	best_combo = maxi(best_combo, wave)
	events.append({"type": "pop", "points": points.duplicate(), "wave": wave, "earned": earned, "groups": groups.duplicate(true), "source": source, "perfect": bonus > 0, "bonus": bonus})
	board.remove(points)

func resolve_events(events: Array, source: String = "cut") -> void:
	fall_event(events)
	var matches := MatchSystem.groups(board)
	var wave := 0
	while not matches.is_empty():
		wave += 1
		var points: Array = []
		for group in matches:
			points.append_array(group)
		remove_event(events, points, wave, matches, source)
		fall_event(events)
		matches = MatchSystem.groups(board)

func fall_event(events: Array) -> void:
	var moves := GravitySystem.apply(board)
	if not moves.is_empty():
		events.append({"type": "fall", "moves": moves, "cells": board.snapshot()})
