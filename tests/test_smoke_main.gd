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
