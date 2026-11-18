class_name VfxAudioManager
extends Node2D
## Gerenciador de Partículas GPU (`GPUParticles2D`) e Áudio Procedural (`AudioStreamGenerator`).
##
## Totalmente desacoplado: escuta sinais do `Events.gd` e dispara:
##   • Pool de `GPUParticles2D` para estilhaços de rocha, ossos e quebra de camada.
##   • Síntese de efeitos sonoros (toc de escavação, acorde de upgrade/dino, estrondo de camada).

const PARTICLE_POOL_SIZE: int = 8
const SAMPLE_RATE: float = 22050.0

var _particle_pool: Array[GPUParticles2D] = []
var _pool_index: int = 0

var _audio_player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _active_tones: Array[Dictionary] = []
var _sfx_cooldown: float = 0.0
var _muted: bool = false


func _ready() -> void:
	_muted = UITheme.audio_muted
	_setup_particle_pool()
	_setup_procedural_audio()

	Events.dig_hit.connect(_on_dig_hit)
	Events.layer_broken.connect(_on_layer_broken)
	Events.upgrade_purchased.connect(_on_upgrade_purchased)
	Events.dino_unlocked.connect(_on_dino_unlocked)
	Events.meteor_impact_started.connect(_on_meteor_impact_started)
	Events.audio_mute_toggled.connect(func(m: bool) -> void: _muted = m)


func _exit_tree() -> void:
	_playback = null
	if _audio_player != null:
		_audio_player.stop()
		_audio_player.stream = null


func _process(delta: float) -> void:
	_sfx_cooldown = maxf(_sfx_cooldown - delta, 0.0)
	_fill_audio_buffer()


func _setup_particle_pool() -> void:
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, -1.0, 0.0)
	mat.spread = 70.0
	mat.initial_velocity_min = 90.0
	mat.initial_velocity_max = 220.0
	mat.gravity = Vector3(0.0, 520.0, 0.0)
	mat.scale_min = 4.0
	mat.scale_max = 8.0

	for _i: int in range(PARTICLE_POOL_SIZE):
		var p := GPUParticles2D.new()
		p.amount = 18
		p.lifetime = 0.55
		p.one_shot = true
		p.explosiveness = 0.92
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


func _play_tone(freq_start: float, freq_end: float, duration: float, amp: float = 0.22) -> void:
	if _muted or _active_tones.size() >= 6:
		return
	_active_tones.append({
		"f0": freq_start,
		"f1": freq_end,
		"dur": maxf(duration, 0.02),
		"t": 0.0,
		"phase": 0.0,
		"amp": amp,
	})


func _fill_audio_buffer() -> void:
	if _playback == null:
		return
	var frames: int = _playback.get_frames_available()
	if frames <= 0:
		return
	if _active_tones.is_empty():
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
				sample += sin(phase) * env
				tone["t"] = t + dt
				tone["phase"] = phase
			idx -= 1
		sample = clampf(sample, -0.9, 0.9)
		_playback.push_frame(Vector2(sample, sample))


func _default_rock_pos() -> Vector2:
	var vp: Rect2 = get_viewport_rect()
	if vp.size.x <= 10.0:
		return Vector2(1200.0, 680.0)
	return Vector2(vp.size.x * 0.76, vp.size.y - 160.0)


func _on_dig_hit(_damage: float, world_pos: Vector2, is_crit: bool) -> void:
	var col: Color = Color(1.0, 0.85, 0.35) if is_crit else Color(0.88, 0.82, 0.72)
	var pos: Vector2 = world_pos if world_pos != Vector2.ZERO else _default_rock_pos()
	_emit_burst(pos, col, 1.35 if is_crit else 1.0)
	if _sfx_cooldown <= 0.0:
		_sfx_cooldown = 0.045
		var pitch: float = randf_range(240.0, 320.0) if not is_crit else 440.0
		_play_tone(pitch, pitch * 0.45, 0.055, 0.18)


func _on_layer_broken(_era_idx: int, _layer_idx: int, _depth: int) -> void:
	_emit_burst(_default_rock_pos(), Color(0.95, 0.72, 0.38), 2.2)
	_play_tone(140.0, 55.0, 0.22, 0.30)


func _on_upgrade_purchased(_upg_id: StringName, _new_level: int) -> void:
	_play_tone(520.0, 780.0, 0.09, 0.20)


func _on_dino_unlocked(_dino_id: StringName) -> void:
	var vp: Rect2 = get_viewport_rect()
	var hatchery_pos := Vector2(vp.size.x * 0.28, vp.size.y - 110.0) if vp.size.x > 10.0 else Vector2(400.0, 600.0)
	_emit_burst(hatchery_pos, Color(0.55, 0.95, 0.45), 2.5)
	_play_tone(330.0, 660.0, 0.25, 0.28)


func _on_meteor_impact_started() -> void:
	_play_tone(110.0, 32.0, 0.55, 0.38)
