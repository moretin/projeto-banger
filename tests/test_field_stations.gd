extends GutTest

var _autosave: bool


func before_each() -> void:
	_autosave = SaveManager.autosave_enabled
	SaveManager.autosave_enabled = false
	GameState.start_new_game()


func after_each() -> void:
	SaveManager.autosave_enabled = _autosave


func test_specialists_require_worksite_and_spend_their_material() -> void:
	for station: StringName in GameState.RUBBLE_ORDER:
		var def: Dictionary = GameState.RUBBLE_DEFS[station]
		var gear: StringName = def["gear"]
		var product: StringName = def["product"]
		assert_false(GameState.is_upgrade_unlocked(gear))
		assert_eq(GameState.get_station_rate(station), 0.0)
		GameState.add_resource(GameState.RES_ROCKS, GameState.get_rubble_cost(station))
		assert_true(GameState.rebuild_rubble(station))
		assert_true(GameState.is_upgrade_unlocked(gear))
		var previous: float = GameState.get_resource(product)
		GameState._tick_passive_income(30.0)
		assert_almost_eq(GameState.get_resource(product) - previous, GameState.get_station_rate(station) * 30, 0.001)
		var cost: float = GameState.get_purchase_cost(gear, 1)
		var stock: float = GameState.get_resource(product)
		var old_rate: float = GameState.get_station_rate(station)
		assert_true(GameState.purchase_upgrade(gear))
		assert_almost_eq(GameState.get_resource(product), stock - cost, 0.001)
		assert_eq(GameState.get_upgrade_level(gear), 1)
		assert_almost_eq(GameState.get_station_rate(station), old_rate * 1.25, 0.001)


func test_offline_stock_migration_and_prestige() -> void:
	var old: Dictionary = {"version": 3, "game": {"resources": {"rocks": 50, "amber": 2}, "rubble_levels": {"rubble_nest": 2}}}
	var migrated: Dictionary = SaveManager._migrate(old)
	GameState.load_save_dict(migrated["game"])
	assert_eq(migrated["version"], 4)
	assert_eq(GameState.get_rubble_level(&"rubble_nest"), 2)
	assert_eq(GameState.get_resource(GameState.RES_FISH), 0.0)
	var gains: Dictionary = GameState.apply_offline_progress(100)
	assert_almost_eq(float(gains[GameState.RES_FISH]), 100 * GameState.get_offline_efficiency(), 0.001)
	assert_true(GameState.purchase_upgrade(&"field_fins"))
	var remaining: float = GameState.get_resource(GameState.RES_FISH)
	var saved: Dictionary = GameState.to_save_dict()
	GameState.start_new_game()
	GameState.load_save_dict(saved)
	assert_almost_eq(GameState.get_resource(GameState.RES_FISH), remaining, 0.001)
	assert_eq(GameState.get_upgrade_level(&"field_fins"), 1)
	GameState.perform_prestige()
	assert_eq(GameState.get_rubble_level(&"rubble_nest"), 0)
	assert_eq(GameState.get_resource(GameState.RES_FISH), 0.0)
	assert_eq(GameState.get_upgrade_level(&"field_fins"), 0)


func test_buy_from_world_and_reach_every_upgrade_and_species() -> void:
	var packed: PackedScene = load("res://scenes/surface/SurfaceScene.tscn") as PackedScene
	var surface: SurfaceScene = add_child_autofree(packed.instantiate()) as SurfaceScene
	var visited: Dictionary = {}
	var species: Dictionary = {}
	for station: StringName in GameState.RUBBLE_ORDER:
		(surface.get_node("%Map").get_node(String(station)) as Button).pressed.emit()
		var groups: HBoxContainer = surface.get_node("%Groups") as HBoxContainer
		for child: Node in groups.get_children():
			(child as Button).pressed.emit()
			for item: StringName in surface._items:
				if child.name == &"species":
					species[item] = true
				elif GameState.get_upgrade(item) != null:
					assert_false(visited.has(item), "Equipamento em dois locais: %s" % item)
					visited[item] = true
	assert_eq(visited.size(), GameState.upgrades_db.size())
	assert_eq(species.size(), GameState.dinos_db.size())
	GameState.add_resource(GameState.RES_ROCKS, 15)
	(surface.get_node("%Map/rubble_forge") as Button).pressed.emit()
	(surface.get_node("%Buy") as Button).pressed.emit()
	assert_eq(GameState.get_rubble_level(&"rubble_forge"), 1)
	Events.station_research_requested.emit()
	assert_eq(surface._section, &"amber")
	assert_eq(surface._site, &"rubble_bunker")
