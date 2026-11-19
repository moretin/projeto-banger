extends GutTest
## Testes do sistema de Save v3 (incl. Museu e migração v2→v3), proteção de Âmbar no prestígio e migração v1.

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


func test_museum_catalog_roundtrip_and_prestige_persistence() -> void:
	GameState.register_fossil_found(&"compsognathus", 1)
	GameState.register_fossil_found(&"trex", 3)
	GameState.register_fossil_found(&"trex", 2)
	assert_eq(GameState.total_fossils_evaluated, 3)
	assert_eq(GameState.total_legendary_fossils, 1)

	# Prestígio NÃO deve limpar o catálogo do Museu.
	GameState.add_resource(GameState.RES_BONES, 250000000.0)
	GameState.depth = 15
	GameState.perform_prestige(0.0)
	assert_eq(GameState.total_fossils_evaluated, 3, "Museu deve sobreviver ao prestígio")
	assert_eq(GameState.total_legendary_fossils, 1)

	assert_true(SaveManager.save_game())
	var exported: String = SaveManager.export_save_string()
	GameState.start_new_game()
	assert_eq(GameState.total_fossils_evaluated, 0, "start_new_game() deve zerar Museu antes do load")

	assert_true(SaveManager.load_game(), "load_game() deve restaurar o Museu salvo na v3")
	assert_eq(GameState.total_fossils_evaluated, 3)
	assert_eq(GameState.total_legendary_fossils, 1)
	assert_true(GameState.fossil_catalog.has(&"trex"))
	var trex_rec: Dictionary = GameState.fossil_catalog.get(&"trex", {}) as Dictionary
	assert_eq(int(trex_rec.get("count", 0)), 2)
	assert_eq(int(trex_rec.get("best_rarity", 0)), 3)
	assert_gt((trex_rec.get("parts", []) as Array).size(), 0)

	GameState.start_new_game()
	assert_true(SaveManager.import_save_string(exported), "Base64 também deve preservar o catálogo do Museu")
	assert_eq(GameState.total_fossils_evaluated, 3)
	assert_eq(GameState.total_legendary_fossils, 1)
	assert_true(GameState.fossil_catalog.has(&"compsognathus"))


func test_v2_save_migrates_to_v3_preserving_progress_with_empty_museum() -> void:
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

	assert_true(SaveManager.load_game(), "Save v2 deve migrar para v3 sem falhar")
	assert_eq(SaveManager.last_migrated_reset_version, -1, "Migração v2→v3 NÃO pode descartar progresso")
	assert_almost_eq(GameState.get_resource(GameState.RES_BONES), 4567.0, 0.01)
	assert_almost_eq(GameState.get_resource(GameState.RES_AMBER), 84.0, 0.01)
	assert_eq(GameState.get_dino_count(&"compsognathus"), 5)
	assert_eq(GameState.get_upgrade_level(&"amber_ark_project"), 1)
	assert_eq(GameState.run_number, 5)
	assert_eq(GameState.max_depth_ever, 14)
	assert_true(GameState.fossil_catalog.is_empty(), "Save v2 migrado deve iniciar com Museu vazio")
	assert_eq(GameState.total_fossils_evaluated, 0)
	assert_eq(GameState.total_legendary_fossils, 0)

	assert_true(SaveManager.save_game())
	var re_parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.SAVE_PATH))
	assert_eq(int((re_parsed as Dictionary).get("version", 0)), SaveManager.SAVE_VERSION)
