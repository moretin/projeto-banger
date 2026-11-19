extends GutTest
## Testes de economia básica: compras 1x, 10x, 100x e MAX devem bater com a soma das compras individuais.


func before_each() -> void:
	SaveManager.autosave_enabled = false
	GameState.start_new_game()


func _assert_bulk_matches_sequential(upgrade_id: StringName, bulk_amount: int, starting_budget: float, start_level: int = 0) -> void:
	var data: UpgradeData = GameState.get_upgrade(upgrade_id)
	assert_not_null(data, "Upgrade %s deve existir no catálogo" % upgrade_id)

	# Run A: compra em lote única
	GameState.start_new_game()
	GameState.current_era_index = maxi(data.required_era_index, 0)
	if data.is_permanent:
		GameState.permanent_upgrade_levels[upgrade_id] = start_level
	else:
		GameState.upgrade_levels[upgrade_id] = start_level
	GameState.add_resource(data.cost_resource, starting_budget)
	var bought_bulk: bool = GameState.purchase_upgrade(upgrade_id, bulk_amount)
	var level_bulk: int = GameState.get_upgrade_level(upgrade_id)
	var remaining_bulk: float = GameState.get_resource(data.cost_resource)
	var spent_bulk: float = starting_budget - remaining_bulk

	# Run B: compras 1x em sequência
	GameState.start_new_game()
	GameState.current_era_index = maxi(data.required_era_index, 0)
	if data.is_permanent:
		GameState.permanent_upgrade_levels[upgrade_id] = start_level
	else:
		GameState.upgrade_levels[upgrade_id] = start_level
	GameState.add_resource(data.cost_resource, starting_budget)
	var target_steps: int = bulk_amount
	if bulk_amount == GameState.BUY_MAX:
		while GameState.purchase_upgrade(upgrade_id, 1):
			pass
	else:
		if data.max_level > 0:
			target_steps = mini(bulk_amount, maxi(data.max_level - start_level, 0))
		for _i: int in range(target_steps):
			if not GameState.purchase_upgrade(upgrade_id, 1):
				break
	var level_seq: int = GameState.get_upgrade_level(upgrade_id)
	var remaining_seq: float = GameState.get_resource(data.cost_resource)
	var spent_seq: float = starting_budget - remaining_seq

	assert_eq(
		bought_bulk,
		level_seq > start_level,
		"%s (amount=%d, budget=%.2f): status de compra deve bater com 1x sequencial" % [upgrade_id, bulk_amount, starting_budget]
	)
	assert_eq(
		level_bulk,
		level_seq,
		"%s (amount=%d, budget=%.2f): nível final deve bater (%d vs %d)" % [upgrade_id, bulk_amount, starting_budget, level_bulk, level_seq]
	)
	var tol: float = maxf(spent_seq * 1e-6, 1e-4)
	assert_almost_eq(
		spent_bulk,
		spent_seq,
		tol,
		"%s (amount=%d): custo total deve bater com a soma das compras 1x" % [upgrade_id, bulk_amount]
	)
	assert_almost_eq(
		remaining_bulk,
		remaining_seq,
		tol,
		"%s (amount=%d): saldo restante deve bater com as compras 1x" % [upgrade_id, bulk_amount]
	)


func test_1x_10x_100x_purchases_match_individual_sum() -> void:
	_assert_bulk_matches_sequential(&"tools_sharp_pickaxe", 1, 1000.0)
	_assert_bulk_matches_sequential(&"tools_sharp_pickaxe", 10, 1.0e8)
	_assert_bulk_matches_sequential(&"tools_sharp_pickaxe", 100, 1.0e14)
	_assert_bulk_matches_sequential(&"machines_pneumatic_drill", 10, 1.0e8)
	_assert_bulk_matches_sequential(&"machines_pneumatic_drill", 100, 1.0e12)
	# Upgrade com max_level = 15: 10x completo e 100x limitado pelos 5 níveis restantes.
	_assert_bulk_matches_sequential(&"defense_reinforced_bunker", 10, 1.0e8, 0)
	_assert_bulk_matches_sequential(&"defense_reinforced_bunker", 100, 1.0e12, 10)
	# Upgrade permanente de Âmbar com max_level = 10.
	_assert_bulk_matches_sequential(&"amber_ark_project", 10, 1.0e6, 0)


func test_buy_max_matches_sequential_individual_purchases() -> void:
	_assert_bulk_matches_sequential(&"tools_sharp_pickaxe", GameState.BUY_MAX, 3.0)
	_assert_bulk_matches_sequential(&"tools_sharp_pickaxe", GameState.BUY_MAX, 500.0)
	_assert_bulk_matches_sequential(&"tools_sharp_pickaxe", GameState.BUY_MAX, 1.0e6)
	_assert_bulk_matches_sequential(&"machines_pneumatic_drill", GameState.BUY_MAX, 25000.0)
	_assert_bulk_matches_sequential(&"defense_reinforced_bunker", GameState.BUY_MAX, 1.0e9)
	_assert_bulk_matches_sequential(&"amber_ark_project", GameState.BUY_MAX, 4000.0)
