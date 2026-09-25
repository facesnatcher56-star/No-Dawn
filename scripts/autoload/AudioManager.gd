extends Node

var sounds: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_synthesize_all_sounds()

func play_sound_3d(sound_name: String, pos: Vector3, volume_db: float = 0.0, unit_size: float = 15.0, max_distance: float = 600.0) -> AudioStreamPlayer3D:
	if not sounds.has(sound_name):
		return null
	var player = AudioStreamPlayer3D.new()
	player.stream = sounds[sound_name]
	player.volume_db = volume_db
	player.unit_size = unit_size
	player.max_distance = max_distance
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP
	get_tree().root.add_child(player)
	player.global_position = pos
	player.play()
	player.finished.connect(func(): player.queue_free())
	return player

func play_sound_2d(sound_name: String, volume_db: float = 0.0) -> AudioStreamPlayer:
	if not sounds.has(sound_name):
		return null
	var player = AudioStreamPlayer.new()
	player.stream = sounds[sound_name]
	player.volume_db = volume_db
	get_tree().root.add_child(player)
	player.play()
	player.finished.connect(func(): player.queue_free())
	return player

func get_stream(sound_name: String) -> AudioStreamWAV:
	return sounds.get(sound_name, null)

func _synthesize_all_sounds() -> void:
	sounds["cannon_fire"] = _create_cannon_fire()
	sounds["cannon_impact"] = _create_cannon_impact()
	sounds["engine_idle"] = _create_engine_loop(40.0, 0.45)
	sounds["engine_combat"] = _create_engine_loop(68.0, 0.7)
	sounds["tracks_loop"] = _create_tracks_loop()
	sounds["at_gun_fire"] = _create_at_gun_fire()
	sounds["infantry_rifle"] = _create_infantry_rifle()
	sounds["steam_press"] = _create_steam_press()
	sounds["flare_launch"] = _create_flare_launch()
	sounds["flare_burn"] = _create_flare_burn()
	sounds["radio_click"] = _create_radio_click()
	sounds["ricochet"] = _create_ricochet()
	sounds["reload_clack"] = _create_reload_clack()

func _create_cannon_fire() -> AudioStreamWAV:
	var rate = 22050
	var duration = 1.6
	var samples = int(rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(samples * 2)

	var rng = RandomNumberGenerator.new()
	rng.seed = 101

	var lp_val: float = 0.0
	for i in range(samples):
		var t = float(i) / rate
		var env = exp(-t * 3.2)
		var bass = sin(t * TAU * (55.0 - t * 20.0)) * 18000.0 * env
		var punch = (rng.randf_range(-1.0, 1.0)) * 24000.0 * exp(-t * 22.0)
		var rumble_noise = rng.randf_range(-1.0, 1.0) * 12000.0 * env
		lp_val = lerpf(lp_val, rumble_noise, 0.15)

		var sample = clampf(bass + punch + lp_val, -32767.0, 32767.0)
		bytes.encode_s16(i * 2, int(sample))

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	return wav

func _create_cannon_impact() -> AudioStreamWAV:
	var rate = 22050
	var duration = 1.3
	var samples = int(rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(samples * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 202

	var lp_val: float = 0.0
	for i in range(samples):
		var t = float(i) / rate
		var env = exp(-t * 4.0)
		var thud = sin(t * TAU * 48.0) * 16000.0 * env
		var metal_clang = (sin(t * TAU * 310.0) + sin(t * TAU * 540.0) * 0.5) * 10000.0 * exp(-t * 9.0)
		var noise = rng.randf_range(-1.0, 1.0) * 14000.0 * env
		lp_val = lerpf(lp_val, noise, 0.2)
		var sample = clampf(thud + metal_clang + lp_val, -32767.0, 32767.0)
		bytes.encode_s16(i * 2, int(sample))

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	return wav

func _create_engine_loop(base_freq: float, speed_mult: float) -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.8
	var samples = int(rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(samples * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 303

	for i in range(samples):
		var t = float(i) / rate
		var f = base_freq
		var h1 = sin(t * TAU * f) * 10000.0
		var h2 = sin(t * TAU * f * 2.0) * 6000.0
		var h3 = sin(t * TAU * f * 3.0) * 3500.0
		var chug = sin(t * TAU * (f * 0.5)) * 4000.0
		var jitter = rng.randf_range(-1.0, 1.0) * 2000.0
		var sample = clampf((h1 + h2 + h3 + chug + jitter) * speed_mult, -32767.0, 32767.0)
		bytes.encode_s16(i * 2, int(sample))

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = samples
	wav.data = bytes
	return wav

func _create_tracks_loop() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.7
	var samples = int(rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(samples * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 404

	for i in range(samples):
		var t = float(i) / rate
		var clank_rate = 8.0
		var cycle = fmod(t * clank_rate, 1.0)
		var clank = exp(-cycle * 12.0) * (sin(cycle * TAU * 180.0) * 7000.0 + rng.randf_range(-1.0, 1.0) * 4000.0)
		var squeal = sin(t * TAU * 820.0) * (sin(t * TAU * 4.0) * 0.5 + 0.5) * 2500.0
		var sample = clampf(clank + squeal, -32767.0, 32767.0)
		bytes.encode_s16(i * 2, int(sample))

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = samples
	wav.data = bytes
	return wav

func _create_at_gun_fire() -> AudioStreamWAV:
	var rate = 22050
	var duration = 1.1
	var samples = int(rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(samples * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 505

	for i in range(samples):
		var t = float(i) / rate
		var crack = rng.randf_range(-1.0, 1.0) * 28000.0 * exp(-t * 45.0)
		var echo = sin(t * TAU * 110.0) * 12000.0 * exp(-t * 4.5)
		var sample = clampf(crack + echo, -32767.0, 32767.0)
		bytes.encode_s16(i * 2, int(sample))

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	return wav

func _create_infantry_rifle() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.45
	var samples = int(rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(samples * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 606

	for i in range(samples):
		var t = float(i) / rate
		var snap = rng.randf_range(-1.0, 1.0) * 24000.0 * exp(-t * 30.0)
		var ring = sin(t * TAU * 340.0) * 6000.0 * exp(-t * 12.0)
		var sample = clampf(snap + ring, -32767.0, 32767.0)
		bytes.encode_s16(i * 2, int(sample))

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	return wav

func _create_steam_press() -> AudioStreamWAV:
	var rate = 22050
	var duration = 2.4
	var samples = int(rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(samples * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 707

	for i in range(samples):
		var t = float(i) / rate
		var thud = 0.0
		var hiss = 0.0
		# Pre-charge hiss (0.0 - 0.7s)
		if t < 0.7:
			hiss = rng.randf_range(-1.0, 1.0) * (t / 0.7) * 8000.0
		# Heavy pneumatic hammer slam at 0.7s
		elif t >= 0.7 and t < 1.4:
			var t_hit = t - 0.7
			thud = sin(t_hit * TAU * 36.0) * 24000.0 * exp(-t_hit * 3.5)
			thud += (rng.randf_range(-1.0, 1.0) * 16000.0) * exp(-t_hit * 8.0)
		# Exhaust steam release hiss at 1.4s
		else:
			var t_steam = t - 1.4
			hiss = rng.randf_range(-1.0, 1.0) * 11000.0 * exp(-t_steam * 2.5)

		var sample = clampf(thud + hiss, -32767.0, 32767.0)
		bytes.encode_s16(i * 2, int(sample))

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	return wav

func _create_flare_launch() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.9
	var samples = int(rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(samples * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 808

	for i in range(samples):
		var t = float(i) / rate
		var freq = lerpf(180.0, 480.0, t / duration)
		var whistle = sin(t * TAU * freq) * 10000.0 * (1.0 - t / duration)
		var sizzle = rng.randf_range(-1.0, 1.0) * 8000.0 * (1.0 - t / duration)
		var sample = clampf(whistle + sizzle, -32767.0, 32767.0)
		bytes.encode_s16(i * 2, int(sample))

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	return wav

func _create_flare_burn() -> AudioStreamWAV:
	var rate = 22050
	var duration = 1.0
	var samples = int(rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(samples * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 909

	for i in range(samples):
		var t = float(i) / rate
		var sputter = (sin(t * TAU * 24.0) * 0.5 + 0.5) * rng.randf_range(-1.0, 1.0) * 5500.0
		var flame = rng.randf_range(-1.0, 1.0) * 3500.0
		var sample = clampf(sputter + flame, -32767.0, 32767.0)
		bytes.encode_s16(i * 2, int(sample))

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = samples
	wav.data = bytes
	return wav

func _create_radio_click() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.08
	var samples = int(rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(samples * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 1010

	for i in range(samples):
		var t = float(i) / rate
		var click = rng.randf_range(-1.0, 1.0) * 15000.0 * exp(-t * 60.0)
		bytes.encode_s16(i * 2, int(click))

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	return wav

func _create_ricochet() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.6
	var samples = int(rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(samples * 2)

	for i in range(samples):
		var t = float(i) / rate
		var f = lerpf(1800.0, 420.0, t / duration)
		var ping = sin(t * TAU * f) * 14000.0 * exp(-t * 5.0)
		bytes.encode_s16(i * 2, int(ping))

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	return wav

func _create_reload_clack() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.5
	var samples = int(rate * duration)
	var bytes = PackedByteArray()
	bytes.resize(samples * 2)
	var rng = RandomNumberGenerator.new()
	rng.seed = 1111

	for i in range(samples):
		var t = float(i) / rate
		var s1 = 0.0
		var s2 = 0.0
		# Clack 1: breech opens
		if t < 0.15:
			s1 = (sin(t * TAU * 450.0) * 8000.0 + rng.randf_range(-1.0, 1.0) * 6000.0) * exp(-t * 25.0)
		# Clack 2: shell locks
		elif t >= 0.25 and t < 0.45:
			var t2 = t - 0.25
			s2 = (sin(t2 * TAU * 620.0) * 11000.0 + rng.randf_range(-1.0, 1.0) * 8000.0) * exp(-t2 * 20.0)

		var sample = clampf(s1 + s2, -32767.0, 32767.0)
		bytes.encode_s16(i * 2, int(sample))

	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	return wav
