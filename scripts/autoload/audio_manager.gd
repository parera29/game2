extends Node
## Audio procedural: todos los efectos, ambientes y la música se sintetizan al arrancar,
## así el proyecto no depende de ficheros de audio externos.

const RATE := 22050

var sounds: Dictionary = {}
var music_player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer
var siren_player: AudioStreamPlayer
var _ambient_mode := ""
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1337
	_setup_buses()
	_generate_all()
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)
	ambient_player = AudioStreamPlayer.new()
	ambient_player.bus = "Ambient"
	add_child(ambient_player)
	siren_player = AudioStreamPlayer.new()
	siren_player.bus = "SFX"
	siren_player.volume_db = -14.0
	siren_player.stream = sounds["siren"]
	add_child(siren_player)
	apply_volumes()
	Events.settings_changed.connect(apply_volumes)


func _setup_buses() -> void:
	for b in ["Music", "SFX", "Ambient"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")


func apply_volumes() -> void:
	_set_bus("Master", float(Settings.get_value("master_volume", 0.8)))
	_set_bus("Music", float(Settings.get_value("music_volume", 0.5)))
	_set_bus("SFX", float(Settings.get_value("sfx_volume", 0.8)))
	_set_bus("Ambient", float(Settings.get_value("ambient_volume", 0.6)))


func _set_bus(name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(idx, linear <= 0.001)


# ------------------------------------------------------------------ Reproducción

func play(name: String, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not sounds.has(name):
		return
	var p := AudioStreamPlayer.new()
	p.stream = sounds[name]
	p.bus = "SFX"
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)


func play_3d(name: String, pos: Vector3, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	if not sounds.has(name):
		return
	var scene := get_tree().current_scene
	if scene == null or not (scene is Node3D or scene.get_node_or_null("World") != null):
		play(name, volume_db - 6.0, pitch)
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = sounds[name]
	p.bus = "SFX"
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.max_distance = 40.0
	p.unit_size = 4.0
	scene.add_child(p)
	p.global_position = pos
	p.play()
	p.finished.connect(p.queue_free)


func play_music(enabled: bool = true) -> void:
	if enabled:
		if not music_player.playing:
			music_player.stream = sounds["music"]
			music_player.play()
	else:
		music_player.stop()


func set_ambient(mode: String) -> void:
	if mode == _ambient_mode:
		return
	_ambient_mode = mode
	if mode == "":
		ambient_player.stop()
		return
	ambient_player.stream = sounds["amb_" + mode]
	ambient_player.play()


func set_siren(active: bool) -> void:
	if active and not siren_player.playing:
		siren_player.play()
	elif not active and siren_player.playing:
		siren_player.stop()


# ------------------------------------------------------------------ Síntesis

func _make_stream(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = RATE
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = samples.size()
	return s


func _env(t: float, attack: float, decay: float) -> float:
	if t < attack:
		return t / attack
	return exp(-(t - attack) / decay)


func _tone(freqs: Array, dur: float, decay: float, vol: float = 0.5, wave: String = "sine") -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		var seg := mini(int(t / dur * freqs.size()), freqs.size() - 1)
		var f: float = freqs[seg]
		var ph := TAU * f * t
		var v := sin(ph) if wave == "sine" else (fmod(t * f, 1.0) * 2.0 - 1.0) * 0.5
		out[i] = v * vol * _env(t - seg * dur / freqs.size(), 0.005, decay)
	return out


func _noise_burst(dur: float, decay: float, vol: float, lowpass: float) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		y = lerpf(y, _rng.randf_range(-1.0, 1.0), lowpass)
		out[i] = y * vol * _env(t, 0.003, decay)
	return out


func _generate_all() -> void:
	sounds["click"] = _make_stream(_tone([1400.0], 0.05, 0.015, 0.35))
	sounds["hover"] = _make_stream(_tone([900.0], 0.03, 0.01, 0.15))
	sounds["cash"] = _make_stream(_tone([1568.0, 2093.0, 2637.0], 0.28, 0.05, 0.4))
	sounds["notify"] = _make_stream(_tone([880.0, 1318.0], 0.3, 0.09, 0.35))
	sounds["quest"] = _make_stream(_tone([523.0, 659.0, 784.0, 1046.0], 0.6, 0.12, 0.35))
	sounds["error"] = _make_stream(_tone([180.0, 140.0], 0.25, 0.1, 0.35, "saw"))
	sounds["pickup"] = _make_stream(_tone([600.0, 900.0], 0.12, 0.04, 0.35))
	sounds["drop"] = _make_stream(_noise_burst(0.15, 0.04, 0.6, 0.15))
	sounds["step"] = _make_stream(_noise_burst(0.09, 0.025, 0.7, 0.25))
	sounds["punch"] = _make_stream(_noise_burst(0.2, 0.05, 1.0, 0.35))
	sounds["eat"] = _make_stream(_noise_burst(0.3, 0.08, 0.4, 0.5))
	sounds["water"] = _make_stream(_noise_burst(0.8, 0.35, 0.35, 0.6))
	sounds["package"] = _make_stream(_noise_burst(0.25, 0.06, 0.5, 0.7))
	sounds["door"] = _make_door()
	sounds["siren"] = _make_siren()
	sounds["amb_day"] = _make_ambient(false)
	sounds["amb_night"] = _make_ambient(true)
	sounds["amb_interior"] = _make_interior()
	sounds["music"] = _make_music()


func _make_door() -> AudioStreamWAV:
	var n := int(0.45 * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		var creak := sin(TAU * (220.0 + 180.0 * t) * t) * 0.15 * _env(t, 0.05, 0.15)
		y = lerpf(y, _rng.randf_range(-1.0, 1.0), 0.12)
		var thump := y * 0.6 * _env(maxf(t - 0.3, 0.0), 0.002, 0.04) * (1.0 if t > 0.3 else 0.0)
		out[i] = creak + thump
	return _make_stream(out)


func _make_siren() -> AudioStreamWAV:
	var dur := 2.0
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var t := float(i) / RATE
		var f := 650.0 + 350.0 * (0.5 - 0.5 * cos(TAU * t / dur))
		ph += TAU * f / RATE
		out[i] = (sin(ph) * 0.6 + sin(ph * 2.0) * 0.15) * 0.5
	return _make_stream(out, true)


func _make_ambient(night: bool) -> AudioStreamWAV:
	var dur := 6.0
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	var y2 := 0.0
	for i in n:
		var t := float(i) / RATE
		y = lerpf(y, _rng.randf_range(-1.0, 1.0), 0.02)
		y2 = lerpf(y2, y, 0.05)
		var v := y2 * (0.9 if not night else 0.5)
		# Fundido en los extremos para que el bucle no haga "clic"
		var edge := minf(t, dur - t)
		v *= clampf(edge * 4.0, 0.0, 1.0) * 0.5 + 0.5
		if night:
			# grillos
			var chirp := fmod(t * 2.5, 1.0)
			if chirp < 0.25:
				v += sin(TAU * 4200.0 * t) * 0.04 * sin(PI * chirp / 0.25) * (0.5 + 0.5 * sin(TAU * 30.0 * t))
		else:
			# pájaros ocasionales
			var b := fmod(t + 0.7, 2.3)
			if b < 0.18:
				v += sin(TAU * (2600.0 + 900.0 * sin(TAU * 12.0 * b)) * t) * 0.05 * sin(PI * b / 0.18)
		out[i] = v
	return _make_stream(out, true)


func _make_interior() -> AudioStreamWAV:
	var dur := 4.0
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = sin(TAU * 60.0 * t) * 0.03 + sin(TAU * 120.0 * t) * 0.015
	return _make_stream(out, true)


## Bucle "lo-fi" de 4 acordes con bajo, pad, batería sencilla y melodía.
func _make_music() -> AudioStreamWAV:
	var bpm := 84.0
	var beat := 60.0 / bpm
	var bars := 4
	var dur := beat * 4.0 * bars
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var chords := [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]  # Am F C G
	var melody := [76, 74, 72, 69, 72, 71, 67, 69, 72, 74, 76, 79, 76, 74, 72, 71]
	var hat_y := 0.0
	for i in n:
		var t := float(i) / RATE
		var bar := mini(int(t / (beat * 4.0)), bars - 1)
		var tb := fmod(t, beat)
		var chord: Array = chords[bar]
		var v := 0.0
		# Pad
		for note in chord:
			var f := 440.0 * pow(2.0, (float(note) - 69.0) / 12.0)
			v += (sin(TAU * f * t) + 0.3 * sin(TAU * f * 2.003 * t)) * 0.045
		# Bajo
		var fb := 440.0 * pow(2.0, (float(chord[0]) - 12.0 - 69.0) / 12.0)
		v += sin(TAU * fb * t) * 0.16 * _env(tb, 0.01, 0.4)
		# Bombo en 1 y 3
		var beat_idx := int(t / beat) % 4
		if beat_idx == 0 or beat_idx == 2:
			var kf := 50.0 + 90.0 * exp(-tb * 30.0)
			v += sin(TAU * kf * tb) * 0.35 * exp(-tb * 9.0)
		# Caja suave en 2 y 4
		if beat_idx == 1 or beat_idx == 3:
			hat_y = lerpf(hat_y, _rng.randf_range(-1.0, 1.0), 0.6)
			v += hat_y * 0.12 * exp(-tb * 18.0)
		# Hi-hat en corcheas
		var te := fmod(t, beat * 0.5)
		v += _rng.randf_range(-1.0, 1.0) * 0.025 * exp(-te * 60.0)
		# Melodía (corcheas cada 2 tiempos)
		var mi := int(t / (beat * 1.0)) % melody.size()
		var fm := 440.0 * pow(2.0, (float(melody[mi]) - 69.0) / 12.0)
		var tm := fmod(t, beat)
		v += sin(TAU * fm * t + 0.6 * sin(TAU * fm * 2.0 * t)) * 0.05 * _env(tm, 0.01, 0.25)
		out[i] = v * 0.8
	return _make_stream(out, true)
