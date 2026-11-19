class_name HUD
extends PanelContainer
## Barra superior de recursos, estatísticas da escavação, timer do meteoro e atalhos de modais.

@onready var _bones_icon: TextureRect = %BonesIcon
@onready var _rocks_icon: TextureRect = %RocksIcon
@onready var _minerals_icon: TextureRect = %MineralsIcon
@onready var _dna_icon: TextureRect = %DnaIcon
@onready var _amber_icon: TextureRect = %AmberIcon
@onready var _meteor_icon: TextureRect = %MeteorIcon
@onready var _era_icon: TextureRect = %EraIcon
@onready var _dps_icon: TextureRect = %DpsIcon

@onready var _bones_label: Label = %BonesLabel
@onready var _bones_rate: Label = %BonesRate
@onready var _rocks_label: Label = %RocksLabel
@onready var _minerals_label: Label = %MineralsLabel
@onready var _dna_label: Label = %DnaLabel
@onready var _dna_rate: Label = %DnaRate
@onready var _amber_label: Label = %AmberLabel
@onready var _era_label: Label = %EraLabel
@onready var _dps_label: Label = %DpsLabel
@onready var _meteor_bar: ProgressBar = %MeteorBar
@onready var _meteor_label: Label = %MeteorLabel
@onready var _amber_forecast: Label = %AmberForecast
@onready var _toast_label: Label = %ToastLabel
@onready var _museum_button: Button = %MuseumButton
@onready var _prestige_button: Button = %PrestigeButton
@onready var _settings_button: Button = %SettingsButton

var _toast_timer: float = 0.0
var _last_meteor_second: int = -1
var _refresh_pending: bool = false
var _stats_dirty: bool = false
var _forecast_dirty: bool = false


func _ready() -> void:
	_bones_icon.texture = AmberTheme.get_icon(&"bones")
	_rocks_icon.texture = AmberTheme.get_icon(&"rocks")
	_minerals_icon.texture = AmberTheme.get_icon(&"minerals")
	_dna_icon.texture = AmberTheme.get_icon(&"dna")
	_amber_icon.texture = AmberTheme.get_icon(&"amber")
	_meteor_icon.texture = AmberTheme.get_icon(&"meteor")
	_era_icon.texture = AmberTheme.get_icon(&"layers")
	_dps_icon.texture = AmberTheme.get_icon(&"power")

	_museum_button.icon = AmberTheme.get_icon(&"museum")
	_prestige_button.icon = AmberTheme.get_icon(&"amber")
	_settings_button.icon = AmberTheme.get_icon(&"save")

	_museum_button.pressed.connect(func() -> void: Events.museum_modal_requested.emit())
	_prestige_button.pressed.connect(func() -> void: Events.prestige_modal_requested.emit())
	_settings_button.pressed.connect(func() -> void: Events.settings_modal_requested.emit())

	Events.resource_changed.connect(_on_resource_changed)
	Events.stats_recalculated.connect(_queue_stats_refresh)
	Events.dino_count_changed.connect(_queue_stats_refresh.unbind(2))
	Events.era_changed.connect(_on_era_changed)
	Events.layer_broken.connect(_queue_stats_refresh.unbind(3))
	Events.layer_hp_changed.connect(_queue_forecast_refresh.unbind(2))
	Events.layer_resources_extracted.connect(_on_layer_resources_extracted)
	Events.meteor_timer_changed.connect(_on_meteor_timer_changed)
	Events.dino_unlocked.connect(_on_dino_unlocked)
	Events.dino_milestone_reached.connect(_on_dino_milestone_reached)
	Events.dino_fossil_completed.connect(_on_dino_fossil_completed)
	Events.vein_cracked.connect(_on_vein_cracked)
	Events.ark_victory_achieved.connect(_on_ark_victory_achieved)
	Events.notification_requested.connect(_on_notification_requested)
	Events.game_loaded.connect(_queue_stats_refresh)
	for res_id: StringName in GameState.ALL_RESOURCES:
		_on_resource_changed(res_id, GameState.get_resource(res_id), 0.0)
	_refresh_stats()
	_refresh_amber_forecast()
	_on_meteor_timer_changed(GameState.meteor_time_left, GameState.meteor_total_time)


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_label.text = ""


func _queue_stats_refresh() -> void:
	_stats_dirty = true
	_queue_forecast_refresh()


func _queue_forecast_refresh() -> void:
	_forecast_dirty = true
	if not _refresh_pending:
		_refresh_pending = true
		_flush_readouts.call_deferred()


func _flush_readouts() -> void:
	_refresh_pending = false
	# A quebra de camada e o reset emitem sinais antes de terminar de atualizar o estado.
	if _stats_dirty:
		_stats_dirty = false
		_refresh_stats()
	if _forecast_dirty:
		_forecast_dirty = false
		_refresh_amber_forecast()


func _refresh_stats() -> void:
	_bones_rate.text = "+%s/s" % GameState.format_number(GameState.get_bones_per_second())
	_dna_rate.text = "+%s/s" % GameState.format_number(GameState.get_dna_per_second())

	var era: EraData = GameState.get_current_era()
	var era_name: String = era.display_name if era != null else "—"
	_era_label.text = "%s · Profundidade: %dm · Expedição #%d" % [era_name, GameState.depth, GameState.run_number]
	_dps_label.text = "Clique: %s · DPS: %s/s · Escudo: %d%%" % [
		GameState.format_number(GameState.get_click_damage()),
		GameState.format_number(GameState.get_total_dps()),
		roundi(GameState.get_shield_ratio() * 100.0),
	]


func _refresh_amber_forecast() -> void:
	_amber_forecast.text = "Previsão: +%s Âmbar" % GameState.format_number(GameState.calculate_amber_reward())


func _on_resource_changed(res_id: StringName, amount: float, delta: float) -> void:
	match res_id:
		GameState.RES_BONES:
			_bones_label.text = GameState.format_number(amount)
			if delta > 0.0:
				_queue_forecast_refresh()
		GameState.RES_ROCKS:
			_rocks_label.text = GameState.format_number(amount)
		GameState.RES_MINERALS:
			_minerals_label.text = GameState.format_number(amount)
		GameState.RES_DNA:
			_dna_label.text = GameState.format_number(amount)
		GameState.RES_AMBER:
			_amber_label.text = GameState.format_number(amount)


func _on_era_changed(era_idx: int) -> void:
	_queue_stats_refresh()
	var era: EraData = GameState.get_current_era()
	if era != null and era_idx > 0:
		show_toast("Nova Era Desbloqueada: %s!" % era.display_name)


func _on_meteor_timer_changed(time_left: float, total_time: float) -> void:
	_meteor_bar.max_value = maxf(total_time, 1.0)
	_meteor_bar.value = time_left
	var second: int = maxi(ceili(time_left), 0)
	if second != _last_meteor_second:
		_last_meteor_second = second
		_meteor_label.text = "Impacto em %s" % GameState.format_time(time_left)


func _on_dino_unlocked(dino_id: StringName) -> void:
	var data: DinoData = GameState.get_dino(dino_id)
	if data != null:
		show_toast("%s revivido pela primeira vez!" % data.display_name)


func _on_dino_milestone_reached(dino_id: StringName, milestone: int) -> void:
	var data: DinoData = GameState.get_dino(dino_id)
	if data != null:
		show_toast("Marco atingido: %d x %s (Produção x%s)!" % [milestone, data.display_name, GameState.format_number(data.milestone_multiplier)])


func _on_vein_cracked(bonus_bones: float, bonus_minerals: float, _dino_id: StringName) -> void:
	show_toast("Veio aberto! +%s Ossos · +%s Minérios" % [GameState.format_number(bonus_bones), GameState.format_number(bonus_minerals)])


func _on_ark_victory_achieved(run_num: int, total_amber: float) -> void:
	show_toast("Projeto Arca concluído na Run #%d! (%s Âmbar acumulado)" % [run_num, GameState.format_number(total_amber)], 6.0)


func _on_layer_resources_extracted(_era_idx: int, bones_bonus: float, minerals_bonus: float) -> void:
	if bones_bonus <= 0.0 and minerals_bonus <= 0.0:
		return
	var parts: PackedStringArray = []
	if bones_bonus > 0.0:
		parts.append("+%s 🦴" % GameState.format_number(bones_bonus))
	if minerals_bonus > 0.0:
		parts.append("+%s 💎" % GameState.format_number(minerals_bonus))
	show_toast("⛏️ Camada rompida! Extração: %s" % " · ".join(parts))


func _on_dino_fossil_completed(dino_id: StringName, current_fragments: int, required_fragments: int) -> void:
	var data: DinoData = GameState.get_dino(dino_id)
	if data != null:
		show_toast("🧩 %s completo (%d/%d)! Pronto para reviver!" % [data.get_fossil_display_name(), current_fragments, required_fragments])


func _on_notification_requested(text: String, _icon: Texture2D) -> void:
	show_toast(text)


func show_toast(text: String, duration: float = 4.0) -> void:
	_toast_label.text = _strip_system_emojis(text)
	_toast_timer = duration


static func _strip_system_emojis(raw: String) -> String:
	var out: String = ""
	for i: int in range(raw.length()):
		var cp: int = raw.unicode_at(i)
		if cp >= 0x1F000 or (cp >= 0x2600 and cp <= 0x27BF) or cp == 0xFE0F:
			continue
		out += char(cp)
	return out.strip_edges()
