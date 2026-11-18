@warning_ignore_start("unsafe_method_access", "unsafe_property_access")
extends SceneTree
## Suíte Automatizada de Testes & Regressão (QA) do Fóssil Rush.
## Execução: Godot_v4.7.1-stable_win64_console.exe --headless -s res://tests/run_tests.gd
##
## Cobre:
##   1. Integridade dos bancos de dados (.tres: dinos, upgrades, eras).
##   2. Matemática de compra em lote (1x, 10x, 100x, Máx) e marcos de dinos.
##   3. Sinergias únicas dos 8 papéis, carryover de overkill, drops e veios especiais.
##   4. Prestígio (reset vs permanência) e vitória Projeto Arca (GDD §7).
##   5. Serialização JSON, Export/Import Base64 e ganhos offline sem avançar meteoro.
##   6. Instanciação da cena Main.tscn, WorldBuildings e layout em 1280x720, 1600x900 e 1920x1080.

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]

var _frame: int = 0
var _res_step: int = 0
var _passed: int = 0
var _failed: int = 0

var _gs: Node
var _sm: Node
var _ev: Node

var _main_node: Node = null
var _dig_site: Node = null


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame == 2:
		_gs = root.get_node("/root/GameState")
		_sm = root.get_node("/root/SaveManager")
		_ev = root.get_node("/root/Events")
		_sm.autosave_enabled = false

		print("==========================================================================")
		print("FÓSSIL RUSH — SUÍTE DE TESTES AUTOMATIZADOS (QA)")
		print("==========================================================================")

		_test_database_integrity()
		_test_bulk_math_and_milestones()
		_test_synergies_overkill_and_veins()
		_test_prestige_and_ark_victory()
		_test_save_load_base64_and_offline()
		_setup_main_scene_test()
		return false

	if _frame >= 3 and _res_step < RESOLUTIONS.size():
		_verify_resolution_step(RESOLUTIONS[_res_step])
		_res_step += 1
		if _res_step >= RESOLUTIONS.size():
			_teardown_main_scene_test()
		return false

	if _frame >= 9:
		print("--------------------------------------------------------------------------")
		if _failed == 0:
			print("[PASS] %d/%d asserções concluídas — ALL TESTS PASSED" % [_passed, _passed])
			quit(0)
		else:
			push_error("[FAIL] %d falhas em %d asserções" % [_failed, _passed + _failed])
			quit(1)
		return true

	return false


func _assert(cond: bool, msg: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		push_error("[ASSERT FALHOU] " + msg)


func _assert_near(a: float, b: float, eps: float, msg: String) -> void:
	var ok: bool = absf(a - b) <= eps
	if not ok:
		_assert(false, "%s (esperado=%s, obtido=%s)" % [msg, str(b), str(a)])
	else:
		_assert(true, msg)


# ------------------------------------------------------------------ 1. Banco de Dados
func _test_database_integrity() -> void:
	print("[1/6] Integridade dos Bancos de Dados...")
	_assert(_gs.dinos_db.size() == 8, "dinos_db deve conter 8 espécies")
	_assert(_gs.upgrades_db.size() == 22, "upgrades_db deve conter 22 upgrades")
	_assert(_gs.eras.size() == 6, "eras deve conter 6 eras geológicas")

	for i: int in range(_gs.eras.size()):
		var era: EraData = _gs.eras[i]
		_assert(era.index == i, "Era %s com índice ordenado=%d" % [era.display_name, i])
		_assert(not era.fragment_pool.is_empty(), "Era %s tem pool de fragmentos não vazio" % era.display_name)
		_assert(era.base_layer_hp > 0.0, "Era %s com HP > 0" % era.display_name)
		_assert(era.bones_per_damage > 0.0, "Era %s com bones_per_damage > 0" % era.display_name)


# ------------------------------------------------------------------ 2. Compras em Lote & Marcos
func _test_bulk_math_and_milestones() -> void:
	print("[2/6] Matemática de Compra em Lote (Upgrades & Dinos) + Marcos...")
	_gs.start_new_game()

	var pick: UpgradeData = _gs.get_upgrade(&"tools_sharp_pickaxe")
	_assert(pick != null, "Upgrade tools_sharp_pickaxe existe")
	var seq_cost_0: float = 0.0
	for lvl: int in range(10):
		seq_cost_0 += pick.get_cost(lvl)
	_assert_near(pick.get_bulk_cost(0, 10), seq_cost_0, 0.05, "Upgrade get_bulk_cost(0, 10) == soma PG sequencial")

	var seq_cost_5: float = 0.0
	for lvl: int in range(5, 15):
		seq_cost_5 += pick.get_cost(lvl)
	_assert_near(pick.get_bulk_cost(5, 10), seq_cost_5, 0.05, "Upgrade get_bulk_cost(5, 10) == soma PG sequencial")

	var budget: float = 500.0
	var expected_max_upg: int = pick.get_max_affordable(0, budget)
	_assert(expected_max_upg > 1, "get_max_affordable compra múltiplos níveis")
	_gs.add_resource(_gs.RES_BONES, budget)
	var bought_upg: bool = bool(_gs.purchase_upgrade(&"tools_sharp_pickaxe", _gs.BUY_MAX))
	_assert(bought_upg, "Compra BUY_MAX de upgrade bem-sucedida")
	_assert(int(_gs.get_upgrade_level(&"tools_sharp_pickaxe")) == expected_max_upg, "Nível final corresponde a BUY_MAX")

	# Compra em lote de dinossauros + trava da 1a montagem
	_gs.start_new_game()
	var compy: DinoData = _gs.get_dino(&"compsognathus")
	_assert(compy != null, "Dino compsognathus existe")
	_gs.set_buy_multiplier(100)
	_gs.add_fragments(&"compsognathus", 10)
	_gs.add_resource(_gs.RES_BONES, 1000.0)
	_assert(int(_gs.resolve_dino_purchase_amount(&"compsognathus", 100)) == 1, "1a montagem sempre resolve para 1 unidade mesmo em 100x")
	_assert(bool(_gs.assemble_dino(&"compsognathus", 100)), "Monta 1a unidade de Compsognato")
	_assert(int(_gs.get_dino_count(&"compsognathus")) == 1, "Contagem após 1a montagem = 1")
	_assert(int(_gs.get_fragments(&"compsognathus")) == 5, "Consome exatamente fragments_required (5)")
	_assert_near(float(_gs.get_resource(_gs.RES_BONES)), 1000.0 - compy.assembly_cost, 0.05, "Custo exato da 1a montagem")

	var seq_dino_cost: float = 0.0
	for k: int in range(1, 11):
		seq_dino_cost += compy.get_unit_cost(k)
	_assert_near(compy.get_bulk_unit_cost(1, 10), seq_dino_cost, 0.1, "Dino get_bulk_unit_cost(1, 10) == soma PG sequencial")

	# Teste de marco em 25 unidades
	var milestone_hits: Array[int] = []
	var on_milestone: Callable = func(d_id: StringName, m: int) -> void:
		if d_id == &"compsognathus":
			milestone_hits.append(m)
	_ev.dino_milestone_reached.connect(on_milestone)

	_gs.add_resource(_gs.RES_BONES, 1e12)
	var before_max: int = int(_gs.get_dino_count(&"compsognathus"))
	var target_add: int = 25 - before_max
	_assert(bool(_gs.assemble_dino(&"compsognathus", target_add)), "Clonagem em lote até marco 25")
	_assert(int(_gs.get_dino_count(&"compsognathus")) == 25, "Contagem exata de 25 unidades")
	_assert(milestone_hits.size() == 1 and milestone_hits[0] == 25, "Sinal dino_milestone_reached emitido para 25")
	_assert_near(compy.get_milestone_multiplier(25), compy.milestone_multiplier, 0.001, "Multiplicador de marco aplicado (1.5x)")
	_ev.dino_milestone_reached.disconnect(on_milestone)


# ------------------------------------------------------------------ 3. Sinergias, Overkill e Veios
func _test_synergies_overkill_and_veins() -> void:
	print("[3/6] Sinergias dos 8 Papéis, Overkill de Camadas & Veios Especiais...")
	_gs.start_new_game()

	# Popula todas as 8 espécies diretamente e verifica efeito + descrição
	for dino_id: StringName in _gs.dinos_db:
		_gs.dino_counts[dino_id] = 10
	_gs.dino_counts[&"compsognathus"] = 40  # testa teto de 30 (+45%)
	_gs.dino_counts[&"pterodactyl"] = 30    # testa teto de 25 (+75%)
	_gs.dino_counts[&"brachiosaurus"] = 25  # testa teto de 20 (+80%)
	_gs.current_era_index = 3
	_gs.recalculate_stats()

	_assert_near(float(_gs.get_collector_bones_multiplier()), 1.45, 0.001, "Sinergia COLLECTOR com teto +45% (30 unid)")
	_assert_near(float(_gs.get_area_tremor_multiplier()), 1.15, 0.001, "Sinergia AREA (+1.5% * 10 = +15%)")
	_assert_near(float(_gs.get_mineral_rate_multiplier()), 1.75, 0.001, "Sinergia TRANSPORT com teto +75% (25 unid)")
	_assert_near(float(_gs.get_support_aura_multiplier()), 1.80, 0.001, "Sinergia SUPPORT com teto +80% (20 unid)")
	_assert(float(_gs.get_shield_ratio()) >= 0.20, "Sinergia DEFENSE contribui para escudo do meteoro (>=20%)")
	_assert(float(_gs.get_acid_dot_dps()) > 0.0, "Sinergia ELEMENTAL gera corrosão ácida (>0 DPS)")

	# Confirma que BREAKER (T-Rex) escala com Era e FAST (Velociraptor) escala com quantidade
	var trex_era3: float = float(_gs.get_dino_damage(&"trex"))
	_gs.current_era_index = 0
	var trex_era0: float = float(_gs.get_dino_damage(&"trex"))
	_assert(trex_era3 > trex_era0, "Sinergia BREAKER aumenta dano por Era geológica")

	var raptor_10: float = float(_gs.get_dino_damage(&"velociraptor"))
	_gs.dino_counts[&"velociraptor"] = 1
	var raptor_1: float = float(_gs.get_dino_damage(&"velociraptor"))
	_assert(raptor_10 > raptor_1, "Sinergia FAST aumenta dano próprio com tamanho do bando")

	for dino_id: StringName in _gs.dinos_db:
		var desc: String = str(_gs.get_dino_synergy_description(dino_id))
		_assert(not desc.is_empty(), "Tooltip de sinergia não vazia para %s" % String(dino_id))

	# Overkill carryover: deve quebrar as 6 camadas do Holoceno e parar exatamente no início do Cretáceo
	_gs.start_new_game()
	_gs.apply_dig_damage(500000.0, Vector2(100, 100))
	_assert(int(_gs.depth) == 6, "Overkill quebra todas as 6 camadas do Holoceno")
	_assert(int(_gs.current_era_index) == 1, "Overkill avança para Era 1 (Cretáceo)")
	_assert(int(_gs.current_layer_index) == 0, "Overkill interrompe carryover ao trocar de Era")
	_assert_near(float(_gs.layer_hp), float(_gs.layer_max_hp), 0.01, "Nova Era inicia com camada cheia")
	_assert(float(_gs.run_total_bones) > 0.0, "Overkill concedeu ossos da Era anterior")

	# Veios especiais
	var vein_signals: Array[float] = []
	var on_vein: Callable = func(b: float, _m: float, _d: StringName) -> void:
		vein_signals.append(b)
	_ev.vein_cracked.connect(on_vein)
	var b_before: float = float(_gs.get_resource(_gs.RES_BONES))
	var m_before: float = float(_gs.get_resource(_gs.RES_MINERALS))
	_gs.crack_rock_vein(Vector2(600, 400))
	_assert(vein_signals.size() == 1, "Sinal vein_cracked emitido ao quebrar veio")
	_assert(float(_gs.get_resource(_gs.RES_BONES)) > b_before, "Quebrar veio concede ossos bônus")
	_assert(float(_gs.get_resource(_gs.RES_MINERALS)) > m_before, "Quebrar veio concede minérios bônus")
	_ev.vein_cracked.disconnect(on_vein)


# ------------------------------------------------------------------ 4. Prestígio & Projeto Arca
func _test_prestige_and_ark_victory() -> void:
	print("[4/6] Prestígio & Vitória Projeto Arca...")
	_gs.start_new_game()
	_gs.add_resource(_gs.RES_BONES, 500000.0)
	_gs.add_resource(_gs.RES_DNA, 100.0)
	_gs.depth = 20
	_gs.current_era_index = 2
	_gs.dino_counts[&"trex"] = 2

	var preview: float = float(_gs.calculate_amber_reward())
	_assert(preview > 0.0, "Prévia de Âmbar positiva para run avançada")
	var gained: float = float(_gs.perform_prestige())
	_assert_near(gained, preview, 0.01, "perform_prestige concede exatamente a prévia")
	_assert_near(float(_gs.get_resource(_gs.RES_AMBER)), gained, 0.01, "Âmbar creditado")
	_assert_near(float(_gs.get_resource(_gs.RES_BONES)), 0.0, 0.001, "Ossos zerados pós-prestígio")
	_assert(int(_gs.depth) == 0, "Profundidade zerada pós-prestígio")
	_assert(_gs.dino_counts.is_empty(), "Dinos zerados pós-prestígio")
	_assert(int(_gs.run_number) == 2, "run_number incrementado para 2")

	# Upgrade permanente sobrevive ao prestígio
	_gs.add_resource(_gs.RES_AMBER, 50.0)
	_assert(bool(_gs.purchase_upgrade(&"amber_fossil_mastery", 1)), "Compra de upgrade permanente com Âmbar")
	_gs.perform_prestige()
	_assert(int(_gs.get_upgrade_level(&"amber_fossil_mastery")) == 1, "Upgrade permanente mantido pós-prestígio")

	# Vitória Projeto Arca (GDD §7)
	_assert(not bool(_gs.can_activate_ark_victory()), "Projeto Arca bloqueado sem requisitos")
	_assert(not bool(_gs.activate_ark_victory()), "activate_ark_victory retorna false sem requisitos")

	_gs.add_resource(_gs.RES_AMBER, 5000.0)
	_assert(bool(_gs.purchase_upgrade(&"amber_ark_project", 5)), "Upgrade Projeto Arca ao nível 5")
	_gs.add_resource(_gs.RES_MINERALS, 10000.0)
	_assert(bool(_gs.purchase_upgrade(&"defense_thermal_dome", 8)), "Domo Térmico elevado para >=75% escudo")
	_gs.current_era_index = 3
	_assert(bool(_gs.can_activate_ark_victory()), "can_activate_ark_victory retorna true com todos os requisitos")

	var ark_events: Array[int] = []
	var on_ark: Callable = func(r: int, _t: float) -> void:
		ark_events.append(r)
	_ev.ark_victory_achieved.connect(on_ark)

	var amber_before_ark: float = float(_gs.get_resource(_gs.RES_AMBER))
	_assert(bool(_gs.activate_ark_victory()), "activate_ark_victory bem-sucedida")
	_assert(bool(_gs.ark_completed), "ark_completed marcado como true")
	_assert(ark_events.size() == 1, "Sinal ark_victory_achieved emitido")
	_assert_near(float(_gs.get_resource(_gs.RES_AMBER)), amber_before_ark + 25.0, 0.01, "+25 Âmbar bônus na 1a ativação")

	# Segunda ativação não duplica bônus de +25
	_assert(bool(_gs.activate_ark_victory()), "Reativação permitida quando requisitos permanecem")
	_assert_near(float(_gs.get_resource(_gs.RES_AMBER)), amber_before_ark + 25.0, 0.01, "Bônus de +25 Âmbar não duplica na 2a ativação")
	_ev.ark_victory_achieved.disconnect(on_ark)


# ------------------------------------------------------------------ 5. Save/Load, Base64 e Offline
func _test_save_load_base64_and_offline() -> void:
	print("[5/6] Serialização, Base64 Export/Import & Progresso Offline...")
	_gs.start_new_game()
	_gs.add_resource(_gs.RES_BONES, 12345.0)
	_gs.add_resource(_gs.RES_MINERALS, 67.0)
	_gs.add_resource(_gs.RES_DNA, 89.0)
	_gs.add_resource(_gs.RES_AMBER, 42.0)
	_gs.fragments[&"trex"] = 7
	_gs.dino_counts[&"trex"] = 3
	_gs.upgrade_levels[&"tools_sharp_pickaxe"] = 4
	_gs.permanent_upgrade_levels[&"amber_offline_lab"] = 2
	_gs.recalculate_stats()
	_gs.set_buy_multiplier(10)
	_gs.ark_completed = true
	_gs.depth = 11

	var saved: Dictionary = _gs.to_save_dict()
	var b64: String = str(_sm.export_save_string())
	_assert(not b64.is_empty(), "export_save_string gera string Base64 válida")

	_gs.start_new_game()
	_gs.load_save_dict(saved)
	_assert_near(float(_gs.get_resource(_gs.RES_BONES)), 12345.0, 0.1, "Round-trip dict preserva ossos")
	_assert_near(float(_gs.get_resource(_gs.RES_AMBER)), 42.0, 0.1, "Round-trip dict preserva âmbar")
	_assert(int(_gs.get_dino_count(&"trex")) == 3, "Round-trip dict preserva dino_counts")
	_assert(int(_gs.get_upgrade_level(&"amber_offline_lab")) == 2, "Round-trip dict preserva permanent_upgrade_levels")
	_assert(int(_gs.buy_multiplier) == 10, "Round-trip dict preserva buy_multiplier")
	_assert(bool(_gs.ark_completed), "Round-trip dict preserva ark_completed")
	_assert(int(_gs.depth) == 11, "Round-trip dict preserva depth")

	# Base64 import sem tocar user://savegame.json
	_gs.start_new_game()
	_assert(bool(_sm.import_save_string(b64)), "import_save_string restaura string Base64")
	_assert_near(float(_gs.get_resource(_gs.RES_BONES)), 12345.0, 0.1, "Base64 restaura ossos")
	_assert(int(_gs.get_dino_count(&"trex")) == 3, "Base64 restaura dinos")
	_assert(bool(_gs.ark_completed), "Base64 restaura ark_completed")

	# Progresso offline: gera ossos + DNA e NÃO altera meteor_time_left
	var meteor_before: float = float(_gs.meteor_time_left)
	var gains: Dictionary = _gs.apply_offline_progress(3600.0)
	_assert(float(gains.get(_gs.RES_BONES, 0.0)) > 0.0, "Progresso offline gera ossos quando há DPS")
	_assert(float(gains.get(_gs.RES_DNA, 0.0)) > 0.0, "Progresso offline gera DNA quando há dinos")
	_assert_near(float(_gs.meteor_time_left), meteor_before, 0.001, "Timer do meteoro NÃO corre offline")


# ------------------------------------------------------------------ 6. Cena Principal & Multi-Resolução
func _setup_main_scene_test() -> void:
	print("[6/6] Instanciando Main.tscn e testando multi-resolução...")
	_gs.start_new_game()
	var packed: PackedScene = load("res://scenes/main/Main.tscn") as PackedScene
	_assert(packed != null, "Main.tscn carregada")
	if packed == null:
		return
	_main_node = packed.instantiate()
	_assert(_main_node != null, "Main.tscn instanciada")
	root.add_child(_main_node)
	var title: Control = _main_node.get_title_screen()
	if title != null:
		title.visible = false
	_dig_site = _main_node.get_dig_site()
	_assert(_dig_site != null, "DigSite acessível em Main")


func _verify_resolution_step(res: Vector2i) -> void:
	if _main_node == null or _dig_site == null:
		return
	root.size = res
	if _main_node is Control:
		(_main_node as Control).set_size(Vector2(res))
	if _dig_site is Control:
		(_dig_site as Control).set_size(Vector2(res))

	var buildings: Array = _dig_site.get_buildings()
	_assert(buildings.size() == 5, "Res %dx%d: 5 construções no cenário" % [res.x, res.y])
	var ground_y: float = float(_dig_site.get_ground_y())
	var rock_face_x: float = float(_dig_site.get_rock_face_x())
	var home_range: Vector2 = _dig_site.get_home_x_range()
	_assert(ground_y > 0.0 and ground_y < float(res.y), "Res %dx%d: ground_y dentro do viewport (%s)" % [res.x, res.y, str(ground_y)])
	_assert(rock_face_x > home_range.y, "Res %dx%d: face da rocha à direita da zona de patrulha" % [res.x, res.y])

	for i: int in range(buildings.size() - 1):
		_dig_site.open_building(i)
		_assert(bool(_dig_site.is_panel_open()), "Res %dx%d: BuildingPanel abre para construção #%d" % [res.x, res.y, i])
	# Segundo clique na última construção de painel (index 3) fecha o painel
	_dig_site.open_building(buildings.size() - 2)
	_assert(not bool(_dig_site.is_panel_open()), "Res %dx%d: clique repetido fecha BuildingPanel" % [res.x, res.y])

	# Construção #4 (Templo) fecha BuildingPanel e abre modal de Âmbar / Arca via prestige_modal_requested
	var modal_hits: Array[bool] = []
	var on_modal: Callable = func() -> void: modal_hits.append(true)
	_ev.prestige_modal_requested.connect(on_modal)
	_dig_site.open_building(buildings.size() - 1)
	_ev.prestige_modal_requested.disconnect(on_modal)
	_assert(modal_hits.size() == 1, "Res %dx%d: Templo (#4) emite prestige_modal_requested" % [res.x, res.y])
	_assert(not bool(_dig_site.is_panel_open()), "Res %dx%d: BuildingPanel permanece fechado ao abrir Templo" % [res.x, res.y])
	var meteor_overlay: Node = _main_node.get_node_or_null("MeteorOverlay")
	if meteor_overlay != null:
		var backdrop: Control = meteor_overlay.get_node_or_null("%ModalBackdrop") as Control
		_assert(backdrop != null and backdrop.visible, "Res %dx%d: MeteorOverlay exibe modal de Âmbar ao clicar no Templo" % [res.x, res.y])
		if backdrop != null:
			backdrop.visible = false


func _teardown_main_scene_test() -> void:
	if _main_node != null:
		_main_node.queue_free()
		_main_node = null
		_dig_site = null
