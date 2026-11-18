class_name MeteorOverlay
extends Control
## Controlador visual do meteoro, cinemática de impacto e modal da Árvore de Âmbar (Prestígio).
##
## • Desenha o meteoro incandescente crescendo no céu conforme `GameState.danger_level`.
## • Ao receber `Events.meteor_impact_started`, executa o clarão de impacto,
##   chama `GameState.perform_prestige()` e abre o modal de Âmbar.
## • Ao receber `Events.prestige_modal_requested`, abre o modal de Âmbar / Projeto Arca.

const UPGRADE_CARD_SCENE: PackedScene = preload("res://scenes/ui/UpgradeCard.tscn")

@onready var _sky_canvas: Control = %MeteorSkyCanvas
@onready var _impact_flash: ColorRect = %ImpactFlash
@onready var _modal_backdrop: ColorRect = %ModalBackdrop
@onready var _amber_balance_label: Label = %AmberBalanceLabel
@onready var _run_summary_label: Label = %RunSummaryLabel
@onready var _early_impact_button: Button = %EarlyImpactButton
@onready var _close_button: Button = %CloseButton
@onready var _amber_upgrades_list: VBoxContainer = %AmberUpgradesList

var _ark_status_label: Label
var _ark_button: Button


func _ready() -> void:
	_modal_backdrop.visible = false
	_sky_canvas.visible = false
	_impact_flash.color = Color(1.0, 0.95, 0.85, 0.0)
	_setup_ark_section()
	_apply_gnorp_styles()

	_early_impact_button.pressed.connect(_on_early_impact_pressed)
	_close_button.pressed.connect(func() -> void: _modal_backdrop.visible = false)

	Events.danger_level_changed.connect(_on_danger_level_changed)
	Events.meteor_impact_started.connect(_on_meteor_impact_started)
	Events.prestige_modal_requested.connect(open_prestige_modal)
	Events.resource_changed.connect(_on_resource_changed)
	Events.upgrade_purchased.connect(_on_upgrade_purchased)
	Events.ark_victory_achieved.connect(func(_r: int, _a: float) -> void: _refresh_modal())
	Events.game_loaded.connect(_refresh_modal)

	_populate_amber_upgrades()
	_refresh_modal()


func _setup_ark_section() -> void:
	var vbox: Node = _early_impact_button.get_parent()
	if vbox == null:
		return
	var idx: int = _early_impact_button.get_index()
	_ark_status_label = Label.new()
	_ark_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_ark_status_label)
	vbox.move_child(_ark_status_label, idx + 1)

	_ark_button = Button.new()
	_ark_button.custom_minimum_size = Vector2(0, 40)
	_ark_button.focus_mode = Control.FOCUS_NONE
	_ark_button.pressed.connect(_on_ark_victory_pressed)
	vbox.add_child(_ark_button)
	vbox.move_child(_ark_button, idx + 2)


func _apply_gnorp_styles() -> void:
	UITheme.style_gnorp_label(_amber_balance_label, 17, UITheme.G_AMBER)
	UITheme.style_gnorp_label(_run_summary_label, 14, UITheme.G_DIM)
	UITheme.style_gnorp_button(_early_impact_button, 15, UITheme.G_WARN)
	UITheme.style_gnorp_button(_close_button, 14)
	if _ark_status_label != null:
		UITheme.style_gnorp_label(_ark_status_label, 14, UITheme.G_FG)
	if _ark_button != null:
		UITheme.style_gnorp_button(_ark_button, 15, UITheme.G_GOOD)


func open_prestige_modal() -> void:
	_refresh_modal()
	_modal_backdrop.visible = true


func _populate_amber_upgrades() -> void:
	for child: Node in _amber_upgrades_list.get_children():
		child.queue_free()
	for data: UpgradeData in GameState.get_upgrades_by_category(UpgradeData.Category.AMBER):
		var card: UpgradeCard = UPGRADE_CARD_SCENE.instantiate() as UpgradeCard
		_amber_upgrades_list.add_child(card)
		card.setup(data)


func _refresh_modal() -> void:
	var amber: float = GameState.get_resource(GameState.RES_AMBER)
	var reward: float = GameState.calculate_amber_reward()
	var shield_pct: int = roundi(GameState.get_shield_ratio() * 100.0)
	_amber_balance_label.text = "🟠 Âmbar Disponível: %s   (Total ganho: %s)" % [
		GameState.format_number(amber),
		GameState.format_number(GameState.total_amber_earned),
	]
	_run_summary_label.text = "Profundidade atual: %dm (Recorde: %dm)  ·  Escudo: %d%%  ·  Recompensa no impacto: +%s 🟠" % [
		GameState.depth,
		GameState.max_depth_ever,
		shield_pct,
		GameState.format_number(reward),
	]
	_early_impact_button.text = "☄️ Antecipar Impacto do Meteoro (+%s 🟠)" % GameState.format_number(reward)
	_early_impact_button.disabled = GameState.is_impacting

	if _ark_status_label != null and _ark_button != null:
		var prog: Dictionary = GameState.get_ark_progress()
		var ark_lvl: int = int(prog["ark_level"])
		var ark_req: int = int(prog["ark_required"])
		var sh_pct: int = roundi(float(prog["shield_ratio"]) * 100.0)
		var sh_req: int = roundi(float(prog["shield_required"]) * 100.0)
		var era_ok: bool = int(prog["era_index"]) >= int(prog["era_required"])
		var era_txt: String = "OK" if era_ok else "chegue ao Triássico"
		_ark_status_label.text = "Projeto Arca (Final): Nv %d/%d · Escudo %d%%/%d%% · Era: %s" % [
			ark_lvl, ark_req, sh_pct, sh_req, era_txt
		]
		var can_win: bool = bool(prog["ready"])
		_ark_button.disabled = not can_win
		if bool(prog["completed"]):
			_ark_button.text = "✦ ARCA ATIVADA (Modo Infinito — Reativar Defesa)"
		elif can_win:
			_ark_button.text = "✦ ATIVAR PROJETO ARCA (VITÓRIA · +25 Âmbar!)"
		else:
			_ark_button.text = "✦ Projeto Arca Bloqueado (complete os requisitos)"


func _on_ark_victory_pressed() -> void:
	if not GameState.activate_ark_victory():
		return
	var tw: Tween = create_tween()
	_impact_flash.color = Color(0.75, 1.0, 0.80, 0.0)
	tw.tween_property(_impact_flash, "color:a", 0.75, 0.25)
	tw.tween_property(_impact_flash, "color:a", 0.0, 0.65)
	_refresh_modal()


func _on_early_impact_pressed() -> void:
	_modal_backdrop.visible = false
	Events.meteor_early_impact_requested.emit()


func _on_meteor_impact_started() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(_impact_flash, "color:a", 1.0, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		var gained: float = GameState.perform_prestige()
		Events.notification_requested.emit("☄️ Impacto! +%s 🟠 Âmbar obtido!" % GameState.format_number(gained), null)
		open_prestige_modal()
	)
	tw.tween_property(_impact_flash, "color:a", 0.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_danger_level_changed(_level: float) -> void:
	_sky_canvas.queue_redraw()


func _on_resource_changed(_res_id: StringName, _amount: float, _delta: float) -> void:
	if _modal_backdrop.visible:
		_refresh_modal()


func _on_upgrade_purchased(_upg_id: StringName, _new_level: int) -> void:
	if _modal_backdrop.visible:
		_refresh_modal()


## Desenha o meteoro no céu proporcional ao danger_level (0..1).
func _on_sky_canvas_draw() -> void:
	var d: float = clampf(GameState.danger_level, 0.0, 1.0)
	var start_pos := Vector2(780.0, 55.0)
	var end_pos := Vector2(360.0, 210.0)
	var pos: Vector2 = start_pos.lerp(end_pos, d)
	var radius: float = lerpf(10.0, 44.0, d)

	# Cauda incandescente
	var tail_dir: Vector2 = (start_pos - end_pos).normalized()
	_sky_canvas.draw_line(pos, pos + tail_dir * (radius * 2.8), Color(1.0, 0.45, 0.12, 0.45 + d * 0.4), radius * 0.9)
	# Halo externo
	_sky_canvas.draw_circle(pos, radius * 1.35, Color(1.0, 0.35, 0.1, 0.35 + d * 0.4))
	# Núcleo de rocha/fogo
	_sky_canvas.draw_circle(pos, radius, Color(0.95, 0.68, 0.25, 0.95))
	_sky_canvas.draw_circle(pos, radius * 0.6, Color(0.42, 0.22, 0.16, 1.0))
