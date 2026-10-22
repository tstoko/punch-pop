class_name EffectsManager
extends Node2D

const COLORS := [Color("ff9b4a"), Color("55aaff"), Color("42d5a4"), Color("b18bff")]
# A full-board cascade must remain bounded on low-end phones.
const MAX_PARTICLES := 240
const MAX_RINGS := 72
const SAMPLE_RATE := 22050
const CHAIN_NOTES := [1.0, 1.125, 1.25, 1.5, 1.6875, 2.0, 2.25, 2.5]
var particles: Array = []
var rings: Array = []
var voices: Array[AudioStreamPlayer] = []
var clips: Dictionary = {}
var voice := 0
var sound_enabled := true
var haptics_enabled := false
var reduced_motion := false

func _ready() -> void:
	set_process(false)
	if DisplayServer.get_name() == "headless":
		return
	for i in 6:
		var player := AudioStreamPlayer.new()
		player.volume_db = -16
		add_child(player)
		voices.append(player)

func _exit_tree() -> void:
	for player in voices:
		player.stop()
		player.stream = null
	clips.clear()

func burst(at: Vector2, color: int, count: int = 10, wave: int = 0) -> void:
	if color < 0 or color >= COLORS.size():
		return
	var strength := clampi(wave, 0, 4)
	var duration := .22 if wave == 0 else .32 + strength * .025
	var tint: Color = COLORS[color]
	if rings.size() < MAX_RINGS:
		rings.append({"p": at, "color": tint, "life": duration, "duration": duration, "reach": 17.0 + strength * 4.0})
	# Reduced motion uses one soft, stationary halo, without drifting particles.
	if not reduced_motion:
		var amount := mini(clampi(count, 0, 24), MAX_PARTICLES - particles.size())
		var rotation := randf() * TAU
		for i in amount:
			var angle := rotation + TAU * float(i) / maxi(amount, 1) + randf_range(-.15, .15)
			var lifetime := randf_range(.19, .34) + strength * .025
			particles.append({"p": at, "v": Vector2.from_angle(angle) * randf_range(65, 125 + strength * 24), "life": lifetime, "duration": lifetime, "color": tint.lerp(Color.WHITE, .32 if i % 3 == 0 else .0), "size": randf_range(1.6, 3.5), "spark": i % 3 == 0})
	set_process(true)
	queue_redraw()

func sound(kind: String, wave: int = 0) -> void:
	if haptics_enabled and OS.has_feature("mobile") and kind in ["cut", "match", "chain"]:
		Input.vibrate_handheld(12 if kind == "cut" else 22 if kind == "match" else 32)
	if not sound_enabled or voices.is_empty():
		return
	var level := clampi(wave, 0, 7) if kind in ["match", "chain"] else 0
	var key := kind + str(level)
	if not clips.has(key):
		clips[key] = synthesise(kind, level)
	# Prefer an idle voice so landing sounds do not chop off a chain's tail.
	var player := voices[voice % voices.size()]
	for candidate in voices:
		if not candidate.playing:
			player = candidate
			break
	voice += 1
	player.stream = clips[key]
	player.play()

func tone(wave: int = 0) -> void:
	sound("cut" if wave == 0 else "match", wave)

func synthesise(kind: String, wave: int) -> AudioStreamWAV:
	var sample := AudioStreamWAV.new()
	sample.format = AudioStreamWAV.FORMAT_16_BITS
	sample.mix_rate = SAMPLE_RATE
	var duration := .11
	if kind == "chain":
		duration = .38
	elif kind == "match":
		duration = .24
	elif kind == "land":
		duration = .06
	elif kind == "supply":
		duration = .14
	var frames := int(duration * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(frames * 2)
	var pitch: float = 440.0 * CHAIN_NOTES[clampi(wave, 0, 7)]
	for i in frames:
		var t := float(i) / float(SAMPLE_RATE)
		var envelope := pow(1.0 - t / duration, 2.0) * minf(1, t * 650)
		var signal_value := 0.0
		match kind:
			"cut":
				# A rounded pop and brief bright attack make single cuts tactile.
				signal_value = sin(TAU * (520 * t - 1550 * t * t)) * .64 + sin(TAU * 1350 * t) * exp(-t * 110) * .20
			"warning": signal_value = sin(TAU * 880 * t) * .36
			"land": signal_value = sin(TAU * (145 * t - 450 * t * t)) * .26
			"supply": signal_value = sin(TAU * (210 * t + 430 * t * t)) * .30
			"match":
				signal_value = (sin(TAU * pitch * t) + sin(TAU * pitch * 1.5 * t) * .35 + sin(TAU * pitch * 2.0 * t) * .18) * .48
			"chain":
				# Overlapping notes have independent attack/release envelopes;
				# unlike switching oscillators, this has no boundary clicks.
				var chord := [1.0, 1.25, 1.5, 2.0]
				for note in chord.size():
					var local_t := t - note * .038
					if local_t >= 0:
						var note_envelope := minf(1.0, local_t * 350) * exp(-local_t * 10)
						signal_value += sin(TAU * pitch * chord[note] * local_t) * note_envelope * .30
		data.encode_s16(i * 2, int(clampf(signal_value * envelope, -1, 1) * 32767))
	sample.data = data
	return sample

func _process(delta: float) -> void:
	# In-place removal avoids allocating new arrays on every animation frame.
	for i in range(particles.size() - 1, -1, -1):
		var p: Dictionary = particles[i]
		p.life -= delta
		if p.life <= 0:
			particles.remove_at(i)
		elif not reduced_motion:
			p.v.y += 220 * delta
			p.p += p.v * delta
	for i in range(rings.size() - 1, -1, -1):
		rings[i].life -= delta
		if rings[i].life <= 0:
			rings.remove_at(i)
	queue_redraw()
	if particles.is_empty() and rings.is_empty():
		set_process(false)

func _draw() -> void:
	for ring in rings:
		var color: Color = ring.color
		var progress: float = clampf(1.0 - ring.life / ring.duration, 0, 1)
		color.a = (1.0 - progress) * .50
		var radius: float = 19.0 if reduced_motion else 10.0 + (1.0 - pow(1.0 - progress, 3.0)) * ring.reach
		# A soft central flash reads immediately; the thin outer halo fades away.
		var glow := color
		glow.a *= .24
		draw_circle(ring.p, radius, glow, true, -1, true)
		draw_arc(ring.p, radius, 0, TAU, 24, color, 1.5, true)
	if reduced_motion:
		return
	for p in particles:
		var color: Color = p.color
		color.a = clampf(p.life / .14, 0, 1)
		var radius: float = p.size * minf(1, p.life / .13)
		if p.spark:
			var direction: Vector2 = p.v.normalized()
			draw_line(p.p - direction * radius * 2.4, p.p + direction * radius, color, 1.6, true)
		else:
			draw_circle(p.p, radius, color, true, -1, true)
