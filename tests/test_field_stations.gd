extends GutTest

var _autosave: bool


func before_each() -> void:
	_autosave = SaveManager.autosave_enabled
	SaveManager.autosave_enabled = false
	GameState.start_new_game()


func after_each() -> void:
	SaveManager.autosave_enabled = _autosave


func test_initial_station_state_only_pedreira_built_and_zero_workers() -> void:
	assert_eq(GameState.current_biome, GameState.BIOME_AMBER, "Jogo deve iniciar na Bacia do Âmbar")
	assert_eq(GameState.RUBBLE_ORDER.size(), 8, "Devem existir exatamente 8 estruturas nos 3 biomas")
	assert_eq(GameState.get_rubble_level(&"rubble_forge"), 1, "Pedreira deve iniciar construída no Nv. 1")
	assert_true(GameState.is_station_built(&"rubble_forge"))
	assert_false(GameState.has_station_worker(&"rubble_forge"), "Pedreira deve iniciar sem dinossauro trabalhador")
	assert_almost_eq(GameState.get_station_rate(&"rubble_forge"), 0.0, 0.0001)

	# Valida custos iniciais mais difíceis/lentos de progressão.
	assert_almost_eq(GameState.get_station_worker_cost(&"rubble_forge"), 65.0, 0.001)
	assert_almost_eq(GameState.get_rubble_cost(&"rubble_nest"), 120.0, 0.001)
	assert_almost_eq(GameState.get_rubble_cost(&"rubble_silo"), 420.0, 0.001)
	assert_almost_eq(GameState.get_rubble_cost(&"rubble_bunker"), 1100.0, 0.001)
	assert_eq(GameState.get_rubble_cost_resource(&"forest_grove"), GameState.RES_METAL)
	assert_eq(GameState.get_rubble_cost_resource(&"forest_sanctuary"), GameState.RES_SCALES)
	assert_eq(GameState.get_rubble_cost_resource(&"snow_glacier"), GameState.RES_BEAKS)
	assert_eq(GameState.get_rubble_cost_resource(&"snow_observatory"), GameState.RES_RESIN)

	for unbuilt: StringName in [
		&"rubble_nest", &"rubble_silo", &"rubble_bunker",
		&"forest_grove", &"forest_sanctuary", &"snow_glacier", &"snow_observatory",
	]:
		assert_eq(GameState.get_rubble_level(unbuilt), 0, "%s deve iniciar não construída" % unbuilt)
		assert_false(GameState.is_station_built(unbuilt))
		assert_false(GameState.has_station_worker(unbuilt))
		assert_almost_eq(GameState.get_station_rate(unbuilt), 0.0, 0.0001)

	# Verifica legendas e estado visual dos marcos (FieldLandmark) antes e depois de construir.
	var packed: PackedScene = load("res://scenes/surface/SurfaceScene.tscn") as PackedScene
	var surface: SurfaceScene = add_child_autofree(packed.instantiate()) as SurfaceScene
	await get_tree().process_frame
	var forge_spot: FieldLandmark = surface.get_node("%Map/rubble_forge") as FieldLandmark
	var nest_spot: FieldLandmark = surface.get_node("%Map/rubble_nest") as FieldLandmark
	var silo_spot: FieldLandmark = surface.get_node("%Map/rubble_silo") as FieldLandmark
	var bunker_spot: FieldLandmark = surface.get_node("%Map/rubble_bunker") as FieldLandmark
	assert_false(forge_spot.tooltip_text.contains("(Construir)"), "Pedreira já nasce construída")
	assert_true(nest_spot.tooltip_text.contains("(Construir)"), "Pesqueiro não construído deve exibir (Construir)")
	assert_true(silo_spot.tooltip_text.contains("(Construir)"), "Torre não construída deve exibir (Construir)")
	assert_true(bunker_spot.tooltip_text.contains("(Construir)"), "Universidade não construída deve exibir (Construir)")

	GameState.add_resource(GameState.RES_ROCKS, GameState.get_rubble_cost(&"rubble_nest"))
	assert_true(GameState.rebuild_rubble(&"rubble_nest"))
	await get_tree().process_frame
	assert_false(nest_spot.tooltip_text.contains("(Construir)"), "Pesqueiro construído deve remover (Construir)")


func test_two_step_unlock_manual_farm_hire_worker_and_expand() -> void:
	Events.orange_rock_hit.emit(20.0, Vector2.ZERO)
	assert_true(GameState.orange_rock_broken)
	assert_almost_eq(GameState.get_resource(GameState.RES_ROCKS), 5.0, 0.001, "Chocar o ovo deve conceder exatamente 5 Rochas")
	assert_false(GameState.can_hire_station_worker(&"rubble_forge"), "5 Rochas iniciais não devem bastar para contratar trabalhador (65)")
	assert_false(GameState.can_rebuild_rubble(&"rubble_nest"), "5 Rochas iniciais não devem bastar para construir Pesqueiro (120)")

	# Farm manual deve bloquear em estruturas não construídas (todos os 3 biomas).
	for unbuilt: StringName in [
		&"rubble_nest", &"rubble_silo", &"rubble_bunker",
		&"forest_grove", &"forest_sanctuary", &"snow_glacier", &"snow_observatory",
	]:
		var prod: StringName = GameState.RUBBLE_DEFS[unbuilt]["product"] as StringName
		var before_locked: float = GameState.get_resource(prod)
		var locked_out: Dictionary = GameState.hero_farm_action(unbuilt)
		assert_eq(locked_out.get("kind", &""), &"locked", "Farm manual deve falhar enquanto %s não está construída" % unbuilt)
		assert_almost_eq(GameState.get_resource(prod), before_locked, 0.0001)

	# Universidade deve produzir Ciência (NUNCA DNA).
	var uni_def: Dictionary = GameState.RUBBLE_DEFS[&"rubble_bunker"] as Dictionary
	assert_eq(uni_def["product"], GameState.RES_SCIENCE)
	assert_eq(uni_def["tier2_product"], GameState.RES_SCIENCE)

	for station: StringName in GameState.RUBBLE_ORDER:
		var def: Dictionary = GameState.RUBBLE_DEFS[station] as Dictionary
		var gear: StringName = def["gear"] as StringName
		var product: StringName = def["product"] as StringName

		assert_false(GameState.is_upgrade_unlocked(gear), "Equipamento %s deve iniciar bloqueado" % gear)
		assert_almost_eq(GameState.get_station_rate(station), 0.0, 0.0001)

		if not GameState.is_station_built(station):
			assert_false(GameState.can_hire_station_worker(station))
			var build_res: StringName = GameState.get_rubble_cost_resource(station)
			GameState.add_resource(build_res, GameState.get_rubble_cost(station))
			assert_true(GameState.rebuild_rubble(station), "Deve construir %s com %s" % [station, build_res])

		# Passo 1 completo (construída), mas sem trabalhador: sem produção passiva, sem expansão e sem equipamento.
		assert_true(GameState.is_station_built(station))
		assert_false(GameState.has_station_worker(station))
		assert_almost_eq(GameState.get_station_rate(station), 0.0, 0.0001)
		assert_false(GameState.is_upgrade_unlocked(gear), "%s só libera após recrutar o dinossauro" % gear)
		var expand_res: StringName = GameState.get_rubble_cost_resource(station)
		GameState.add_resource(expand_res, GameState.get_rubble_cost(station))
		assert_false(GameState.can_rebuild_rubble(station), "Expansão de %s exige trabalhador contratado" % station)

		# Farm manual agora funciona na estrutura construída e não gera RES_BONES.
		var bones_before: float = GameState.get_resource(GameState.RES_BONES)
		var prog_before: float = GameState.run_surface_progress
		var prod_before: float = GameState.get_resource(product)
		var farm_out: Dictionary = GameState.hero_farm_action(station)
		assert_eq(farm_out.get("kind", &""), &"farm")
		assert_eq(farm_out.get("product", &""), product)
		assert_gt(GameState.get_resource(product), prod_before)
		assert_gt(GameState.run_surface_progress, prog_before)
		assert_almost_eq(GameState.get_resource(GameState.RES_BONES), bones_before, 0.0001, "Farm na superfície não deve gerar Ossos")

		# Passo 2: recrutar o dinossauro trabalhador gastando o recurso da própria estrutura.
		var worker_cost: float = GameState.get_station_worker_cost(station)
		GameState.add_resource(product, worker_cost)
		var stock_before_hire: float = GameState.get_resource(product)
		assert_true(GameState.can_hire_station_worker(station))
		assert_true(GameState.hire_station_worker(station))
		assert_true(GameState.has_station_worker(station))
		assert_almost_eq(GameState.get_resource(product), stock_before_hire - worker_cost, 0.001)
		assert_gt(GameState.get_station_rate(station), 0.0, "Trabalhador em %s deve ativar produção passiva" % station)
		assert_true(GameState.is_upgrade_unlocked(gear), "Recrutar trabalhador em %s deve liberar %s" % [station, gear])
		assert_true(GameState.can_rebuild_rubble(station), "Recrutar trabalhador em %s deve liberar ampliação" % station)

		# Produção passiva e equipamento especialista (+25% local exato).
		var dna_before: float = GameState.get_resource(GameState.RES_DNA)
		var previous: float = GameState.get_resource(product)
		GameState._tick_passive_income(30.0)
		var expected_gain: float = GameState.get_station_rate(station) * 30.0
		assert_almost_eq(GameState.get_resource(product) - previous, expected_gain, 0.02)
		if station == &"rubble_bunker":
			assert_gt(GameState.get_resource(GameState.RES_SCIENCE) - previous, 0.0)
			assert_almost_eq(GameState.get_resource(GameState.RES_DNA) - dna_before, GameState.get_dna_per_second() * 30.0, 0.01)

		var gear_cost: float = GameState.get_purchase_cost(gear, 1)
		GameState.add_resource(product, gear_cost)
		var stock_before_gear: float = GameState.get_resource(product)
		var old_rate: float = GameState.get_station_rate(station)
		assert_true(GameState.purchase_upgrade(gear, 1))
		assert_almost_eq(GameState.get_resource(product), stock_before_gear - gear_cost, 0.001)
		assert_eq(GameState.get_upgrade_level(gear), 1)
		assert_almost_eq(GameState.get_station_rate(station), old_rate * 1.25, 0.001)


func test_unique_and_maxed_upgrades_stay_visible_dimmed_and_unlock_next_tier() -> void:
	Events.orange_rock_hit.emit(20.0, Vector2.ZERO)
	var packed: PackedScene = load("res://scenes/surface/SurfaceScene.tscn") as PackedScene
	var surface: SurfaceScene = add_child_autofree(packed.instantiate()) as SurfaceScene
	await get_tree().process_frame

	# 1) Construção e recrutamento no Pesqueiro ficam apagados ("Comprado") e liberam próximos cards.
	surface.move_hero_to_station(&"rubble_nest")
	await get_tree().process_frame
	var action_btn: Button = surface.get_node("%ToDigSiteButton") as Button
	assert_true(action_btn.disabled, "Botão de farm manual deve ficar desabilitado em estrutura não construída")
	assert_false(surface.is_item_card_dimmed(SurfaceScene.ITEM_BUILD_STATION))
	assert_null(surface.get_item_card(SurfaceScene.ITEM_HIRE_WORKER))

	GameState.add_resource(GameState.RES_ROCKS, GameState.get_rubble_cost(&"rubble_nest"))
	await get_tree().process_frame
	var build_btn: Button = surface.get_item_buy_button(SurfaceScene.ITEM_BUILD_STATION)
	assert_not_null(build_btn)
	assert_false(build_btn.disabled)
	build_btn.pressed.emit()
	await get_tree().process_frame

	assert_true(GameState.is_station_built(&"rubble_nest"))
	var build_card: PanelContainer = surface.get_item_card(SurfaceScene.ITEM_BUILD_STATION)
	assert_not_null(build_card, "Card de construir deve permanecer visível no estado apagado")
	assert_true(surface.is_item_card_dimmed(SurfaceScene.ITEM_BUILD_STATION))
	assert_eq(build_card.modulate, SurfaceScene.DIMMED_MODULATE)
	var build_btn_after: Button = surface.get_item_buy_button(SurfaceScene.ITEM_BUILD_STATION)
	assert_true(build_btn_after.disabled)
	assert_eq(build_btn_after.text, "Comprado")
	assert_null(build_btn_after.icon)
	assert_not_null(surface.get_item_card(SurfaceScene.ITEM_HIRE_WORKER), "Construir estrutura deve liberar card do trabalhador")
	assert_false(action_btn.disabled, "Botão de farm manual deve habilitar após construir estrutura")

	GameState.add_resource(GameState.RES_FISH, GameState.get_station_worker_cost(&"rubble_nest"))
	await get_tree().process_frame
	var hire_btn: Button = surface.get_item_buy_button(SurfaceScene.ITEM_HIRE_WORKER)
	assert_not_null(hire_btn)
	assert_false(hire_btn.disabled)
	hire_btn.pressed.emit()
	await get_tree().process_frame

	assert_true(GameState.has_station_worker(&"rubble_nest"))
	assert_true(surface.is_item_card_dimmed(SurfaceScene.ITEM_HIRE_WORKER), "Card do trabalhador recrutado deve ficar apagado")
	assert_true(surface.get_item_buy_button(SurfaceScene.ITEM_HIRE_WORKER).disabled)
	assert_not_null(surface.get_item_card(SurfaceScene.ITEM_EXPAND_STATION), "Recrutar trabalhador deve liberar Ampliar posto")
	assert_not_null(surface.get_item_card(&"field_fins"), "Recrutar trabalhador deve liberar equipamento especialista")

	# 2) Upgrades únicos (max_level == 1) na aba Pedreira ficam apagados e liberam o próximo upgrade da cadeia.
	surface.move_hero_to_station(&"rubble_forge")
	surface.select_section(&"upgrades")
	await get_tree().process_frame
	assert_not_null(surface.get_item_card(&"tools_sharp_pickaxe"))
	assert_null(surface.get_item_card(&"tools_fine_brush"), "Pincel Fino só aparece após Picareta Afiada")

	GameState.add_resource(GameState.RES_ROCKS, 500.0)
	await get_tree().process_frame
	surface.get_item_buy_button(&"tools_sharp_pickaxe").pressed.emit()
	await get_tree().process_frame
	assert_not_null(surface.get_item_card(&"tools_fine_brush"), "Comprar Picareta Afiada deve liberar Pincel Fino")
	assert_null(surface.get_item_card(&"tools_geologist_lens"))

	surface.get_item_buy_button(&"tools_fine_brush").pressed.emit()
	await get_tree().process_frame
	assert_eq(GameState.get_upgrade_level(&"tools_fine_brush"), 1)
	var brush_card: PanelContainer = surface.get_item_card(&"tools_fine_brush")
	assert_not_null(brush_card, "Upgrade único comprado deve permanecer visível em estado apagado")
	assert_true(surface.is_item_card_dimmed(&"tools_fine_brush"))
	assert_eq(brush_card.modulate, SurfaceScene.DIMMED_MODULATE)
	var brush_btn: Button = surface.get_item_buy_button(&"tools_fine_brush")
	assert_true(brush_btn.disabled)
	assert_eq(brush_btn.text, "Comprado")
	assert_null(brush_btn.icon)
	assert_not_null(surface.get_item_card(&"tools_geologist_lens"), "Comprar Pincel Fino deve liberar Lupa de Geólogo")

	surface.get_item_buy_button(&"tools_geologist_lens").pressed.emit()
	await get_tree().process_frame
	assert_true(surface.is_item_card_dimmed(&"tools_geologist_lens"))
	assert_not_null(surface.get_item_card(&"tools_diamond_chisel"), "Comprar Lupa de Geólogo deve liberar Cinzel de Diamante")


func test_offline_stock_migration_and_prestige() -> void:
	var old: Dictionary = {"version": 3, "game": {"resources": {"rocks": 50, "amber": 2}, "rubble_levels": {"rubble_nest": 2}}}
	var migrated: Dictionary = SaveManager._migrate(old)
	GameState.load_save_dict(migrated["game"] as Dictionary)
	assert_eq(migrated["version"], SaveManager.SAVE_VERSION)
	assert_eq(GameState.current_biome, GameState.BIOME_AMBER)
	assert_eq(GameState.get_rubble_level(&"rubble_nest"), 2)
	assert_true(GameState.has_station_worker(&"rubble_nest"), "Migração v3→v6 deve preservar trabalhador em estação já construída")
	assert_eq(GameState.get_rubble_level(&"rubble_forge"), 1)
	assert_eq(GameState.get_resource(GameState.RES_FISH), 0.0)
	var expected_fish: float = GameState.get_station_rate(&"rubble_nest") * 100.0 * GameState.get_offline_efficiency()
	var gains: Dictionary = GameState.apply_offline_progress(100.0)
	assert_almost_eq(float(gains[GameState.RES_FISH]), expected_fish, 0.001)
	GameState.add_resource(GameState.RES_FISH, GameState.get_purchase_cost(&"field_fins", 1))
	assert_true(GameState.purchase_upgrade(&"field_fins", 1))
	var remaining: float = GameState.get_resource(GameState.RES_FISH)
	GameState.set_current_biome(GameState.BIOME_FOREST)
	var saved: Dictionary = GameState.to_save_dict()
	GameState.start_new_game()
	GameState.load_save_dict(saved)
	assert_eq(GameState.current_biome, GameState.BIOME_FOREST)
	assert_almost_eq(GameState.get_resource(GameState.RES_FISH), remaining, 0.001)
	assert_eq(GameState.get_upgrade_level(&"field_fins"), 1)
	assert_true(GameState.has_station_worker(&"rubble_nest"))
	GameState.perform_prestige()
	assert_eq(GameState.current_biome, GameState.BIOME_AMBER, "Prestígio deve retornar à Bacia do Âmbar")
	assert_eq(GameState.get_rubble_level(&"rubble_forge"), 1)
	assert_eq(GameState.get_rubble_level(&"rubble_nest"), 0)
	assert_false(GameState.has_station_worker(&"rubble_forge"))
	assert_false(GameState.has_station_worker(&"rubble_nest"))
	assert_eq(GameState.get_resource(GameState.RES_FISH), 0.0)
	assert_eq(GameState.get_upgrade_level(&"field_fins"), 0)


func test_buy_from_world_and_reach_every_upgrade_and_species() -> void:
	# Constrói todas as 8 estações dos 3 biomas, recruta trabalhadores e desbloqueia pré-requisitos.
	for station: StringName in GameState.RUBBLE_ORDER:
		GameState.rubble_levels[station] = maxi(GameState.get_rubble_level(station), 1)
		GameState.station_worker_unlocked[station] = true
	for upg_val: Variant in GameState.upgrades_db.values():
		var upg: UpgradeData = upg_val as UpgradeData
		if upg.required_upgrade != &"":
			GameState.upgrade_levels[upg.required_upgrade] = maxi(GameState.get_upgrade_level(upg.required_upgrade), upg.required_level)
	GameState.recalculate_stats()

	var packed: PackedScene = load("res://scenes/surface/SurfaceScene.tscn") as PackedScene
	var surface: SurfaceScene = add_child_autofree(packed.instantiate()) as SurfaceScene
	await get_tree().process_frame
	var visited: Dictionary = {}
	var revive_species: Dictionary = {}
	for station: StringName in GameState.RUBBLE_ORDER:
		var r_dino: StringName = GameState.get_station_revive_dino_id(station)
		if r_dino != &"":
			revive_species[r_dino] = true
		surface.move_hero_to_station(station)
		var groups: HBoxContainer = surface.get_node("%Groups") as HBoxContainer
		for child: Node in groups.get_children():
			var btn: Button = child as Button
			assert_ne(btn.name, "species", "Aba legada 'species' (Ossos) não deve mais existir")
			assert_eq(btn.text, "", "Aba %s deve usar somente ícone minimalista sem texto" % btn.name)
			btn.pressed.emit()
			for item: StringName in surface._items:
				if btn.name != "fossils" and GameState.get_upgrade(item) != null:
					assert_false(visited.has(item), "Upgrade duplicado em dois locais: %s" % item)
					visited[item] = true
	assert_eq(visited.size(), GameState.upgrades_db.size(), "Todos os 46 upgrades do catálogo devem aparecer na UI das 8 estruturas")
	assert_eq(revive_species.size(), GameState.dinos_db.size(), "Todas as 8 espécies devem ser revivíveis via estruturas dos 3 biomas")

	# Testa compra real no mundo (construir Pesqueiro + abrir laboratório Âmbar vindo de outro bioma).
	GameState.start_new_game()
	GameState.add_resource(GameState.RES_ROCKS, GameState.get_rubble_cost(&"rubble_nest"))
	surface.move_hero_to_station(&"rubble_nest")
	await get_tree().process_frame
	var build_btn: Button = surface.get_item_buy_button(SurfaceScene.ITEM_BUILD_STATION)
	assert_not_null(build_btn)
	build_btn.pressed.emit()
	assert_eq(GameState.get_rubble_level(&"rubble_nest"), 1)
	GameState.set_current_biome(GameState.BIOME_SNOW)
	Events.station_research_requested.emit()
	assert_eq(GameState.current_biome, GameState.BIOME_AMBER)
	assert_eq(surface._section, &"amber")
	assert_eq(surface._site, &"rubble_bunker")


func test_click_does_not_teleport_and_wasd_opens_floating_bench_under_station() -> void:
	Events.orange_rock_hit.emit(20.0, Vector2.ZERO)
	assert_true(GameState.orange_rock_broken)
	assert_almost_eq(GameState.get_resource(GameState.RES_ROCKS), 5.0, 0.001, "Chocar o ovo deve render exatamente 5 Rochas")

	# Constrói estruturas da Bacia do Âmbar para testar o farm específico ao caminhar com WASD.
	for station: StringName in [&"rubble_nest", &"rubble_silo", &"rubble_bunker"]:
		GameState.add_resource(GameState.RES_ROCKS, GameState.get_rubble_cost(station))
		assert_true(GameState.rebuild_rubble(station))

	var packed: PackedScene = load("res://scenes/surface/SurfaceScene.tscn") as PackedScene
	var surface: SurfaceScene = add_child_autofree(packed.instantiate()) as SurfaceScene
	await get_tree().process_frame
	var dock: Control = surface.get_node("%Dock") as Control
	assert_false(dock.visible, "Janela flutuante deve ficar oculta longe das estruturas")

	# Clicar diretamente em uma estrutura NÃO deve teleportar o dinossauro nem abrir a janela.
	var initial_pos: Vector2 = surface._hero_map_pos
	(surface.get_node("%Map/rubble_forge") as Button).pressed.emit()
	assert_eq(surface._site, &"")
	assert_eq(GameState.hero_station, &"")
	assert_false(dock.visible)
	assert_eq(surface._hero_map_pos, initial_pos)

	# Caminha com WASD até cada estação: janela flutuante abre e permite farm específico.
	var targets: Array[Dictionary] = [
		{"station": &"rubble_forge", "res": GameState.RES_ROCKS},
		{"station": &"rubble_nest", "res": GameState.RES_FISH},
		{"station": &"rubble_silo", "res": GameState.RES_FEATHERS},
		{"station": &"rubble_bunker", "res": GameState.RES_SCIENCE},
	]
	for entry: Dictionary in targets:
		var station: StringName = entry["station"] as StringName
		var res_id: StringName = entry["res"] as StringName
		var target_pos: Vector2 = SurfaceScene.SITES[station] as Vector2
		for _step: int in range(30):
			var delta_vec: Vector2 = target_pos - surface._hero_map_pos
			if delta_vec.length() <= 6.0:
				break
			surface.move_hero_by_vector(delta_vec, 0.1)
		assert_eq(GameState.hero_station, station)
		assert_eq(surface._site, station)
		assert_true(dock.visible, "Janela flutuante deve abrir ao chegar perto de %s" % station)

		var before: float = GameState.get_resource(res_id)
		var out: Dictionary = GameState.hero_farm_action(station)
		assert_eq(out.get("product", &""), res_id)
		assert_gt(GameState.get_resource(res_id), before)

	# Afasta-se das estruturas: janela flutuante fecha novamente.
	for _step: int in range(30):
		var back_vec: Vector2 = (SurfaceScene.SITES[&"egg"] as Vector2) - surface._hero_map_pos
		if back_vec.length() <= 6.0:
			break
		surface.move_hero_by_vector(back_vec, 0.1)
	assert_eq(GameState.hero_station, &"")
	assert_false(dock.visible)


func test_raw_fossils_40s_university_tab_and_revive_spawns_dino_in_origin_station() -> void:
	# Chance base 1 em 1000 (0.001), limpeza base 40.0s e flash de fóssil 2.8s.
	assert_almost_eq(GameState.BASE_RAW_FOSSIL_CHANCE, 0.001, 0.00001)
	assert_almost_eq(GameState.BASE_FOSSIL_CLEAN_SECONDS, 40.0, 0.0001)
	assert_almost_eq(GameState.STATION_FOSSIL_FLASH_DURATION, 2.8, 0.0001)
	assert_almost_eq(GameState.get_raw_fossil_find_chance(&"rubble_forge"), 0.001, 0.00001)

	Events.orange_rock_hit.emit(20.0, Vector2.ZERO)

	# Encontra fóssil bruto na Pedreira -> entra na fila da Universidade com aviso visual por 2.8s.
	assert_true(GameState.roll_station_raw_fossil(&"rubble_forge", 1, true))
	assert_eq(GameState.raw_fossil_queue.size(), 1)
	assert_eq(GameState.raw_fossil_queue[0], &"ankylosaurus")
	assert_almost_eq(GameState.get_resource(GameState.RES_RAW_FOSSILS), 1.0, 0.001)
	assert_almost_eq(GameState.get_station_fossil_flash(&"rubble_forge"), 2.8, 0.01)

	# Sem Universidade construída, limpeza não avança.
	assert_almost_eq(GameState.get_university_cleaning_speed(), 0.0, 0.0001)
	GameState._tick_passive_income(40.0)
	assert_eq(GameState.raw_fossil_queue.size(), 1)

	# Constrói Universidade (1100 Rochas, sem trabalhador e sem herói nela): duração base exata de 40.0s.
	GameState.add_resource(GameState.RES_ROCKS, GameState.get_rubble_cost(&"rubble_bunker"))
	assert_true(GameState.rebuild_rubble(&"rubble_bunker"))
	assert_almost_eq(GameState.get_university_cleaning_speed(), 1.0, 0.0001)
	assert_almost_eq(GameState.get_university_clean_duration(), 40.0, 0.0001)

	GameState._tick_passive_income(20.0)
	assert_eq(GameState.raw_fossil_queue.size(), 1, "Em 20s (metade de 40s) o fóssil ainda está limpando")
	assert_almost_eq(GameState.fossil_cleaning_progress, 0.5, 0.01)
	assert_almost_eq(GameState.get_university_clean_remaining_seconds(), 20.0, 0.1)

	GameState._tick_passive_income(19.0)
	assert_eq(GameState.raw_fossil_queue.size(), 1, "Em 39s o fóssil ainda não concluiu os 40s base")

	# Abre a aba Fósseis da Universidade e valida ícone do dino + ProgressBar.
	var packed: PackedScene = load("res://scenes/surface/SurfaceScene.tscn") as PackedScene
	var surface: SurfaceScene = add_child_autofree(packed.instantiate()) as SurfaceScene
	await get_tree().process_frame
	surface.move_hero_to_station(&"rubble_bunker")
	surface.select_section(&"fossils")
	await get_tree().process_frame

	var qty_btn: Button = surface.get_node("%Quantity") as Button
	assert_false(qty_btn.visible, "Botão de lote deve ficar oculto na aba Fósseis")
	var items_list: VBoxContainer = surface.get_node("%ItemsList") as VBoxContainer
	var row0: Control = items_list.get_node_or_null("FossilRow_0") as Control
	assert_not_null(row0, "Aba Fósseis deve exibir o fóssil bruto em limpeza")
	var icon_rect: TextureRect = row0.get_node("Margin/Row/IconSlot/Icon") as TextureRect
	var clean_bar: ProgressBar = row0.get_node("Margin/Row/Info/CleanProgress") as ProgressBar
	var status_lbl: Label = row0.get_node("Margin/Row/Info/Header/StatusLabel") as Label
	assert_not_null(icon_rect.texture, "Linha do fóssil deve exibir o ícone do dinossauro")
	assert_gt(clean_bar.value, 90.0)
	assert_lt(clean_bar.value, 100.0)
	assert_true(status_lbl.text.contains("Limpeza:"), "Status deve indicar limpeza em andamento")

	# Conclui os 40s: fóssil desaparece da aba Fósseis e incrementa os fósseis limpos.
	GameState._tick_passive_income(2.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(GameState.raw_fossil_queue.size(), 0)
	assert_almost_eq(GameState.get_resource(GameState.RES_RAW_FOSSILS), 0.0, 0.001)
	assert_null(items_list.get_node_or_null("FossilRow_0"), "Fóssil concluído deve desaparecer da aba Fósseis")
	var ankylo_frags: int = GameState.get_fragments(&"ankylosaurus")
	assert_gte(ankylo_frags, 1)

	# Na aba Universidade (upgrades), surge o card de revive com contador limpos / 10.
	surface.select_section(&"upgrades")
	await get_tree().process_frame
	var revive_origin_id: StringName = StringName(SurfaceScene.REVIVE_ORIGIN_PREFIX + "rubble_forge")
	var revive_card: PanelContainer = surface.get_item_card(revive_origin_id)
	assert_not_null(revive_card, "Fóssil limpo deve aparecer na aba de upgrades com contagem limpos / 10")
	var desc_lbl: Label = revive_card.get_node("Margin/Row/Info/Description") as Label
	assert_true(desc_lbl.text.contains("%d / 10" % ankylo_frags), "Descrição deve mostrar fósseis limpos / 10")

	# Completa 10 fósseis limpos + contrata trabalhador na Pedreira -> compra revive (×2.5 produção + Metal!).
	GameState.add_resource(GameState.RES_ROCKS, GameState.get_station_worker_cost(&"rubble_forge") + GameState.get_station_revive_cost(&"rubble_forge"))
	assert_true(GameState.hire_station_worker(&"rubble_forge"))
	GameState.add_fragments(&"ankylosaurus", maxi(10 - ankylo_frags, 0))
	await get_tree().process_frame
	assert_true(GameState.can_revive_station_dino(&"rubble_forge"))
	var base_rate_before: float = GameState.get_station_rate(&"rubble_forge")
	var revive_btn: Button = surface.get_item_buy_button(revive_origin_id)
	assert_not_null(revive_btn)
	assert_false(revive_btn.disabled)
	revive_btn.pressed.emit()
	await get_tree().process_frame

	assert_eq(GameState.get_station_revived_count(&"rubble_forge"), 1, "Comprar revive deve gerar o novo dinossauro na estrutura de origem")
	assert_eq(GameState.get_dino_count(&"ankylosaurus"), 1)
	assert_almost_eq(GameState.get_station_rate(&"rubble_forge"), base_rate_before * 2.5, 0.01, "Reviver Anquilossauro deve multiplicar produção da Pedreira por 2.5x")
	assert_gt(GameState.get_station_tier2_rate(&"rubble_forge"), 0.0)

	var metal_before: float = GameState.get_resource(GameState.RES_METAL)
	GameState._tick_passive_income(4.0)
	assert_gt(GameState.get_resource(GameState.RES_METAL), metal_before)

	# Novo recurso Metal compra Picareta de Metal Puro.
	GameState.add_resource(GameState.RES_METAL, GameState.get_purchase_cost(&"tools_metal_pick", 1))
	assert_true(GameState.purchase_upgrade(&"tools_metal_pick", 1))
	assert_eq(GameState.get_upgrade_level(&"tools_metal_pick"), 1)


func test_audio_sliders_and_museum_removed() -> void:
	var modals_packed: PackedScene = load("res://scenes/ui/SaveModals.tscn") as PackedScene
	var modals: SaveModals = add_child_autofree(modals_packed.instantiate()) as SaveModals
	await get_tree().process_frame
	modals.open_settings()
	var reset_btn: Button = modals.get_node("%ResetButton") as Button
	assert_true(reset_btn.is_visible_in_tree(), "Botão de resetar save deve estar visível nas configurações")
	var sfx_slider: HSlider = modals.get_node("%SfxSlider") as HSlider
	var music_slider: HSlider = modals.get_node("%MusicSlider") as HSlider
	sfx_slider.value = 35.0
	music_slider.value = 60.0
	assert_almost_eq(GameState.sfx_volume, 0.35, 0.01)
	assert_almost_eq(GameState.music_volume, 0.60, 0.01)

	# Museu completamente removido do projeto, de Main.tscn, do HUD e de Events.gd.
	assert_false(ResourceLoader.exists("res://scenes/ui/FossilMuseum.tscn"))
	assert_false(FileAccess.file_exists("res://scenes/ui/FossilMuseum.gd"))
	assert_false(Events.has_signal(&"museum_modal_requested"))
	var main_src: String = FileAccess.get_file_as_string("res://scenes/main/Main.tscn")
	assert_false(main_src.contains("FossilMuseum"), "Main.tscn não pode referenciar FossilMuseum")
	assert_almost_eq(GameState.get_museum_collection_multiplier(), 1.0, 0.0001)

	# register_fossil_found ainda emite Events.fossil_found para SFX sem UI de Museu.
	watch_signals(Events)
	GameState.register_fossil_found(&"trex", 3)
	assert_signal_emitted_with_parameters(Events, "fossil_found", [&"trex", 3])

	var hud_packed: PackedScene = load("res://scenes/ui/HUD.tscn") as PackedScene
	var hud: HUD = add_child_autofree(hud_packed.instantiate()) as HUD
	await get_tree().process_frame
	assert_null(hud.get_node_or_null("%MuseumButton"), "HUD não deve conter MuseumButton")
	Events.layer_resources_extracted.emit(0, 10.0, 2.0)
	var toast_lbl: Label = hud.get_node("%ToastLabel") as Label
	assert_false(toast_lbl.text.contains("Camada rompida"), "Não deve exibir toast de camada rompida")

	Events.orange_rock_hit.emit(20.0, Vector2.ZERO)
	var surface_packed: PackedScene = load("res://scenes/surface/SurfaceScene.tscn") as PackedScene
	var surface: SurfaceScene = add_child_autofree(surface_packed.instantiate()) as SurfaceScene
	await get_tree().process_frame
	surface.move_hero_to_station(&"rubble_forge")
	await get_tree().process_frame
	var hire_btn: Button = surface.get_item_buy_button(SurfaceScene.ITEM_HIRE_WORKER)
	assert_not_null(hire_btn, "Botão de recrutamento deve existir na Pedreira")
	assert_not_null(hire_btn.icon, "Botão de compra deve exibir ícone do recurso consumido")
	var hp_before: float = GameState.layer_hp
	GameState.hero_farm_action(&"rubble_forge")
	assert_almost_eq(GameState.layer_hp, hp_before, 0.001, "Farmar na superfície não deve causar dano na camada de escavação")


func test_all_upgrades_use_valid_surface_or_amber_resources_and_active_surface_stats() -> void:
	var valid_currencies: Array[StringName] = [
		GameState.RES_ROCKS,
		GameState.RES_FISH,
		GameState.RES_FEATHERS,
		GameState.RES_SCIENCE,
		GameState.RES_METAL,
		GameState.RES_SCALES,
		GameState.RES_BEAKS,
		GameState.RES_WOOD,
		GameState.RES_BERRIES,
		GameState.RES_RESIN,
		GameState.RES_ICE,
		GameState.RES_CRYSTALS,
		GameState.RES_AMBER,
	]
	var forbidden_currencies: Array[StringName] = [
		GameState.RES_BONES,
		GameState.RES_MINERALS,
		GameState.RES_DNA,
	]
	var valid_stats: Array[StringName] = [
		GameState.STAT_MANUAL_YIELD,
		GameState.STAT_STATION_YIELD,
		GameState.STAT_TIER2_YIELD,
		GameState.STAT_FOSSIL_LUCK,
		GameState.STAT_CLEANING_SPEED,
		GameState.STAT_CLEAN_DOUBLE_CHANCE,
		GameState.STAT_METEOR_SHIELD,
		GameState.STAT_METEOR_TIME,
		GameState.STAT_AMBER_MULT,
		GameState.STAT_OFFLINE_MULT,
	]
	var forbidden_stats: Array[StringName] = [
		GameState.STAT_CLICK_DAMAGE,
		GameState.STAT_DINO_DAMAGE,
		GameState.STAT_DINO_EVO_MULT,
		GameState.STAT_BONES_MULT,
		GameState.STAT_AUTO_DPS,
		GameState.STAT_MINERAL_CHANCE,
		GameState.STAT_FRAGMENT_CHANCE,
		GameState.STAT_DNA_MULT,
	]

	assert_null(GameState.get_upgrade(&"dinos_apex_jaw"), "Upgrade obsoleto dinos_apex_jaw deve estar removido")
	assert_null(GameState.get_upgrade(&"dinos_primal_fury"), "Upgrade obsoleto dinos_primal_fury deve estar removido")

	for upg: Variant in GameState.upgrades_db.values():
		var data: UpgradeData = upg as UpgradeData
		assert_false(String(data.id).begins_with("machines_"), "ID de máquina não deve existir (%s)" % data.id)
		assert_false(data.cost_resource in forbidden_currencies, "Upgrade %s não pode custar recurso legado (%s)" % [data.id, data.cost_resource])
		assert_true(data.cost_resource in valid_currencies, "Upgrade %s deve custar recurso válido de superfície/âmbar (%s)" % [data.id, data.cost_resource])
		assert_false(data.stat_id in forbidden_stats, "Upgrade %s não pode usar stat obsoleto de DigSite (%s)" % [data.id, data.stat_id])
		assert_true(data.stat_id in valid_stats, "Upgrade %s deve usar stat ativo de superfície (%s)" % [data.id, data.stat_id])
		if not data.is_permanent:
			assert_eq(data.required_era_index, 0, "Upgrade de superfície %s não deve depender de era subterrânea" % data.id)

	var lens: UpgradeData = GameState.get_upgrade(&"field_lens")
	assert_not_null(lens)
	assert_eq(lens.cost_resource, GameState.RES_SCIENCE)
	assert_eq(lens.stat_id, GameState.STAT_CLEANING_SPEED)

	# Testa a compra encadeada dos upgrades de Bacia do Âmbar, Floresta e Neve.
	var checks: Array[Dictionary] = [
		{"id": &"dinos_sky_scouts", "res": GameState.RES_FEATHERS},
		{"id": &"dinos_fish_banquet", "res": GameState.RES_FEATHERS},
		{"id": &"dinos_paleo_treatise", "res": GameState.RES_SCIENCE},
		{"id": &"uni_cleaning_speed", "res": GameState.RES_SCIENCE},
		{"id": &"uni_fossil_luck", "res": GameState.RES_SCIENCE},
		{"id": &"uni_clean_double", "res": GameState.RES_SCIENCE},
		{"id": &"tools_metal_pick", "res": GameState.RES_METAL},
		{"id": &"dinos_scale_armor", "res": GameState.RES_SCALES},
		{"id": &"dinos_beak_talons", "res": GameState.RES_BEAKS},
		{"id": &"forest_sawmill_blades", "res": GameState.RES_WOOD},
		{"id": &"forest_amber_sap", "res": GameState.RES_WOOD},
		{"id": &"forest_resin_refinery", "res": GameState.RES_RESIN},
		{"id": &"forest_berry_tonic", "res": GameState.RES_BERRIES},
		{"id": &"snow_cryo_drill", "res": GameState.RES_ICE},
		{"id": &"snow_aurora_beacon", "res": GameState.RES_CRYSTALS},
	]
	for item: Dictionary in checks:
		var upg_id: StringName = item["id"] as StringName
		var res_id: StringName = item["res"] as StringName
		assert_not_null(GameState.get_upgrade(upg_id))
		var cost: float = GameState.get_purchase_cost(upg_id, 1)
		GameState.add_resource(res_id, cost)
		assert_true(GameState.purchase_upgrade(upg_id, 1), "Deve comprar %s usando %s" % [upg_id, res_id])
		assert_eq(GameState.get_upgrade_level(upg_id), 1)


func test_meteor_drawn_in_basin_background_not_foreground_overlay() -> void:
	var basin_src: String = FileAccess.get_file_as_string("res://scenes/surface/BasinLandscape.gd")
	var sky_idx: int = basin_src.find("draw_texture_rect(SKY,")
	var meteor_idx: int = basin_src.find("_draw_background_meteor(danger)")
	var ridge_idx: int = basin_src.find("draw_texture_rect(RIDGES,")
	var ground_idx: int = basin_src.find("draw_colored_polygon(_ground_shape,")
	assert_gt(sky_idx, -1, "BasinLandscape deve desenhar a camada de céu")
	assert_gt(meteor_idx, sky_idx, "O meteoro deve aparecer sobre o céu")
	assert_gt(ridge_idx, meteor_idx, "As serras devem ficar na frente do meteoro")
	assert_gt(ground_idx, ridge_idx, "O chão deve ficar na frente do relevo")

	var overlay_src: String = FileAccess.get_file_as_string("res://scenes/meteor/MeteorOverlay.gd")
	assert_true(overlay_src.contains("if _current_scenario != &\"dig_site\":"), "MeteorOverlay não deve desenhar meteoro em primeiro plano na superfície")
	assert_false(overlay_src.contains("thermal"), "MeteorOverlay não deve desenhar brilho térmico sobre janelas/HUD")

	# Exercita renderização em todos os 3 biomas sob múltiplos danger_levels sem erros.
	var surface_packed: PackedScene = load("res://scenes/surface/SurfaceScene.tscn") as PackedScene
	var surface: SurfaceScene = add_child_autofree(surface_packed.instantiate()) as SurfaceScene
	var overlay_packed: PackedScene = load("res://scenes/meteor/MeteorOverlay.tscn") as PackedScene
	var overlay: MeteorOverlay = add_child_autofree(overlay_packed.instantiate()) as MeteorOverlay
	await get_tree().process_frame
	for biome: StringName in GameState.BIOME_ORDER:
		GameState.set_current_biome(biome)
		for d: float in [0.0, 0.35, 0.75, 1.0]:
			GameState._set_danger_level(d)
			(surface.get_node("%Map") as Control).queue_redraw()
			(overlay.get_node("%MeteorSkyCanvas") as Control).queue_redraw()
			await get_tree().process_frame
	assert_true(surface.is_inside_tree())
	assert_true(overlay.is_inside_tree())


func test_custom_dino_pixel_art_sprites_and_icons() -> void:
	for dino_id: StringName in [&"compsognathus", &"pterodactyl", &"pachycephalosaurus"]:
		var tex: Texture2D = AmberTheme.get_dino_sprite(dino_id)
		assert_not_null(tex, "Sprite %s deve existir em assets/sprites" % dino_id)
		var img: Image = tex.get_image()
		assert_not_null(img)
		assert_lt(img.get_pixel(0, 0).a, 0.05, "Fundo de %s deve ser transparente" % dino_id)
	var ptero_data: DinoData = GameState.get_dino(&"pterodactyl")
	assert_not_null(ptero_data)
	assert_not_null(ptero_data.sprite, "pterodactyl.tres deve apontar para o sprite")

	# Verifica ícones dos 5 novos recursos de Floresta e Neve.
	for new_res: StringName in [
		GameState.RES_WOOD, GameState.RES_BERRIES, GameState.RES_RESIN,
		GameState.RES_ICE, GameState.RES_CRYSTALS,
	]:
		var res_icon: Texture2D = AmberTheme.get_resource_icon(new_res)
		assert_not_null(res_icon, "Ícone de recurso %s deve existir" % new_res)
		assert_eq(res_icon.get_size(), Vector2(24.0, 24.0), "Ícone de %s deve ser 24x24" % new_res)

	var packed: PackedScene = load("res://scenes/surface/SurfaceScene.tscn") as PackedScene
	var surface: SurfaceScene = add_child_autofree(packed.instantiate()) as SurfaceScene
	await get_tree().process_frame
	assert_eq(surface._get_worker_icon(&"rubble_forge"), AmberTheme.get_dino_sprite(&"pachycephalosaurus"))
	assert_eq(surface._get_worker_icon(&"rubble_silo"), AmberTheme.get_dino_sprite(&"pterodactyl"))
	for station: StringName in [&"rubble_nest", &"rubble_bunker"]:
		assert_true(surface._get_worker_icon(station) is AtlasTexture, "O posto deve mostrar o sprite do seu especialista")
	for biome_station: StringName in [&"forest_grove", &"forest_sanctuary", &"snow_glacier", &"snow_observatory"]:
		assert_not_null(StationWorkerArt.get_icon(biome_station), "Ícone do trabalhador de %s deve existir" % biome_station)

	# Exercita as poses dos trabalhadores base e revividos em todos os 8 postos nos 3 biomas.
	for station: StringName in GameState.RUBBLE_ORDER:
		GameState.rubble_levels[station] = 1
		GameState.station_worker_unlocked[station] = true
		GameState.station_revived_dinos[station] = 1
	Events.orange_rock_hit.emit(20.0, Vector2.ZERO)
	for biome: StringName in GameState.BIOME_ORDER:
		GameState.set_current_biome(biome)
		await get_tree().process_frame
	surface.move_hero_to_station(&"rubble_forge")
	surface._on_field_action_pressed()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(surface._hero_action_timer, 0.0)


func test_hero_avatar_size_clean_sprite_and_4frame_walk_animation() -> void:
	# 1) Tamanho +20% (125px) e zero texto/anel/caixas ao redor do Compsognato.
	assert_almost_eq(SurfaceScene.HeroAvatar.DRAW_WIDTH, 125.0, 0.001, "Herói deve ser +20% maior (draw_w == 125.0)")
	var surface_src: String = FileAccess.get_file_as_string("res://scenes/surface/SurfaceScene.gd")
	var hero_start: int = surface_src.find("class HeroAvatar:")
	var hero_end: int = surface_src.find("class CardRow:")
	assert_gt(hero_start, -1)
	assert_gt(hero_end, hero_start)
	var hero_code: String = surface_src.substr(hero_start, hero_end - hero_start)
	assert_false(hero_code.contains("draw_string"), "HeroAvatar não pode desenhar texto ao redor do dinossauro")
	assert_false(hero_code.contains("draw_arc"), "HeroAvatar não pode desenhar anel/círculo ao redor do dinossauro")
	assert_false(hero_code.contains("draw_rect("), "HeroAvatar não pode desenhar caixas/sombras extras ao redor do dinossauro")
	assert_false(hero_code.contains("draw_circle"), "HeroAvatar não pode desenhar círculos ao redor do dinossauro")
	assert_true(hero_code.contains("draw_texture_rect_region(walk_sheet"), "HeroAvatar deve usar draw_texture_rect_region na spritesheet de caminhada")
	assert_true(hero_code.contains("draw_texture_rect(idle_sprite"), "HeroAvatar deve usar sprite parado distinto quando ocioso")

	# 2) Spritesheet de caminhada 4 frames (472x47), transparente e com quadros distintos entre si e do idle.
	var idle_tex: Texture2D = AmberTheme.get_dino_sprite(&"compsognathus")
	var walk_tex: Texture2D = AmberTheme.get_compsognathus_walk_sheet()
	assert_not_null(idle_tex)
	assert_not_null(walk_tex, "compsognathus_walk.png deve carregar via AmberTheme.get_compsognathus_walk_sheet()")
	var idle_img: Image = idle_tex.get_image()
	var walk_img: Image = walk_tex.get_image()
	assert_eq(walk_img.get_width(), idle_img.get_width() * 4, "Walk sheet deve ter 4 quadros horizontais (472px)")
	assert_eq(walk_img.get_height(), idle_img.get_height(), "Altura da walk sheet deve bater com idle (47px)")

	var cell_w: int = idle_img.get_width()
	var cell_h: int = idle_img.get_height()
	for f_idx: int in range(4):
		var x0: int = f_idx * cell_w
		assert_lt(walk_img.get_pixel(x0, 0).a, 0.05, "Canto superior esquerdo do frame %d deve ser transparente" % f_idx)
		assert_lt(walk_img.get_pixel(x0 + cell_w - 1, 0).a, 0.05, "Canto superior direito do frame %d deve ser transparente" % f_idx)

	# Confirma que os quadros de caminhada são distintos entre si e distintos do sprite idle.
	for f_a: int in range(4):
		var diff_from_idle: int = 0
		for y: int in range(cell_h):
			for x: int in range(cell_w):
				if walk_img.get_pixel(f_a * cell_w + x, y) != idle_img.get_pixel(x, y):
					diff_from_idle += 1
		assert_gt(diff_from_idle, 25, "Frame %d da caminhada deve ser visualmente distinto do idle" % f_a)
		for f_b: int in range(f_a + 1, 4):
			var diff_pair: int = 0
			for y: int in range(cell_h):
				for x: int in range(cell_w):
					if walk_img.get_pixel(f_a * cell_w + x, y) != walk_img.get_pixel(f_b * cell_w + x, y):
						diff_pair += 1
			assert_gt(diff_pair, 25, "Frames %d e %d da caminhada devem diferir entre si" % [f_a, f_b])

	# 3) Exercita renderização ociosa vs caminhando no SurfaceScene real.
	Events.orange_rock_hit.emit(20.0, Vector2.ZERO)
	var packed: PackedScene = load("res://scenes/surface/SurfaceScene.tscn") as PackedScene
	var surface: SurfaceScene = add_child_autofree(packed.instantiate()) as SurfaceScene
	await get_tree().process_frame
	assert_not_null(surface._hero_avatar)
	assert_eq(surface._hero_avatar.size, Vector2(196.0, 112.0))
	assert_false(surface._hero_avatar.walking)
	surface._hero_avatar.queue_redraw()
	await get_tree().process_frame
	surface.move_hero_by_vector(Vector2.RIGHT, 0.1)
	assert_true(surface._hero_avatar.walking)
	for p: float in [0.0, 0.12, 0.24, 0.36]:
		surface._hero_avatar.phase = p
		surface._hero_avatar.queue_redraw()
		await get_tree().process_frame


func test_fossil_found_block_texture_and_overlay_text_duration() -> void:
	# 1) Textura fossil_found_block.png 48x48 com cantos transparentes e arte no centro.
	var fossil_tex: Texture2D = AmberTheme.get_fossil_found_texture()
	assert_not_null(fossil_tex, "fossil_found_block.png deve carregar via AmberTheme.get_fossil_found_texture()")
	var img: Image = fossil_tex.get_image()
	assert_eq(img.get_width(), 48)
	assert_eq(img.get_height(), 48)
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(47, 0), Vector2i(0, 47), Vector2i(47, 47)]:
		assert_lt(img.get_pixel(corner.x, corner.y).a, 0.05, "Canto %s de fossil_found_block.png deve ser transparente" % corner)
	var opaque_center: int = 0
	for y: int in range(12, 36):
		for x: int in range(12, 36):
			if img.get_pixel(x, y).a > 0.8:
				opaque_center += 1
	assert_gt(opaque_center, 300, "Centro de fossil_found_block.png deve conter arte opaca nítida")

	# 2) FieldLandmark._draw_fossil_badge usa a textura e exibe "Fóssil Encontrado!" acima dela.
	var landmark_src: String = FileAccess.get_file_as_string("res://scenes/surface/FieldLandmark.gd")
	var badge_idx: int = landmark_src.find("func _draw_fossil_badge(")
	assert_gt(badge_idx, -1)
	var badge_code: String = landmark_src.substr(badge_idx)
	assert_true(badge_code.contains("AmberTheme.get_fossil_found_texture()"), "_draw_fossil_badge deve usar AmberTheme.get_fossil_found_texture()")
	assert_true(badge_code.contains("\"Fóssil Encontrado!\""), "_draw_fossil_badge deve desenhar o texto 'Fóssil Encontrado!'")
	assert_true(badge_code.contains("center.y - block_sz"), "Texto 'Fóssil Encontrado!' deve ficar posicionado acima da animação do fóssil")

	# 3) Flash dura exatamente 2.8s e decai até 0.0.
	assert_almost_eq(GameState.STATION_FOSSIL_FLASH_DURATION, 2.8, 0.001)
	var packed: PackedScene = load("res://scenes/surface/SurfaceScene.tscn") as PackedScene
	var surface: SurfaceScene = add_child_autofree(packed.instantiate()) as SurfaceScene
	await get_tree().process_frame
	assert_true(GameState.roll_station_raw_fossil(&"rubble_forge", 1, true))
	assert_almost_eq(GameState.get_station_fossil_flash(&"rubble_forge"), 2.8, 0.01)
	var forge_spot: FieldLandmark = surface.get_node("%Map/rubble_forge") as FieldLandmark
	forge_spot.queue_redraw()
	await get_tree().process_frame
	GameState._tick_passive_income(1.4)
	assert_gt(GameState.get_station_fossil_flash(&"rubble_forge"), 1.0, "Na metade dos 2.8s o aviso de fóssil ainda deve estar ativo")
	forge_spot.queue_redraw()
	await get_tree().process_frame
	GameState._tick_passive_income(1.6)
	assert_almost_eq(GameState.get_station_fossil_flash(&"rubble_forge"), 0.0, 0.001, "Após ~2.8s o aviso de fóssil deve encerrar")


func test_icon_tabs_minimalist_outline_and_blue_alert_badge() -> void:
	# 1) Todos os 9 ícones de aba são 24x24, fundo transparente e exclusivamente contorno preto minimalista.
	for tab_key: StringName in [&"site", &"tools", &"dinos", &"scouts", &"university", &"fossils", &"amber", &"forest", &"snow"]:
		var icon_tex: Texture2D = AmberTheme.get_tab_icon(tab_key)
		assert_not_null(icon_tex, "Ícone de aba %s deve existir" % tab_key)
		var img: Image = icon_tex.get_image()
		assert_eq(img.get_width(), 24)
		assert_eq(img.get_height(), 24)
		assert_lt(img.get_pixel(0, 0).a, 0.05, "Fundo do ícone de aba %s deve ser transparente" % tab_key)
		var ink_pixels: int = 0
		var colored_pixels: int = 0
		for y: int in range(24):
			for x: int in range(24):
				var px: Color = img.get_pixel(x, y)
				if px.a > 0.1:
					if px.r <= 0.15 and px.g <= 0.15 and px.b <= 0.15:
						ink_pixels += 1
					else:
						colored_pixels += 1
		assert_gt(ink_pixels, 20, "Ícone de aba %s deve ter silhueta visível" % tab_key)
		assert_eq(colored_pixels, 0, "Ícone de aba %s deve ser exclusivamente contorno preto minimalista" % tab_key)

	# 2) Valida botões de aba na Pedreira e disparo preciso do badge azul "!".
	Events.orange_rock_hit.emit(20.0, Vector2.ZERO)
	GameState.spend(GameState.RES_ROCKS, GameState.get_resource(GameState.RES_ROCKS))
	var packed: PackedScene = load("res://scenes/surface/SurfaceScene.tscn") as PackedScene
	var surface: SurfaceScene = add_child_autofree(packed.instantiate()) as SurfaceScene
	await get_tree().process_frame

	surface.move_hero_to_station(&"rubble_forge")
	await get_tree().process_frame
	var groups: HBoxContainer = surface.get_node("%Groups") as HBoxContainer
	for child: Node in groups.get_children():
		var btn: Button = child as Button
		assert_eq(btn.text, "", "Botão de aba %s não deve exibir texto" % btn.name)
		assert_ne(btn.tooltip_text, "", "Botão de aba %s deve ter tooltip descritivo" % btn.name)
		var icon_node: TextureRect = btn.get_node_or_null("Content/Icon") as TextureRect
		var badge_node: Label = btn.get_node_or_null("Content/AlertBadge") as Label
		assert_not_null(icon_node)
		assert_true(icon_node.visible)
		assert_not_null(icon_node.texture)
		assert_not_null(badge_node)
		assert_eq(badge_node.text, "!")
		assert_eq(badge_node.get_theme_color("font_color"), Color("#1488ff"), "Badge '!' deve ser azul (#1488ff)")

	assert_false(surface.is_tab_alert_visible(&"site"), "Sem Rochas, badge '!' da aba Estrutura deve ficar oculto")
	assert_false(surface.is_tab_alert_visible(&"upgrades"), "Sem Rochas, badge '!' da aba Upgrades deve ficar oculto")

	# 45 Rochas: compra tools_sharp_pickaxe (45), mas ainda NÃO compra trabalhador (65).
	GameState.add_resource(GameState.RES_ROCKS, 45.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(surface.is_tab_alert_visible(&"site"), "45 Rochas não pagam trabalhador (65) — badge da aba Estrutura segue oculto")
	assert_true(surface.is_tab_alert_visible(&"upgrades"), "45 Rochas pagam Picareta Afiada — badge azul '!' deve acender em Upgrades")

	# +20 Rochas (65 total): agora trabalhador da Pedreira fica acessível -> badge '!' acende em Estrutura.
	GameState.add_resource(GameState.RES_ROCKS, 20.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(surface.is_tab_alert_visible(&"site"), "65 Rochas pagam Paquicefalossauro — badge azul '!' deve acender em Estrutura")

	# Contrata trabalhador (gasta 65 -> 0 Rochas): ambos badges apagam.
	assert_true(GameState.hire_station_worker(&"rubble_forge"))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(surface.is_tab_alert_visible(&"site"), "Após gastar Rochas, badge '!' de Estrutura deve apagar")
	assert_false(surface.is_tab_alert_visible(&"upgrades"), "Após gastar Rochas, badge '!' de Upgrades deve apagar")

	# 3) Universidade: aba Fósseis nunca acende '!'; Âmbar acende só com saldo; revive 10/10 acende em Upgrades.
	GameState.add_resource(GameState.RES_ROCKS, GameState.get_rubble_cost(&"rubble_bunker"))
	assert_true(GameState.rebuild_rubble(&"rubble_bunker"))
	assert_true(GameState.roll_station_raw_fossil(&"rubble_forge", 1, true))
	surface.move_hero_to_station(&"rubble_bunker")
	await get_tree().process_frame
	await get_tree().process_frame
	assert_false(surface.is_tab_alert_visible(&"fossils"), "Aba Fósseis é fila informativa e não deve exibir badge '!'")
	assert_false(surface.is_tab_alert_visible(&"amber"), "Sem Âmbar, badge da aba Âmbar deve ficar oculto")
	assert_false(surface.is_tab_alert_visible(&"upgrades"), "Sem recursos/fósseis suficientes, aba Upgrades fica sem '!'")

	GameState.add_resource(GameState.RES_AMBER, 5.0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(surface.is_tab_alert_visible(&"amber"), "Com Âmbar suficiente, badge '!' deve acender na aba Âmbar")

	GameState.add_fragments(&"ankylosaurus", 10)
	GameState.add_resource(GameState.RES_ROCKS, GameState.get_station_revive_cost(&"rubble_forge"))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(surface.is_tab_alert_visible(&"upgrades"), "Com 10/10 fósseis + Rochas, badge '!' deve acender na Universidade para reviver")


func test_ground_collision_and_three_biome_transitions() -> void:
	Events.orange_rock_hit.emit(20.0, Vector2.ZERO)
	var packed: PackedScene = load("res://scenes/surface/SurfaceScene.tscn") as PackedScene
	var surface: SurfaceScene = add_child_autofree(packed.instantiate()) as SurfaceScene
	await get_tree().process_frame

	var map: Control = surface.get_node("%Map") as Control
	var basin_name: Label = surface.get_node("Map/BasinName") as Label
	var dock: Control = surface.get_node("%Dock") as Control
	assert_true(map.has_method(&"get_walkable_min_y"))
	assert_true(map.has_method(&"get_walkable_max_y"))

	# 1) Todos os marcos de todos os 3 biomas repousam estritamente dentro do terreno caminhável.
	for biome_key: Variant in SurfaceScene.BIOME_SITES:
		var biome_id: StringName = biome_key as StringName
		var sites_dict: Dictionary = SurfaceScene.BIOME_SITES[biome_id] as Dictionary
		for st_key: Variant in sites_dict:
			var pt: Vector2 = sites_dict[st_key] as Vector2
			var min_y: float = float(map.call(&"get_walkable_min_y", biome_id, pt.x))
			var max_y: float = float(map.call(&"get_walkable_max_y", biome_id, pt.x))
			assert_gte(pt.y, min_y, "Marco %s (%s) deve ficar abaixo da linha de montanha" % [st_key, biome_id])
			assert_lte(pt.y, max_y, "Marco %s (%s) deve ficar acima da borda inferior" % [st_key, biome_id])

	# 2) Empurrar o herói para cima/baixo nos 3 biomas NUNCA o leva ao céu/montanha nem para fora do chão.
	for biome_id: StringName in GameState.BIOME_ORDER:
		GameState.set_current_biome(biome_id)
		await get_tree().process_frame
		for _i: int in range(35):
			surface.move_hero_by_vector(Vector2.UP, 0.1)
		var min_y_up: float = float(map.call(&"get_walkable_min_y", biome_id, surface._hero_map_pos.x))
		assert_gte(surface._hero_map_pos.y, min_y_up - 0.05, "Herói não pode subir para as montanhas/céu em %s" % biome_id)
		for _i: int in range(35):
			surface.move_hero_by_vector(Vector2.DOWN, 0.1)
		var max_y_down: float = float(map.call(&"get_walkable_max_y", biome_id, surface._hero_map_pos.x))
		assert_lte(surface._hero_map_pos.y, max_y_down + 0.05, "Herói não pode cair abaixo da borda do chão em %s" % biome_id)

	# 3) Transição caminhando para esquerda: amber_basin -> forest -> bloqueio na borda esquerda -> volta para amber_basin.
	GameState.set_current_biome(GameState.BIOME_AMBER)
	await get_tree().process_frame
	surface.move_hero_to_station(&"rubble_forge")
	assert_true(dock.visible)
	for _i: int in range(40):
		surface.move_hero_by_vector(Vector2.LEFT, 0.1)
		if GameState.current_biome == GameState.BIOME_FOREST:
			break
	assert_eq(GameState.current_biome, GameState.BIOME_FOREST, "Caminhar à esquerda da Bacia do Âmbar deve entrar na Floresta Ancestral")
	assert_eq(basin_name.text, "Floresta Ancestral")
	assert_false(dock.visible, "Trocar de bioma deve fechar o dock aberto")
	assert_true((surface.get_node("%Map/forest_grove") as Control).visible)
	assert_true((surface.get_node("%Map/forest_sanctuary") as Control).visible)
	assert_false((surface.get_node("%Map/rubble_forge") as Control).visible)
	assert_false((surface.get_node("%Map/snow_glacier") as Control).visible)

	# Continua andando à esquerda na Floresta: borda esquerda bloqueada!
	for _i: int in range(60):
		surface.move_hero_by_vector(Vector2.LEFT, 0.1)
	assert_eq(GameState.current_biome, GameState.BIOME_FOREST, "Borda esquerda da Floresta deve ser fechada")
	assert_gte(surface._hero_map_pos.x, SurfaceScene.EDGE_FOREST_MIN_X - 0.05)

	# Caminha à direita na Floresta: retorna para Bacia do Âmbar!
	for _i: int in range(60):
		surface.move_hero_by_vector(Vector2.RIGHT, 0.1)
		if GameState.current_biome == GameState.BIOME_AMBER:
			break
	assert_eq(GameState.current_biome, GameState.BIOME_AMBER, "Caminhar à direita na Floresta deve retornar à Bacia do Âmbar")
	assert_eq(basin_name.text, "Bacia do Âmbar")

	# 4) Continua caminhando à direita na Bacia do Âmbar: entra em Cordilheira Nevada -> bloqueio direita -> volta!
	for _i: int in range(60):
		surface.move_hero_by_vector(Vector2.RIGHT, 0.1)
		if GameState.current_biome == GameState.BIOME_SNOW:
			break
	assert_eq(GameState.current_biome, GameState.BIOME_SNOW, "Caminhar à direita da Bacia do Âmbar deve entrar na Cordilheira Nevada")
	assert_eq(basin_name.text, "Cordilheira Nevada")
	assert_true((surface.get_node("%Map/snow_glacier") as Control).visible)
	assert_true((surface.get_node("%Map/snow_observatory") as Control).visible)
	assert_false((surface.get_node("%Map/rubble_forge") as Control).visible)
	assert_false((surface.get_node("%Map/forest_grove") as Control).visible)

	# Continua andando à direita na Neve: borda direita bloqueada!
	for _i: int in range(60):
		surface.move_hero_by_vector(Vector2.RIGHT, 0.1)
	assert_eq(GameState.current_biome, GameState.BIOME_SNOW, "Borda direita da Neve deve ser fechada")
	assert_lte(surface._hero_map_pos.x, SurfaceScene.EDGE_SNOW_MAX_X + 0.05)

	# Caminha à esquerda na Neve: retorna para Bacia do Âmbar!
	for _i: int in range(60):
		surface.move_hero_by_vector(Vector2.LEFT, 0.1)
		if GameState.current_biome == GameState.BIOME_AMBER:
			break
	assert_eq(GameState.current_biome, GameState.BIOME_AMBER, "Caminhar à esquerda na Neve deve retornar à Bacia do Âmbar")


func test_forest_and_snow_full_lifecycle_and_revive_milestones() -> void:
	Events.orange_rock_hit.emit(20.0, Vector2.ZERO)
	# Constrói Universidade para limpar fósseis dos novos biomas e testa bônus global do Braquiossauro.
	GameState.add_resource(GameState.RES_ROCKS, GameState.get_rubble_cost(&"rubble_bunker"))
	assert_true(GameState.rebuild_rubble(&"rubble_bunker"))
	var clean_speed_before: float = GameState.get_university_cleaning_speed()
	var global_mult_before: float = GameState.get_global_revive_station_multiplier()
	GameState.add_fragments(&"brachiosaurus", 10)
	GameState.add_resource(GameState.RES_SCIENCE, GameState.get_station_revive_cost(&"rubble_bunker"))
	assert_true(GameState.revive_station_dino(&"rubble_bunker"))
	assert_almost_eq(GameState.get_university_cleaning_speed(), clean_speed_before + 0.60, 0.01, "Braquiossauro deve conceder +60% velocidade de limpeza")
	assert_almost_eq(GameState.get_global_revive_station_multiplier(), global_mult_before + 0.35, 0.01, "Braquiossauro deve conceder +35% produção global")

	# Exige recursos Tier-2 para construir estruturas de Floresta e Neve (14 Metal não basta para forest_grove que custa 15).
	GameState.add_resource(GameState.RES_METAL, 14.0)
	assert_false(GameState.can_rebuild_rubble(&"forest_grove"), "Bosque das Sequoias exige exatamente 15 Metal")
	GameState.add_resource(GameState.RES_METAL, 1.0)
	assert_true(GameState.rebuild_rubble(&"forest_grove"))

	GameState.add_resource(GameState.RES_SCALES, 18.0)
	assert_true(GameState.rebuild_rubble(&"forest_sanctuary"))

	GameState.add_resource(GameState.RES_BEAKS, 18.0)
	assert_true(GameState.rebuild_rubble(&"snow_glacier"))

	GameState.add_resource(GameState.RES_RESIN, 25.0)
	assert_true(GameState.rebuild_rubble(&"snow_observatory"))

	# Ciclo completo em todas as 4 estações de Floresta e Neve: farm -> worker -> fóssil -> limpeza -> revive!
	var specs: Array[Dictionary] = [
		{"station": &"forest_grove", "product": GameState.RES_WOOD, "dino": &"triceratops", "mult": 2.5, "tier2": GameState.RES_RESIN},
		{"station": &"forest_sanctuary", "product": GameState.RES_BERRIES, "dino": &"trex", "mult": 2.5, "tier2": GameState.RES_BERRIES},
		{"station": &"snow_glacier", "product": GameState.RES_ICE, "dino": &"pterodactyl", "mult": 2.5, "tier2": GameState.RES_CRYSTALS},
		{"station": &"snow_observatory", "product": GameState.RES_CRYSTALS, "dino": &"compsognathus", "mult": 3.0, "tier2": GameState.RES_CRYSTALS},
	]
	for spec: Dictionary in specs:
		var st: StringName = spec["station"] as StringName
		var prod: StringName = spec["product"] as StringName
		var dino: StringName = spec["dino"] as StringName
		var expected_mult: float = float(spec["mult"])
		var tier2_res: StringName = spec["tier2"] as StringName

		var before_farm: float = GameState.get_resource(prod)
		var out: Dictionary = GameState.hero_farm_action(st)
		assert_eq(out.get("kind", &""), &"farm")
		assert_gt(GameState.get_resource(prod), before_farm)

		GameState.add_resource(prod, GameState.get_station_worker_cost(st))
		assert_true(GameState.hire_station_worker(st))
		var rate_before_revive: float = GameState.get_station_rate(st)
		var global_before: float = GameState.get_global_revive_station_multiplier()
		var shield_before: float = GameState.get_shield_ratio()
		GameState.run_surface_progress = 500000.0
		var amber_before: float = GameState.calculate_amber_reward()

		# Encontra fóssil bruto na estação e limpa na Universidade (fila limpa antes para teste determinístico).
		GameState.raw_fossil_queue.clear()
		GameState.fossil_cleaning_progress = 0.0
		assert_true(GameState.roll_station_raw_fossil(st, 1, true))
		assert_eq(GameState.raw_fossil_queue[0], dino)
		GameState._tick_passive_income(45.0)
		assert_gte(GameState.get_fragments(dino), 1, "Limpeza deve produzir fóssil limpo de %s" % dino)

		# Completa 10/10 e revive!
		var missing: int = maxi(10 - GameState.get_fragments(dino), 0)
		if missing > 0:
			GameState.add_fragments(dino, missing)
		GameState.add_resource(prod, GameState.get_station_revive_cost(st))
		assert_true(GameState.revive_station_dino(st), "Deve reviver %s em %s" % [dino, st])

		var global_ratio: float = GameState.get_global_revive_station_multiplier() / global_before
		assert_almost_eq(
			GameState.get_station_rate(st),
			rate_before_revive * expected_mult * global_ratio,
			0.05,
			"Reviver em %s deve conceder >= %.1fx produção" % [st, expected_mult]
		)
		assert_gt(GameState.get_station_tier2_rate(st), 0.0, "Reviver em %s deve liberar produção Tier-2 (%s)" % [st, tier2_res])

		if st == &"forest_sanctuary":
			assert_almost_eq(GameState.get_global_revive_station_multiplier(), global_before + 0.50, 0.01, "T-Rex deve dar +50% produção global")
		if st == &"snow_observatory":
			assert_almost_eq(GameState.get_shield_ratio(), minf(shield_before + 0.15, 1.0), 0.01, "Compsognato Ártico deve dar +15% escudo")
			assert_gt(GameState.calculate_amber_reward(), amber_before * 1.45, "Compsognato Ártico deve aumentar recompensa de Âmbar em +50%")
