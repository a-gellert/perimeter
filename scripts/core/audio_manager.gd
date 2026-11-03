# Autoload singleton: AudioManager (registered in Project Settings -> Globals -> Autoload)
extends Node
## Global Audio Manager & Procedural Sound Engine for Perimeter.
## Provides diegetic sound effects (axe chops, gunshots, trap snaps, mutant growls, alarm bell)
## and manages spatial 3D audio playback and ambient soundscapes.

signal sound_played(sound_name: String, pos: Vector3)

static var instance: Node = null

var _sound_cache: Dictionary = {}
var _active_ambience_player: AudioStreamPlayer = null
var _active_music_player: AudioStreamPlayer = null

func _ready() -> void:
	instance = self
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_procedural_sound_library()

# ==============================================================================
# ПУБЛИЧНЫЙ API ВОСПРОИЗВЕДЕНИЯ ЗВУКОВ
# ==============================================================================

func play_sfx_3d(sound_name: String, world_pos: Vector3, volume_db: float = 0.0, max_dist: float = 35.0) -> void:
	var stream := get_sound_stream(sound_name)
	if not stream:
		return

	var p3d := AudioStreamPlayer3D.new()
	p3d.stream = stream
	p3d.bus = "SFX"
	p3d.volume_db = volume_db
	p3d.max_distance = max_dist
	p3d.unit_size = 5.0

	var root_scene := get_tree().current_scene
	if root_scene:
		root_scene.add_child(p3d)
	else:
		add_child(p3d)

	p3d.global_position = world_pos
	p3d.play()
	p3d.finished.connect(p3d.queue_free)
	sound_played.emit(sound_name, world_pos)

func play_sfx_2d(sound_name: String, volume_db: float = 0.0) -> void:
	var stream := get_sound_stream(sound_name)
	if not stream:
		return

	var p2d := AudioStreamPlayer.new()
	p2d.stream = stream
	p2d.bus = "UI"
	p2d.volume_db = volume_db
	add_child(p2d)
	p2d.play()
	p2d.finished.connect(p2d.queue_free)

func get_sound_stream(sound_name: String) -> AudioStream:
	if _sound_cache.has(sound_name):
		return _sound_cache[sound_name]
	return null

# ==============================================================================
# ПРОЦЕДУРНЫЙ СИНТЕЗАТОР ЗВУКОВ ДЛЯ ТАЙГИ И БОЯ
# ==============================================================================

func _init_procedural_sound_library() -> void:
	_sound_cache["chop"] = _synth_axe_chop()
	_sound_cache["gunshot"] = _synth_gunshot()
	_sound_cache["trap_snap"] = _synth_trap_snap()
	_sound_cache["alarm_bell"] = _synth_alarm_bell()
	_sound_cache["mutant_growl"] = _synth_mutant_growl()
	_sound_cache["footstep"] = _synth_footstep()
	print("[AudioManager] Procedural sound library initialized (6 audio effects synthesized).")

func _create_wav(samples: PackedByteArray, sample_rate: int = 22050) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = samples
	return wav

func _synth_axe_chop() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.28
	var total_samples := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)

	for i in range(total_samples):
		var t := float(i) / float(rate)
		var env := exp(-t * 22.0)
		var tone := sin(t * TAU * 110.0) * 0.6 + sin(t * TAU * 220.0) * 0.4
		var click := (randf() * 2.0 - 1.0) * exp(-t * 80.0) * 0.5
		var sample := clampf((tone * 0.6 + click) * env, -1.0, 1.0)
		var val16 := int(sample * 32000.0)
		bytes.encode_s16(i * 2, val16)

	return _create_wav(bytes, rate)

func _synth_gunshot() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.65
	var total_samples := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)

	for i in range(total_samples):
		var t := float(i) / float(rate)
		var noise := (randf() * 2.0 - 1.0)
		var boom := sin(t * TAU * (80.0 - t * 60.0))
		var env := exp(-t * 8.0)
		var crack := exp(-t * 45.0) * 1.5
		var sample := clampf((noise * crack + boom * 0.7) * env, -1.0, 1.0)
		var val16 := int(sample * 32500.0)
		bytes.encode_s16(i * 2, val16)

	return _create_wav(bytes, rate)

func _synth_trap_snap() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.35
	var total_samples := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)

	for i in range(total_samples):
		var t := float(i) / float(rate)
		var metallic_ping := sin(t * TAU * 780.0) * exp(-t * 14.0) + sin(t * TAU * 1420.0) * exp(-t * 28.0)
		var slam := (randf() * 2.0 - 1.0) * exp(-t * 60.0)
		var sample := clampf(metallic_ping * 0.65 + slam * 0.6, -1.0, 1.0)
		var val16 := int(sample * 32000.0)
		bytes.encode_s16(i * 2, val16)

	return _create_wav(bytes, rate)

func _synth_alarm_bell() -> AudioStreamWAV:
	var rate := 22050
	var dur := 1.8
	var total_samples := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)

	for i in range(total_samples):
		var t := float(i) / float(rate)
		var strike := exp(-t * 2.8)
		var chime := sin(t * TAU * 440.0) * 0.5 + sin(t * TAU * 880.0) * 0.3 + sin(t * TAU * 1320.0) * 0.2
		var sample := clampf(chime * strike, -1.0, 1.0)
		var val16 := int(sample * 31500.0)
		bytes.encode_s16(i * 2, val16)

	return _create_wav(bytes, rate)

func _synth_mutant_growl() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.95
	var total_samples := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)

	for i in range(total_samples):
		var t := float(i) / float(rate)
		var env := sin(t / dur * PI)
		var base_pitch := 75.0 + sin(t * 18.0) * 25.0
		var sub := sin(t * TAU * base_pitch)
		var rasp := (randf() * 2.0 - 1.0) * 0.35
		var sample := clampf((sub * 0.7 + rasp) * env, -1.0, 1.0)
		var val16 := int(sample * 31000.0)
		bytes.encode_s16(i * 2, val16)

	return _create_wav(bytes, rate)

func _synth_footstep() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.14
	var total_samples := int(rate * dur)
	var bytes := PackedByteArray()
	bytes.resize(total_samples * 2)

	for i in range(total_samples):
		var t := float(i) / float(rate)
		var env := exp(-t * 32.0)
		var rustle := (randf() * 2.0 - 1.0) * env * 0.4
		var val16 := int(clampf(rustle, -1.0, 1.0) * 28000.0)
		bytes.encode_s16(i * 2, val16)

	return _create_wav(bytes, rate)
