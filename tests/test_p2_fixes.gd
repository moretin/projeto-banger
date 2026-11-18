extends GutTest
## Testes de regressão dos bugs P2: Rocha Laranja, pausa do meteoro com modal de Âmbar e signals ligados.


func before_each() -> void:
	SaveManager.autosave_enabled = false
	GameState.start_new_game()


func after_each() -> void:
	GameState.is_prestige_modal_open = false


func test_orange_rock_click_does_not_emit_fake_crit_dig_hit() -> void:
	var packed: PackedScene = load("res://scenes/surface/SurfaceScene.tscn") as PackedScene
	var surface: SurfaceScene = packed.instantiate() as SurfaceScene
	add_child_autoqfree(surface)
	await get_tree().process_frame

	watch_signals(Events)
	var mb := InputEventMouseButton.new()
	mb.button_index = MOUSE_BUTTON_LEFT
	mb.pressed = true
	mb.position = Vector2(16.0, 16.0)
	surface._on_orange_rock_gui_input(mb)

	assert_signal_emitted(Events, "orange_rock_hit", "Clique na Rocha Laranja deve emitir orange_rock_hit")
	assert_signal_not_emitted(Events, "dig_hit", "Clique na Rocha Laranja não pode disparar dig_hit falso sempre crítico")
	assert_lt(GameState.orange_rock_hp, GameState.ORANGE_ROCK_MAX_HP, "Dano deve ser aplicado na Rocha Laranja")


func test_meteor_timer_paused_while_amber_modal_open() -> void:
	var packed: PackedScene = load("res://scenes/meteor/MeteorOverlay.tscn") as PackedScene
	var overlay: MeteorOverlay = packed.instantiate() as MeteorOverlay
	add_child_autoqfree(overlay)
	await get_tree().process_frame

	var t0: float = GameState.meteor_time_left
	assert_true(GameState.meteor_active)
	assert_false(GameState.is_prestige_modal_open)

	Events.prestige_modal_requested.emit()
	assert_true(GameState.is_prestige_modal_open, "Abrir modal de Âmbar deve pausar o meteoro")
	GameState._process(5.0)
	assert_almost_eq(GameState.meteor_time_left, t0, 0.0001, "Timer do meteoro deve ficar congelado com o modal aberto")

	var close_btn: Button = overlay.get_node("%CloseButton") as Button
	close_btn.pressed.emit()
	assert_false(GameState.is_prestige_modal_open, "Fechar modal de Âmbar deve despausar o meteoro")
	GameState._process(5.0)
	assert_almost_eq(GameState.meteor_time_left, t0 - 5.0, 0.0001, "Timer do meteoro deve voltar a correr ao fechar o modal")


func test_dino_fossil_completed_emits_when_threshold_reached() -> void:
	watch_signals(Events)
	var req: int = GameState.get_required_fragments_for_dino(&"compsognathus")
	assert_gt(req, 0)
	GameState.add_fragments(&"compsognathus", req)
	assert_signal_emitted_with_parameters(Events, "dino_fossil_completed", [&"compsognathus", req, req])


func test_all_events_signals_have_emitter_and_listener() -> void:
	var events_text: String = FileAccess.get_file_as_string("res://autoload/Events.gd")
	var sig_regex := RegEx.new()
	sig_regex.compile("(?m)^signal\\s+([A-Za-z0-9_]+)")
	var signals: Array[String] = []
	for m: RegExMatch in sig_regex.search_all(events_text):
		signals.append(m.get_string(1))

	var scripts_content: PackedStringArray = []
	for root_dir: String in ["res://autoload", "res://scenes"]:
		_collect_gd_texts(root_dir, scripts_content)
	var combined: String = "\n".join(scripts_content)

	for sig: String in signals:
		var has_emit: bool = combined.contains("Events.%s.emit" % sig)
		var has_connect: bool = combined.contains("Events.%s.connect" % sig)
		assert_true(has_emit, "Signal Events.%s deve possuir ao menos um emissor" % sig)
		assert_true(has_connect, "Signal Events.%s deve possuir ao menos um ouvinte" % sig)


static func _collect_gd_texts(dir_path: String, out: PackedStringArray) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return
	for sub: String in dir.get_directories():
		_collect_gd_texts(dir_path.path_join(sub), out)
	for file: String in dir.get_files():
		if not file.ends_with(".gd"):
			continue
		var full_path: String = dir_path.path_join(file)
		if full_path == "res://autoload/Events.gd" or full_path == "res://scenes/ui/test_ui_layout.gd":
			continue
		out.append(FileAccess.get_file_as_string(full_path))
