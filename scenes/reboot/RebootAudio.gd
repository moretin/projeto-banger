class_name RebootAudio
extends Node
## Áudio procedural leve para o reboot via AudioStreamGenerator (22050 Hz).
## Totalmente seguro em headless (driver Dummy) e sem vazamentos de ObjectDB em _exit_tree().

const SAMPLE_RATE: float = 22050.0
const MAX_ACTIVE_TONES: int = 10

var _player: AudioStreamPlayer = null
var _playback: AudioStreamGeneratorPlayback = null
var _active_tones: Array[Dictionary] = []
var _hit_cooldown: float = 0.0
var _deposit_cooldown: float = 0.0
var _connected: bool = false


func _ready() -> void:
	_setup_audio_player()
	_connect_signals()


func _exit_tree() -> void:
	_disconnect_signals()
	_active_tones.clear()
	_playback = null
	if _player != null:
		_player.stop()
		_player.stream = null
		_player = null


func _process(delta: float) -> void:
	_hit_cooldown = maxf(_hit_cooldown - delta, 0.0)
	_deposit_cooldown = maxf(_deposit_cooldown - delta, 0.0)
	_fill_buffer()


func _setup_audio_player() -> void:
	if AudioServer.get_driver_name() == "Dummy":
		return
	_player = AudioStreamPlayer.new()
	_player.name = "ProceduralSfxPlayer"
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = SAMPLE_RATE
	stream.buffer_length = 0.12
	_player.stream = stream
	_player.volume_db = -6.0
	add_child(_player)
	_player.play()
	_playback = _player.get_stream_playback() as AudioStreamGeneratorPlayback


func _connect_signals() -> void:
	if _connected:
		return
	_connected = true
	GnorpGame.rock_hit.connect(_on_rock_hit)
	GnorpGame.pile_compressed.connect(_on_pile_compressed)
	GnorpGame.deposit_collected.connect(_on_deposit_collected)
	GnorpGame.structure_built.connect(_on_structure_built)
	GnorpGame.dino_recruited.connect(_on_dino_recruited)
	GnorpGame.upgrade_purchased.connect(_on_upgrade_purchased)
	GnorpGame.talent_purchased.connect(_on_talent_purchased)
	GnorpGame.roar_triggered.connect(_on_roar_triggered)
	GnorpGame.cannon_fired.connect(_on_cannon_fired)
	GnorpGame.run_ended.connect(_on_run_ended)


func _disconnect_signals() -> void:
	if not _connected:
		return
	_connected = false
	if GnorpGame.rock_hit.is_connected(_on_rock_hit):
		GnorpGame.rock_hit.disconnect(_on_rock_hit)
	if GnorpGame.pile_compressed.is_connected(_on_pile_compressed):
		GnorpGame.pile_compressed.disconnect(_on_pile_compressed)
	if GnorpGame.deposit_collected.is_connected(_on_deposit_collected):
		GnorpGame.deposit_collected.disconnect(_on_deposit_collected)
	if GnorpGame.structure_built.is_connected(_on_structure_built):
		GnorpGame.structure_built.disconnect(_on_structure_built)
	if GnorpGame.dino_recruited.is_connected(_on_dino_recruited):
		GnorpGame.dino_recruited.disconnect(_on_dino_recruited)
	if GnorpGame.upgrade_purchased.is_connected(_on_upgrade_purchased):
		GnorpGame.upgrade_purchased.disconnect(_on_upgrade_purchased)
	if GnorpGame.talent_purchased.is_connected(_on_talent_purchased):
		GnorpGame.talent_purchased.disconnect(_on_talent_purchased)
	if GnorpGame.roar_triggered.is_connected(_on_roar_triggered):
		GnorpGame.roar_triggered.disconnect(_on_roar_triggered)
	if GnorpGame.cannon_fired.is_connected(_on_cannon_fired):
		GnorpGame.cannon_fired.disconnect(_on_cannon_fired)
	if GnorpGame.run_ended.is_connected(_on_run_ended):
		GnorpGame.run_ended.disconnect(_on_run_ended)


func _play_tone(freq_start: float, freq_end: float, duration: float, amp: float = 0.22, noise_mix: float = 0.0, wave: String = "sine") -> void:
	if _playback == null:
		return
	if GnorpGame.audio_muted or GnorpGame.master_volume <= 0.001:
		return
	if _active_tones.size() >= MAX_ACTIVE_TONES:
		return
	_active_tones.append({
		"f0": freq_start,
		"f1": freq_end,
		"dur": maxf(duration, 0.02),
		"t": 0.0,
		"phase": 0.0,
		"amp": amp,
		"noise": clampf(noise_mix, 0.0, 1.0),
		"wave": wave,
	})


func _fill_buffer() -> void:
	if _playback == null:
		return
	var frames: int = _playback.get_frames_available()
	if frames <= 0:
		return
	var vol: float = 0.0 if GnorpGame.audio_muted else clampf(GnorpGame.master_volume, 0.0, 1.0)
	if _active_tones.is_empty() or vol <= 0.001:
		for _i: int in range(frames):
			_playback.push_frame(Vector2.ZERO)
		return

	var dt: float = 1.0 / SAMPLE_RATE
	for _i: int in range(frames):
		var mix: float = 0.0
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
				var nm: float = float(tone["noise"])
				var wave: String = String(tone["wave"])
				var osc: float = 0.0
				if wave == "saw":
					var p_norm: float = fposmod(phase / TAU, 1.0)
					osc = p_norm * 2.0 - 1.0
				elif wave == "square":
					osc = 1.0 if sin(phase) >= 0.0 else -1.0
				else:
					osc = sin(phase)
				var grain: float = randf_range(-1.0, 1.0)
				mix += (osc * (1.0 - nm) + grain * nm) * env
				tone["t"] = t + dt
				tone["phase"] = phase
			idx -= 1
		mix = clampf(mix * vol, -0.88, 0.88)
		_playback.push_frame(Vector2(mix, mix))


func _on_rock_hit(_pos_x: float, _damage: float, _shards: float, is_crit: bool, source: String) -> void:
	if _hit_cooldown > 0.0 and source != "click":
		return
	_hit_cooldown = 0.042
	if is_crit:
		_play_tone(540.0, 290.0, 0.09, 0.24, 0.18)
		_play_tone(880.0, 1240.0, 0.10, 0.14, 0.0)
	elif source == "click":
		var p: float = randf_range(290.0, 355.0)
		_play_tone(p, p * 0.44, 0.065, 0.22, 0.22)
	elif source == "ankylo" or source == "trex":
		_play_tone(145.0, 62.0, 0.12, 0.26, 0.30)
	else:
		var dp: float = randf_range(230.0, 295.0)
		_play_tone(dp, dp * 0.50, 0.05, 0.13, 0.20)


func _on_pile_compressed(_new_tier: int, _multiplier: float) -> void:
	_play_tone(440.0, 660.0, 0.14, 0.22, 0.0)
	_play_tone(660.0, 990.0, 0.18, 0.20, 0.0)
	_play_tone(880.0, 1320.0, 0.22, 0.16, 0.0)


func _on_deposit_collected(_amount: float, source: String) -> void:
	if _deposit_cooldown > 0.0 and source != "manual" and source != "scoop":
		return
	_deposit_cooldown = 0.085
	_play_tone(510.0, 740.0, 0.075, 0.14, 0.05)


func _on_structure_built(_struct_id: String, _world_x: float) -> void:
	_play_tone(160.0, 72.0, 0.15, 0.26, 0.25)
	_play_tone(392.0, 587.33, 0.22, 0.20, 0.0)
	_play_tone(587.33, 783.99, 0.26, 0.18, 0.0)


func _on_dino_recruited(_species_id: String, _new_count: int, _struct_x: float) -> void:
	_play_tone(420.0, 680.0, 0.11, 0.18, 0.05)


func _on_upgrade_purchased(_upgrade_id: String) -> void:
	_play_tone(560.0, 880.0, 0.14, 0.20, 0.0)


func _on_talent_purchased(_talent_id: String, _new_rank: int) -> void:
	_play_tone(523.25, 783.99, 0.18, 0.22, 0.0)
	_play_tone(783.99, 1046.5, 0.24, 0.18, 0.0)


func _on_roar_triggered(_duration: float, _multiplier: float) -> void:
	_play_tone(142.0, 52.0, 0.45, 0.34, 0.35, "saw")
	_play_tone(96.0, 40.0, 0.50, 0.26, 0.22, "square")


func _on_cannon_fired(_damage: float, _new_meteor_hp: float, source: String) -> void:
	if source == "ptero":
		_play_tone(720.0, 360.0, 0.11, 0.14, 0.12)
	else:
		_play_tone(480.0, 92.0, 0.24, 0.30, 0.28, "saw")
		_play_tone(180.0, 54.0, 0.22, 0.24, 0.35)


func _on_run_ended(outcome: String, _amber_earned: float) -> void:
	if outcome == "victory":
		_play_tone(523.25, 523.25, 0.24, 0.24, 0.0)
		_play_tone(659.25, 659.25, 0.28, 0.22, 0.0)
		_play_tone(783.99, 1046.5, 0.42, 0.26, 0.0)
	else:
		_play_tone(108.0, 26.0, 0.65, 0.40, 0.48, "saw")
		_play_tone(64.0, 24.0, 0.55, 0.32, 0.35)
