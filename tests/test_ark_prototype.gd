extends GutTest
## Testes de integração do Protótipo 1 — A Arca dos Vivos:
## Pista na Pedreira após Ovo, Extração dedicada (escovação + Golpe Preciso),
## despertar do Anquilossauro sem Universidade, Módulo 1 da Arca, Save v7,
## migração v6→v7, continuidade pós-meteoro e Gazeta do Cratera V2.

var _bak_main: Dictionary = {}
var _bak_backup: Dictionary = {}
var _bak_tmp: Dictionary = {}
var _previous_autosave: bool = true


func _backup_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "bytes": PackedByteArray()}
	return {"exists": true, "bytes": FileAccess.get_file_as_bytes(path)}


func _restore_file(path: String, backup: Dictionary) -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return
	var fname: String = path.get_file()
	if bool(backup.get("exists", false)):
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_buffer(backup["bytes"] as PackedByteArray)
			f.close()
	elif dir.file_exists(fname):
		dir.remove(fname)


func _clear_save_files() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return
	for path: String in [SaveManager.SAVE_PATH, SaveManager.BACKUP_PATH, SaveManager.TEMP_PATH]:
		if dir.file_exists(path.get_file()):
			dir.remove(path.get_file())


func before_all() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_bak_main = _backup_file(SaveManager.SAVE_PATH)
	_bak_backup = _backup_file(SaveManager.BACKUP_PATH)
	_bak_tmp = _backup_file(SaveManager.TEMP_PATH)
	_previous_autosave = SaveManager.autosave_enabled


func before_each() -> void:
	_clear_save_files()
	SaveManager.autosave_enabled = false
	SaveManager.last_migrated_reset_version = -1
	GameState.start_new_game()


func after_each() -> void:
	GameState.is_prestige_modal_open = false
	GameState.is_impacting = false
	SaveManager.autosave_enabled = false


func after_all() -> void:
	_restore_file(SaveManager.SAVE_PATH, _bak_main)
	_restore_file(SaveManager.BACKUP_PATH, _bak_backup)
	_restore_file(SaveManager.TEMP_PATH, _bak_tmp)
	SaveManager.autosave_enabled = _previous_autosave
	GameState.start_new_game()


func test_egg_hatch_triggers_quarry_clue_and_guided_extraction_ui() -> void:
	assert_false(GameState.orange_rock_broken)
	assert_false(GameState.quarry_clue_active)
	assert_false(GameState.is_quarry_extraction_available())
	assert_false(GameState.is_quarry_slab_broken())

	var surface_packed: PackedScene = load("res://scenes/surface/SurfaceScene.tscn") as PackedScene
	var surface: SurfaceScene = add_child_autofree(surface_packed.instantiate()) as SurfaceScene
	await get_tree().process_frame

	var camp_lbl: Label = surface.get_node("Map/Camp") as Label
	assert_eq(camp_lbl.text, GameState.get_campaign_next_goal_text())

	# Quebra o Ovo de Âmbar -> ativa pista sísmica e extração guiada na Pedreira.
	Events.orange_rock_hit.emit(20.0, Vector2.ZERO)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(GameState.orange_rock_broken)
	assert_true(GameState.quarry_clue_active, "Quebrar o Ovo deve ativar quarry_clue_active")
	assert_true(GameState.is_quarry_extraction_available(), "Extração da Pedreira deve ficar disponível após o Ovo")
	assert_false(GameState.can_awaken_quarry_ankylosaurus())
	assert_false(GameState.is_quarry_slab_broken())
	assert_true(camp_lbl.text.contains("Pedreira do Casco"), "Banner de objetivo deve apontar para a Pedreira")

	surface.move_hero_to_station(&"rubble_forge")
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(surface.is_tab_alert_visible(&"site"), "Aba Estrutura da Pedreira deve exibir badge azul '!'")
	var extract_card: PanelContainer = surface.get_item_card(SurfaceScene.ITEM_QUARRY_EXTRACT)
	var extract_btn: Button = surface.get_item_buy_button(SurfaceScene.ITEM_QUARRY_EXTRACT)
	assert_not_null(extract_card, "Card guiado da Jazida Soterrada deve aparecer na Pedreira")
	assert_not_null(extract_btn)
	assert_false(extract_btn.disabled)
	assert_eq(extract_btn.text, "Escavar")

	# Clicar em Escavar abre o QuarryExtractionModal e bloqueia movimento/atalhos do mapa.
	var qmodal: QuarryExtractionModal = surface.get_node("%QuarryExtractionModal") as QuarryExtractionModal
	assert_not_null(qmodal)
	assert_false(qmodal.is_extraction_open())
	extract_btn.pressed.emit()
	await get_tree().process_frame

	assert_true(qmodal.is_extraction_open(), "QuarryExtractionModal deve abrir via botão Escavar")
	assert_true(surface._is_gameplay_input_blocked(), "Entrada de movimento/[E] deve ficar bloqueada com extração aberta")

	qmodal.close_extraction()
	await get_tree().process_frame
	assert_false(qmodal.is_extraction_open())


func test_quarry_extraction_modal_brush_only_golpe_preciso_and_idempotency() -> void:
	Events.orange_rock_hit.emit(20.0, Vector2.ZERO)

	var modal_src: String = FileAccess.get_file_as_string("res://scenes/surface/QuarryExtractionModal.gd")
	assert_false(modal_src.contains("RES_BONES"), "QuarryExtractionModal não pode usar Ossos")
	assert_false(modal_src.contains("RES_MINERALS"), "QuarryExtractionModal não pode usar Minérios")
	assert_false(modal_src.contains("RES_DNA"), "QuarryExtractionModal não pode usar DNA")

	var surface_check_packed: PackedScene = load("res://scenes/surface/SurfaceScene.tscn") as PackedScene
	var surface_check: SurfaceScene = add_child_autofree(surface_check_packed.instantiate()) as SurfaceScene
	await get_tree().process_frame
	assert_eq(int(ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter", -1)), 1, "Filtro padrão deve ser LINEAR para textos nítidos")
	var basin_lbl: Label = surface_check.get_node("Map/BasinName") as Label
	var camp_hint_lbl: Label = surface_check.get_node("Map/Camp") as Label
	assert_eq(basin_lbl.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)
	assert_eq(camp_hint_lbl.texture_filter, CanvasItem.TEXTURE_FILTER_LINEAR)

	var modal_packed: PackedScene = load("res://scenes/surface/QuarryExtractionModal.tscn") as PackedScene
	var qmodal: QuarryExtractionModal = add_child_autofree(modal_packed.instantiate()) as QuarryExtractionModal
	await get_tree().process_frame

	# 1) Golpe Preciso: perfect > good > miss, sem penalidade no erro (miss), mantendo paridade visual-mecânica.
	watch_signals(Events)
	qmodal.open_extraction()
	assert_true(qmodal.is_extraction_open())
	assert_almost_eq(qmodal.get_extraction_progress(), 0.0, 0.0001)
	assert_almost_eq(qmodal.get_visual_cleared_ratio(), 0.0, 0.0001)

	qmodal.apply_brush_progress(0.25)
	var expected_after_brush: float = clampf(qmodal.get_visual_cleared_ratio() / QuarryExtractionModal.COMPLETE_CLEAR_THRESHOLD, 0.0, 1.0)
	assert_almost_eq(qmodal.get_extraction_progress(), expected_after_brush, 0.02, "Progresso da escova deve corresponder exatamente ao sedimento visual")
	assert_lt(qmodal.get_visual_cleared_ratio(), 0.95)

	qmodal.trigger_precise_strike_window()
	var before_miss: float = qmodal.get_extraction_progress()
	qmodal.resolve_precise_strike_attempt(&"miss")
	var miss_gain: float = qmodal.get_extraction_progress() - before_miss
	assert_almost_eq(miss_gain, 0.0, 0.0001, "Erro no Golpe Preciso não pode aplicar penalidade nem reduzir progresso")
	assert_signal_emitted_with_parameters(Events, "precise_strike_resolved", [&"miss", 0.0])

	qmodal.trigger_precise_strike_window()
	var before_good: float = qmodal.get_extraction_progress()
	qmodal.resolve_precise_strike_attempt(&"good")
	var good_gain: float = qmodal.get_extraction_progress() - before_good
	assert_gt(good_gain, miss_gain, "Acerto 'good' deve superar 'miss'")
	assert_almost_eq(
		qmodal.get_extraction_progress(),
		clampf(qmodal.get_visual_cleared_ratio() / QuarryExtractionModal.COMPLETE_CLEAR_THRESHOLD, 0.0, 1.0),
		0.02,
		"Acerto 'good' deve remover massa visual proporcional ao progresso"
	)
	assert_signal_emitted_with_parameters(Events, "precise_strike_resolved", [&"good", 12.0])

	qmodal.trigger_precise_strike_window()
	var before_perfect: float = qmodal.get_extraction_progress()
	qmodal.resolve_precise_strike_attempt(&"perfect")
	var perfect_gain: float = qmodal.get_extraction_progress() - before_perfect
	assert_gt(perfect_gain, good_gain, "Acerto 'perfect' deve superar 'good'")
	assert_almost_eq(
		qmodal.get_extraction_progress(),
		clampf(qmodal.get_visual_cleared_ratio() / QuarryExtractionModal.COMPLETE_CLEAR_THRESHOLD, 0.0, 1.0),
		0.02,
		"Acerto 'perfect' deve remover massa visual proporcional ao progresso"
	)
	assert_signal_emitted_with_parameters(Events, "precise_strike_resolved", [&"perfect", 22.0])

	# 2) Conclusão 100% por escovação (errando qualquer pulso sísmico que abrir).
	qmodal.close_extraction()
	qmodal.open_extraction()
	var bones_before_brush: float = GameState.get_resource(GameState.RES_BONES)
	var minerals_before_brush: float = GameState.get_resource(GameState.RES_MINERALS)
	var dna_before_brush: float = GameState.get_resource(GameState.RES_DNA)
	assert_false(GameState.quarry_special_plate_found)
	for _step: int in range(30):
		if qmodal.get_extraction_progress() >= 1.0:
			break
		qmodal.apply_brush_progress(0.05)
		qmodal.resolve_precise_strike_attempt(&"miss")

	assert_almost_eq(qmodal.get_extraction_progress(), 1.0, 0.0001, "Escovação contínua deve concluir a extração sem depender do Sismógrafo")
	assert_true(GameState.quarry_special_plate_found, "Conclusão deve registrar Placa Especial encontrada")
	assert_false(GameState.quarry_clue_active)
	assert_false(GameState.is_quarry_extraction_available())
	assert_true(GameState.can_awaken_quarry_ankylosaurus())

	var complete_btn: Button = qmodal.get_node("%CompleteReturnButton") as Button
	assert_true(complete_btn.visible, "Botão de retorno após conclusão deve ficar visível")

	# 3) Zero moedas legadas concedidas pela extração + idempotência de claim_quarry_special_plate().
	assert_almost_eq(GameState.get_resource(GameState.RES_BONES), bones_before_brush, 0.0001)
	assert_almost_eq(GameState.get_resource(GameState.RES_MINERALS), minerals_before_brush, 0.0001)
	assert_almost_eq(GameState.get_resource(GameState.RES_DNA), dna_before_brush, 0.0001)
	assert_false(modal_src.to_lower().contains("bones"), "QuarryExtractionModal.gd não deve referenciar bones")
	assert_false(modal_src.to_lower().contains("minerals"), "QuarryExtractionModal.gd não deve referenciar minerals")
	assert_false(modal_src.to_lower().contains("\"dna\""), "QuarryExtractionModal.gd não deve referenciar dna")

	var fossils_after_claim: int = GameState.total_fossils_evaluated
	assert_false(GameState.claim_quarry_special_plate(), "claim_quarry_special_plate() deve ser idempotente")
	assert_eq(GameState.total_fossils_evaluated, fossils_after_claim, "Segunda chamada não pode duplicar registro de fóssil")

	complete_btn.pressed.emit()
	await get_tree().process_frame
	assert_false(qmodal.is_extraction_open())


func test_awaken_ankylosaurus_without_university_opens_vein_and_passive_metal() -> void:
	Events.orange_rock_hit.emit(20.0, Vector2.ZERO)
	assert_true(GameState.claim_quarry_special_plate())
	assert_false(GameState.is_station_built(&"rubble_bunker"), "Universidade NÃO deve ser necessária para despertar o Anquilossauro")
	assert_eq(GameState.get_fragments(&"ankylosaurus"), 0)

	var surface_packed: PackedScene = load("res://scenes/surface/SurfaceScene.tscn") as PackedScene
	var surface: SurfaceScene = add_child_autofree(surface_packed.instantiate()) as SurfaceScene
	await get_tree().process_frame

	surface.move_hero_to_station(&"rubble_forge")
	await get_tree().process_frame
	await get_tree().process_frame

	assert_null(surface.get_item_card(SurfaceScene.ITEM_QUARRY_EXTRACT))
	var wake_btn: Button = surface.get_item_buy_button(SurfaceScene.ITEM_AWAKEN_ANKYLO)
	assert_not_null(wake_btn, "Card de despertar Anquilossauro deve aparecer após extrair a Placa Especial")
	assert_false(wake_btn.disabled)
	assert_eq(wake_btn.text, "Despertar")

	watch_signals(Events)
	wake_btn.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_signal_emitted(Events, "quarry_vein_opened")
	assert_true(GameState.quarry_ankylo_rescued)
	assert_true(GameState.is_quarry_slab_broken(), "Laje da Pedreira deve estar aberta após despertar")
	assert_false(GameState.quarry_clue_active)
	assert_true(bool(GameState.rescued_station_dinos.get(&"rubble_forge", false)))
	assert_eq(GameState.get_station_revived_count(&"rubble_forge"), 1)
	assert_eq(GameState.get_dino_count(&"ankylosaurus"), 1)
	assert_almost_eq(GameState.get_resource(GameState.RES_METAL), GameState.QUARRY_STARTER_METAL_BURST, 0.001)
	assert_gt(GameState.get_station_tier2_rate(&"rubble_forge"), 0.0, "Taxa passiva de Metal na Pedreira deve iniciar > 0")
	assert_gt(GameState.get_resource_rate(GameState.RES_METAL), 0.0)
	assert_false(GameState.awaken_quarry_ankylosaurus(), "awaken_quarry_ankylosaurus() deve ser idempotente")

	# Verifica produção passiva real de Metal mesmo sem Universidade e sem trabalhador contratado.
	var metal_before: float = GameState.get_resource(GameState.RES_METAL)
	GameState._tick_passive_income(5.0)
	assert_gt(GameState.get_resource(GameState.RES_METAL), metal_before, "Metal passivo deve acumular automaticamente após abrir o veio")

	var ark_spot: FieldLandmark = surface.get_node("%Map/ark") as FieldLandmark
	assert_not_null(ark_spot)
	assert_eq(ark_spot.tooltip_text, "Arca dos Vivos", "Marco da Arca deve atualizar legenda ao resgatar o primeiro companheiro")


func test_ark_hull_reinforcement_module_cost_bonuses_and_no_double_buy() -> void:
	Events.orange_rock_hit.emit(20.0, Vector2.ZERO)
	assert_true(GameState.claim_quarry_special_plate())
	assert_true(GameState.awaken_quarry_ankylosaurus())
	GameState.run_surface_progress = 20000.0

	# Zera Rochas/Metal e testa fronteira exata (80 Rochas + 6 Metal).
	GameState.spend(GameState.RES_ROCKS, GameState.get_resource(GameState.RES_ROCKS))
	GameState.spend(GameState.RES_METAL, GameState.get_resource(GameState.RES_METAL))
	GameState.add_resource(GameState.RES_ROCKS, 79.0)
	GameState.add_resource(GameState.RES_METAL, 6.0)
	assert_false(GameState.can_build_ark_module(GameState.ARK_MODULE_HULL), "79 Rochas não devem bastar para Reforço de Casco")
	assert_false(GameState.build_ark_module(GameState.ARK_MODULE_HULL))

	GameState.add_resource(GameState.RES_ROCKS, 1.0)
	GameState.spend(GameState.RES_METAL, 1.0)
	assert_false(GameState.can_build_ark_module(GameState.ARK_MODULE_HULL), "5 Metal não devem bastar para Reforço de Casco")
	GameState.add_resource(GameState.RES_METAL, 1.0)
	assert_true(GameState.can_build_ark_module(GameState.ARK_MODULE_HULL), "80 Rochas + 6 Metal devem liberar Reforço de Casco")

	var shield_before: float = GameState.get_shield_ratio()
	var mult_before: float = GameState.get_ark_impact_amber_multiplier()
	var amber_before: float = GameState.calculate_amber_reward()
	assert_almost_eq(mult_before, 1.0, 0.0001)

	var surface_packed: PackedScene = load("res://scenes/surface/SurfaceScene.tscn") as PackedScene
	var surface: SurfaceScene = add_child_autofree(surface_packed.instantiate()) as SurfaceScene
	await get_tree().process_frame

	surface.move_hero_to_station(GameState.ARK_SITE_ID)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_true(surface.is_tab_alert_visible(&"site"), "Aba da Arca deve acender badge '!' quando Reforço de Casco é comprável")
	var action_btn: Button = surface.get_node("%ToDigSiteButton") as Button
	assert_eq(action_btn.text, "Impacto & Âmbar")
	var hull_btn: Button = surface.get_item_buy_button(SurfaceScene.ITEM_ARK_MODULE_HULL)
	assert_not_null(hull_btn)
	assert_false(hull_btn.disabled)
	assert_eq(hull_btn.text, "80 Rochas · 6 Metal")

	watch_signals(Events)
	hull_btn.pressed.emit()
	await get_tree().process_frame
	await get_tree().process_frame

	assert_signal_emitted_with_parameters(Events, "ark_module_built", [GameState.ARK_MODULE_HULL, 1])
	assert_true(GameState.is_ark_module_built(GameState.ARK_MODULE_HULL))
	assert_eq(GameState.get_ark_built_module_count(), 1)
	assert_almost_eq(GameState.get_resource(GameState.RES_ROCKS), 0.0, 0.001)
	assert_almost_eq(GameState.get_resource(GameState.RES_METAL), 0.0, 0.001)
	assert_almost_eq(GameState.get_ark_impact_amber_multiplier(), 1.40, 0.0001, "Reforço de Casco deve conceder +40% multiplicador de Âmbar")
	assert_almost_eq(GameState.get_shield_ratio(), shield_before + 0.10, 0.0001, "Reforço de Casco deve conceder +10% escudo permanente")
	assert_gt(GameState.calculate_amber_reward(), amber_before, "Recompensa de Âmbar no impacto deve aumentar com Reforço de Casco")

	# Impede compra duplicada na API e na UI.
	assert_false(GameState.can_build_ark_module(GameState.ARK_MODULE_HULL))
	assert_false(GameState.build_ark_module(GameState.ARK_MODULE_HULL))
	var hull_btn_after: Button = surface.get_item_buy_button(SurfaceScene.ITEM_ARK_MODULE_HULL)
	assert_true(hull_btn_after.disabled)
	assert_eq(hull_btn_after.text, "Concluído")
	assert_true(surface.is_item_card_dimmed(SurfaceScene.ITEM_ARK_MODULE_HULL))


func test_save_v7_prestige_continuity_migration_and_gazeta_v2() -> void:
	# 1) Monta campanha real do Protótipo 1 antes do impacto (Anquilossauro + Reforço de Casco + Universidade parcial).
	Events.orange_rock_hit.emit(20.0, Vector2.ZERO)
	assert_true(GameState.claim_quarry_special_plate())
	assert_true(GameState.awaken_quarry_ankylosaurus())
	GameState.add_resource(GameState.RES_ROCKS, 80.0)
	GameState.add_resource(GameState.RES_METAL, 6.0)
	assert_true(GameState.build_ark_module(GameState.ARK_MODULE_HULL))

	GameState.add_fragments(&"triceratops", 5)
	assert_true(GameState.roll_station_raw_fossil(&"rubble_nest", 1, true))
	GameState.fossil_cleaning_progress = 0.45
	GameState.run_surface_progress = 15000.0

	# Testa atalho/aceleração do meteoro sem falhas.
	GameState.fast_forward_meteor_to(3.0)
	assert_almost_eq(GameState.meteor_time_left, 3.0, 0.001)
	assert_gt(GameState.danger_level, 0.99)

	# 2) Round-trip Save v7 ANTES do impacto (2% Anquilossauro + 10% Reforço de Casco = 12%).
	assert_true(SaveManager.save_game())
	GameState.start_new_game()
	assert_true(SaveManager.load_game(), "Save v7 pré-impacto deve carregar corretamente")
	assert_true(GameState.quarry_ankylo_rescued)
	assert_true(GameState.is_quarry_slab_broken())
	assert_true(GameState.is_ark_module_built(GameState.ARK_MODULE_HULL))
	assert_eq(GameState.get_fragments(&"triceratops"), 5)
	assert_eq(GameState.raw_fossil_queue, [&"dilophosaurus"])
	assert_almost_eq(GameState.fossil_cleaning_progress, 0.45, 0.001)
	assert_almost_eq(GameState.get_shield_ratio(), 0.12, 0.001)

	# 3) Prestígio + validação da Gazeta do Cratera V2 (sem "-0m" e mostrando companheiro + objetivo).
	var overlay_packed: PackedScene = load("res://scenes/meteor/MeteorOverlay.tscn") as PackedScene
	var overlay: MeteorOverlay = add_child_autofree(overlay_packed.instantiate()) as MeteorOverlay
	await get_tree().process_frame

	var gained: float = GameState.perform_prestige()
	assert_gt(gained, 0.0)
	assert_eq(GameState.run_number, 2)
	assert_false(GameState.orange_rock_broken)
	assert_false(GameState.quarry_clue_active)

	# Continuidade exata sem duplicação após impacto.
	assert_true(GameState.quarry_ankylo_rescued)
	assert_true(GameState.quarry_special_plate_found)
	assert_true(GameState.is_quarry_slab_broken())
	assert_true(bool(GameState.rescued_station_dinos.get(&"rubble_forge", false)))
	assert_eq(GameState.get_station_revived_count(&"rubble_forge"), 1, "Anquilossauro não pode duplicar no prestígio")
	assert_eq(GameState.get_dino_count(&"ankylosaurus"), 1)
	assert_gt(GameState.get_station_tier2_rate(&"rubble_forge"), 0.0, "Veio de Metal deve seguir ativo na Run 2")
	assert_true(GameState.is_ark_module_built(GameState.ARK_MODULE_HULL))
	assert_eq(GameState.get_ark_built_module_count(), 1)
	assert_almost_eq(GameState.get_shield_ratio(), 0.12, 0.001)
	assert_eq(GameState.get_fragments(&"triceratops"), 5, "Fragmentos parciais devem persistir no prestígio")
	assert_eq(GameState.raw_fossil_queue, [&"dilophosaurus"], "Fila bruta deve persistir no prestígio")
	assert_almost_eq(GameState.get_resource(GameState.RES_RAW_FOSSILS), 1.0, 0.001)
	assert_almost_eq(GameState.fossil_cleaning_progress, 0.45, 0.001)

	overlay.open_prestige_modal()
	await get_tree().process_frame
	var summary_lbl: Label = overlay.get_node("%RunSummaryLabel") as Label
	assert_true(summary_lbl.text.contains("Bando na Arca: 1/8"))
	assert_true(summary_lbl.text.contains("Módulos da Arca: 1"))
	assert_true(summary_lbl.text.contains("Escudo: 12%"))

	overlay.show_prehistoric_newspaper(gained, GameState.depth, "Bacia do Âmbar", roundi(GameState.get_shield_ratio() * 100.0), GameState.run_number)
	await get_tree().process_frame
	var news_headline: Label = overlay.get_node("%NewsHeadlineLabel") as Label
	var news_body: Label = overlay.get_node("%NewsBodyLabel") as Label
	assert_false(news_headline.text.contains("-0m"), "Manchete da superfície nunca pode exibir -0m")
	assert_false(news_body.text.contains("-0m"), "Corpo da Gazeta da superfície nunca pode exibir -0m")
	assert_false(news_body.text.contains("espécimes preservados"), "Texto legado de profundidade não deve aparecer na superfície")
	assert_true(news_body.text.contains("Anquilossauro Minerador"), "Gazeta deve celebrar o companheiro resgatado")
	assert_true(news_body.text.contains("Próximo objetivo:"), "Gazeta deve mostrar o próximo objetivo")

	# 4) Round-trip Save v7 APÓS o impacto + quebrar Ovo na Run 2 sem reativar pista nem duplicar Anquilossauro.
	assert_true(SaveManager.save_game())
	GameState.start_new_game()
	assert_true(SaveManager.load_game(), "Save v7 pós-impacto deve restaurar todo o estado contínuo")
	assert_eq(GameState.run_number, 2)
	assert_almost_eq(GameState.get_resource(GameState.RES_AMBER), gained, 0.01)
	assert_true(GameState.quarry_ankylo_rescued)
	assert_true(GameState.is_quarry_slab_broken())
	assert_eq(GameState.get_station_revived_count(&"rubble_forge"), 1)
	assert_eq(GameState.get_dino_count(&"ankylosaurus"), 1)
	assert_true(GameState.is_ark_module_built(GameState.ARK_MODULE_HULL))
	assert_eq(GameState.get_fragments(&"triceratops"), 5)
	assert_eq(GameState.raw_fossil_queue, [&"dilophosaurus"])
	assert_almost_eq(GameState.fossil_cleaning_progress, 0.45, 0.001)
	assert_eq(int(GameState.last_impact_summary.get("rescued_count", 0)), 1)

	Events.orange_rock_hit.emit(20.0, Vector2.ZERO)
	assert_true(GameState.orange_rock_broken)
	assert_false(GameState.quarry_clue_active, "Quebrar o Ovo na Run 2 não pode reativar pista da Pedreira já resgatada")
	assert_false(GameState.is_quarry_extraction_available())
	assert_eq(GameState.get_station_revived_count(&"rubble_forge"), 1)
	assert_eq(GameState.get_dino_count(&"ankylosaurus"), 1)

	# 5) Migração direta v6 -> v7 com Anquilossauro + fila de fósseis.
	var v6_payload: Dictionary = {
		"version": 6,
		"saved_at": Time.get_unix_time_from_system(),
		"game": {
			"resources": {"rocks": 50.0, "amber": 15.0},
			"fragments": {"brachiosaurus": 2},
			"rubble_levels": {"rubble_forge": 1},
			"station_revived_dinos": {"rubble_forge": 1},
			"raw_fossil_queue": ["trex"],
			"fossil_cleaning_progress": 0.25,
			"orange_rock_hp": 0.0,
			"orange_rock_broken": true,
			"run_number": 2,
			"meteor_time_left": 700.0,
		},
	}
	var f_v6: FileAccess = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f_v6.store_string(JSON.stringify(v6_payload))
	f_v6.close()
	assert_true(SaveManager.load_game())
	assert_true(GameState.quarry_ankylo_rescued)
	assert_true(GameState.is_quarry_slab_broken())
	assert_true(bool(GameState.rescued_station_dinos.get(&"rubble_forge", false)))
	assert_eq(GameState.get_fragments(&"brachiosaurus"), 2)
	assert_eq(GameState.raw_fossil_queue, [&"trex"])
	assert_almost_eq(GameState.fossil_cleaning_progress, 0.25, 0.001)
