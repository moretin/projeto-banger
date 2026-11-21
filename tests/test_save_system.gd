extends GutTest
## Testes do sistema de Save v6 (multi-bioma, remoção do Museu e migrações v1/v2/v3/v4/v5→v6), proteção de Âmbar no prestígio.

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
	# Garante que SaveManager.load_game.call_deferred() do boot já concluiu.
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


func test_save_v2_round_trip() -> void:
	GameState.add_resource(GameState.RES_BONES, 12345.5)
	GameState.add_resource(GameState.RES_ROCKS, 88.0)
	GameState.add_resource(GameState.RES_MINERALS, 19.0)
	GameState.add_resource(GameState.RES_DNA, 42.25)
	GameState.add_resource(GameState.RES_AMBER, 317.0)
	GameState.total_amber_earned = 500.0
	GameState.run_number = 4
	GameState.max_depth_ever = 12
	GameState.depth = 7
	GameState.current_era_index = 2
	GameState.current_layer_index = 1
	GameState.orange_rock_broken = true
	GameState.orange_rock_hp = 0.0
	GameState.add_fragments(&"trex", 9)
	GameState.dino_counts[&"compsognathus"] = 3
	GameState.discovered_dinos[&"compsognathus"] = true
	GameState.upgrade_levels[&"tools_sharp_pickaxe"] = 5
	GameState.permanent_upgrade_levels[&"amber_ark_project"] = 2
	GameState.rubble_levels[&"rubble_forge"] = 3
	GameState.set_buy_multiplier(10)
	GameState.recalculate_stats()
	GameState.layer_hp = 1234.0
	GameState.meteor_time_left = 432.5

	assert_true(SaveManager.save_game(), "save_game() deve gravar SAVE_VERSION 3 em disco")
	var raw_text: String = FileAccess.get_file_as_string(SaveManager.SAVE_PATH)
	var parsed: Variant = JSON.parse_string(raw_text)
	assert_true(parsed is Dictionary, "Arquivo salvo deve ser JSON válido")
	assert_eq(int((parsed as Dictionary).get("version", 0)), SaveManager.SAVE_VERSION)

	var exported: String = SaveManager.export_save_string()
	GameState.start_new_game()
	assert_true(SaveManager.load_game(), "load_game() deve carregar o save v2 do disco")

	assert_almost_eq(GameState.get_resource(GameState.RES_BONES), 12345.5, 0.01)
	assert_almost_eq(GameState.get_resource(GameState.RES_ROCKS), 88.0, 0.01)
	assert_almost_eq(GameState.get_resource(GameState.RES_MINERALS), 19.0, 0.01)
	assert_almost_eq(GameState.get_resource(GameState.RES_DNA), 42.25, 0.01)
	assert_almost_eq(GameState.get_resource(GameState.RES_AMBER), 317.0, 0.01)
	assert_eq(GameState.run_number, 4)
	assert_eq(GameState.max_depth_ever, 12)
	assert_eq(GameState.depth, 7)
	assert_eq(GameState.current_era_index, 2)
	assert_eq(GameState.current_layer_index, 1)
	assert_true(GameState.orange_rock_broken)
	assert_eq(GameState.get_fragments(&"trex"), 9)
	assert_eq(GameState.get_dino_count(&"compsognathus"), 3)
	assert_eq(GameState.get_upgrade_level(&"tools_sharp_pickaxe"), 5)
	assert_eq(GameState.get_upgrade_level(&"amber_ark_project"), 2)
	assert_eq(GameState.get_rubble_level(&"rubble_forge"), 3)
	assert_eq(GameState.buy_multiplier, 10)
	assert_almost_eq(GameState.layer_hp, 1234.0, 0.1)
	assert_almost_eq(GameState.meteor_time_left, 432.5, 0.01)

	GameState.start_new_game()
	assert_true(SaveManager.import_save_string(exported), "import_save_string() deve restaurar save v2 em Base64")
	assert_almost_eq(GameState.get_resource(GameState.RES_AMBER), 317.0, 0.01)
	assert_eq(GameState.run_number, 4)


func test_prestige_close_without_save_reload_no_duplicate_amber() -> void:
	SaveManager.autosave_enabled = true
	GameState.add_resource(GameState.RES_BONES, 250000000.0)
	GameState.depth = 20
	GameState.current_era_index = 1
	GameState.meteor_time_left = 0.0
	var expected_amber: float = GameState.calculate_amber_reward(0.0)
	assert_gt(expected_amber, 0.0, "Prestígio de reprodução deve conceder Âmbar positivo")

	var gained: float = GameState.perform_prestige(0.0)
	assert_almost_eq(gained, expected_amber, 0.01, "Prestígio de reprodução deve conceder exatamente a prévia")
	assert_eq(GameState.run_number, 2)

	var saved_dict: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	var saved_game: Dictionary = (saved_dict as Dictionary).get("game", {}) as Dictionary
	assert_gt(float(saved_game.get("meteor_time_left", 0.0)), 0.0, "Save após prestígio já deve ter timer resetado")
	assert_almost_eq(float(saved_game.get("run_total_bones", -1.0)), 0.0, 0.001, "Save após prestígio já deve ter run_total_bones zerado")

	# Simula fechar sem salvar novamente e reabrir o jogo.
	SaveManager.autosave_enabled = false
	GameState.start_new_game()
	watch_signals(Events)
	assert_true(SaveManager.load_game())
	GameState._process(0.016)
	GameState._process(0.016)

	assert_signal_not_emitted(Events, "meteor_impact_started", "Recarregar após prestígio não deve disparar novo impacto")
	assert_signal_not_emitted(Events, "prestige_completed", "Recarregar após prestígio não deve reaplicar prestígio")
	assert_almost_eq(GameState.get_resource(GameState.RES_AMBER), expected_amber, 0.01, "Âmbar não pode duplicar ao reabrir sem novo save")
	assert_almost_eq(GameState.total_amber_earned, expected_amber, 0.01)
	assert_eq(GameState.run_number, 2)


func test_legacy_bugged_zero_timer_save_loads_without_reimpact() -> void:
	var bugged_payload: Dictionary = {
		"version": SaveManager.SAVE_VERSION,
		"saved_at": Time.get_unix_time_from_system(),
		"game": {
			"resources": {"bones": 0.0, "rocks": 0.0, "minerals": 0.0, "dna": 0.0, "amber": 4714.0},
			"fragments": {},
			"dino_counts": {},
			"upgrade_levels": {},
			"rubble_levels": {},
			"orange_rock_hp": 10.0,
			"orange_rock_broken": false,
			"permanent_upgrade_levels": {},
			"discovered_dinos": [],
			"current_era_index": 0,
			"current_layer_index": 0,
			"layer_hp": 120000.0,
			"depth": 0,
			"run_total_bones": 1000192601.25,
			"meteor_time_left": 0.0,
			"run_number": 2,
			"max_depth_ever": 0,
			"lifetime_bones": 1000192601.25,
			"total_amber_earned": 4714.0,
			"buy_multiplier": 1,
		},
	}
	var f: FileAccess = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(bugged_payload))
	f.close()

	watch_signals(Events)
	assert_true(SaveManager.load_game(), "Save bugado com meteor_time_left == 0 deve carregar com fallback seguro")
	assert_push_warning("Save inconsistente", "Deve emitir push_warning ao detectar meteor_active com timer <= 0")
	assert_almost_eq(GameState.meteor_time_left, GameState.meteor_total_time, 0.001)

	GameState._process(0.016)
	assert_signal_not_emitted(Events, "meteor_impact_started", "Save antigo com timer 0 não pode disparar impacto imediato")
	assert_signal_not_emitted(Events, "prestige_completed", "Save antigo com timer 0 não pode reaplicar prestígio")
	assert_almost_eq(GameState.get_resource(GameState.RES_AMBER), 4714.0, 0.01)
	assert_almost_eq(GameState.run_total_bones, 0.0, 0.001)
	assert_almost_eq(GameState.meteor_time_left, GameState.meteor_total_time - 0.016, 0.001)
	assert_eq(GameState.run_number, 2)


func test_save_blocked_while_impacting() -> void:
	GameState.is_impacting = true
	var saved: bool = SaveManager.save_game()
	assert_false(saved, "SaveManager.save_game() deve retornar false durante GameState.is_impacting")
	assert_false(FileAccess.file_exists(SaveManager.SAVE_PATH), "Nenhum arquivo de save deve ser gravado durante o impacto")


func test_v1_migration_notifies_player() -> void:
	var v1_payload: Dictionary = {
		"version": 1,
		"saved_at": Time.get_unix_time_from_system() - 3600.0,
		"game": {
			"resources": {"bones": 9999.0, "amber": 50.0},
			"run_number": 3,
		},
	}
	var f: FileAccess = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(v1_payload))
	f.close()

	watch_signals(Events)
	assert_true(SaveManager.load_game())
	assert_push_warning("Save v1", "Migração v1 deve registrar aviso")
	assert_eq(SaveManager.last_migrated_reset_version, 1)
	assert_signal_emitted(Events, "notification_requested", "Jogador deve ser notificado quando save v1 é descartado")
	assert_almost_eq(GameState.get_resource(GameState.RES_AMBER), 0.0, 0.01)
	assert_eq(GameState.run_number, 1)


func test_fossil_counters_roundtrip_prestige_and_museum_removed() -> void:
	watch_signals(Events)
	GameState.register_fossil_found(&"compsognathus", 1)
	GameState.register_fossil_found(&"trex", 3)
	assert_signal_emitted_with_parameters(Events, "fossil_found", [&"trex", 3])
	GameState.register_fossil_found(&"trex", 2)
	assert_signal_emitted_with_parameters(Events, "fossil_found", [&"trex", 2])
	assert_eq(GameState.total_fossils_evaluated, 3)
	assert_eq(GameState.total_legendary_fossils, 1)
	assert_almost_eq(GameState.get_museum_collection_multiplier(), 1.0, 0.0001, "Multiplicador do Museu removido deve permanecer 1.0")

	# Prestígio NÃO deve limpar contadores permanentes de fósseis avaliados.
	GameState.add_resource(GameState.RES_BONES, 250000000.0)
	GameState.depth = 15
	GameState.perform_prestige(0.0)
	assert_eq(GameState.total_fossils_evaluated, 3, "Contadores de fósseis devem sobreviver ao prestígio")
	assert_eq(GameState.total_legendary_fossils, 1)

	assert_true(SaveManager.save_game())
	var exported: String = SaveManager.export_save_string()
	GameState.start_new_game()
	assert_eq(GameState.total_fossils_evaluated, 0, "start_new_game() deve zerar contadores antes do load")

	assert_true(SaveManager.load_game(), "load_game() deve restaurar contadores salvos na v6")
	assert_eq(GameState.total_fossils_evaluated, 3)
	assert_eq(GameState.total_legendary_fossils, 1)

	GameState.start_new_game()
	assert_true(SaveManager.import_save_string(exported), "Base64 também deve preservar os contadores de fósseis")
	assert_eq(GameState.total_fossils_evaluated, 3)
	assert_eq(GameState.total_legendary_fossils, 1)


func test_v2_save_migrates_to_v6_preserving_progress() -> void:
	var v2_payload: Dictionary = {
		"version": 2,
		"saved_at": Time.get_unix_time_from_system(),
		"game": {
			"resources": {"bones": 4567.0, "rocks": 33.0, "minerals": 12.0, "dna": 9.0, "amber": 84.0},
			"fragments": {"trex": 4},
			"dino_counts": {"compsognathus": 5},
			"upgrade_levels": {"tools_sharp_pickaxe": 3},
			"rubble_levels": {"rubble_forge": 2},
			"orange_rock_hp": 0.0,
			"orange_rock_broken": true,
			"permanent_upgrade_levels": {"amber_ark_project": 1},
			"discovered_dinos": ["compsognathus"],
			"current_era_index": 1,
			"current_layer_index": 2,
			"layer_hp": 800.0,
			"depth": 9,
			"run_total_bones": 90000.0,
			"meteor_time_left": 510.0,
			"run_number": 5,
			"max_depth_ever": 14,
			"lifetime_bones": 420000.0,
			"total_amber_earned": 120.0,
			"buy_multiplier": 10,
			"ark_completed": false,
		},
	}
	var f: FileAccess = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(v2_payload))
	f.close()

	assert_true(SaveManager.load_game(), "Save v2 deve migrar para v6 sem falhar")
	assert_eq(SaveManager.last_migrated_reset_version, -1, "Migração v2→v6 NÃO pode descartar progresso")
	assert_almost_eq(GameState.get_resource(GameState.RES_BONES), 4567.0, 0.01)
	assert_almost_eq(GameState.get_resource(GameState.RES_AMBER), 84.0, 0.01)
	assert_eq(GameState.get_dino_count(&"compsognathus"), 5)
	assert_eq(GameState.get_upgrade_level(&"amber_ark_project"), 1)
	assert_eq(GameState.run_number, 5)
	assert_eq(GameState.max_depth_ever, 14)
	assert_eq(GameState.current_biome, GameState.BIOME_AMBER, "Save v2 migrado deve iniciar na Bacia do Âmbar")
	assert_eq(GameState.total_fossils_evaluated, 0)
	assert_eq(GameState.total_legendary_fossils, 0)

	assert_true(SaveManager.save_game())
	var re_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	assert_eq(int((re_parsed as Dictionary).get("version", 0)), SaveManager.SAVE_VERSION)
	var saved_game: Dictionary = (re_parsed as Dictionary).get("game", {}) as Dictionary
	assert_false(saved_game.has("fossil_catalog"), "Save v6 não deve persistir fossil_catalog legado")


func test_v4_and_v5_saves_migrate_to_v6_preserving_progress_workers_and_biomes() -> void:
	var v4_payload: Dictionary = {
		"version": 4,
		"saved_at": Time.get_unix_time_from_system(),
		"game": {
			"resources": {
				"rocks": 140.0,
				"fish": 48.0,
				"feathers": 0.0,
				"science": 22.0,
				"amber": 95.0,
				"raw_fossils": 1.0,
			},
			"fragments": {"ankylosaurus": 4, "dilophosaurus": 2},
			"dino_counts": {"compsognathus": 1},
			"upgrade_levels": {"tools_sharp_pickaxe": 3, "field_fins": 2},
			"rubble_levels": {"rubble_forge": 0, "rubble_nest": 2, "rubble_bunker": 1},
			"orange_rock_hp": 0.0,
			"orange_rock_broken": true,
			"permanent_upgrade_levels": {"amber_ark_project": 2},
			"discovered_dinos": ["compsognathus"],
			"current_era_index": 0,
			"current_layer_index": 0,
			"layer_hp": 120000.0,
			"depth": 0,
			"run_total_bones": 0.0,
			"meteor_time_left": 480.0,
			"run_number": 3,
			"max_depth_ever": 5,
			"lifetime_bones": 25000.0,
			"total_amber_earned": 150.0,
			"buy_multiplier": 1,
			"ark_completed": false,
			"fossil_catalog": {"ankylosaurus": {"count": 4, "best_rarity": 2, "parts": ["Placa Osteoderma"]}},
			"total_fossils_evaluated": 4,
			"total_legendary_fossils": 0,
			"raw_fossil_queue": ["ankylosaurus"],
			"fossil_cleaning_progress": 0.4,
			"station_revived_dinos": {"rubble_nest": 1},
		},
	}
	var f: FileAccess = FileAccess.open(SaveManager.SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(v4_payload))
	f.close()

	assert_true(SaveManager.load_game(), "Save v4 deve migrar para v6 sem falhar")
	assert_eq(SaveManager.last_migrated_reset_version, -1, "Migração v4→v6 NÃO pode descartar progresso")
	assert_eq(SaveManager.SAVE_VERSION, 6)

	# Pedreira que estava 0 na v4 passa a 1 (sem trabalhador); estações já construídas preservam trabalhadores.
	assert_eq(GameState.get_rubble_level(&"rubble_forge"), 1)
	assert_false(GameState.has_station_worker(&"rubble_forge"))
	assert_eq(GameState.get_rubble_level(&"rubble_nest"), 2)
	assert_true(GameState.has_station_worker(&"rubble_nest"), "Pesqueiro já construído na v4 preserva trabalhador na v6")
	assert_gt(GameState.get_station_rate(&"rubble_nest"), 0.0)
	assert_eq(GameState.get_rubble_level(&"rubble_bunker"), 1)
	assert_true(GameState.has_station_worker(&"rubble_bunker"), "Universidade já construída na v4 preserva trabalhador na v6")
	assert_eq(GameState.get_rubble_level(&"rubble_silo"), 0)
	assert_false(GameState.has_station_worker(&"rubble_silo"))
	assert_eq(GameState.current_biome, GameState.BIOME_AMBER)

	# Recursos, upgrades, fila de fósseis e revividos preservados; novos recursos de Floresta/Neve zerados.
	assert_almost_eq(GameState.get_resource(GameState.RES_ROCKS), 140.0, 0.01)
	assert_almost_eq(GameState.get_resource(GameState.RES_FISH), 48.0, 0.01)
	assert_almost_eq(GameState.get_resource(GameState.RES_SCIENCE), 22.0, 0.01)
	assert_almost_eq(GameState.get_resource(GameState.RES_AMBER), 95.0, 0.01)
	for new_res: StringName in [GameState.RES_WOOD, GameState.RES_BERRIES, GameState.RES_RESIN, GameState.RES_ICE, GameState.RES_CRYSTALS]:
		assert_almost_eq(GameState.get_resource(new_res), 0.0, 0.001)
	assert_eq(GameState.get_upgrade_level(&"tools_sharp_pickaxe"), 3)
	assert_eq(GameState.get_upgrade_level(&"field_fins"), 2)
	assert_eq(GameState.raw_fossil_queue, [&"ankylosaurus"])
	assert_almost_eq(GameState.fossil_cleaning_progress, 0.4, 0.01)
	assert_eq(GameState.get_station_revived_count(&"rubble_nest"), 1)
	assert_eq(GameState.total_fossils_evaluated, 4)

	# Migração explícita v5 -> v6 com fossil_catalog legado deve funcionar sem erro e remover fossil_catalog.
	var v5_payload: Dictionary = {
		"version": 5,
		"saved_at": Time.get_unix_time_from_system(),
		"game": {
			"resources": {"rocks": 310.0, "metal": 19.0, "amber": 44.0},
			"rubble_levels": {"rubble_forge": 2, "rubble_nest": 1},
			"station_worker_unlocked": {"rubble_forge": true, "rubble_nest": false},
			"fossil_catalog": {"trex": {"count": 2, "best_rarity": 3, "parts": ["Dente"]}},
			"run_surface_progress": 5555.0,
			"run_number": 2,
			"meteor_time_left": 500.0,
		},
	}
	var migrated_v5: Dictionary = SaveManager._migrate(v5_payload)
	assert_eq(int(migrated_v5.get("version", 0)), 6)
	var mig_game: Dictionary = migrated_v5.get("game", {}) as Dictionary
	assert_eq(String(mig_game.get("current_biome", "")), "amber_basin")
	assert_false(mig_game.has("fossil_catalog"), "Migração v5→v6 deve apagar fossil_catalog legado")

	# Round-trip completo em v6 (incluindo current_biome, recursos de Floresta/Neve, station_worker_unlocked e run_surface_progress).
	GameState.set_current_biome(GameState.BIOME_SNOW)
	GameState.add_resource(GameState.RES_WOOD, 77.5)
	GameState.add_resource(GameState.RES_BERRIES, 33.0)
	GameState.add_resource(GameState.RES_RESIN, 14.0)
	GameState.add_resource(GameState.RES_ICE, 55.0)
	GameState.add_resource(GameState.RES_CRYSTALS, 21.5)
	GameState.rubble_levels[&"forest_grove"] = 1
	GameState.station_worker_unlocked[&"forest_grove"] = true
	GameState.run_surface_progress = 12345.0
	assert_true(SaveManager.save_game())
	var re_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	assert_eq(int((re_parsed as Dictionary).get("version", 0)), 6)
	var saved_v6_game: Dictionary = (re_parsed as Dictionary).get("game", {}) as Dictionary
	assert_false(saved_v6_game.has("fossil_catalog"))

	GameState.start_new_game()
	assert_true(SaveManager.load_game())
	assert_eq(GameState.current_biome, GameState.BIOME_SNOW, "Save v6 deve restaurar current_biome")
	assert_almost_eq(GameState.get_resource(GameState.RES_WOOD), 77.5, 0.01)
	assert_almost_eq(GameState.get_resource(GameState.RES_BERRIES), 33.0, 0.01)
	assert_almost_eq(GameState.get_resource(GameState.RES_RESIN), 14.0, 0.01)
	assert_almost_eq(GameState.get_resource(GameState.RES_ICE), 55.0, 0.01)
	assert_almost_eq(GameState.get_resource(GameState.RES_CRYSTALS), 21.5, 0.01)
	assert_true(GameState.has_station_worker(&"rubble_nest"))
	assert_true(GameState.has_station_worker(&"forest_grove"))
	assert_false(GameState.has_station_worker(&"rubble_forge"))
	assert_almost_eq(GameState.run_surface_progress, 12345.0, 0.01)
	assert_eq(GameState.raw_fossil_queue, [&"ankylosaurus"])
	assert_almost_eq(GameState.fossil_cleaning_progress, 0.4, 0.01)
