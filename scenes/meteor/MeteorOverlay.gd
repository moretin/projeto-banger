class_name MeteorOverlay
extends Control
## Controlador visual do Meteoro relativo à câmera, Manchete Pré-Histórica ("Gazeta do Cratera")
## e Bancada do Laboratório da Arca (investimento permanente de Âmbar).

const UPGRADE_CARD_SCENE: PackedScene = preload("res://scenes/ui/UpgradeCard.tscn")
const MAX_METEOR_EMBERS: int = 28

@onready var _sky_canvas: Control = %MeteorSkyCanvas
@onready var _impact_flash: ColorRect = %ImpactFlash

@onready var _newspaper_backdrop: ColorRect = %NewspaperBackdrop
@onready var _news_meteor_icon: TextureRect = %NewsMeteorIcon
@onready var _edition_meta_label: Label = %EditionMetaLabel
@onready var _news_headline_label: Label = %NewsHeadlineLabel
@onready var _news_body_label: Label = %NewsBodyLabel
@onready var _news_amber_banner: Label = %NewsAmberBanner
@onready var _open_arca_lab_button: Button = %OpenArcaLabButton
@onready var _news_close_button: Button = %NewsCloseButton

@onready var _modal_backdrop: ColorRect = %ModalBackdrop
@onready var _lab_amber_icon: TextureRect = %LabAmberIcon
@onready var _amber_balance_label: Label = %AmberBalanceLabel
@onready var _run_summary_label: Label = %RunSummaryLabel
@onready var _early_impact_button: Button = %EarlyImpactButton
@onready var _close_button: Button = %CloseButton
@onready var _amber_upgrades_list: VBoxContainer = %AmberUpgradesList

var _current_scenario: StringName = &"surface"
var _embers: Array[Dictionary] = []
var _ember_spawn_accum: float = 0.0
var _sky_pulse_t: float = 0.0


func _ready() -> void:
	_modal_backdrop.visible = false
	_newspaper_backdrop.visible = false
	_modal_backdrop.visibility_changed.connect(_on_modal_visibility_changed)
	_newspaper_backdrop.visibility_changed.connect(_on_modal_visibility_changed)
	_impact_flash.color = Color(1.0, 0.88, 0.65, 0.0)

	_lab_amber_icon.texture = AmberTheme.get_icon(&"amber")
	_news_meteor_icon.texture = AmberTheme.get_icon(&"meteor")
	_open_arca_lab_button.icon = AmberTheme.get_icon(&"amber")
	_early_impact_button.icon = AmberTheme.get_icon(&"meteor")

	_sky_canvas.draw.connect(_on_sky_canvas_draw)
	_early_impact_button.pressed.connect(_on_early_impact_pressed)
	_close_button.pressed.connect(func() -> void: _modal_backdrop.visible = false)
	_open_arca_lab_button.pressed.connect(func() -> void:
		_newspaper_backdrop.visible = false
		open_prestige_modal()
	)
	_news_close_button.pressed.connect(func() -> void:
		_newspaper_backdrop.visible = false
	)

	Events.scenario_changed.connect(_on_scenario_changed)
	Events.danger_level_changed.connect(_on_danger_level_changed)
	Events.meteor_impact_started.connect(_on_meteor_impact_started)
	Events.prestige_modal_requested.connect(open_prestige_modal)
	Events.resource_changed.connect(_on_resource_changed)
	Events.upgrade_purchased.connect(_on_upgrade_purchased)
	Events.game_loaded.connect(_refresh_modal)

	_populate_amber_upgrades()
	_refresh_modal()


func _exit_tree() -> void:
	var was_open: bool = (_modal_backdrop != null and _modal_backdrop.visible) or (_newspaper_backdrop != null and _newspaper_backdrop.visible)
	if was_open and is_instance_valid(Events):
		Events.prestige_modal_visibility_changed.emit(false)


func _on_modal_visibility_changed() -> void:
	Events.prestige_modal_visibility_changed.emit(_modal_backdrop.visible or _newspaper_backdrop.visible)


func _process(delta: float) -> void:
	_sky_pulse_t += delta
	var d: float = clampf(GameState.danger_level, 0.0, 1.0)
	if d > 0.15 or not _embers.is_empty():
		var play_w: float = maxf(size.x - 540.0, 640.0)
		if d > 0.15:
			_ember_spawn_accum += delta * (4.0 + d * 14.0)
			while _ember_spawn_accum >= 1.0:
				_ember_spawn_accum -= 1.0
				if _embers.size() >= MAX_METEOR_EMBERS:
					_embers.pop_front()
				_embers.append({
					"pos": Vector2(randf_range(60.0, play_w - 60.0), randf_range(0.0, 32.0)),
					"vel": Vector2(randf_range(-24.0, 12.0), randf_range(38.0, 96.0)),
					"r": randf_range(2.0, 4.5),
					"life": randf_range(0.9, 1.8),
					"max_life": 1.8,
				})
		var i: int = _embers.size() - 1
		while i >= 0:
			var e: Dictionary = _embers[i]
			var life: float = float(e["life"]) - delta
			if life <= 0.0:
				_embers.remove_at(i)
			else:
				e["life"] = life
				e["pos"] = (e["pos"] as Vector2) + (e["vel"] as Vector2) * delta
			i -= 1
		_sky_canvas.queue_redraw()


func open_prestige_modal() -> void:
	_newspaper_backdrop.visible = false
	_refresh_modal()
	_modal_backdrop.visible = true


## Exibe a capa da Gazeta do Cratera para o impacto atual ou resumo simulado.
func show_prehistoric_newspaper(gained_amber: float, snapshot_depth: int, snapshot_era: String, snapshot_shield_pct: int, snapshot_run: int) -> void:
	_modal_backdrop.visible = false
	_edition_meta_label.text = "EXPEDIÇÃO #%d · BOLETIM SÍSMICO DO CATACLISMA · CRATERA %s" % [
		maxi(snapshot_run - 1, 1),
		snapshot_era.to_upper(),
	]

	if snapshot_depth <= 0:
		_news_headline_label.text = "BÓLIDO ATINGE A SUPERFÍCIE! ACAMPAMENTO RECUPERA +%s DE ÂMBAR PURO!" % GameState.format_number(gained_amber)
	elif snapshot_shield_pct >= 50:
		_news_headline_label.text = "IMPACTO CONTIDO NA COTA -%dm! BASTIÕES SALVAM %d%% DO ACERVO FÓSSIL!" % [snapshot_depth, snapshot_shield_pct]
	else:
		_news_headline_label.text = "CRATERA ABERTA EM %s (-%dm): CÁPSULA DA ARCA CRISTALIZA +%s ÂMBAR!" % [
			snapshot_era.to_upper(),
			snapshot_depth,
			GameState.format_number(gained_amber),
		]

	var species_count: int = 0
	for id: Variant in GameState.discovered_dinos:
		if bool(GameState.discovered_dinos[id]):
			species_count += 1

	_news_body_label.text = "CRÔNICA DE CAMPO — Após perfurar até a cota -%dm na faixa de %s, os sismógrafos registraram a reentrada final do meteoro.\n\n• Escudo estrutural e Anquilossauros preservaram %d%% dos espécimes da expedição.\n• Espécies já catalogadas na história da expedição: %d de 8.\n• Toda a pesquisa permanente permanece intacta no Laboratório da Arca para a nova escavação." % [
		snapshot_depth,
		snapshot_era,
		snapshot_shield_pct,
		species_count,
	]
	_news_amber_banner.text = "Âmbar Cristalizado na Cápsula da Arca: +%s (Total disponível: %s)" % [
		GameState.format_number(gained_amber),
		GameState.format_number(GameState.get_resource(GameState.RES_AMBER)),
	]
	_newspaper_backdrop.visible = true


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
	_amber_balance_label.text = "Resina de Âmbar Disponível: %s   (Total acumulado: %s)" % [
		GameState.format_number(amber),
		GameState.format_number(GameState.total_amber_earned),
	]
	_run_summary_label.text = "Cota atual: -%dm (Recorde: -%dm)  ·  Escudo da Arca: %d%%  ·  Evacuação agora rende: +%s Âmbar" % [
		GameState.depth,
		GameState.max_depth_ever,
		shield_pct,
		GameState.format_number(reward),
	]
	_early_impact_button.text = "Acionar Cápsula & Evacuar Expedição Agora (+%s Âmbar)" % GameState.format_number(reward)
	_early_impact_button.disabled = GameState.is_impacting


func _on_early_impact_pressed() -> void:
	_modal_backdrop.visible = false
	Events.meteor_early_impact_requested.emit()


func _on_meteor_impact_started() -> void:
	var snap_depth: int = GameState.depth
	var era: EraData = GameState.get_current_era()
	var snap_era: String = era.display_name if era != null else "Crosta"
	var snap_shield: int = roundi(GameState.get_shield_ratio() * 100.0)

	var tw: Tween = create_tween()
	tw.tween_property(_impact_flash, "color:a", 1.0, 0.35).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		var gained: float = GameState.perform_prestige()
		Events.notification_requested.emit("Impacto! +%s Âmbar cristalizado na Arca!" % GameState.format_number(gained), AmberTheme.get_icon(&"amber"))
		show_prehistoric_newspaper(gained, snap_depth, snap_era, snap_shield, GameState.run_number)
	)
	tw.tween_property(_impact_flash, "color:a", 0.0, 0.65).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _on_scenario_changed(scenario: StringName) -> void:
	_current_scenario = scenario
	_sky_canvas.queue_redraw()


func _on_danger_level_changed(_level: float) -> void:
	_sky_canvas.queue_redraw()


func _on_resource_changed(_res_id: StringName, _amount: float, _delta: float) -> void:
	if _modal_backdrop.visible:
		_refresh_modal()


func _on_upgrade_purchased(_upg_id: StringName, _new_level: int) -> void:
	if _modal_backdrop.visible:
		_refresh_modal()


## Desenha o meteoro em coordenadas relativas ao ScenarioViewport e à profundidade da câmera.
func _on_sky_canvas_draw() -> void:
	var d: float = clampf(GameState.danger_level, 0.0, 1.0)
	var play_w: float = maxf(size.x - 540.0, 640.0)

	# Clarão térmico no topo da tela proporcional ao perigo
	if d > 0.10:
		var glow_a: float = clampf((d - 0.10) * 0.28 + sin(_sky_pulse_t * 3.5) * 0.03 * d, 0.0, 0.32)
		_sky_canvas.draw_rect(Rect2(0.0, 0.0, play_w, 72.0 + d * 48.0), Color(1.0, 0.32, 0.08, glow_a))

	# Fagulhas e cinzas incandescentes no quadrante do cenário
	for e: Dictionary in _embers:
		var alpha: float = clampf(float(e["life"]) / float(e["max_life"]), 0.0, 1.0)
		_sky_canvas.draw_circle(e["pos"] as Vector2, float(e["r"]), Color(1.0, 0.62, 0.18, alpha * 0.85))

	if _current_scenario == &"dig_site":
		# No subsolo, a câmera desceu: apenas clarão na boca superior se profundidade rasinha
		if GameState.depth <= 2 and d > 0.05:
			var peek_pos := Vector2(play_w * 0.80, 26.0 - float(GameState.depth) * 10.0)
			_sky_canvas.draw_circle(peek_pos, 18.0 + d * 18.0, Color(1.0, 0.42, 0.12, 0.25 + d * 0.35))
		return

	# Na Superfície: o meteoro rasga o quadrante superior-direito da tela útil, longe do HeaderLabel
	var start_pos := Vector2(play_w * 0.89, 88.0)
	var end_pos := Vector2(play_w * 0.77, 178.0)
	var pos: Vector2 = start_pos.lerp(end_pos, d)
	var radius: float = lerpf(11.0, 40.0, d)
	var tail_dir: Vector2 = (start_pos - end_pos).normalized()

	# Rastro atmosférico / plasma
	_sky_canvas.draw_line(pos, pos + tail_dir * (radius * 3.2), Color(1.0, 0.42, 0.10, 0.38 + d * 0.42), radius * 0.95)
	_sky_canvas.draw_line(pos, pos + tail_dir * (radius * 2.0), Color(1.0, 0.78, 0.28, 0.55 + d * 0.35), radius * 0.45)
	# Halo e corpo irregular rochoso em chamas
	_sky_canvas.draw_circle(pos, radius * 1.38, Color(1.0, 0.34, 0.08, 0.30 + d * 0.40))
	_sky_canvas.draw_circle(pos, radius, Color(0.95, 0.62, 0.22, 0.96))
	_sky_canvas.draw_circle(pos + Vector2(-radius * 0.12, radius * 0.10), radius * 0.68, Color(0.36, 0.17, 0.12, 1.0))
	_sky_canvas.draw_circle(pos + Vector2(-radius * 0.30, -radius * 0.20), radius * 0.22, Color(0.22, 0.10, 0.07, 0.90))
