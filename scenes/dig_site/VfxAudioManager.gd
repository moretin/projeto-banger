class_name VfxAudioManager
extends Node2D
## Gerenciador de Partículas GPU (`GPUParticles2D`) e Áudio Procedural (`AudioStreamGenerator`).
##
## Totalmente desacoplado: escuta sinais do `Events.gd` e dispara:
##   • Pool de `GPUParticles2D` para estilhaços sedimentares, poeira de escovação e âmbar.
##   • Síntese de efeitos sonoros (escovação em areia, cinzel, acorde de compra/dino, carimbo).

const PARTICLE_POOL_SIZE: int = 8
const SAMPLE_RATE: float = 22050.0

var _particle_pool: Array[GPUParticles2D] = []
var _pool_index: int = 0

var _audio_player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _music_player: AudioStreamPlayer
var _music_playback: AudioStreamGeneratorPlayback
var _music_phase_a: float = 0.0
var _music_phase_b: float = 0.0
var _music_step_t: float = 0.0
var _music_note_idx: int = 0
var _active_tones: Array[Dictionary] = []
var _sfx_cooldown: float = 0.0
var _brush_cooldown: float = 0.0
var _brush_suppress_timer: float = 0.0
var _drum_timer: float = 0.0
var _drum_double_timer: float = -1.0
var _current_scenario: StringName = &"surface"

const MUSIC_NOTES: PackedFloat64Array = [220.0, 261.63, 293.66, 329.63, 392.0, 329.63, 293.66, 261.63]


func _ready() -> void:
	_setup_particle_pool()
	_setup_procedural_audio()

	Events.dig_hit.connect(_on_dig_hit)
	Events.orange_rock_hit.connect(_on_orange_rock_hit)
	Events.brush_stroke.connect(_on_brush_stroke)
	Events.fossil_found.connect(_on_fossil_found)
	Events.precise_strike_resolved.connect(_on_precise_strike_resolved)
	Events.layer_broken.connect(_on_layer_broken)
	Events.upgrade_purchased.connect(_on_upgrade_purchased)
	Events.dino_unlocked.connect(_on_dino_unlocked)
	Events.meteor_impact_started.connect(_on_meteor_impact_started)
	Events.scenario_changed.connect(_on_scenario_changed)


func _exit_tree() -> void:
	_playback = null
	_music_playback = null
	if _audio_player != null:
		_audio_player.stop()
		_audio_player.stream = null
	if _music_player != null:
		_music_player.stop()
		_music_player.stream = null


func _process(delta: float) -> void:
	_sfx_cooldown = maxf(_sfx_cooldown - delta, 0.0)
	_brush_cooldown = maxf(_brush_cooldown - delta, 0.0)
	_brush_suppress_timer = maxf(_brush_suppress_timer - delta, 0.0)
	_tick_seismic_drum(delta)
	_fill_audio_buffer()
	_fill_music_buffer()


func _tick_seismic_drum(delta: float) -> void:
	if _playback == null or GameState.is_impacting:
		return
	var d: float = GameState.danger_level
	if d < 0.45:
		_drum_timer = 0.0
		_drum_double_timer = -1.0
		return
	var danger_t: float = clampf((d - 0.45) / 0.55, 0.0, 1.0)
	if _drum_double_timer > 0.0:
		_drum_double_timer -= delta
		if _drum_double_timer <= 0.0:
			_drum_double_timer = -1.0
			_play_tone(52.0, 28.0, 0.14, 0.18 + danger_t * 0.08)
	_drum_timer -= delta
	if _drum_timer <= 0.0:
		_drum_timer = lerpf(1.20, 0.34, danger_t)
		_drum_double_timer = lerpf(0.18, 0.11, danger_t)
		_play_tone(68.0, 34.0, 0.16, 0.22 + danger_t * 0.12)


func _setup_particle_pool() -> void:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 70.0
	mat.initial_velocity_min = 80.0
	mat.initial_velocity_max = 195.0
	mat.gravity = Vector3(0.0, 480.0, 0.0)
	mat.scale_min = 4.0
	mat.scale_max = 7.0

	for _i: int in range(PARTICLE_POOL_SIZE):
		var p := GPUParticles2D.new()
		p.amount = 16
		p.lifetime = 0.50
		p.one_shot = true
		p.explosiveness = 0.90
		p.emitting = false
		p.process_material = mat
		add_child(p)
		_particle_pool.append(p)


func _emit_burst(world_pos: Vector2, color: Color, scale_mult: float = 1.0) -> void:
	if _particle_pool.is_empty():
		return
	var p: GPUParticles2D = _particle_pool[_pool_index]
	_pool_index = (_pool_index + 1) % _particle_pool.size()
	p.global_position = world_pos
	p.modulate = color
	p.scale = Vector2.ONE * scale_mult
	p.restart()
	p.emitting = true


func _setup_procedural_audio() -> void:
	if AudioServer.get_driver_name() == "Dummy":
		return
	_audio_player = AudioStreamPlayer.new()
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = 0.1
	_audio_player.stream = stream
	_audio_player.volume_db = -10.0
	add_child(_audio_player)
	_audio_player.play()
	_playback = _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback

	_music_player = AudioStreamPlayer.new()
	var m_stream := AudioStreamGenerator.new()
	m_stream.mix_rate = SAMPLE_RATE
	m_stream.buffer_length = 0.15
	_music_player.stream = m_stream
	_music_player.volume_db = -16.0
	add_child(_music_player)
	_music_player.play()
	_music_playback = _music_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _play_tone(freq_start: float, freq_end: float, duration: float, amp: float = 0.22, noise_mix: float = 0.0) -> void:
	if _playback == null or _active_tones.size() >= 6 or GameState.sfx_volume <= 0.001:
		return
	_active_tones.append({
		"f0": freq_start,
		"f1": freq_end,
		"dur": maxf(duration, 0.02),
		"t": 0.0,
		"phase": 0.0,
		"amp": amp,
		"noise": noise_mix,
	})


func _fill_audio_buffer() -> void:
	if _playback == null:
		return
	var frames: int = _playback.get_frames_available()
	if frames <= 0:
		return
	var vol: float = clampf(GameState.sfx_volume, 0.0, 1.0)
	if _active_tones.is_empty() or vol <= 0.001:
		for _i: int in range(frames):
			_playback.push_frame(Vector2.ZERO)
		return

	var dt: float = 1.0 / SAMPLE_RATE
	for _i: int in range(frames):
		var sample: float = 0.0
		var idx: int = _active_tones.size() - 1
		while idx >= 0:
			var tone: Dictionary = _active_tones[idx]
			var t: float = float(tone["t"])
			var dur: float = float(tone["dur"])
			if t >= dur:
				_active_tones.remove_at(idx)
			else:
				var ratio: float = t / dur
				var freq: float = lerpf(float(tone["f0"]), float(tone["f1"]), ratio)
				var phase: float = float(tone["phase"]) + freq * dt * TAU
				var env: float = (1.0 - ratio) * float(tone["amp"])
				var nm: float = float(tone.get("noise", 0.0))
				var pure: float = sin(phase) * (1.0 - nm)
				var grain: float = randf_range(-1.0, 1.0) * nm
				sample += (pure + grain) * env
				tone["t"] = t + dt
				tone["phase"] = phase
			idx -= 1
		sample = clampf(sample * vol, -0.9, 0.9)
		_playback.push_frame(Vector2(sample, sample))


func _fill_music_buffer() -> void:
	if _music_playback == null:
		return
	var frames: int = _music_playback.get_frames_available()
	if frames <= 0:
		return
	var vol: float = clampf(GameState.music_volume, 0.0, 1.0)
	if vol <= 0.001:
		for _i: int in range(frames):
			_music_playback.push_frame(Vector2.ZERO)
		return
	var dt: float = 1.0 / SAMPLE_RATE
	var note_dur: float = 1.4
	for _i: int in range(frames):
		_music_step_t += dt
		if _music_step_t >= note_dur:
			_music_step_t -= note_dur
			_music_note_idx = (_music_note_idx + 1) % MUSIC_NOTES.size()
		var freq: float = MUSIC_NOTES[_music_note_idx]
		var pad_freq: float = 110.0
		_music_phase_a = fmod(_music_phase_a + freq * dt * TAU, TAU)
		_music_phase_b = fmod(_music_phase_b + pad_freq * dt * TAU, TAU)
		var env: float = sin(clampf(_music_step_t / note_dur, 0.0, 1.0) * PI)
		var mel: float = sin(_music_phase_a) * 0.14 * env
		var pad: float = sin(_music_phase_b) * 0.09
		var out_sample: float = clampf((mel + pad) * vol, -0.6, 0.6)
		_music_playback.push_frame(Vector2(out_sample, out_sample))


func _on_brush_stroke(world_pos: Vector2) -> void:
	_brush_suppress_timer = 0.09
	_emit_burst(world_pos, Color(0.92, 0.78, 0.52, 0.85), 0.75)
	if _brush_cooldown <= 0.0:
		_brush_cooldown = 0.055
		_play_tone(780.0, 460.0, 0.05, 0.12, 0.68)


func _on_dig_hit(_damage: float, world_pos: Vector2, is_crit: bool) -> void:
	if _current_scenario != &"dig_site" or _brush_suppress_timer > 0.0:
		return
	var col: Color = Color(1.0, 0.82, 0.30) if is_crit else Color(0.88, 0.72, 0.48)
	_emit_burst(world_pos, col, 1.35 if is_crit else 0.95)
	if _sfx_cooldown <= 0.0:
		_sfx_cooldown = 0.045
		var pitch: float = randf_range(240.0, 320.0) if not is_crit else 440.0
		_play_tone(pitch, pitch * 0.45, 0.055, 0.18, 0.15)


func _on_orange_rock_hit(_damage: float, world_pos: Vector2) -> void:
	_emit_burst(world_pos, Color(0.95, 0.55, 0.18), 1.1)
	if _sfx_cooldown <= 0.0:
		_sfx_cooldown = 0.045
		var pitch: float = randf_range(250.0, 330.0)
		_play_tone(pitch, pitch * 0.48, 0.055, 0.18)


func _on_scenario_changed(current_scenario: StringName) -> void:
	_current_scenario = current_scenario
	if current_scenario == &"dig_site":
		_play_tone(260.0, 175.0, 0.08, 0.12)
	else:
		_play_tone(175.0, 260.0, 0.08, 0.12)


func _on_layer_broken(_era_idx: int, _layer_idx: int, _depth: int) -> void:
	if _current_scenario != &"dig_site":
		return
	_emit_burst(Vector2(480.0, 420.0), Color(0.95, 0.72, 0.34), 2.2)
	_play_tone(140.0, 55.0, 0.22, 0.30)


func _on_upgrade_purchased(_upg_id: StringName, _new_level: int) -> void:
	_play_tone(520.0, 780.0, 0.09, 0.20)


func _on_dino_unlocked(_dino_id: StringName) -> void:
	_emit_burst(Vector2(480.0, 300.0), Color(0.55, 0.95, 0.45), 2.5)
	_play_tone(330.0, 660.0, 0.25, 0.28)


func _on_meteor_impact_started() -> void:
	_play_tone(110.0, 32.0, 0.55, 0.38)


func _on_fossil_found(_dino_id: StringName, rarity: int) -> void:
	# Batida seca do carimbo de laboratório + acorde por raridade
	_play_tone(175.0, 72.0, 0.08, 0.28, 0.25)
	if rarity == 1:
		_play_tone(520.0, 680.0, 0.14, 0.18)
	elif rarity == 2:
		_play_tone(587.0, 880.0, 0.18, 0.22)
	elif rarity >= 3:
		_emit_burst(Vector2(240.0, 760.0), Color(1.0, 0.84, 0.30), 1.8)
		_play_tone(659.0, 1046.0, 0.26, 0.26)
		_play_tone(523.0, 784.0, 0.22, 0.20)


func _on_precise_strike_resolved(result: StringName, _bonus_damage: float) -> void:
	if result == &"perfect":
		_emit_burst(Vector2(520.0, 480.0), Color(1.0, 0.88, 0.32), 2.4)
		_play_tone(587.0, 1174.0, 0.24, 0.28)
		_play_tone(440.0, 880.0, 0.18, 0.20)
	elif result == &"good":
		_emit_burst(Vector2(520.0, 480.0), Color(0.65, 0.94, 0.45), 1.6)
		_play_tone(440.0, 660.0, 0.16, 0.22)
	else:
		_play_tone(180.0, 120.0, 0.10, 0.12)
