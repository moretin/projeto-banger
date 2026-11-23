class_name MeteorOverlay
extends Control
## Controlador dos modais de prestígio (Manchete Pré-Histórica "Gazeta do Cratera",
## Arca de Evacuação e clarão de impacto). O meteoro em aproximação é desenhado
## no céu de fundo em BasinLandscape.gd, atrás do cenário, janelas e HUD.

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
@onready var _visit_lab: Button = %VisitLab

var _current_scenario: StringName = &"surface"


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
		Events.station_research_requested.emit()
	)
	_visit_lab.pressed.connect(func() -> void:
		_modal_backdrop.visible = false
		Events.station_research_requested.emit()
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
	Events.ark_module_built.connect(_on_campaign_modal_state_changed.unbind(2))
	Events.quarry_vein_opened.connect(_on_campaign_modal_state_changed)
	Events.dino_count_changed.connect(_on_campaign_modal_state_changed.unbind(2))
	Events.game_loaded.connect(_refresh_modal)

	_refresh_modal()


func _exit_tree() -> void:
	var was_open: bool = (_modal_backdrop != null and _modal_backdrop.visible) or (_newspaper_backdrop != null and _newspaper_backdrop.visible)
	if was_open and is_instance_valid(Events):
		Events.prestige_modal_visibility_changed.emit(false)


func _on_modal_visibility_changed() -> void:
	Events.prestige_modal_visibility_changed.emit(_modal_backdrop.visible or _newspaper_backdrop.visible)


func open_prestige_modal() -> void:
	_newspaper_backdrop.visible = false
	_refresh_modal()
	_modal_backdrop.visible = true


## Exibe a capa da Gazeta do Cratera para o impacto atual ou resumo simulado.
func show_prehistoric_newspaper(gained_amber: float = -1.0, snapshot_depth: int = 0, snapshot_era: String = "Bacia do Âmbar", snapshot_shield_pct: int = -1, snapshot_run: int = -1) -> void:
	_modal_backdrop.visible = false
	var summary: Dictionary = GameState.last_impact_summary
	var has_summary: bool = not summary.is_empty()
	var effective_amber: float = gained_amber if gained_amber >= 0.0 else float(summary.get("amber_gained", 0.0))
	var finished_run: int = int(summary.get("run_number", maxi(snapshot_run - 1, 1))) if has_summary else maxi(snapshot_run - 1, 1)
	var shield_pct: int = int(summary.get("shield_pct", snapshot_shield_pct)) if has_summary else snapshot_shield_pct
	if shield_pct < 0:
		shield_pct = roundi(GameState.get_shield_ratio() * 100.0)

	var rescued_names: Array[String] = []
	if has_summary and summary.get("rescued_names", null) is Array:
		for raw_name: Variant in summary["rescued_names"] as Array:
			rescued_names.append(String(raw_name))
	else:
		rescued_names = GameState.get_rescued_companion_names()
	var rescued_count: int = int(summary.get("rescued_count", rescued_names.size()))
	var slab_broken: bool = bool(summary.get("slab_broken", GameState.is_quarry_slab_broken()))
	var hull_built: bool = bool(summary.get("hull_built", GameState.is_ark_module_built(GameState.ARK_MODULE_HULL)))
	var ark_modules_count: int = int(summary.get("ark_modules_count", GameState.get_ark_built_module_count()))
	var next_goal: String = String(summary.get("next_goal", ""))
	if next_goal.is_empty():
		next_goal = GameState.get_campaign_next_goal_text()

	var amber_str: String = GameState.format_number(effective_amber)
	var total_amber_str: String = GameState.format_number(GameState.get_resource(GameState.RES_AMBER))

	if snapshot_depth <= 0:
		_edition_meta_label.text = "EXPEDIÇÃO #%d · BOLETIM DA ARCA DOS VIVOS · BACIA DO ÂMBAR" % finished_run
		if hull_built and rescued_count > 0:
			_news_headline_label.text = "ARCA PROTEGE %d COMPANHEIRO(S)! +%s ÂMBAR CRISTALIZADO NA BACIA!" % [rescued_count, amber_str]
		elif rescued_count > 0:
			_news_headline_label.text = "IMPACTO NA BACIA! %s RESISTE NA ARCA (+%s ÂMBAR)!" % [rescued_names[0].to_upper(), amber_str]
		else:
			_news_headline_label.text = "BÓLIDO ATINGE A BACIA DO ÂMBAR! CÁPSULA SALVA +%s DE ÂMBAR PURO!" % amber_str

		var companion_line: String = "• Bando salvo na Arca (%d/8): %s — seguem ao seu lado na nova expedição!" % [rescued_count, ", ".join(rescued_names)] if not rescued_names.is_empty() else "• Nenhum companheiro resgatado ainda — quebre o Ovo e investigue a trinca da Pedreira!"
		var quarry_line: String = "• Veio de Metal da Pedreira aberto! A laje permanece quebrada e o veio segue acessível." if slab_broken else "• A laje da Pedreira ainda bloqueia o veio de Metal — escove a Placa Especial após chocar o Ovo."
		var ark_line: String = "• Módulos construídos na Arca: %d (Reforço de Casco ativo · Escudo %d%%)." % [ark_modules_count, shield_pct] if (hull_built or ark_modules_count > 0) else "• Base da Arca instalada (Escudo %d%%) — construa o Reforço de Casco com 80 Rochas e 6 Metal." % shield_pct
		var clean_goal: String = next_goal.trim_prefix("Objetivo: ")
		var goal_line: String = "• Próximo objetivo: %s" % clean_goal

		_news_body_label.text = "CRÔNICA DA SUPERFÍCIE — O meteoro atingiu a Bacia do Âmbar, mas a Arca dos Vivos preservou suas conquistas permanentes.\n\n%s\n%s\n%s\n%s" % [
			companion_line,
			quarry_line,
			ark_line,
			goal_line,
		]
	else:
		_edition_meta_label.text = "EXPEDIÇÃO #%d · BOLETIM SÍSMICO DO CATACLISMA · CRATERA %s" % [
			finished_run,
			snapshot_era.to_upper(),
		]
		_news_headline_label.text = "CRATERA ABERTA EM %s (-%dm): ARCA CRISTALIZA +%s ÂMBAR!" % [
			snapshot_era.to_upper(),
			snapshot_depth,
			amber_str,
		]
		var companion_txt: String = ", ".join(rescued_names) if not rescued_names.is_empty() else "Nenhum"
		_news_body_label.text = "CRÔNICA DE CAMPO — Após avançar até -%dm na faixa de %s, a Arca dos Vivos absorveu o impacto.\n\n• Bando salvo na Arca (%d/8): %s.\n• Módulos da Arca: %d · Escudo permanente: %d%%.\n• Próximo passo: %s" % [
			snapshot_depth,
			snapshot_era,
			rescued_count,
			companion_txt,
			ark_modules_count,
			shield_pct,
			next_goal,
		]

	_news_amber_banner.text = "Âmbar Cristalizado na Cápsula da Arca: +%s (Total disponível: %s)" % [
		amber_str,
		total_amber_str,
	]
	_newspaper_backdrop.visible = true


func _refresh_modal() -> void:
	var amber: float = GameState.get_resource(GameState.RES_AMBER)
	var reward: float = GameState.calculate_amber_reward()
	var shield_pct: int = roundi(GameState.get_shield_ratio() * 100.0)
	var companion_count: int = GameState.get_rescued_companion_count()
	var ark_modules: int = GameState.get_ark_built_module_count()
	_amber_balance_label.text = "Resina de Âmbar Disponível: %s   (Total acumulado: %s)" % [
		GameState.format_number(amber),
		GameState.format_number(GameState.total_amber_earned),
	]
	_run_summary_label.text = "Bando na Arca: %d/8 · Módulos da Arca: %d · Escudo: %d%% · Evacuar agora rende: +%s Âmbar" % [
		companion_count,
		ark_modules,
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
	if _current_scenario == &"dig_site":
		_sky_canvas.queue_redraw()


func _on_resource_changed(_res_id: StringName, _amount: float, _delta: float) -> void:
	if _modal_backdrop.visible:
		_refresh_modal()


func _on_upgrade_purchased(_upg_id: StringName, _new_level: int) -> void:
	if _modal_backdrop.visible:
		_refresh_modal()


func _on_campaign_modal_state_changed() -> void:
	if _modal_backdrop.visible:
		_refresh_modal()


## Na Superfície o meteoro vive no céu de fundo em BasinLandscape.gd (atrás de janelas e HUD).
## Aqui preservamos apenas um reflexo sutil na boca do poço quando o jogador está raso no subsolo.
func _on_sky_canvas_draw() -> void:
	if _current_scenario != &"dig_site":
		return
	var d: float = clampf(GameState.danger_level, 0.0, 1.0)
	if GameState.depth <= 2 and d > 0.05:
		var play_w: float = size.x
		var peek_pos: Vector2 = Vector2(play_w * 0.80, 26.0 - float(GameState.depth) * 10.0)
		_sky_canvas.draw_circle(peek_pos, 16.0 + d * 14.0, Color(1.0, 0.42, 0.12, 0.16 + d * 0.24))
