extends GutTest

var _autosave: bool


func before_each() -> void:
	_autosave = SaveManager.autosave_enabled
	SaveManager.autosave_enabled = false
	GameState.start_new_game()


func after_each() -> void:
	SaveManager.autosave_enabled = _autosave


func test_initial_station_state_only_pedreira_built_and_zero_workers() -> void:
	assert_eq(GameState.get_rubble_level(&"rubble_forge"), 1, "Pedreira deve iniciar construída no Nv. 1")
	assert_true(GameState.is_station_built(&"rubble_forge"))
	assert_false(GameState.has_station_worker(&"rubble_forge"), "Pedreira deve iniciar sem dinossauro trabalhador")
	assert_almost_eq(GameState.get_station_rate(&"rubble_forge"), 0.0, 0.0001)

	for unbuilt: StringName in [&"rubble_nest", &"rubble_silo", &"rubble_bunker"]:
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

	# Farm manual deve bloquear em estruturas não construídas.
	for unbuilt: StringName in [&"rubble_nest", &"rubble_silo", &"rubble_bunker"]:
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
			GameState.add_resource(GameState.RES_ROCKS, GameState.get_rubble_cost(station))
			assert_true(GameState.rebuild_rubble(station), "Deve construir %s com Rochas" % station)

		# Passo 1 completo (construída), mas sem trabalhador: sem produção passiva, sem expansão e sem equipamento.
		assert_true(GameState.is_station_built(station))
		assert_false(GameState.has_station_worker(station))
		assert_almost_eq(GameState.get_station_rate(station), 0.0, 0.0001)
		assert_false(GameState.is_upgrade_unlocked(gear), "%s só libera após recrutar o dinossauro" % gear)
		GameState.add_resource(GameState.RES_ROCKS, GameState.get_rubble_cost(station))
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

		# Produção passiva e equipamento especialista.
		var dna_before: float = GameState.get_resource(GameState.RES_DNA)
		var previous: float = GameState.get_resource(product)
		GameState._tick_passive_income(30.0)
		var expected_gain: float = GameState.get_station_rate(station) * 30.0
		assert_almost_eq(GameState.get_resource(product) - previous, expected_gain, 0.01)
		if station == &"rubble_bunker":
			assert_gt(GameState.get_resource(GameState.RES_SCIENCE) - previous, 0.0)
			# Universidade nunca deve adicionar DNA além da taxa passiva natural de dinos (compsognathus = 0.05/s).
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

	# 2) Upgrades únicos (max_level == 1) na aba Ferramentas ficam apagados e liberam o próximo upgrade da cadeia.
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
	assert_eq(GameState.get_rubble_level(&"rubble_nest"), 2)
	assert_true(GameState.has_station_worker(&"rubble_nest"), "Migração v3→v5 deve preservar trabalhador em estação já construída")
	assert_eq(GameState.get_rubble_level(&"rubble_forge"), 1)
	assert_eq(GameState.get_resource(GameState.RES_FISH), 0.0)
	var expected_fish: float = GameState.get_station_rate(&"rubble_nest") * 100.0 * GameState.get_offline_efficiency()
	var gains: Dictionary = GameState.apply_offline_progress(100.0)
	assert_almost_eq(float(gains[GameState.RES_FISH]), expected_fish, 0.001)
	assert_true(GameState.purchase_upgrade(&"field_fins", 1))
	var remaining: float = GameState.get_resource(GameState.RES_FISH)
	var saved: Dictionary = GameState.to_save_dict()
	GameState.start_new_game()
	GameState.load_save_dict(saved)
	assert_almost_eq(GameState.get_resource(GameState.RES_FISH), remaining, 0.001)
	assert_eq(GameState.get_upgrade_level(&"field_fins"), 1)
	assert_true(GameState.has_station_worker(&"rubble_nest"))
	GameState.perform_prestige()
	assert_eq(GameState.get_rubble_level(&"rubble_forge"), 1)
	assert_eq(GameState.get_rubble_level(&"rubble_nest"), 0)
	assert_false(GameState.has_station_worker(&"rubble_forge"))
	assert_false(GameState.has_station_worker(&"rubble_nest"))
	assert_eq(GameState.get_resource(GameState.RES_FISH), 0.0)
	assert_eq(GameState.get_upgrade_level(&"field_fins"), 0)


func test_buy_from_world_and_reach_every_upgrade_and_species() -> void:
	# Constrói todas as estações, recruta todos os trabalhadores e desbloqueia pré-requisitos para inspecionar o catálogo inteiro na UI.
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
	var species: Dictionary = {}
	for station: StringName in GameState.RUBBLE_ORDER:
		surface.move_hero_to_station(station)
		var groups: HBoxContainer = surface.get_node("%Groups") as HBoxContainer
		for child: Node in groups.get_children():
			(child as Button).pressed.emit()
			for item: StringName in surface._items:
				if child.name == "species":
					species[item] = true
				elif child.name != "fossils" and GameState.get_upgrade(item) != null:
					assert_false(visited.has(item), "Equipamento em dois locais: %s" % item)
					visited[item] = true
	assert_eq(visited.size(), GameState.upgrades_db.size(), "Todos os upgrades do catálogo devem aparecer na UI das estruturas")
	assert_eq(species.size(), GameState.dinos_db.size(), "Todas as espécies devem aparecer na Incubadora")

	# Testa compra real no mundo (construir Pesqueiro + abrir laboratório Âmbar via evento).
	GameState.start_new_game()
	GameState.add_resource(GameState.RES_ROCKS, GameState.get_rubble_cost(&"rubble_nest"))
	surface.move_hero_to_station(&"rubble_nest")
	await get_tree().process_frame
	var build_btn: Button = surface.get_item_buy_button(SurfaceScene.ITEM_BUILD_STATION)
	assert_not_null(build_btn)
	build_btn.pressed.emit()
	assert_eq(GameState.get_rubble_level(&"rubble_nest"), 1)
	Events.station_research_requested.emit()
	assert_eq(surface._section, &"amber")
	assert_eq(surface._site, &"rubble_bunker")


func test_click_does_not_teleport_and_wasd_opens_floating_bench_under_station() -> void:
	Events.orange_rock_hit.emit(20.0, Vector2.ZERO)
	assert_true(GameState.orange_rock_broken)
	assert_gte(GameState.get_resource(GameState.RES_ROCKS), 15.0, "Chocar o ovo deve render ao menos 15 Rochas")

	# Constrói todas as estruturas para testar o farm específico ao caminhar com WASD.
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
	# Chance base 1 em 1000 (0.001) e limpeza base de exatamente 40.0s.
	assert_almost_eq(GameState.BASE_RAW_FOSSIL_CHANCE, 0.001, 0.00001)
	assert_almost_eq(GameState.BASE_FOSSIL_CLEAN_SECONDS, 40.0, 0.0001)
	assert_almost_eq(GameState.get_raw_fossil_find_chance(&"rubble_forge"), 0.001, 0.00001)

	Events.orange_rock_hit.emit(20.0, Vector2.ZERO)

	# Encontra fóssil bruto na Pedreira -> entra na fila da Universidade com brilho dourado.
	assert_true(GameState.roll_station_raw_fossil(&"rubble_forge", 1, true))
	assert_eq(GameState.raw_fossil_queue.size(), 1)
	assert_eq(GameState.raw_fossil_queue[0], &"ankylosaurus")
	assert_almost_eq(GameState.get_resource(GameState.RES_RAW_FOSSILS), 1.0, 0.001)
	assert_gt(GameState.get_station_fossil_flash(&"rubble_forge"), 0.0)

	# Sem Universidade construída, limpeza não avança.
	assert_almost_eq(GameState.get_university_cleaning_speed(), 0.0, 0.0001)
	GameState._tick_passive_income(40.0)
	assert_eq(GameState.raw_fossil_queue.size(), 1)

	# Constrói Universidade (sem trabalhador e sem herói nela): duração base exata de 40.0s.
	GameState.add_resource(GameState.RES_ROCKS, 500.0)
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

	# Completa 10 fósseis limpos + contrata trabalhador na Pedreira -> compra revive e spawna o Anquilossauro na Pedreira!
	GameState.add_resource(GameState.RES_ROCKS, 500.0)
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
	assert_gt(GameState.get_station_rate(&"rubble_forge"), base_rate_before)
	assert_gt(GameState.get_station_tier2_rate(&"rubble_forge"), 0.0)

	var metal_before: float = GameState.get_resource(GameState.RES_METAL)
	GameState._tick_passive_income(4.0)
	assert_gt(GameState.get_resource(GameState.RES_METAL), metal_before)

	# Novo recurso Metal compra Picareta de Metal Puro.
	GameState.add_resource(GameState.RES_METAL, 10.0)
	assert_true(GameState.purchase_upgrade(&"tools_metal_pick", 1))
	assert_eq(GameState.get_upgrade_level(&"tools_metal_pick"), 1)


func test_audio_sliders_and_silent_museum_notifications() -> void:
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

	var museum_packed: PackedScene = load("res://scenes/ui/FossilMuseum.tscn") as PackedScene
	var museum: FossilMuseum = add_child_autofree(museum_packed.instantiate()) as FossilMuseum
	await get_tree().process_frame
	GameState.register_fossil_found(&"trex", 3)
	var laudo: Control = museum.get_node("%LaudoCard") as Control
	assert_false(laudo.visible, "Notificação de fóssil no canto inferior direito deve ficar desativada")

	var hud_packed: PackedScene = load("res://scenes/ui/HUD.tscn") as PackedScene
	var hud: HUD = add_child_autofree(hud_packed.instantiate()) as HUD
	await get_tree().process_frame
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


func test_all_upgrades_use_valid_surface_or_amber_resources_and_no_machines() -> void:
	var valid_currencies: Array[StringName] = [
		GameState.RES_ROCKS,
		GameState.RES_FISH,
		GameState.RES_FEATHERS,
		GameState.RES_SCIENCE,
		GameState.RES_METAL,
		GameState.RES_SCALES,
		GameState.RES_BEAKS,
		GameState.RES_AMBER,
	]
	var forbidden_currencies: Array[StringName] = [
		GameState.RES_BONES,
		GameState.RES_MINERALS,
		GameState.RES_DNA,
	]
	for upg: Variant in GameState.upgrades_db.values():
		var data: UpgradeData = upg as UpgradeData
		assert_ne(data.stat_id, GameState.STAT_AUTO_DPS, "Não deve haver upgrades de máquinas (%s)" % data.id)
		assert_false(String(data.id).begins_with("machines_"), "ID de máquina não deve existir (%s)" % data.id)
		assert_false(data.cost_resource in forbidden_currencies, "Upgrade %s não pode custar recurso legado (%s)" % [data.id, data.cost_resource])
		assert_true(data.cost_resource in valid_currencies, "Upgrade %s deve custar recurso válido de superfície/âmbar (%s)" % [data.id, data.cost_resource])
		if not data.is_permanent:
			assert_eq(data.required_era_index, 0, "Upgrade de superfície %s não deve depender de era subterrânea" % data.id)

	var lens: UpgradeData = GameState.get_upgrade(&"field_lens")
	assert_not_null(lens)
	assert_eq(lens.cost_resource, GameState.RES_SCIENCE)
	assert_eq(lens.stat_id, GameState.STAT_CLEANING_SPEED)

	# Testa a compra encadeada dos upgrades de campo/superfície.
	var checks: Array[Dictionary] = [
		{"id": &"dinos_sky_scouts", "res": GameState.RES_FEATHERS},
		{"id": &"dinos_fish_banquet", "res": GameState.RES_FISH},
		{"id": &"dinos_paleo_treatise", "res": GameState.RES_SCIENCE},
		{"id": &"uni_cleaning_speed", "res": GameState.RES_SCIENCE},
		{"id": &"uni_fossil_luck", "res": GameState.RES_SCIENCE},
		{"id": &"uni_clean_double", "res": GameState.RES_SCIENCE},
		{"id": &"tools_metal_pick", "res": GameState.RES_METAL},
		{"id": &"dinos_scale_armor", "res": GameState.RES_SCALES},
		{"id": &"dinos_beak_talons", "res": GameState.RES_BEAKS},
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
	var meteor_call_idx: int = basin_src.find("_draw_background_meteor(")
	var first_ridge_idx: int = basin_src.find("_ridge(")
	assert_gt(meteor_call_idx, -1, "BasinLandscape deve desenhar o meteoro ao fundo")
	assert_gt(first_ridge_idx, -1)
	assert_lt(meteor_call_idx, first_ridge_idx, "Meteoro deve ser desenhado ANTES das montanhas e elementos de frente")

	var overlay_src: String = FileAccess.get_file_as_string("res://scenes/meteor/MeteorOverlay.gd")
	assert_true(overlay_src.contains("if _current_scenario != &\"dig_site\":"), "MeteorOverlay não deve desenhar meteoro em primeiro plano na superfície")
	assert_false(overlay_src.contains("thermal"), "MeteorOverlay não deve desenhar brilho térmico sobre janelas/HUD")

	# Exercita ambos em cena real sob múltiplos danger_levels sem erros.
	var surface_packed: PackedScene = load("res://scenes/surface/SurfaceScene.tscn") as PackedScene
	var surface: SurfaceScene = add_child_autofree(surface_packed.instantiate()) as SurfaceScene
	var overlay_packed: PackedScene = load("res://scenes/meteor/MeteorOverlay.tscn") as PackedScene
	var overlay: MeteorOverlay = add_child_autofree(overlay_packed.instantiate()) as MeteorOverlay
	await get_tree().process_frame
	for d: float in [0.0, 0.35, 0.75, 1.0]:
		GameState._set_danger_level(d)
		(surface.get_node("%Map") as Control).queue_redraw()
		(overlay.get_node("%MeteorSkyCanvas") as Control).queue_redraw()
		await get_tree().process_frame
	assert_true(surface.is_inside_tree())
	assert_true(overlay.is_inside_tree())
