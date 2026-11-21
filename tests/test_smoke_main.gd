extends GutTest
## Teste de fumaça: instancia Main.tscn por 600 frames e valida o HUD inferior dinâmico e a barra do meteoro.


func test_main_scene_runs_600_frames_without_errors() -> void:
	var prev_autosave: bool = SaveManager.autosave_enabled
	SaveManager.autosave_enabled = false
	GameState.start_new_game()
	var initial_meteor: float = GameState.meteor_time_left

	var main_packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	assert_not_null(main_packed, "Main.tscn deve carregar corretamente")
	var main_instance: Control = main_packed.instantiate() as Control
	assert_not_null(main_instance, "Main.tscn deve instanciar como Control")

	add_child(main_instance)
	for _i: int in range(600):
		await get_tree().process_frame

	assert_true(main_instance.is_inside_tree(), "Main deve permanecer ativa após 600 frames")
	assert_not_null(main_instance.get_node_or_null("%SurfaceScene"), "SurfaceScene deve estar presente")
	assert_not_null(main_instance.get_node_or_null("%DigSite"), "DigSite deve estar presente")
	assert_not_null(main_instance.get_node_or_null("MeteorOverlay"), "MeteorOverlay deve estar presente")
	assert_null(main_instance.get_node_or_null("FossilMuseum"), "FossilMuseum deve ter sido removido de Main.tscn")
	assert_false(ResourceLoader.exists("res://scenes/ui/FossilMuseum.tscn"), "FossilMuseum.tscn deve ter sido excluído")
	assert_false(FileAccess.file_exists("res://scenes/ui/FossilMuseum.gd"), "FossilMuseum.gd deve ter sido excluído")
	assert_lt(GameState.meteor_time_left, initial_meteor, "Timer do meteoro deve avançar normalmente durante os 600 frames")

	main_instance.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	SaveManager.autosave_enabled = prev_autosave


func test_hud_shows_only_active_surface_resources_and_meteor_bar_without_numeric_timer() -> void:
	var prev_autosave: bool = SaveManager.autosave_enabled
	SaveManager.autosave_enabled = false
	GameState.start_new_game()

	var hud_scene: PackedScene = preload("res://scenes/ui/HUD.tscn")
	var hud: HUD = hud_scene.instantiate() as HUD
	add_child_autofree(hud)
	await get_tree().process_frame

	# 1) Nenhum recurso legado (Ossos / Minérios / DNA), nenhum botão de Museu e nenhum timer numérico no HUD.
	assert_null(hud.get_node_or_null("%BonesLabel"), "HUD não deve exibir Ossos")
	assert_null(hud.get_node_or_null("%DnaRate"), "HUD não deve exibir DNA")
	assert_null(hud.get_node_or_null("%AmberForecast"), "HUD não deve exibir previsão legada")
	assert_null(hud.get_node_or_null("%MeteorLabel"), "Timer numérico do meteoro deve estar removido do HUD")
	assert_null(hud.get_node_or_null("%MuseumButton"), "Botão de Museu deve estar removido do HUD")
	assert_false(Events.has_signal(&"museum_modal_requested"), "Events.museum_modal_requested deve estar removido")
	assert_true(Events.has_signal(&"biome_changed"), "Events.biome_changed deve existir")

	var meteor_bar: ProgressBar = hud.get_node("%MeteorBar") as ProgressBar
	assert_not_null(meteor_bar)
	assert_true(meteor_bar.is_visible_in_tree(), "Barra visual do meteoro deve estar visível")
	assert_false(meteor_bar.show_percentage, "Barra do meteoro não deve exibir porcentagem/texto numérico")
	assert_almost_eq(meteor_bar.value, GameState.meteor_time_left, 0.01)
	assert_almost_eq(GameState.meteor_total_time, 1200.0, 0.01, "Timer base do meteoro deve ser 20 minutos (1200s)")
	assert_almost_eq(meteor_bar.max_value, 1200.0, 0.01, "Barra do meteoro deve refletir 20 minutos (1200s)")

	# 2) No início da run, apenas Pedreira está construída -> somente Rochas aparece no HUD.
	var initial_displayed: Array[StringName] = hud.get_displayed_resources()
	assert_eq(initial_displayed, [GameState.RES_ROCKS], "HUD inicial deve mostrar apenas Rochas")

	# Nenhum texto visível do HUD pode mencionar Ossos, Minérios, DNA ou cronômetro numérico (mm:ss).
	var timer_regex := RegEx.new()
	timer_regex.compile("\\b\\d{1,2}:\\d{2}\\b")
	for node: Node in hud.find_children("*", "Label", true, false):
		var lbl: Label = node as Label
		if lbl != null and lbl.is_visible_in_tree():
			var txt: String = lbl.text
			assert_false(txt.contains("Ossos"), "HUD não deve mostrar Ossos")
			assert_false(txt.contains("Minérios"), "HUD não deve mostrar Minérios")
			assert_false(txt.contains("DNA"), "HUD não deve mostrar DNA")
			assert_false(txt.contains("Impacto em"), "HUD não deve exibir texto de contagem regressiva")
			assert_null(timer_regex.search(txt), "HUD não deve exibir timer numérico (%s)" % txt)

	# 3) Com o meteoro pausado pelo modal de prestígio, %MeteorBar congela; ao despausar, encolhe.
	var bar_before_pause: float = meteor_bar.value
	Events.prestige_modal_visibility_changed.emit(true)
	GameState._process(30.0)
	await get_tree().process_frame
	assert_almost_eq(meteor_bar.value, bar_before_pause, 0.01, "Barra do meteoro deve congelar com modal aberto")
	Events.prestige_modal_visibility_changed.emit(false)
	GameState._process(60.0)
	await get_tree().process_frame
	assert_lt(meteor_bar.value, bar_before_pause - 50.0, "Barra do meteoro deve encolher conforme o tempo passa")

	# 4) Adicionar Ossos/Minérios/DNA nos bastidores NUNCA faz esses chips aparecerem no HUD.
	GameState.add_resource(GameState.RES_BONES, 50000.0)
	GameState.add_resource(GameState.RES_MINERALS, 250.0)
	GameState.add_resource(GameState.RES_DNA, 120.0)
	await get_tree().process_frame
	var after_legacy: Array[StringName] = hud.get_displayed_resources()
	assert_false(GameState.RES_BONES in after_legacy)
	assert_false(GameState.RES_MINERALS in after_legacy)
	assert_false(GameState.RES_DNA in after_legacy)

	# 5) Quebrar ovo rende 5 Rochas (não basta para Pesqueiro imediato); construir Pesqueiro adiciona Peixes e contratar exibe +taxa/s.
	Events.orange_rock_hit.emit(20.0, Vector2.ZERO)
	await get_tree().process_frame
	assert_almost_eq(GameState.get_resource(GameState.RES_ROCKS), 5.0, 0.001, "Ovo de Âmbar deve render 5 Rochas")
	assert_false(GameState.can_rebuild_rubble(&"rubble_nest"), "5 Rochas iniciais não devem bastar para construir Pesqueiro (120)")
	var rocks_chip: Control = hud.get_resource_chip(GameState.RES_ROCKS)
	assert_not_null(rocks_chip)
	var rocks_amount_lbl: Label = rocks_chip.get_node("Readout/Balance/AmountLabel") as Label
	assert_eq(rocks_amount_lbl.text, GameState.format_number(GameState.get_resource(GameState.RES_ROCKS)))

	GameState.add_resource(GameState.RES_ROCKS, GameState.get_rubble_cost(&"rubble_nest"))
	assert_true(GameState.rebuild_rubble(&"rubble_nest"))
	await get_tree().process_frame
	assert_true(GameState.RES_FISH in hud.get_displayed_resources(), "Construir Pesqueiro deve adicionar Peixes no HUD")
	var fish_chip: Control = hud.get_resource_chip(GameState.RES_FISH)
	assert_not_null(fish_chip)
	var fish_name_lbl: Label = fish_chip.get_node("Readout/ResourceName") as Label
	var fish_rate_lbl: Label = fish_chip.get_node("Readout/Balance/RateLabel") as Label
	assert_eq(fish_name_lbl.text, "Peixes")
	assert_false(fish_rate_lbl.visible, "Taxa de Peixes deve ficar oculta antes de contratar o trabalhador")

	GameState.add_resource(GameState.RES_FISH, GameState.get_station_worker_cost(&"rubble_nest"))
	assert_true(GameState.hire_station_worker(&"rubble_nest"))
	await get_tree().process_frame
	assert_true(fish_rate_lbl.visible, "Contratar Bariônix deve exibir taxa +/s de Peixes no HUD")
	assert_eq(fish_rate_lbl.text, "+%s/s" % GameState.format_number(GameState.get_resource_rate(GameState.RES_FISH)))

	# 6) Construir Universidade adiciona Ciência (nunca DNA); achar fóssil bruto adiciona e limpar remove Fósseis Brutos.
	GameState.add_resource(GameState.RES_ROCKS, GameState.get_rubble_cost(&"rubble_bunker"))
	assert_true(GameState.rebuild_rubble(&"rubble_bunker"))
	await get_tree().process_frame
	assert_true(GameState.RES_SCIENCE in hud.get_displayed_resources())
	assert_false(GameState.RES_DNA in hud.get_displayed_resources())

	assert_true(GameState.roll_station_raw_fossil(&"rubble_forge", 1, true))
	await get_tree().process_frame
	assert_true(GameState.RES_RAW_FOSSILS in hud.get_displayed_resources(), "Fóssil bruto na fila deve aparecer no HUD")
	GameState._tick_passive_income(45.0)
	await get_tree().process_frame
	assert_false(GameState.RES_RAW_FOSSILS in hud.get_displayed_resources(), "Fóssil bruto deve sumir do HUD após limpeza")

	# 6b) Ativação de todos os 14 recursos de superfície (3 biomas) alterna HUD para 2 linhas compactas sem legado.
	var row_bottom: Control = hud.get_node("%RowBottom") as Control
	assert_false(row_bottom.visible, "Com <= 7 recursos o HUD usa uma única linha espaçosa")
	for res_id: StringName in [
		GameState.RES_FEATHERS, GameState.RES_METAL, GameState.RES_SCALES, GameState.RES_BEAKS,
		GameState.RES_WOOD, GameState.RES_BERRIES, GameState.RES_RESIN,
		GameState.RES_ICE, GameState.RES_CRYSTALS, GameState.RES_AMBER,
	]:
		GameState.add_resource(res_id, 10.0)
	assert_true(GameState.roll_station_raw_fossil(&"rubble_forge", 1, true))
	await get_tree().process_frame
	await get_tree().process_frame
	var all_displayed: Array[StringName] = hud.get_displayed_resources()
	assert_eq(all_displayed.size(), 14, "HUD deve exibir exatamente os 14 recursos ativos dos 3 biomas")
	assert_true(row_bottom.visible, "Com >= 8 recursos o HUD deve ativar a segunda linha compacta")
	assert_false(GameState.RES_BONES in all_displayed)
	assert_false(GameState.RES_MINERALS in all_displayed)
	assert_false(GameState.RES_DNA in all_displayed)

	# 7) Novo jogo reseta HUD de volta para apenas Rochas zerado em linha única.
	GameState.start_new_game()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(hud.get_displayed_resources(), [GameState.RES_ROCKS])
	assert_false(row_bottom.visible, "Reset deve retornar HUD para linha única")
	var reset_rocks_chip: Control = hud.get_resource_chip(GameState.RES_ROCKS)
	assert_not_null(reset_rocks_chip)
	assert_eq((reset_rocks_chip.get_node("Readout/Balance/AmountLabel") as Label).text, "0")
	assert_false((reset_rocks_chip.get_node("Readout/Balance/RateLabel") as Label).visible)

	SaveManager.autosave_enabled = prev_autosave
