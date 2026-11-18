class_name HUD
extends Control
## HUD minimalista estilo Gnorp Apologue.
## • Topo central: recursos em texto limpo + botão [ARCA?], Era e timer do Meteoro.
## • Topo direito: controles compactos (Áudio, Salvar, Configurações, Tela Inicial).
## • Esquerda: caixa de telemetria (Dano / Coleta) com barras proporcionais.

signal menu_requested

@onready var _bones_label: Label = %BonesLabel
@onready var _minerals_label: Label = %MineralsLabel
@onready var _dna_label: Label = %DnaLabel
@onready var _amber_label: Label = %AmberLabel
@onready var _era_label: Label = %EraLabel
@onready var _meteor_bar: ProgressBar = %MeteorBar
@onready var _meteor_label: Label = %MeteorLabel
@onready var _prestige_button: Button = %PrestigeButton

@onready var _mute_button: Button = %MuteButton
@onready var _save_quick_button: Button = %SaveQuickButton
@onready var _settings_button: Button = %SettingsButton
@onready var _menu_button: Button = %MenuButton

@onready var _telemetry_panel: PanelContainer = %TelemetryPanel
@onready var _dmg_title: Label = %DmgTitle
@onready var _total_dps_label: Label = %TotalDpsLabel
@onready var _dinos_dps_bar: ProgressBar = %DinosDpsBar
@onready var _machines_dps_bar: ProgressBar = %MachinesDpsBar
@onready var _click_info_label: Label = %ClickInfoLabel
@onready var _col_title: Label = %ColTitle
@onready var _total_bps_label: Label = %TotalBpsLabel
@onready var _bones_rate_bar: ProgressBar = %BonesRateBar
@onready var _dna_shield_label: Label = %DnaShieldLabel

@onready var _toast_badge: PanelContainer = %ToastBadge
@onready var _toast_label: Label = %ToastLabel

var _toast_timer: float = 0.0


func _ready() -> void:
	_apply_styles()

	_prestige_button.pressed.connect(func() -> void: Events.prestige_modal_requested.emit())
	_settings_button.pressed.connect(func() -> void: Events.settings_modal_requested.emit())
	_menu_button.pressed.connect(func() -> void: menu_requested.emit())
	_save_quick_button.pressed.connect(func() -> void:
		if SaveManager.save_game():
			show_toast("jogo salvo!", 2.5)
	)
	_mute_button.pressed.connect(_on_mute_pressed)

	Events.resource_changed.connect(_on_resource_changed)
	Events.stats_recalculated.connect(_refresh_all)
	Events.era_changed.connect(_on_era_changed)
	Events.layer_broken.connect(_on_layer_broken)
	Events.meteor_timer_changed.connect(_on_meteor_timer_changed)
	Events.dino_unlocked.connect(_on_dino_unlocked)
	Events.dino_milestone_reached.connect(_on_dino_milestone_reached)
	Events.vein_cracked.connect(_on_vein_cracked)
	Events.ark_victory_achieved.connect(_on_ark_victory)
	Events.notification_requested.connect(_on_notification_requested)
	Events.game_loaded.connect(_refresh_all)
	_refresh_all()


func _apply_styles() -> void:
	UITheme.style_gnorp_label(_bones_label, 20, UITheme.G_FG)
	UITheme.style_gnorp_label(_minerals_label, 18, Color("#5FE3E8"))
	UITheme.style_gnorp_label(_dna_label, 18, UITheme.G_GOOD)
	UITheme.style_gnorp_label(_amber_label, 18, UITheme.G_AMBER)
	UITheme.style_gnorp_label(_era_label, 14, UITheme.G_DIM)
	UITheme.style_gnorp_label(_meteor_label, 14, UITheme.G_WARN)
	UITheme.style_gnorp_bar(_meteor_bar, UITheme.G_WARN)

	UITheme.style_gnorp_button(_prestige_button, 13, UITheme.G_FG)
	UITheme.style_gnorp_button(_mute_button, 14)
	UITheme.style_gnorp_button(_save_quick_button, 14)
	UITheme.style_gnorp_button(_settings_button, 14)
	UITheme.style_gnorp_button(_menu_button, 14)

	_telemetry_panel.add_theme_stylebox_override("panel", UITheme.make_gnorp_box(UITheme.G_BG, UITheme.G_FG, 2, 10, 8))
	UITheme.style_gnorp_label(_dmg_title, 15, UITheme.G_FG)
	UITheme.style_gnorp_label(_total_dps_label, 15, UITheme.G_FG)
	UITheme.style_gnorp_label(_click_info_label, 13, UITheme.G_DIM)
	UITheme.style_gnorp_label(_col_title, 15, UITheme.G_FG)
	UITheme.style_gnorp_label(_total_bps_label, 15, UITheme.G_FG)
	UITheme.style_gnorp_label(_dna_shield_label, 13, UITheme.G_DIM)
	UITheme.style_gnorp_bar(_dinos_dps_bar, UITheme.G_GOOD)
	UITheme.style_gnorp_bar(_machines_dps_bar, Color("#5FE3E8"))
	UITheme.style_gnorp_bar(_bones_rate_bar, UITheme.G_FG)

	_toast_badge.add_theme_stylebox_override("panel", UITheme.make_gnorp_box(UITheme.G_BG, UITheme.G_AMBER, 2, 12, 6))
	UITheme.style_gnorp_label(_toast_label, 15, UITheme.G_FG)


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_label.text = ""
			_toast_badge.visible = false


func _on_mute_pressed() -> void:
	UITheme.audio_muted = not UITheme.audio_muted
	_mute_button.text = "✕♪" if UITheme.audio_muted else "♪"
	Events.audio_mute_toggled.emit(UITheme.audio_muted)


func _refresh_all() -> void:
	_bones_label.text = "%s ossos" % GameState.format_number(GameState.get_resource(GameState.RES_BONES))
	_minerals_label.text = "%s min" % GameState.format_number(GameState.get_resource(GameState.RES_MINERALS))
	_dna_label.text = "%s dna" % GameState.format_number(GameState.get_resource(GameState.RES_DNA))
	_amber_label.text = "%s âmbar" % GameState.format_number(GameState.get_resource(GameState.RES_AMBER))

	var era: EraData = GameState.get_current_era()
	var era_name: String = era.display_name.to_lower() if era != null else "holoceno"
	_era_label.text = "run #%d · %s" % [GameState.run_number, era_name]

	var dino_dps: float = GameState.get_total_dino_dps()
	var auto_dps: float = GameState.get_auto_dps()
	var total_dps: float = dino_dps + auto_dps
	_total_dps_label.text = "Σ %s/s" % GameState.format_number(total_dps)
	_dinos_dps_bar.value = (dino_dps / total_dps) if total_dps > 0.0 else 0.0
	_machines_dps_bar.value = (auto_dps / total_dps) if total_dps > 0.0 else 0.0

	var crit_pct: int = roundi(clampf(GameState.get_stat(GameState.STAT_CLICK_CRIT_CHANCE, 0.05), 0.0, 0.95) * 100.0)
	_click_info_label.text = "clique: %s · crit: %d%%" % [
		GameState.format_number(GameState.get_click_damage()),
		crit_pct,
	]

	var bps: float = GameState.get_bones_per_second()
	_total_bps_label.text = "Σ %s/s" % GameState.format_number(bps)
	_bones_rate_bar.value = clampf(log(maxf(bps, 1.0)) / log(1e6), 0.0, 1.0) if bps > 0.0 else 0.0
	_dna_shield_label.text = "dna: +%s/s · escudo: %d%%" % [
		GameState.format_number(GameState.get_dna_per_second()),
		roundi(GameState.get_shield_ratio() * 100.0),
	]

	var ark_ready: bool = GameState.can_activate_ark_victory()
	if GameState.ark_completed:
		_prestige_button.text = "ARCA ★"
		UITheme.style_gnorp_button(_prestige_button, 13, UITheme.G_GOOD)
	elif ark_ready:
		_prestige_button.text = "ARCA!"
		UITheme.style_gnorp_button(_prestige_button, 13, UITheme.G_GOOD)
	else:
		_prestige_button.text = "ARCA?"
		UITheme.style_gnorp_button(_prestige_button, 13, UITheme.G_AMBER if GameState.calculate_amber_reward() > 0.0 else UITheme.G_FG)

	_on_meteor_timer_changed(GameState.meteor_time_left, GameState.meteor_total_time)


func _on_resource_changed(_res_id: StringName, _amount: float, _delta: float) -> void:
	_refresh_all()


func _on_era_changed(era_idx: int) -> void:
	_refresh_all()
	var era: EraData = GameState.get_current_era()
	if era != null and era_idx > 0:
		show_toast("nova era desbloqueada: %s!" % era.display_name.to_lower())


func _on_layer_broken(_era_idx: int, _layer_idx: int, _depth: int) -> void:
	_refresh_all()


func _on_meteor_timer_changed(time_left: float, total_time: float) -> void:
	_meteor_bar.max_value = maxf(total_time, 1.0)
	_meteor_bar.value = time_left
	var preview_amber: float = GameState.calculate_amber_reward()
	_meteor_label.text = "%s (+%s)" % [
		GameState.format_time(time_left),
		GameState.format_number(preview_amber),
	]


func _on_dino_unlocked(dino_id: StringName) -> void:
	var data: DinoData = GameState.get_dino(dino_id)
	if data != null:
		show_toast("%s revivido pela primeira vez!" % data.display_name.to_lower())


func _on_dino_milestone_reached(dino_id: StringName, milestone: int) -> void:
	var data: DinoData = GameState.get_dino(dino_id)
	if data != null:
		show_toast("marco: %dx %s (produção x2)!" % [milestone, data.display_name.to_lower()])


func _on_vein_cracked(bonus_bones: float, bonus_minerals: float, dino_id: StringName) -> void:
	var msg: String = "veio quebrado: +%s ossos · +%s min" % [
		GameState.format_number(bonus_bones),
		GameState.format_number(bonus_minerals),
	]
	if dino_id != &"":
		var d: DinoData = GameState.get_dino(dino_id)
		if d != null:
			msg += " · +1 frag %s!" % d.display_name.to_lower()
	show_toast(msg)


func _on_ark_victory(_run_num: int, _total_amber: float) -> void:
	show_toast("✦ projeto arca ativado! meteoro desviado (+25 âmbar)!", 6.0)
	_refresh_all()


func _on_notification_requested(text: String, _icon: Texture2D) -> void:
	show_toast(text)


func show_toast(text: String, duration: float = 4.0) -> void:
	_toast_label.text = text
	_toast_badge.visible = not text.is_empty()
	_toast_timer = duration
