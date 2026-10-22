class_name EffectsManager
extends Node2D

const COLORS := [Color("ff9b4a"), Color("55aaff"), Color("42d5a4"), Color("b18bff")]
var particles: Array = []
var rings: Array = []
var voices: Array[AudioStreamPlayer] = []
var clips: Dictionary = {}
var voice := 0
var sound_enabled := true
var haptics_enabled := false
var reduced_motion := false

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	for i in 4:
		var player := AudioStreamPlayer.new()
		player.volume_db = -18
		add_child(player)
		voices.append(player)

func _exit_tree() -> void:
	for player in voices:
		player.stop()
		player.stream = null
	clips.clear()

func burst(at: Vector2, color: int, count: int = 10) -> void:
	if color < 0:
		return
	rings.append({"p": at, "color": COLORS[color], "life": .32})
	for i in count:
		var angle := randf() * TAU
		particles.append({"p": at, "v": Vector2(cos(angle), sin(angle)) * (0 if reduced_motion else randf_range(50, 160)), "life": randf_range(.25, .55), "color": COLORS[color], "size": randf_range(2, 5), "spark": i % 3 == 0})

func sound(kind: String, wave: int = 0) -> void:
	if haptics_enabled and OS.has_feature("mobile") and kind in ["cut", "match", "chain"]:
		Input.vibrate_handheld(15 if kind == "cut" else 28)
	if not sound_enabled or voices.is_empty():
		return
	var level := mini(wave, 7)
	var key := kind + str(level)
	if not clips.has(key):
		clips[key] = synthesise(kind, level)
	var player := voices[voice % voices.size()]
	voice += 1
	player.stream = clips[key]
	player.play()

func tone(wave: int = 0) -> void:
	sound("cut" if wave == 0 else "match", wave)

func synthesise(kind: String, wave: int) -> AudioStreamWAV:
	var sample := AudioStreamWAV.new()
	sample.format = AudioStreamWAV.FORMAT_16_BITS
	sample.mix_rate = 22050
	var duration := .12
	if kind == "chain":
		duration = .30
	elif kind == "match":
		duration = .20
	elif kind == "land":
		duration = .055
	var frames := int(duration * 22050)
	var data := PackedByteArray()
	data.resize(frames * 2)
	for i in frames:
		var t := float(i) / 22050.0
		var envelope := pow(1.0 - t / duration, 2.0) * minf(1, t * 1000)
		var signal_value := 0.0
		match kind:
			"cut": signal_value = sin(TAU * (480 * t - 1050 * t * t)) * .70
			"warning": signal_value = sin(TAU * 880 * t) * .48
			"land": signal_value = sin(TAU * 105 * t) * .23
			"supply": signal_value = sin(TAU * (240 * t + 600 * t * t)) * .33
			"match": signal_value = (sin(TAU * 660 * t) + sin(TAU * 990 * t) * .35) * .52
			"chain":
				var notes := [1.0, 1.25, 1.5, 2.0]
				var frequency: float = (440 + wave * 55) * notes[mini(3, int(t / .065))]
				var local_t := fmod(t, .065)
				signal_value = sin(TAU * frequency * local_t) * .65 * minf(1, local_t * 500)
		data.encode_s16(i * 2, int(clampf(signal_value * envelope, -1, 1) * 32767))
	sample.data = data
	return sample

func _process(delta: float) -> void:
	for p in particles:
		p.life -= delta
		if not reduced_motion:
			p.v.y += 330 * delta
			p.p += p.v * delta
	for ring in rings:
		ring.life -= delta
	particles = particles.filter(func(p: Dictionary) -> bool: return p.life > 0)
	rings = rings.filter(func(r: Dictionary) -> bool: return r.life > 0)
	queue_redraw()

func _draw() -> void:
	for ring in rings:
		var color: Color = ring.color
		color.a = ring.life / .32 * .6
		draw_arc(ring.p, 19 if reduced_motion else 15 + (1 - ring.life / .32) * 30, 0, TAU, 32, color, 2, true)
	for p in particles:
		var color: Color = p.color
		color.a = clampf(p.life / .20, 0, 1)
		var radius: float = p.size * minf(1, p.life / .15)
		if p.spark:
			draw_line(p.p - Vector2(radius, 0), p.p + Vector2(radius, 0), color, 2, true)
			draw_line(p.p - Vector2(0, radius), p.p + Vector2(0, radius), color, 2, true)
		else:
			draw_circle(p.p, radius, color, true, -1, true)
