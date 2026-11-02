extends SceneTree

# Balance lab: sweep pressure presets with seeded bots and report the shape of
# the difficulty curve (board fill per move, death level, session length).
# Engineering evidence only: bots are not people.
#   tools/test.sh --lab -- --preset=v8 --episodes=20
var episodes := 20
var dump := 0
var trace := false
var turn_based := true
var cap := 260
var presets := {}
var policies := [
	{"policy": "random", "think": 3.0},
	{"policy": "novice", "think": 4.0},
	{"policy": "casual", "think": 3.5},
	{"policy": "height_aware", "think": 2.5},
	{"policy": "height_aware", "think": 1.0},
	{"policy": "height_aware", "think": 0.0},
]
const FILL_AT := [5, 10, 20, 30, 45, 60, 80, 100, 130, 160, 200]

func _initialize() -> void:
	call_deferred("run")

func define_presets() -> void:
	presets.v10 = {"full": true, "pillar": true, "tuning": {}}
	# v0.10 stress candidates: more pressure, with mercy rows near the ceiling.
	presets.base_nomercy = {"full": true, "pillar": true, "tuning": {"mercy_height": 99}}
	presets.s1 = {"full": true, "pillar": true, "tuning": {"plain": [10, 11, 12, 13, 14, 15, 16, 17, 18, 20, 22, 24]}}
	presets.s2 = {"full": true, "pillar": true, "tuning": {"plain": [10, 11, 12, 13, 14, 15, 16, 17, 18, 20, 22, 24], "match_share": .6}}
	presets.s3 = {"full": true, "pillar": true, "tuning": {"plain": [11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 22, 24], "match_share": .55}}
	presets.m6 = {"full": true, "pillar": true, "tuning": {"level_punches": 6}}
	presets.m7 = {"full": true, "pillar": true, "tuning": {"level_punches": 7}}
	presets.m8_6 = {"full": true, "pillar": true, "tuning": {"level_punches": 6, "mercy_height": 8}}
	presets.m8_7 = {"full": true, "pillar": true, "tuning": {"level_punches": 7, "mercy_height": 8}}
	presets.l1 = {"full": true, "pillar": true, "tuning": {"level_punches": 7, "mercy_height": 7, "late_growth": 2}}
	presets.l2 = {"full": true, "pillar": true, "tuning": {"level_punches": 7, "mercy_height": 8, "late_growth": 2}}
	presets.l3 = {"full": true, "pillar": true, "tuning": {"level_punches": 8, "mercy_height": 7, "late_growth": 3}}
	presets.l4 = {"full": true, "pillar": true, "tuning": {"level_punches": 7, "mercy_height": 7, "late_growth": 3}}
	# Board-size trials, all on the shipped l3 balance.
	for size in [Vector2i(7, 9), Vector2i(7, 8), Vector2i(6, 9), Vector2i(6, 8), Vector2i(8, 8), Vector2i(6, 10)]:
		presets["b%dx%d" % [size.x, size.y]] = {"full": true, "pillar": true, "width": size.x, "height": size.y, "tuning": {}}
	presets.v10_soft = {"full": true, "pillar": true, "tuning": {"plain": [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 20, 22, 24]}}
	presets.v10_hard = {"full": true, "pillar": true, "tuning": {"plain": [8, 9, 11, 12, 13, 14, 16, 17, 18, 20, 22, 24]}}
	presets.v8 = {"full": false, "tuning": {}}
	var hard := [8, 9, 11, 12, 13, 14, 16, 17, 18, 20, 22, 24]
	presets.h1 = {"full": true, "pillar": true, "tuning": {"plain": hard, "match_share": .67}}
	presets.h2 = {"full": true, "pillar": true, "tuning": {"plain": hard, "match_share": .67, "level_punches": 8}}
	presets.h3 = {"full": true, "pillar": true, "tuning": {"plain": hard, "match_share": .6, "level_punches": 8, "chain_free_until": 4}}
	presets.v8_full = {"full": true, "tuning": {}}
	var gentle := [11.0, 10.5, 10.0, 9.5, 9.0, 8.5, 8.0]
	var smooth := [.35, .42, .49, .55, .60, .65, .70, .74, .78, .82, .85, .88, .91, .94, .97, 1.0, 1.03, 1.06, 1.09, 1.12, 1.15, 1.2]
	var refund := [0.0, 0.0, 1.0, 1.5, 2.0]
	presets.p1 = {"full": false, "tuning": {"intervals": gentle, "ratios": smooth, "refund": refund}}
	presets.p1_full = {"full": true, "tuning": {"intervals": gentle, "ratios": smooth, "refund": refund}}
	presets.p2_full = {"full": true, "tuning": {"intervals": gentle, "ratios": smooth.map(func(r: float) -> float: return r + .1), "refund": refund}}
	presets.p1_pillar = {"full": false, "pillar": true, "tuning": presets.p1.tuning}
	presets.p1_full_pillar = {"full": true, "pillar": true, "tuning": presets.p1.tuning}
	presets.v8_full_pillar = {"full": true, "pillar": true, "tuning": {}}
	var warm := [.40, .50, .60, .68, .75, .80, .85, .89, .92, .95, .98, 1.0]
	for level in range(13, 40):
		warm.append(minf(1.35, 1.0 + .015 * (level - 12)))
	presets.d1 = {"full": true, "pillar": true, "tuning": {"intervals": gentle, "ratios": warm, "refund": refund}}
	presets.d1_partial = {"full": false, "pillar": true, "tuning": {"intervals": gentle, "ratios": warm, "refund": refund}}
	var warm_steeper := warm.map(func(r: float) -> float: return r)
	for i in range(12, warm_steeper.size()):
		warm_steeper[i] = minf(1.5, 1.0 + .03 * (i - 11))
	presets.d2 = {"full": true, "pillar": true, "tuning": {"intervals": gentle, "ratios": warm_steeper, "refund": refund}}
	var decay := []
	for level in range(1, 40):
		decay.append(maxf(.25, 1.0 - .06 * (level - 1)))
	var slow_decay := []
	for level in range(1, 40):
		slow_decay.append(maxf(.4, 1.0 - .04 * (level - 1)))
	presets.e1 = {"full": true, "pillar": true, "tuning": {"intervals": gentle, "ratios": warm, "refund": refund, "generosity": decay}}
	presets.e2 = {"full": true, "pillar": true, "tuning": {"intervals": gentle, "ratios": warm, "refund": refund, "generosity": slow_decay}}
	presets.e1_partial = {"full": false, "pillar": true, "tuning": {"intervals": gentle, "ratios": warm, "refund": refund, "generosity": decay}}
	for slope in [4, 6, 8]:
		var climb := warm.slice(0, 12)
		for level in range(13, 40):
			climb.append(minf(2.0, 1.0 + slope / 100.0 * (level - 12)))
		presets["f%d" % slope] = {"full": true, "pillar": true, "tuning": {"intervals": gentle, "ratios": climb, "refund": refund, "generosity": decay}}
	for slope in [4, 6]:
		for refund_name in ["r1", "r0"]:
			var climb := warm.slice(0, 12)
			for level in range(13, 40):
				climb.append(minf(2.5, 1.0 + slope / 100.0 * (level - 12)))
			var table: Array = [0.0, 0.0, 1.0, 1.25, 1.5] if refund_name == "r1" else [0.0, 0.0, .75, 1.0, 1.0]
			presets["g%d%s" % [slope, refund_name]] = {"full": true, "pillar": true, "tuning": {"intervals": gentle, "ratios": climb, "refund": table, "generosity": decay}}
	presets.g6r0_partial = presets.g6r0.duplicate(true)
	presets.g6r0_partial.full = false
	presets.g6r0_partial.pillar = false
	presets.d3 = {"full": true, "pillar": true, "tuning": {"intervals": gentle, "ratios": warm_steeper, "refund": [0.0, 0.0, .75, 1.25, 1.5]}}
	for start in [.6, .7, .8]:
		var ratios := []
		for level in range(1, 30):
			ratios.append(start + .04 * mini(level - 1, 10) + .02 * maxi(0, level - 11))
		presets["c%d" % int(start * 10)] = {"full": true, "pillar": true, "tuning": {"intervals": gentle, "ratios": ratios, "refund": refund}}

var default_size := Vector2i(BoardManager.WIDTH, BoardManager.HEIGHT)

func run() -> void:
	define_presets()
	var chosen: Array = []
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--preset="):
			chosen.append_array(argument.trim_prefix("--preset=").split(","))
		elif argument.begins_with("--episodes="):
			episodes = int(argument.trim_prefix("--episodes="))
		elif argument == "--trace":
			trace = true
		elif argument.begins_with("--dump="):
			dump = int(argument.trim_prefix("--dump="))
		elif argument.begins_with("--cap="):
			cap = int(argument.trim_prefix("--cap="))
		elif argument.begins_with("--policies="):
			var names := argument.trim_prefix("--policies=").split(",")
			policies = policies.filter(func(p: Dictionary) -> bool: return ("%s@%s" % [p.policy, p.think]) in names or p.policy in names)
	if chosen.is_empty():
		chosen = presets.keys()
	for name in chosen:
		var preset: Dictionary = presets[name]
		CutterManager.full_footprint = preset.full
		CutterManager.shape_count = 4 if preset.get("pillar", false) else 3
		SupplySystem.tuning = preset.tuning
		BoardManager.WIDTH = preset.get("width", default_size.x)
		BoardManager.HEIGHT = preset.get("height", default_size.y)
		for profile in policies:
			report(name, profile, await cohort(profile))
	CutterManager.full_footprint = false
	SupplySystem.tuning = {}
	print("Lab complete")
	quit()

func cohort(profile: Dictionary) -> Array:
	var sessions: Array = []
	for episode in episodes:
		sessions.append(session(profile, 20261101 + episode, episode + 7))
		if episode % 5 == 4:
			await process_frame
	return sessions

func session(profile: Dictionary, seed_value: int, choice_seed: int) -> Dictionary:
	var model := RoundModel.new()
	model.reset(seed_value)
	var choices := RandomNumberGenerator.new()
	choices.seed = choice_seed
	var start := model.board.occupied()
	var data := {"moves": 0, "end": "cap", "fills": {}, "history": [], "reason": "", "board": [], "level": 1, "active": 0.0, "fresh": 0, "chains": 0, "matches": 0, "removed": 0, "arrived": 0, "score": 0, "start": start}
	for turn in cap:
		var thinking: float = profile.think
		if profile.policy == "casual":
			thinking = choices.randf_range(2.0, 5.0)
		elif profile.policy == "novice":
			thinking = choices.randf_range(2.5, 6.0)
		while turn_based == false and thinking > 0 and not model.over:
			var spent := minf(thinking, maxf(model.rise_remaining, .001))
			thinking -= spent
			if model.advance_clock(spent):
				count_arrivals(data, model.expire_clock())
		while model.rise_remaining <= 0 and not model.over:
			count_arrivals(data, model.expire_clock())
		if model.over:
			data.end = "overflow"
			break
		var actions: Array = []
		for slot in 3:
			if model.tray[slot].is_empty():
				continue
			for origin in CutterManager.placements(model.board, model.tray[slot]):
				actions.append({"slot": slot, "origin": origin})
		if actions.is_empty():
			data.end = "stuck"
			break
		var chosen: Dictionary = actions[choices.randi_range(0, actions.size() - 1)]
		if profile.policy != "random":
			var pool := actions
			if profile.policy == "casual":
				# Limited vision: a person notices a few promising spots, not all.
				pool = []
				for action in actions:
					if choices.randf() < .3:
						pool.append(action)
				if pool.is_empty():
					pool = [chosen]
			var best := -1e9
			for action in pool:
				var value := evaluate(model, action, profile.policy not in ["greedy", "novice"])
				if value > best:
					best = value
					chosen = action
		data.history.append(model.board.occupied())
		var events := model.play(chosen.slot, chosen.origin)
		# Tension proxy: moves spent within two rows of the ceiling, and
		# escapes from one row away back to a comfortable stack.
		var tallest := SupplySystem.tallest(model.board)
		if tallest >= BoardManager.HEIGHT - 2:
			data.danger = data.get("danger", 0) + 1
		if tallest >= BoardManager.HEIGHT - 1:
			data.brink = true
		elif tallest <= BoardManager.HEIGHT - 3 and data.get("brink", false):
			data.brink = false
			data.escapes = data.get("escapes", 0) + 1
		for event in events:
			if event.type == "pop" and event.source in ["cut", "player"]:
				data.removed += event.points.size()
		count_arrivals(data, events)
		if events.any(func(e: Dictionary) -> bool: return e.type == "pop" and e.wave == 1 and e.source == "cut"):
			data.matches += 1
		if events.any(func(e: Dictionary) -> bool: return e.type == "pop" and e.wave >= 2 and e.source == "cut"):
			data.chains += 1
		while model.rise_remaining <= 0 and not model.over:
			count_arrivals(data, model.expire_clock())
		if model.over:
			data.end = "overflow"
			break
		if model.turns in FILL_AT:
			data.fills[model.turns] = model.board.occupied()
		if trace and choice_seed == 7 and model.turns % 20 == 0:
			print("  t%d lvl %d period %.1f effort %.2f rows %d fresh %d fill %d chain_credit2 %.2f" % [model.turns, SupplySystem.pressure_level(model.turns, model.active_seconds), model.rise_period, model.punch_effort(), model.timed_rows, model.fresh_batches, model.board.occupied(), SupplySystem.chain_credit(2, model.punch_effort())])
	data.moves = model.turns
	data.reason = model.end_reason
	data.board = model.board.snapshot()
	data.level = SupplySystem.play_level(model.turns)
	data.best_streak = model.best_streak
	data.active = model.active_seconds
	data.fresh = model.fresh_batches
	data.rows = model.timed_rows
	if trace and choice_seed == 7:
		print("  conservation: start %d + added %d - removed %d - arrived %d = %d vs board %d; row events %d" % [data.get("start", 0), data.get("added", 0), data.removed, data.arrived, data.get("start", 0) + data.get("added", 0) - data.removed - data.arrived, model.board.occupied(), data.get("added", 0) / 7])
	data.score = model.score
	return data

func count_arrivals(data: Dictionary, events: Array) -> void:
	for event in events:
		if event.type == "row":
			data.added = data.get("added", 0) + 7
		if event.type == "pop" and event.source not in ["new_row", "refill", "cut", "player"]:
			print("  unknown pop source ", event.source)
		if event.type == "pop" and event.source in ["new_row", "refill"]:
			data.arrived += event.points.size()

func evaluate(model: RoundModel, action: Dictionary, height_aware: bool) -> float:
	var prediction := model.forecast(action.slot, action.origin, height_aware)
	var value: float = prediction.score
	if height_aware:
		var trial := BoardManager.new()
		trial.cells = prediction.cells
		var tallest := 0
		var roughness := 0
		var previous := 0
		for x in BoardManager.WIDTH:
			var h := SupplySystem.height(trial, x)
			tallest = maxi(tallest, h)
			if x > 0:
				roughness += absi(h - previous)
			previous = h
		value -= 80 * tallest + 20 * roughness + 6 * trial.occupied()
	return value

func pct(values: Array, q: float) -> Variant:
	if values.is_empty():
		return "-"
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size() - 1, int(sorted.size() * q))]

func report(name: String, profile: Dictionary, sessions: Array) -> void:
	var moves := sessions.map(func(s: Dictionary) -> int: return s.moves)
	var minutes := sessions.map(func(s: Dictionary) -> float: return snappedf((s.active + s.moves * .9) / 60.0, .1))
	var levels := sessions.map(func(s: Dictionary) -> int: return s.level)
	var streaks := sessions.map(func(s: Dictionary) -> int: return s.get("best_streak", 0))
	var scores := sessions.map(func(s: Dictionary) -> int: return s.score)
	var capped := sessions.filter(func(s: Dictionary) -> bool: return s.end == "cap").size()
	var fresh := 0
	var chains := 0
	var matches := 0
	var removed := 0
	var rows := 0
	var arrived := 0
	var total := 0
	var danger := 0
	var escapes := sessions.map(func(s: Dictionary) -> int: return s.get("escapes", 0))
	for s in sessions:
		danger += s.get("danger", 0)
		fresh += s.fresh
		chains += s.chains
		matches += s.matches
		removed += s.removed
		rows += s.rows
		arrived += s.arrived
		total += s.moves
	var reasons := {}
	var tail := {5: [], 15: [], 30: []}
	for s in sessions:
		if s.end != "overflow":
			continue
		reasons[s.reason] = reasons.get(s.reason, 0) + 1
		for back in tail:
			if s.history.size() > back:
				tail[back].append(s.history[s.history.size() - back])
	var dumped := 0
	for s in sessions:
		if s.end == "overflow" and dumped < dump:
			dumped += 1
			print("  death at move %d (%s):" % [s.moves, s.reason])
			for row in s.board:
				print("    " + "".join(row.map(func(c: int) -> String: return "." if c < 0 else str(c))))
	var curve := []
	for at in FILL_AT:
		var fills := sessions.filter(func(s: Dictionary) -> bool: return s.fills.has(at)).map(func(s: Dictionary) -> int: return s.fills[at])
		if fills.size() * 2 < sessions.size():
			break
		curve.append("%d:%s" % [at, pct(fills, .5)])
	print("%-14s %-13s danger%% %.0f escapes p50/p90 %s/%s" % [name, "%s@%s" % [profile.policy, profile.think], 100.0 * danger / maxi(1, total), pct(escapes, .5), pct(escapes, .9)])
	print("%-14s %-13s moves p10/50/90 %s/%s/%s  min %s  lvl %s streak %s score %s  cap %d/%d  fresh %.1f  match%% %.0f chain%% %.1f  out/move %.2f arrive/move %.2f rows/move %.2f  fill %s  pre-death fill -30/-15/-5 %s/%s/%s %s" % [name, "%s@%s" % [profile.policy, profile.think], pct(moves, .1), pct(moves, .5), pct(moves, .9), pct(minutes, .5), pct(levels, .5), pct(streaks, .5), pct(scores, .5), capped, sessions.size(), float(fresh) / sessions.size(), 100.0 * matches / maxi(1, total), 100.0 * chains / maxi(1, total), float(removed) / maxi(1, total), float(arrived) / maxi(1, total), float(rows) / maxi(1, total), " ".join(curve), pct(tail[30], .5), pct(tail[15], .5), pct(tail[5], .5), reasons])
