class_name QuarryExtractionModal
extends Control
## Minigame dedicado de extração na Jazida da Pedreira (20–40s).
##
## Escova uma grade sedimentar 18x10 revelando o fóssil em pixel art da cauda
## blindada do Anquilossauro ("Placa Especial") e integra o Sismógrafo de Golpe
## Preciso abaixo da laje para acelerar a extração sem punir erros.

const GRID_COLS: int = 18
const GRID_ROWS: int = 10
const CELL_COUNT: int = GRID_COLS * GRID_ROWS
const BED_WIDTH: float = 540.0
const BED_HEIGHT: float = 280.0
const FOSSIL_ART: Texture2D = preload("res://assets/sprites/surface/quarry_fossil.png")
const SEDIMENT_ART: Texture2D = preload("res://assets/sprites/surface/quarry_sediment.png")

const COMPLETE_CLEAR_THRESHOLD: float = 0.92
const BRUSH_STEP_PX: float = 20.0
const BRUSH_RADIUS_PX: float = 38.0
const BRUSH_STEPS_PER_SEC_BUDGET: float = 16.0
const BRUSH_BUDGET_CAP: float = 5.0

const MAX_BRUSH_PUFFS: int = 56
const MAX_ROCK_SHARDS: int = 44

const STRIKE_PROGRESS_INTERVAL: float = 0.24
const STRIKE_TIME_INTERVAL: float = 6.0
const STRIKE_MAX_PROGRESS_THRESHOLD: float = 0.96
const STRIKE_WINDOW_DURATION: float = 3.0
const STRIKE_RESULT_HOLD: float = 1.15
const SWEET_HALF_PERFECT: float = 0.065
const SWEET_HALF_GOOD: float = 0.19
const STRIKE_PERFECT_BONUS: float = 0.22
const STRIKE_GOOD_BONUS: float = 0.12

const COL_FOSSIL_BONE: Color = Color("#d89b6e")
const COL_AMBER_VEIN: Color = Color("#edaa48")


@onready var _header_icon: TextureRect = %HeaderIcon
@onready var _title_label: Label = %TitleLabel
@onready var _close_button: Button = %CloseButton
@onready var _progress_bar: ProgressBar = %ExtractionProgressBar
@onready var _progress_label: Label = %ProgressPercentLabel
@onready var _hint_label: Label = %HintLabel
@onready var _sediment_bed: Control = %SedimentBed
@onready var _seismograph_bar: Control = %SeismographBar
@onready var _status_label: Label = %StatusLabel
@onready var _complete_return_button: Button = %CompleteReturnButton

var _brush_tex: Texture2D = null

var _sediment_cells: PackedFloat32Array = PackedFloat32Array()
var _progress: float = 0.0
var _completed: bool = false

var _is_hovering_bed: bool = false
var _is_brushing: bool = false
var _brush_last_pos: Vector2 = Vector2.ZERO
var _brush_cursor_pos: Vector2 = Vector2(-100.0, -100.0)
var _brush_accum_px: float = 0.0
var _brush_tilt: float = 0.0
var _drag_step_budget: float = BRUSH_BUDGET_CAP
var _recent_brush_timer: float = 0.0
var _bed_shake: float = 0.0
var _celebrate_time: float = 0.0

var _dust_puffs: Array[Dictionary] = []
var _rock_shards: Array[Dictionary] = []

var _strike_active: bool = false
var _strike_resolved: bool = false
var _strike_elapsed: float = 0.0
var _strike_result_hold: float = 0.0
var _needle_pos: float = 0.5
var _sweet_center: float = 0.5
var _progress_since_strike: float = 0.0
var _active_brush_time_since_strike: float = 0.0
var _strike_status_text: String = "SISMÓGRAFO — Escove o arenito para despertar o pulso sísmico"
var _strike_status_color: Color = Color(0.92, 0.80, 0.58, 0.92)
var _previous_focus: Control = null


func _ready() -> void:
	visible = false
	z_index = 26
	_sediment_cells.resize(CELL_COUNT)
	_reset_sediment_grid()

	_brush_tex = AmberTheme.get_icon(&"brush")
	if _header_icon != null:
		_header_icon.texture = _brush_tex

	_close_button.pressed.connect(close_extraction)
	_complete_return_button.pressed.connect(close_extraction)

	_sediment_bed.gui_input.connect(_on_bed_gui_input)
	_sediment_bed.mouse_entered.connect(_on_bed_mouse_entered)
	_sediment_bed.mouse_exited.connect(_on_bed_mouse_exited)
	_sediment_bed.draw.connect(_on_bed_draw)

	_seismograph_bar.gui_input.connect(_on_seismo_gui_input)
	_seismograph_bar.draw.connect(_on_seismo_draw)

	Events.quarry_extraction_requested.connect(open_extraction)
	Events.meteor_impact_started.connect(close_extraction)
	Events.run_started.connect(close_extraction.unbind(1))
	Events.game_loaded.connect(close_extraction)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return

	_drag_step_budget = minf(_drag_step_budget + delta * BRUSH_STEPS_PER_SEC_BUDGET, BRUSH_BUDGET_CAP)
	_brush_tilt = lerpf(_brush_tilt, 0.0, minf(delta * 10.0, 1.0))
	if _bed_shake > 0.05:
		_bed_shake = lerpf(_bed_shake, 0.0, minf(delta * 15.0, 1.0))
	else:
		_bed_shake = 0.0

	var particles_active: bool = _tick_particles(delta)

	if _completed:
		_celebrate_time += delta
		_sediment_bed.queue_redraw()
		return

	if _recent_brush_timer > 0.0:
		_recent_brush_timer = maxf(_recent_brush_timer - delta, 0.0)
		if not _strike_active:
			_active_brush_time_since_strike += delta
			if _active_brush_time_since_strike >= STRIKE_TIME_INTERVAL and _progress < STRIKE_MAX_PROGRESS_THRESHOLD:
				trigger_precise_strike_window()

	if _strike_active:
		if _strike_resolved:
			_strike_result_hold -= delta
			if _strike_result_hold <= 0.0:
				_strike_active = false
				_strike_resolved = false
				_strike_status_text = "SISMÓGRAFO — Escove o arenito para despertar o pulso sísmico"
				_strike_status_color = Color(0.92, 0.80, 0.58, 0.92)
			_seismograph_bar.queue_redraw()
		else:
			_strike_elapsed += delta
			_needle_pos = 0.5 + sin(_strike_elapsed * 4.4) * 0.46
			if _strike_elapsed >= STRIKE_WINDOW_DURATION:
				resolve_precise_strike_attempt(&"miss")
			else:
				_seismograph_bar.queue_redraw()
	elif _recent_brush_timer > 0.0:
		_seismograph_bar.queue_redraw()

	if particles_active or _is_hovering_bed or _bed_shake > 0.0:
		_sediment_bed.queue_redraw()


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree():
		return
	var ek: InputEventKey = event as InputEventKey
	if ek == null or not ek.pressed or ek.echo:
		return
	var vp: Viewport = get_viewport()
	if ek.keycode == KEY_ESCAPE:
		close_extraction()
		if vp != null:
			vp.set_input_as_handled()
		return
	if _strike_active and not _strike_resolved and not _completed:
		if ek.keycode == KEY_SPACE or ek.keycode == KEY_ENTER or ek.keycode == KEY_KP_ENTER:
			_resolve_strike_from_player_input()
			if vp != null:
				vp.set_input_as_handled()


func open_extraction() -> void:
	if is_inside_tree():
		var vp: Viewport = get_viewport()
		if vp != null:
			var owner_ctrl: Control = vp.gui_get_focus_owner()
			if owner_ctrl != null and not is_ancestor_of(owner_ctrl):
				_previous_focus = owner_ctrl

	_progress = 0.0
	_completed = false
	_is_brushing = false
	_is_hovering_bed = false
	_brush_accum_px = 0.0
	_brush_tilt = 0.0
	_drag_step_budget = BRUSH_BUDGET_CAP
	_recent_brush_timer = 0.0
	_bed_shake = 0.0
	_celebrate_time = 0.0
	_dust_puffs.clear()
	_rock_shards.clear()

	_strike_active = false
	_strike_resolved = false
	_strike_elapsed = 0.0
	_strike_result_hold = 0.0
	_needle_pos = 0.5
	_sweet_center = 0.5
	_progress_since_strike = 0.0
	_active_brush_time_since_strike = 0.0
	_strike_status_text = "SISMÓGRAFO — Escove o arenito para despertar o pulso sísmico"
	_strike_status_color = Color(0.92, 0.80, 0.58, 0.92)

	_reset_sediment_grid()

	if _title_label != null:
		_title_label.text = "Jazida da Pedreira — Extração de Fóssil"
	if _hint_label != null:
		_hint_label.text = "Arraste a escova sobre o arenito para revelar a placa da cauda do Anquilossauro."
	if _status_label != null:
		_status_label.text = "Escove com o botão esquerdo do mouse; acerte o Sismógrafo para acelerar!"
		_status_label.add_theme_color_override("font_color", Color(0.96, 0.88, 0.70, 1.0))
	if _complete_return_button != null:
		_complete_return_button.visible = false
	if _seismograph_bar != null:
		_seismograph_bar.mouse_default_cursor_shape = Control.CURSOR_ARROW

	_sync_progress_ui()
	visible = true

	if _sediment_bed != null:
		_sediment_bed.queue_redraw()
		if is_inside_tree():
			_sediment_bed.grab_focus()
	if _seismograph_bar != null:
		_seismograph_bar.queue_redraw()


func close_extraction() -> void:
	visible = false
	_is_brushing = false
	_is_hovering_bed = false
	_strike_active = false
	_strike_resolved = false
	_recent_brush_timer = 0.0
	if _seismograph_bar != null:
		_seismograph_bar.mouse_default_cursor_shape = Control.CURSOR_ARROW

	if is_inside_tree() and _previous_focus != null and is_instance_valid(_previous_focus):
		if _previous_focus.is_visible_in_tree() and _previous_focus.focus_mode != Control.FOCUS_NONE:
			_previous_focus.grab_focus()
	_previous_focus = null


func is_extraction_open() -> bool:
	return visible


func get_extraction_progress() -> float:
	return _progress


func get_visual_cleared_ratio() -> float:
	var total_remaining: float = 0.0
	for idx: int in range(_sediment_cells.size()):
		total_remaining += _sediment_cells[idx]
	return clampf(1.0 - total_remaining / float(maxi(CELL_COUNT, 1)), 0.0, 1.0)


func apply_brush_progress(amount: float) -> void:
	if not visible or _completed or amount <= 0.0:
		return
	var target_mass: float = amount * COMPLETE_CLEAR_THRESHOLD * float(CELL_COUNT)
	_erode_mass_outward(target_mass)
	_recompute_progress_from_grid(true)
	if _sediment_bed != null:
		_sediment_bed.queue_redraw()


func trigger_precise_strike_window() -> void:
	if not visible or _completed:
		return
	_strike_active = true
	_strike_resolved = false
	_strike_elapsed = 0.0
	_strike_result_hold = 0.0
	_progress_since_strike = 0.0
	_active_brush_time_since_strike = 0.0
	_sweet_center = randf_range(0.36, 0.64)
	_needle_pos = 0.06
	_strike_status_text = "GOLPE PRECISO! CLIQUE AQUI OU [ESPAÇO] / [ENTER]"
	_strike_status_color = Color(1.0, 0.90, 0.62, 1.0)
	if _seismograph_bar != null:
		_seismograph_bar.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_seismograph_bar.queue_redraw()


func resolve_precise_strike_attempt(hit_quality: StringName) -> void:
	if not visible or _completed:
		return
	if _strike_active and _strike_resolved:
		return

	_strike_active = true
	_strike_resolved = true
	_strike_result_hold = STRIKE_RESULT_HOLD
	_progress_since_strike = 0.0
	_active_brush_time_since_strike = 0.0
	if _seismograph_bar != null:
		_seismograph_bar.mouse_default_cursor_shape = Control.CURSOR_ARROW

	if hit_quality == &"perfect":
		_strike_status_text = "GOLPE PERFEITO! (+22%)"
		_strike_status_color = Color(1.0, 0.86, 0.30, 1.0)
		if _status_label != null:
			_status_label.text = "Epicentro perfeito! Camada espessa estilhaçada (+22%)."
			_status_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.34, 1.0))
		_bed_shake = 6.0
		_shatter_sediment_mass(STRIKE_PERFECT_BONUS, true)
		_recompute_progress_from_grid(false)
		Events.precise_strike_resolved.emit(&"perfect", 22.0)
	elif hit_quality == &"good":
		_strike_status_text = "BOM GOLPE! (+12%)"
		_strike_status_color = Color(0.55, 0.94, 0.52, 1.0)
		if _status_label != null:
			_status_label.text = "Boa ressonância! Fragmentos de arenito soltos (+12%)."
			_status_label.add_theme_color_override("font_color", Color(0.62, 0.94, 0.56, 1.0))
		_bed_shake = 3.5
		_shatter_sediment_mass(STRIKE_GOOD_BONUS, false)
		_recompute_progress_from_grid(false)
		Events.precise_strike_resolved.emit(&"good", 12.0)
	else:
		_strike_status_text = "Sem ressonância — continue escovando!"
		_strike_status_color = Color(0.86, 0.74, 0.56, 0.96)
		if _status_label != null:
			_status_label.text = "Sem ressonância — continue escovando!"
			_status_label.add_theme_color_override("font_color", Color(0.92, 0.82, 0.64, 1.0))
		Events.precise_strike_resolved.emit(&"miss", 0.0)

	if _seismograph_bar != null:
		_seismograph_bar.queue_redraw()
	if _sediment_bed != null:
		_sediment_bed.queue_redraw()


func _recompute_progress_from_grid(from_brush: bool) -> void:
	if _completed:
		return
	var next_progress: float = clampf(get_visual_cleared_ratio() / COMPLETE_CLEAR_THRESHOLD, 0.0, 1.0)
	var delta_progress: float = maxf(next_progress - _progress, 0.0)
	_progress = next_progress
	_sync_progress_ui()

	if _progress >= 1.0 - 1e-6:
		_complete_extraction()
		return

	if from_brush and not _strike_active and delta_progress > 0.0:
		_progress_since_strike += delta_progress
		if (
			(_progress_since_strike >= STRIKE_PROGRESS_INTERVAL or _active_brush_time_since_strike >= STRIKE_TIME_INTERVAL)
			and _progress < STRIKE_MAX_PROGRESS_THRESHOLD
		):
			trigger_precise_strike_window()


func _complete_extraction() -> void:
	if _completed:
		return
	_completed = true
	_progress = 1.0
	_is_brushing = false
	_recent_brush_timer = 0.0
	_celebrate_time = 0.0
	if _strike_active and not _strike_resolved:
		_strike_active = false
		_strike_resolved = false
		if _seismograph_bar != null:
			_seismograph_bar.mouse_default_cursor_shape = Control.CURSOR_ARROW

	for idx: int in range(CELL_COUNT):
		_sediment_cells[idx] = 0.0

	GameState.claim_quarry_special_plate()

	_sync_progress_ui()
	if _hint_label != null:
		_hint_label.text = "Fóssil completo exposto na jazida!"
	if _status_label != null:
		_status_label.text = "Placa Especial do Anquilossauro liberada! Volte à Pedreira para despertá-lo!"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.36, 1.0))
	if _strike_status_text.begins_with("GOLPE PRECISO") or _strike_status_text.begins_with("SISMÓGRAFO"):
		_strike_status_text = "EXTRAÇÃO CONCLUÍDA — Placa Especial recuperada!"
		_strike_status_color = Color(1.0, 0.88, 0.36, 1.0)
	if _complete_return_button != null:
		_complete_return_button.visible = true
		if is_inside_tree():
			_complete_return_button.grab_focus()
	if _sediment_bed != null:
		_sediment_bed.queue_redraw()
	if _seismograph_bar != null:
		_seismograph_bar.queue_redraw()


func _sync_progress_ui() -> void:
	var pct: float = clampf(_progress * 100.0, 0.0, 100.0)
	if _progress_bar != null:
		_progress_bar.value = pct
	if _progress_label != null:
		_progress_label.text = "%d%%" % roundi(pct)


func _reset_sediment_grid() -> void:
	for idx: int in range(CELL_COUNT):
		_sediment_cells[idx] = 1.0


func _resolve_strike_from_player_input() -> void:
	var dist: float = absf(_needle_pos - _sweet_center)
	if dist <= SWEET_HALF_PERFECT:
		resolve_precise_strike_attempt(&"perfect")
	elif dist <= SWEET_HALF_GOOD:
		resolve_precise_strike_attempt(&"good")
	else:
		resolve_precise_strike_attempt(&"miss")


func _on_bed_mouse_entered() -> void:
	_is_hovering_bed = true
	_sediment_bed.queue_redraw()


func _on_bed_mouse_exited() -> void:
	_is_hovering_bed = false
	_is_brushing = false
	_brush_accum_px = 0.0
	_sediment_bed.queue_redraw()


func _on_bed_gui_input(event: InputEvent) -> void:
	if not visible or _completed:
		return

	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_brush_cursor_pos = mb.position
		if mb.pressed:
			_is_brushing = true
			_brush_last_pos = mb.position
			_perform_brush_step(mb.position, Vector2.UP * 8.0, true)
		else:
			_is_brushing = false
			_brush_accum_px = 0.0
		_sediment_bed.queue_redraw()
		_sediment_bed.accept_event()
		return

	var mm: InputEventMouseMotion = event as InputEventMouseMotion
	if mm != null:
		_is_hovering_bed = true
		_brush_cursor_pos = mm.position
		var holding_left: bool = (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0 or _is_brushing
		if holding_left:
			var step_vec: Vector2 = mm.position - _brush_last_pos
			var step_len: float = step_vec.length()
			if step_len < 0.5:
				step_vec = mm.relative
				step_len = step_vec.length()
			_brush_last_pos = mm.position
			_brush_tilt = clampf(step_vec.x * 0.04, -0.55, 0.55)
			if step_len > 0.5:
				_brush_accum_px += step_len
				while _brush_accum_px >= BRUSH_STEP_PX:
					_brush_accum_px -= BRUSH_STEP_PX
					if _drag_step_budget >= 1.0:
						_drag_step_budget -= 1.0
						_perform_brush_step(mm.position, step_vec, false)
					else:
						var micro_cleared: float = _scrub_cells_at(mm.position, 0.30)
						if micro_cleared > 0.0:
							_recent_brush_timer = 0.25
							_recompute_progress_from_grid(true)
		else:
			_brush_last_pos = mm.position
			_brush_tilt = clampf(mm.relative.x * 0.02, -0.32, 0.32)
		_sediment_bed.queue_redraw()


func _on_seismo_gui_input(event: InputEvent) -> void:
	if not visible or _completed or not _strike_active or _strike_resolved:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_resolve_strike_from_player_input()
		_seismograph_bar.accept_event()


func _perform_brush_step(local_pos: Vector2, motion_vec: Vector2, is_click: bool) -> void:
	var cleared_amount: float = _scrub_cells_at(local_pos, 1.35 if is_click else 1.0)
	if cleared_amount > 0.0:
		_recent_brush_timer = 0.25
		_spawn_dust_puffs(local_pos, motion_vec, 3 if is_click else 2)
		var global_pos: Vector2 = _sediment_bed.get_global_transform_with_canvas() * local_pos
		Events.brush_stroke.emit(global_pos)
		_recompute_progress_from_grid(true)
	elif is_click:
		_spawn_dust_puffs(local_pos, motion_vec, 1)


func _scrub_cells_at(local_pos: Vector2, strength: float) -> float:
	var bed_sz: Vector2 = _get_bed_size()
	var cell_w: float = bed_sz.x / float(GRID_COLS)
	var cell_h: float = bed_sz.y / float(GRID_ROWS)
	var total_cleared: float = 0.0

	for row: int in range(GRID_ROWS):
		for col: int in range(GRID_COLS):
			var idx: int = row * GRID_COLS + col
			var cur: float = _sediment_cells[idx]
			if cur <= 0.0:
				continue
			var center := Vector2((float(col) + 0.5) * cell_w, (float(row) + 0.5) * cell_h)
			var dist: float = center.distance_to(local_pos)
			if dist <= BRUSH_RADIUS_PX:
				var falloff: float = clampf(1.0 - dist / BRUSH_RADIUS_PX, 0.0, 1.0)
				var cut: float = (0.065 + 0.125 * falloff) * strength
				var next_val: float = maxf(cur - cut, 0.0)
				if next_val < 0.02:
					next_val = 0.0
				_sediment_cells[idx] = next_val
				total_cleared += cur - next_val
	return total_cleared


func _erode_mass_outward(target_mass: float) -> void:
	if target_mass <= 0.0:
		return
	var bed_sz: Vector2 = _get_bed_size()
	var cell_w: float = bed_sz.x / float(GRID_COLS)
	var cell_h: float = bed_sz.y / float(GRID_ROWS)
	var fossil_focus := Vector2(bed_sz.x * 0.54, bed_sz.y * 0.50)

	var candidates: Array[Dictionary] = []
	for row: int in range(GRID_ROWS):
		for col: int in range(GRID_COLS):
			var idx: int = row * GRID_COLS + col
			var val: float = _sediment_cells[idx]
			if val <= 0.001:
				continue
			var cpos := Vector2((float(col) + 0.5) * cell_w, (float(row) + 0.5) * cell_h)
			candidates.append({"idx": idx, "dist": cpos.distance_to(fossil_focus)})

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["dist"]) < float(b["dist"])
	)

	var remaining_to_remove: float = target_mass
	for entry: Dictionary in candidates:
		if remaining_to_remove <= 0.0001:
			break
		var idx: int = int(entry["idx"])
		var cur: float = _sediment_cells[idx]
		var take: float = minf(cur, remaining_to_remove)
		var next_val: float = cur - take
		if next_val < 0.02:
			next_val = 0.0
		_sediment_cells[idx] = next_val
		remaining_to_remove -= take


func _shatter_sediment_mass(target_progress_gain: float, is_perfect: bool) -> void:
	var target_mass: float = maxf(target_progress_gain, 0.0) * COMPLETE_CLEAR_THRESHOLD * float(CELL_COUNT)
	if target_mass <= 0.0:
		return
	var bed_sz: Vector2 = _get_bed_size()
	var cell_w: float = bed_sz.x / float(GRID_COLS)
	var cell_h: float = bed_sz.y / float(GRID_ROWS)

	var candidates: Array[Dictionary] = []
	var preferred_focus := Vector2(bed_sz.x * 0.62, bed_sz.y * 0.50)
	for row: int in range(GRID_ROWS):
		for col: int in range(GRID_COLS):
			var idx: int = row * GRID_COLS + col
			var val: float = _sediment_cells[idx]
			if val <= 0.01:
				continue
			var center := Vector2((float(col) + 0.5) * cell_w, (float(row) + 0.5) * cell_h)
			var score: float = center.distance_to(preferred_focus) - val * 85.0
			candidates.append({"idx": idx, "center": center, "score": score})

	if candidates.is_empty():
		return

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) < float(b["score"])
	)
	var epicenter: Vector2 = candidates[0]["center"] as Vector2
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var da: float = (a["center"] as Vector2).distance_to(epicenter)
		var db: float = (b["center"] as Vector2).distance_to(epicenter)
		return da < db
	)

	var removed: float = 0.0
	for entry: Dictionary in candidates:
		if removed >= target_mass - 0.0001:
			break
		var idx: int = int(entry["idx"])
		var center: Vector2 = entry["center"] as Vector2
		var cur: float = _sediment_cells[idx]
		var need: float = target_mass - removed
		if cur <= need + 0.05:
			_sediment_cells[idx] = 0.0
			removed += cur
			_spawn_rock_shards(center, 3 if is_perfect else 2, is_perfect)
		else:
			_sediment_cells[idx] = maxf(cur - need, 0.0)
			removed += need
			_spawn_rock_shards(center, 2 if is_perfect else 1, is_perfect)


func _spawn_dust_puffs(local_pos: Vector2, motion_vec: Vector2, count: int) -> void:
	var drift: Vector2 = motion_vec.normalized() if motion_vec.length() > 1.0 else Vector2.UP
	for _i: int in range(count):
		if _dust_puffs.size() >= MAX_BRUSH_PUFFS:
			_dust_puffs.pop_front()
		_dust_puffs.append({
			"pos": local_pos + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0)),
			"vel": (drift * randf_range(-34.0, -12.0)) + Vector2(randf_range(-24.0, 24.0), randf_range(-32.0, -10.0)),
			"radius": randf_range(5.0, 11.0),
			"life": randf_range(0.28, 0.48),
			"max_life": 0.48,
		})


func _spawn_rock_shards(local_pos: Vector2, count: int, is_perfect: bool) -> void:
	for _i: int in range(count):
		if _rock_shards.size() >= MAX_ROCK_SHARDS:
			_rock_shards.pop_front()
		var angle: float = randf_range(-PI * 0.95, -PI * 0.05)
		var speed: float = randf_range(75.0, 195.0)
		_rock_shards.append({
			"pos": local_pos + Vector2(randf_range(-8.0, 8.0), randf_range(-6.0, 6.0)),
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"sz": randf_range(4.0, 8.0),
			"life": randf_range(0.32, 0.58),
			"max_life": 0.58,
			"col": COL_AMBER_VEIN if (is_perfect and randf() < 0.35) else COL_FOSSIL_BONE,
		})


func _tick_particles(delta: float) -> bool:
	var any_active: bool = false
	if not _dust_puffs.is_empty():
		any_active = true
		var idx: int = _dust_puffs.size() - 1
		while idx >= 0:
			var p: Dictionary = _dust_puffs[idx] as Dictionary
			var life: float = float(p["life"]) - delta
			if life <= 0.0:
				_dust_puffs.remove_at(idx)
			else:
				p["life"] = life
				p["pos"] = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
				p["radius"] = float(p["radius"]) + delta * 14.0
			idx -= 1

	if not _rock_shards.is_empty():
		any_active = true
		var idx2: int = _rock_shards.size() - 1
		while idx2 >= 0:
			var s: Dictionary = _rock_shards[idx2] as Dictionary
			var life2: float = float(s["life"]) - delta
			if life2 <= 0.0:
				_rock_shards.remove_at(idx2)
			else:
				s["life"] = life2
				var vel: Vector2 = (s["vel"] as Vector2) + Vector2(0.0, 380.0 * delta)
				s["vel"] = vel
				s["pos"] = (s["pos"] as Vector2) + vel * delta
			idx2 -= 1

	return any_active


func _get_bed_size() -> Vector2:
	if _sediment_bed != null and _sediment_bed.size.x > 10.0 and _sediment_bed.size.y > 10.0:
		return _sediment_bed.size
	return Vector2(BED_WIDTH, BED_HEIGHT)


func _on_bed_draw() -> void:
	var sz: Vector2 = _get_bed_size()
	var shake_offset := Vector2.ZERO
	if _bed_shake > 0.05:
		shake_offset = Vector2(
			randf_range(-_bed_shake, _bed_shake),
			randf_range(-_bed_shake * 0.65, _bed_shake * 0.65)
		)
	_sediment_bed.draw_set_transform(shake_offset, 0.0, Vector2.ONE)

	_sediment_bed.draw_texture_rect(FOSSIL_ART, Rect2(Vector2.ZERO, sz), false)

	# 2) Brilho celebratório pulsante sobre a placa da cauda quando concluída.
	if _completed:
		var pulse: float = 0.55 + 0.45 * sin(_celebrate_time * 4.5)
		var club_center := Vector2(sz.x * 0.77, sz.y * 0.46)
		_sediment_bed.draw_circle(club_center, 52.0 + pulse * 6.0, Color(1.0, 0.78, 0.28, 0.06 + pulse * 0.07))
		_sediment_bed.draw_circle(club_center, 30.0 + pulse * 4.0, Color(1.0, 0.90, 0.52, 0.08 + pulse * 0.08))
		for s_i: int in range(6):
			var ang: float = _celebrate_time * 1.4 + float(s_i) * (TAU / 6.0)
			var sp_pos: Vector2 = club_center + Vector2(cos(ang) * 58.0, sin(ang) * 34.0)
			var glint_alpha: float = 0.45 + 0.55 * absf(sin(_celebrate_time * 5.0 + float(s_i)))
			_sediment_bed.draw_rect(Rect2(sp_pos - Vector2(4.0, 1.0), Vector2(8.0, 2.0)), Color(1.0, 0.96, 0.76, glint_alpha))
			_sediment_bed.draw_rect(Rect2(sp_pos - Vector2(1.0, 4.0), Vector2(2.0, 8.0)), Color(1.0, 0.96, 0.76, glint_alpha))

	# A mesma textura contínua cobre todo o leito, com opacidade local da escovação.
	var cell_size: Vector2 = sz / Vector2(GRID_COLS, GRID_ROWS)
	var source_cell_size: Vector2 = SEDIMENT_ART.get_size() / Vector2(GRID_COLS, GRID_ROWS)
	var show_dust_hint: bool = (_progress >= 0.72 and not _completed)
	var hint_alpha: float = 0.16 * (0.5 + 0.5 * sin(float(Time.get_ticks_msec()) * 0.006)) if show_dust_hint else 0.0
	for row: int in range(GRID_ROWS):
		for col: int in range(GRID_COLS):
			var coverage: float = _sediment_cells[row * GRID_COLS + col]
			if coverage <= 0.01:
				continue
			var cell: Vector2 = Vector2(col, row)
			var destination: Rect2 = Rect2(cell * cell_size, cell_size)
			var source: Rect2 = Rect2(cell * source_cell_size, source_cell_size)
			var alpha: float = clampf(pow(coverage, 0.68), 0.0, 1.0)
			_sediment_bed.draw_texture_rect_region(SEDIMENT_ART, destination, source, Color(1.0, 1.0, 1.0, alpha))
			if show_dust_hint and coverage > 0.12:
				_sediment_bed.draw_rect(destination, Color(1.0, 0.90, 0.58, hint_alpha))

	# 4) Nuvens de poeira da escovação e estilhaços de rocha do Golpe Preciso.
	for p: Dictionary in _dust_puffs:
		var p_alpha: float = clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0) * 0.68
		_sediment_bed.draw_circle(p["pos"] as Vector2, float(p["radius"]), Color(0.96, 0.84, 0.62, p_alpha))

	for s: Dictionary in _rock_shards:
		var s_alpha: float = clampf(float(s["life"]) / float(s["max_life"]), 0.0, 1.0)
		var scol: Color = s["col"] as Color
		var ssz: float = float(s["sz"])
		var spos: Vector2 = s["pos"] as Vector2
		_sediment_bed.draw_rect(Rect2(spos - Vector2(ssz * 0.5, ssz * 0.5), Vector2(ssz, ssz)), Color(scol.r, scol.g, scol.b, s_alpha))

	_sediment_bed.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# 5) Ícone inclinado da escova acompanhando o cursor sobre a jazida.
	if (
		_is_hovering_bed
		and not _completed
		and _brush_tex != null
		and _brush_cursor_pos.x >= 0.0
		and _brush_cursor_pos.x <= sz.x
		and _brush_cursor_pos.y >= 0.0
		and _brush_cursor_pos.y <= sz.y
	):
		var press_off: Vector2 = Vector2(4.0, -5.0) if _is_brushing else Vector2(6.0, -9.0)
		_sediment_bed.draw_set_transform(_brush_cursor_pos + press_off, _brush_tilt - 0.18, Vector2(1.25, 1.25))
		_sediment_bed.draw_texture(_brush_tex, Vector2(-12.0, -14.0), Color(1.0, 0.96, 0.86, 0.95))
		_sediment_bed.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _on_seismo_draw() -> void:
	var w: float = _seismograph_bar.size.x
	var h: float = _seismograph_bar.size.y
	if w <= 20.0 or h <= 20.0:
		return

	var brass: Color = Color("#e9ae59") if _strike_active else Color("#9c6a3d")
	_seismograph_bar.draw_rect(Rect2(0.0, 3.0, w, h - 6.0), Color("#221418"))
	_seismograph_bar.draw_rect(Rect2(3.0, 1.0, w - 6.0, h - 5.0), Color("#774433"))
	_seismograph_bar.draw_rect(Rect2(6.0, 6.0, w - 12.0, h - 13.0), Color("#31201f"))
	_seismograph_bar.draw_rect(Rect2(4.0, 2.0, w - 8.0, 2.0), brass)
	for x: float in [8.0, w - 12.0]:
		for y: float in [8.0, h - 15.0]:
			_seismograph_bar.draw_rect(Rect2(x, y, 5.0, 5.0), Color("#42241e"))
			_seismograph_bar.draw_rect(Rect2(x, y, 3.0, 3.0), brass)

	var font: Font = ThemeDB.fallback_font
	if font != null:
		_seismograph_bar.draw_string(font, Vector2(12.0, 20.0), _strike_status_text, HORIZONTAL_ALIGNMENT_CENTER, w - 24.0, 12, _strike_status_color)

	# Faixa de papel milimetrado.
	var bar_x: float = 18.0
	var bar_y: float = 30.0
	var bar_w: float = w - 36.0
	var bar_h: float = 34.0
	var paper_col: Color = Color(0.95, 0.88, 0.72, 0.96) if _strike_active else Color(0.78, 0.68, 0.52, 0.42)
	_seismograph_bar.draw_rect(Rect2(bar_x - 3.0, bar_y - 3.0, bar_w + 6.0, bar_h + 6.0), Color("#1c1214"))
	_seismograph_bar.draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), paper_col)

	var grid_col := Color(0.76, 0.62, 0.42, 0.38 if _strike_active else 0.18)
	for gx: int in range(1, 16):
		var lx: float = bar_x + bar_w * (float(gx) / 16.0)
		_seismograph_bar.draw_line(Vector2(lx, bar_y), Vector2(lx, bar_y + bar_h), grid_col, 1.0)

	if _strike_active:
		# Zona Âmbar (good +-0.19) e Zona Central Ouro-Rubi (perfect +-0.065).
		var good_x0: float = bar_x + (_sweet_center - SWEET_HALF_GOOD) * bar_w
		var good_w: float = SWEET_HALF_GOOD * 2.0 * bar_w
		_seismograph_bar.draw_rect(Rect2(good_x0, bar_y + 2.0, good_w, bar_h - 4.0), Color(0.92, 0.64, 0.18, 0.58))

		var perf_x0: float = bar_x + (_sweet_center - SWEET_HALF_PERFECT) * bar_w
		var perf_w: float = SWEET_HALF_PERFECT * 2.0 * bar_w
		_seismograph_bar.draw_rect(Rect2(perf_x0, bar_y + 2.0, perf_w, bar_h - 4.0), Color(0.98, 0.84, 0.24, 0.94))
		_seismograph_bar.draw_rect(Rect2(perf_x0, bar_y + 2.0, perf_w, bar_h - 4.0), Color(0.68, 0.18, 0.08, 0.88), false, 2.0)

		var wave_pts := PackedVector2Array()
		for s_i: int in range(32):
			var r: float = float(s_i) / 31.0
			var wx: float = bar_x + r * bar_w
			var amp: float = 4.0 + maxf(0.0, 1.0 - absf(r - _sweet_center) * 4.0) * 9.0
			var wy: float = bar_y + bar_h * 0.5 + sin(r * 26.0 + _strike_elapsed * 18.0) * amp
			wave_pts.append(Vector2(wx, wy))
		_seismograph_bar.draw_polyline(wave_pts, Color(0.28, 0.14, 0.06, 0.72), 1.6)

		var nx: float = bar_x + _needle_pos * bar_w
		_seismograph_bar.draw_rect(Rect2(nx - 3.0, bar_y - 3.0, 6.0, bar_h + 6.0), Color(0.16, 0.08, 0.04, 1.0))
		_seismograph_bar.draw_rect(Rect2(nx - 1.0, bar_y - 1.0, 2.0, bar_h + 2.0), Color(1.0, 0.94, 0.72, 1.0))

		var time_ratio: float = 1.0 - clampf(_strike_elapsed / STRIKE_WINDOW_DURATION, 0.0, 1.0)
		_seismograph_bar.draw_rect(Rect2(bar_x, bar_y + bar_h + 8.0, bar_w, 5.0), Color(0.09, 0.05, 0.03, 0.90))
		_seismograph_bar.draw_rect(Rect2(bar_x, bar_y + bar_h + 8.0, bar_w * time_ratio, 5.0), Color(0.95, 0.68, 0.22, 0.95))
	else:
		# Linha dormente + barra discreta de carga até o próximo pulso sísmico.
		var mid_y: float = bar_y + bar_h * 0.5
		_seismograph_bar.draw_line(Vector2(bar_x + 4.0, mid_y), Vector2(bar_x + bar_w - 4.0, mid_y), Color(0.32, 0.18, 0.10, 0.50), 1.5)
		var charge_p: float = clampf(_progress_since_strike / STRIKE_PROGRESS_INTERVAL, 0.0, 1.0)
		var charge_t: float = clampf(_active_brush_time_since_strike / STRIKE_TIME_INTERVAL, 0.0, 1.0)
		var charge: float = 1.0 if _completed else maxf(charge_p, charge_t)
		_seismograph_bar.draw_rect(Rect2(bar_x, bar_y + bar_h + 8.0, bar_w, 5.0), Color(0.09, 0.05, 0.03, 0.85))
		_seismograph_bar.draw_rect(Rect2(bar_x, bar_y + bar_h + 8.0, bar_w * charge, 5.0), Color(0.84, 0.56, 0.22, 0.72))
