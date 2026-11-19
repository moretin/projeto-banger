extends GutTest
## Teste de fumaça: instancia Main.tscn e executa 600 frames sem erros ou travamentos.


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
	assert_lt(GameState.meteor_time_left, initial_meteor, "Timer do meteoro deve avançar normalmente durante os 600 frames")

	main_instance.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	SaveManager.autosave_enabled = prev_autosave


func test_hud_updates_balances_rates_and_forecast_with_the_meteor_paused() -> void:
	GameState.start_new_game()
	var hud_scene: PackedScene = preload("res://scenes/ui/HUD.tscn")
	var hud: HUD = hud_scene.instantiate() as HUD
	add_child_autofree(hud)
	var bones: Label = hud.get_node("%BonesLabel") as Label
	var dna_rate: Label = hud.get_node("%DnaRate") as Label
	var forecast: Label = hud.get_node("%AmberForecast") as Label
	var countdown: Label = hud.get_node("%MeteorLabel") as Label
	var start_countdown: String = countdown.text
	var start_forecast: String = forecast.text

	Events.prestige_modal_visibility_changed.emit(true)
	Events.orange_rock_hit.emit(20000.0, Vector2.ZERO)
	GameState.add_resource(GameState.RES_BONES, 1000000000.0)
	await get_tree().process_frame
	await get_tree().process_frame

	assert_eq(bones.text, GameState.format_number(GameState.get_resource(GameState.RES_BONES)))
	assert_eq(dna_rate.text, "+%s/s" % GameState.format_number(GameState.get_dna_per_second()))
	assert_ne(dna_rate.text, "+0/s", "O nascimento do primeiro dino deve atualizar a produção")
	assert_eq(forecast.text, "Previsão: +%s Âmbar" % GameState.format_number(GameState.calculate_amber_reward()))
	assert_ne(forecast.text, start_forecast, "O ganho de ossos atualiza a previsão com o cronômetro pausado")
	assert_eq(countdown.text, start_countdown)

	GameState.start_new_game()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(bones.text, "0")
	assert_eq(dna_rate.text, "+0/s")
	assert_eq(forecast.text, "Previsão: +0 Âmbar")
