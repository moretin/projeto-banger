extends GutTest
## Regression tests for the ambient meteor tremor: no constant camera jitter.

const MAIN_SCENE: PackedScene = preload("res://scenes/main/Main.tscn")


func test_tremor_stays_disabled_before_final_danger_phase() -> void:
	var main: Control = MAIN_SCENE.instantiate() as Control
	add_child_autofree(main)
	await get_tree().process_frame

	for elapsed: float in [0.0, 0.1, 0.3, 1.0, 10.0]:
		var offset: float = float(main.call("_meteor_tremor_offset", 0.70, elapsed))
		assert_almost_eq(offset, 0.0, 0.001)


func test_tremor_is_brief_and_bounded() -> void:
	var main: Control = MAIN_SCENE.instantiate() as Control
	add_child_autofree(main)
	await get_tree().process_frame

	var peak_detected: bool = false
	for i: int in range(451):
		var time: float = float(i) / 1000.0
		var offset: float = float(main.call("_meteor_tremor_offset", 1.0, time))
		assert_lte(absf(offset), 2.401, "Meteor offset must stay subtle")
		if absf(offset) > 0.5:
			peak_detected = true
	assert_true(peak_detected, "A late-game meteor must still produce a visible tremor")

	for elapsed: float in [0.45, 0.75, 2.0, 3.9, 4.49]:
		var offset: float = float(main.call("_meteor_tremor_offset", 1.0, elapsed))
		assert_almost_eq(offset, 0.0, 0.001, "Most of each period should be still")


func test_tremor_fades_with_danger_and_repeats_periodically() -> void:
	var main: Control = MAIN_SCENE.instantiate() as Control
	add_child_autofree(main)
	await get_tree().process_frame

	var full: float = float(main.call("_meteor_tremor_offset", 1.0, 0.19))
	var partial: float = float(main.call("_meteor_tremor_offset", 0.86, 0.19))
	assert_lte(absf(partial), absf(full) + 0.001)
	var repeated: float = float(main.call("_meteor_tremor_offset", 1.0, 4.69))
	assert_almost_eq(repeated, full, 0.001)
