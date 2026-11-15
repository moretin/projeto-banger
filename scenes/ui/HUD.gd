class_name HUD
extends PanelContainer
## Barra superior de recursos, estatísticas da escavação, timer do meteoro e atalhos de modais.

@onready var _bones_label: Label = %BonesLabel
@onready var _minerals_label: Label = %MineralsLabel
@onready var _dna_label: Label = %DnaLabel
@onready var _amber_label: Label = %AmberLabel
@onready var _era_label: Label = %EraLabel
@onready var _dps_label: Label = %DpsLabel
@onready var _meteor_bar: ProgressBar = %MeteorBar
@onready var _meteor_label: Label = %MeteorLabel
@onready var _toast_label: Label = %ToastLabel
@onready var _prestige_button: Button = %PrestigeButton
@onready var _settings_button: Button = %SettingsButton

var _toast_timer: float = 0.0


func _ready() -> void:
	_prestige_button.pressed.connect(func() -> void: Events.prestige_modal_requested.emit())
	_settings_button.pressed.connect(func() -> void: Events.settings_modal_requested.emit())

	Events.resource_changed.connect(_on_resource_changed)
	Events.stats_recalculated.connect(_refresh_all)
	Events.era_changed.connect(_on_era_changed)
	Events.layer_broken.connect(_on_layer_broken)
	Events.meteor_timer_changed.connect(_on_meteor_timer_changed)
	Events.dino_unlocked.connect(_on_dino_unlocked)
	Events.dino_milestone_reached.connect(_on_dino_milestone_reached)
	Events.notification_requested.connect(_on_notification_requested)
	Events.game_loaded.connect(_refresh_all)
	_refresh_all()


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_label.text = ""


func _refresh_all() -> void:
	var bones: float = GameState.get_resource(GameState.RES_BONES)
	var bps: float = GameState.get_bones_per_second()
	_bones_label.text = "🦴 %s  (+%s/s)" % [GameState.format_number(bones), GameState.format_number(bps)]
	_minerals_label.text = "💎 %s" % GameState.format_number(GameState.get_resource(GameState.RES_MINERALS))
	var dna: float = GameState.get_resource(GameState.RES_DNA)
	var dps_dna: float = GameState.get_dna_per_second()
	_dna_label.text = "🧬 %s  (+%s/s)" % [GameState.format_number(dna), GameState.format_number(dps_dna)]
	_amber_label.text = "🟠 %s" % GameState.format_number(GameState.get_resource(GameState.RES_AMBER))

	var era: EraData = GameState.get_current_era()
	var era_name: String = era.display_name if era != null else "—"
	_era_label.text = "⛏️ %s · Profundidade: %dm · Run #%d" % [era_name, GameState.depth, GameState.run_number]
	_dps_label.text = "⚡ Clique: %s · DPS: %s/s · 🛡️ Escudo: %d%%" % [
		GameState.format_number(GameState.get_click_damage()),
		GameState.format_number(GameState.get_total_dps()),
		roundi(GameState.get_shield_ratio() * 100.0),
	]
	_on_meteor_timer_changed(GameState.meteor_time_left, GameState.meteor_total_time)


func _on_resource_changed(_res_id: StringName, _amount: float, _delta: float) -> void:
	_refresh_all()


func _on_era_changed(era_idx: int) -> void:
	_refresh_all()
	var era: EraData = GameState.get_current_era()
	if era != null and era_idx > 0:
		show_toast("🌍 Nova Era Desbloqueada: %s!" % era.display_name)


func _on_layer_broken(_era_idx: int, _layer_idx: int, _depth: int) -> void:
	_refresh_all()


func _on_meteor_timer_changed(time_left: float, total_time: float) -> void:
	_meteor_bar.max_value = maxf(total_time, 1.0)
	_meteor_bar.value = time_left
	var preview_amber: float = GameState.calculate_amber_reward()
	_meteor_label.text = "☄️ Impacto em %s  (🟠 +%s)" % [
		GameState.format_time(time_left),
		GameState.format_number(preview_amber),
	]


func _on_dino_unlocked(dino_id: StringName) -> void:
	var data: DinoData = GameState.get_dino(dino_id)
	if data != null:
		show_toast("🦖 %s revivido pela primeira vez!" % data.display_name)


func _on_dino_milestone_reached(dino_id: StringName, milestone: int) -> void:
	var data: DinoData = GameState.get_dino(dino_id)
	if data != null:
		show_toast("🏅 Marco atingido: %d× %s (Produção ×2)!" % [milestone, data.display_name])


func _on_notification_requested(text: String, _icon: Texture2D) -> void:
	show_toast(text)


func show_toast(text: String, duration: float = 4.0) -> void:
	_toast_label.text = text
	_toast_timer = duration
