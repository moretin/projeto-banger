class_name DigSite
extends Control
## Corte Geológico Vertical — perfil estratigráfico com descida progressiva de câmera.
##
## • Exibe camadas anteriores já escavadas acima do terraço ativo (nichos vazios, escoras de
##   madeira, escada de corda e régua lateral de cota em metros).
## • Ao quebrar uma camada, a câmera desliza suavemente para baixo (nova faixa entra no corte).
## • Permite escovar a jazida por arrasto (`BRUSH_STEP_PX`) revelando silhuetas de fósseis.

const MAX_FLOATING_LABELS: int = 32
const BRUSH_STEP_PX: float = 28.0
const BRUSH_DAMAGE_FACTOR: float = 0.55
const MAX_BRUSH_PUFFS: int = 48
const MAX_SCRUB_SPOTS: int = 32
const MAX_EXCAVATED_HISTORY: int = 3
const STRATUM_DESCENT_PX: float = 128.0
const DINO_STAGE_BASE_Y: float = 272.0
const PALETTE: AmberPalette = preload("res://scenes/ui/amber_palette.tres")

@onready var _camera_container: Control = %CameraContainer
@onready var _sky_rect: ColorRect = %SkyRect
@onready var _excavated_backdrop: Control = %ExcavatedBackdrop
@onready var _surface_grass: ColorRect = %SurfaceGrass
@onready var _rock_button: Control = %RockHitArea
@onready var _rock_bg: ColorRect = %RockBg
@onready var _sub_layer_1: ColorRect = %SubLayer1
@onready var _sub_layer_1_label: Label = %SubLayer1Label
@onready var _sub_layer_2: ColorRect = %SubLayer2
@onready var _sub_layer_2_label: Label = %SubLayer2Label
@onready var _sub_layer_3: ColorRect = %SubLayer3
@onready var _sub_layer_3_label: Label = %SubLayer3Label
@onready var _trench_walls_overlay: Control = %TrenchWallsOverlay
@onready var _era_title_label: Label = %EraTitleLabel
@onready var _era_desc_label: Label = %EraDescLabel
@onready var _hp_bar: ProgressBar = %LayerHpBar
@onready var _hp_label: Label = %LayerHpLabel
@onready var _floating_container: Control = %FloatingContainer
@onready var _dino_stage: Node2D = %DinoStage
@onready var _to_surface_button: Button = %ToSurfaceButton

var _shake_strength: float = 0.0
var _active_Preset_labels: int = 0
var _camera_scroll_offset_y: float = 0.0
var _camera_tween: Tween = null

var _is_hovering_bed: bool = false
var _is_brushing: bool = false
var _brush_last_pos: Vector2 = Vector2.ZERO
var _brush_cursor_pos: Vector2 = Vector2(-100.0, -100.0)
var _brush_accum_px: float = 0.0
var _brush_tilt: float = 0.0
var _brush_tex: Texture2D = null

var _bed_fossils: Array[Dictionary] = []
var _scrub_spots: Array[Dictionary] = []
var _brush_puffs: Array[Dictionary] = []
var _excavated_history: Array[Dictionary] = []
var _seeded_layer_key: int = -1
var _last_era_color: Color = Color(0.55, 0.36, 0.18)
var _last_era_name: String = "Terra (Crosta)"


func _ready() -> void:
	Events.scenario_changed.connect(func(scenario: StringName) -> void:
		if scenario == &"dig_site":
			(%ToSurfaceButton as Button).grab_focus()
	)
	_brush_tex = AmberTheme.get_icon(&"brush")
	_to_surface_button.icon = AmberTheme.get_icon(&"camp")
	_rock_button.gui_input.connect(_on_rock_gui_input)
	_rock_button.mouse_entered.connect(func() -> void: _is_hovering_bed = true)
	_rock_button.mouse_exited.connect(_on_rock_mouse_exited)
	_rock_bg.draw.connect(_on_rock_draw)
	_excavated_backdrop.draw.connect(_on_excavated_backdrop_draw)
	_trench_walls_overlay.draw.connect(_on_trench_walls_draw)
	_sub_layer_1.draw.connect(func() -> void: _draw_sublayer_texture(_sub_layer_1, 1))
	_sub_layer_2.draw.connect(func() -> void: _draw_sublayer_texture(_sub_layer_2, 2))
	_sub_layer_3.draw.connect(func() -> void: _draw_sublayer_texture(_sub_layer_3, 3))
	_to_surface_button.pressed.connect(func() -> void:
		Events.scenario_transition_requested.emit(&"surface")
	)

	Events.layer_hp_changed.connect(_on_layer_hp_changed)
	Events.layer_broken.connect(_on_layer_broken)
	Events.era_changed.connect(_on_era_changed)
	Events.color_progress_changed.connect(_on_color_progress_changed)
	Events.danger_level_changed.connect(_on_danger_level_changed)
	Events.loot_dropped.connect(_on_loot_dropped)
	Events.fragment_dropped.connect(_on_fragment_dropped)
	Events.precise_strike_resolved.connect(_on_precise_strike_resolved)
	Events.run_started.connect(_on_run_started)
	Events.game_loaded.connect(_refresh_all)

	_refresh_all()


func _process(delta: float) -> void:
	if _shake_strength > 0.01:
		_shake_strength = lerpf(_shake_strength, 0.0, minf(delta * 14.0, 1.0))
		_rock_bg.position = Vector2(
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength * 0.65, _shake_strength * 0.65)
		)
	else:
		_shake_strength = 0.0
		_rock_bg.position = Vector2.ZERO

	_camera_container.position.y = _camera_scroll_offset_y
	_dino_stage.position.y = DINO_STAGE_BASE_Y
	_brush_tilt = lerpf(_brush_tilt, 0.0, minf(delta * 10.0, 1.0))

	if not _brush_puffs.is_empty():
		var idx: int = _brush_puffs.size() - 1
		while idx >= 0:
			var p: Dictionary = _brush_puffs[idx]
			var life: float = float(p["life"]) - delta
			if life <= 0.0:
				_brush_puffs.remove_at(idx)
			else:
				p["life"] = life
				var pos: Vector2 = (p["pos"] as Vector2) + (p["vel"] as Vector2) * delta
				p["pos"] = pos
				p["radius"] = float(p["radius"]) + delta * 14.0
			idx -= 1
		_rock_bg.queue_redraw()
	elif _is_hovering_bed:
		_rock_bg.queue_redraw()


## Nó onde a cena de Dinos (B4) ou VFX (B7) é posicionada no terraço estratigráfico.
func get_dino_stage() -> Node2D:
	return _dino_stage


func _refresh_all() -> void:
	_rebuild_excavated_history_from_depth()
	_rebuild_bed_fossils()
	_update_era_visuals()
	_update_sky_color()
	_on_layer_hp_changed(GameState.layer_hp, GameState.layer_max_hp)


func _on_run_started(_run: int) -> void:
	_scrub_spots.clear()
	_brush_puffs.clear()
	_excavated_history.clear()
	_camera_scroll_offset_y = 0.0
	_seeded_layer_key = -1
	_refresh_all()


func _rebuild_excavated_history_from_depth() -> void:
	if GameState.depth <= 0:
		_excavated_history.clear()
		return
	if _excavated_history.size() >= mini(GameState.depth, MAX_EXCAVATED_HISTORY):
		return
	_excavated_history.clear()
	var count: int = mini(GameState.depth, MAX_EXCAVATED_HISTORY)
	var start_d: int = GameState.depth - count
	for idx: int in range(count):
		var d: int = start_d + idx
		var era_idx: int = clampi(GameState.current_era_index - (count - 1 - idx) / 3, 0, maxi(GameState.eras.size() - 1, 0))
		var e: EraData = GameState.eras[era_idx] if era_idx < GameState.eras.size() else null
		var ename: String = e.display_name if e != null else "Crosta"
		var ecol: Color = e.get_rock_color(maxf(GameState.color_progress, 0.35)) if e != null else Color(0.55, 0.36, 0.18)
		_excavated_history.append({
			"depth": d,
			"era_name": ename,
			"color": ecol.darkened(0.22),
		})


func _rebuild_bed_fossils() -> void:
	var layer_key: int = GameState.run_number * 1009 + GameState.depth * 37 + GameState.current_layer_index * 7
	if layer_key == _seeded_layer_key and not _bed_fossils.is_empty():
		return
	_seeded_layer_key = layer_key
	_bed_fossils.clear()
	_scrub_spots.clear()

	var rng := RandomNumberGenerator.new()
	rng.seed = int(layer_key + 17)
	var count: int = 5
	for i: int in range(count):
		var nx: float = clampf(0.14 + (float(i) + 0.5) / float(count) * 0.72 + rng.randf_range(-0.03, 0.03), 0.12, 0.88)
		var ny: float = rng.randf_range(0.24, 0.76)
		_bed_fossils.append({
			"nx": nx,
			"ny": ny,
			"kind": (i + GameState.depth) % 5,
			"scale": rng.randf_range(0.85, 1.18),
			"rot": rng.randf_range(-0.35, 0.35),
			"scrub": 0.0,
		})


func _update_era_visuals() -> void:
	var era: EraData = GameState.get_current_era()
	if era == null:
		return
	var cp: float = GameState.color_progress
	var danger: float = GameState.danger_level
	var rock_col: Color = PALETTE.sample_stratum_color(era.get_rock_color(maxf(cp, 0.35)), 0, danger)
	_last_era_color = rock_col
	_last_era_name = era.display_name
	_rock_bg.color = rock_col
	_surface_grass.color = PALETTE.sample_canopy_color(GameState.depth, GameState.current_era_index, danger)

	_update_sub_layer(_sub_layer_1, _sub_layer_1_label, 1, cp, danger)
	_update_sub_layer(_sub_layer_2, _sub_layer_2_label, 2, cp, danger)
	_update_sub_layer(_sub_layer_3, _sub_layer_3_label, 3, cp, danger)

	var total_eras: int = maxi(GameState.eras.size(), 1)
	var current_idx: int = clampi(GameState.current_era_index, 0, total_eras - 1)
	_era_title_label.text = "%s [Faixa %d/%d] — Subcamada %d / %d  (Cota -%dm)" % [
		era.display_name,
		current_idx + 1,
		total_eras,
		GameState.current_layer_index + 1,
		era.layers_count,
		GameState.depth,
	]
	_era_desc_label.text = era.description
	_rock_bg.queue_redraw()
	_excavated_backdrop.queue_redraw()
	_trench_walls_overlay.queue_redraw()
	_sub_layer_1.queue_redraw()
	_sub_layer_2.queue_redraw()
	_sub_layer_3.queue_redraw()


func _update_sub_layer(rect: ColorRect, label: Label, offset: int, cp: float, danger: float) -> void:
	var total_eras: int = GameState.eras.size()
	if total_eras == 0:
		return
	var depth_mark: int = GameState.depth + offset
	var target_idx: int = GameState.current_era_index + offset
	if target_idx < total_eras:
		var next_era: EraData = GameState.eras[target_idx]
		rect.color = PALETTE.sample_stratum_color(next_era.get_rock_color(maxf(cp, 0.35)), offset, danger)
		var prefix: String = "-%dm · Próximo estrato: " % depth_mark if offset == 1 else "-%dm · " % depth_mark
		label.text = "%s%s" % [prefix, next_era.display_name]
	else:
		var core_era: EraData = GameState.eras[total_eras - 1]
		rect.color = PALETTE.sample_stratum_color(core_era.get_rock_color(maxf(cp, 0.35)), offset + 1, danger)
		var core_subdivisions: Array[String] = [
			"-%dm · Núcleo Externo Fluido (Ferro-Níquel em Convecção)" % depth_mark,
			"-%dm · Descontinuidade de Lehmann" % depth_mark,
			"-%dm · Núcleo Interno Sólido (Centro da Terra)" % depth_mark,
		]
		var sub_idx: int = clampi(target_idx - total_eras, 0, core_subdivisions.size() - 1)
		label.text = core_subdivisions[sub_idx]


func _update_sky_color() -> void:
	_sky_rect.color = PALETTE.sample_sky_color(GameState.depth, GameState.current_era_index, GameState.danger_level)
	_excavated_backdrop.queue_redraw()


func _on_rock_mouse_exited() -> void:
	_is_hovering_bed = false
	_is_brushing = false
	_brush_accum_px = 0.0
	_rock_bg.queue_redraw()


func _on_rock_gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT:
		_brush_cursor_pos = mb.position
		if mb.pressed:
			_is_brushing = true
			_brush_last_pos = mb.position
			_apply_bed_scrub(mb.position, Vector2.UP * 8.0)
			_emit_dig_strike(mb.position, 1.0, false)
		else:
			_is_brushing = false
			_brush_accum_px = 0.0
		_rock_bg.queue_redraw()
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
			_brush_tilt = clampf(step_vec.x * 0.035, -0.55, 0.55)
			if step_len > 0.5:
				_brush_accum_px += step_len
				_apply_bed_scrub(mm.position, step_vec)
				while _brush_accum_px >= BRUSH_STEP_PX:
					_brush_accum_px -= BRUSH_STEP_PX
					var global_hit: Vector2 = _rock_button.get_global_transform_with_canvas() * mm.position
					Events.brush_stroke.emit(global_hit)
					_emit_dig_strike(mm.position, BRUSH_DAMAGE_FACTOR, true)
		else:
			_brush_last_pos = mm.position
			_brush_tilt = clampf(mm.relative.x * 0.018, -0.30, 0.30)
		_rock_bg.queue_redraw()


func _emit_dig_strike(local_pos: Vector2, factor: float, is_brush: bool) -> void:
	var dmg: float = maxf(0.25, GameState.get_click_damage() * factor)
	var crit_chance: float = clampf(GameState.get_stat(GameState.STAT_CLICK_CRIT_CHANCE, 0.05), 0.0, 0.95)
	var is_crit: bool = randf() < crit_chance
	if is_crit:
		dmg *= 2.5
	if not is_brush:
		_shake_strength = maxf(_shake_strength, 4.5 if is_crit else 2.2)
	else:
		_shake_strength = maxf(_shake_strength, 1.2)
	var global_pos: Vector2 = _rock_button.get_global_transform_with_canvas() * local_pos
	Events.dig_hit.emit(dmg, global_pos, is_crit)


func _apply_bed_scrub(local_pos: Vector2, motion_vec: Vector2) -> void:
	var bed_sz: Vector2 = _rock_bg.size
	if bed_sz.x <= 10.0 or bed_sz.y <= 10.0:
		return
	var norm_pos := Vector2(
		clampf(local_pos.x / bed_sz.x, 0.06, 0.94),
		clampf(local_pos.y / bed_sz.y, 0.06, 0.94)
	)
	for f: Dictionary in _bed_fossils:
		var fpos := Vector2(float(f["nx"]) * bed_sz.x, float(f["ny"]) * bed_sz.y)
		if fpos.distance_to(local_pos) <= 78.0:
			f["scrub"] = minf(float(f["scrub"]) + 0.16, 0.78)

	if _scrub_spots.size() < MAX_SCRUB_SPOTS:
		var should_add: bool = true
		if not _scrub_spots.is_empty():
			var last_n: Vector2 = _scrub_spots[_scrub_spots.size() - 1]["norm"] as Vector2
			if last_n.distance_to(norm_pos) < 0.035:
				should_add = false
		if should_add:
			_scrub_spots.append({
				"norm": norm_pos,
				"r": randf_range(26.0, 42.0),
			})

	var puff_count: int = 2
	var drift_dir: Vector2 = motion_vec.normalized() if motion_vec.length() > 1.0 else Vector2.UP
	for _i: int in range(puff_count):
		if _brush_puffs.size() >= MAX_BRUSH_PUFFS:
			_brush_puffs.pop_front()
		_brush_puffs.append({
			"pos": local_pos + Vector2(randf_range(-10.0, 10.0), randf_range(-8.0, 8.0)),
			"vel": (drift_dir * randf_range(-40.0, -15.0)) + Vector2(randf_range(-24.0, 24.0), randf_range(-34.0, -10.0)),
			"radius": randf_range(6.0, 12.0),
			"life": randf_range(0.28, 0.52),
			"max_life": 0.52,
		})


func _on_layer_hp_changed(current_hp: float, max_hp: float) -> void:
	_hp_bar.max_value = maxf(max_hp, 1.0)
	_hp_bar.value = clampf(current_hp, 0.0, max_hp)
	_hp_label.text = "Jazida: %s / %s HP" % [
		GameState.format_number(current_hp),
		GameState.format_number(max_hp),
	]
	_rock_bg.queue_redraw()


func _on_layer_broken(_era_idx: int, _layer_idx: int, new_depth: int) -> void:
	_excavated_history.append({
		"depth": maxi(new_depth - 1, 0),
		"era_name": _last_era_name,
		"color": _last_era_color.darkened(0.24),
	})
	while _excavated_history.size() > MAX_EXCAVATED_HISTORY:
		_excavated_history.pop_front()

	_shake_strength = 9.0
	_seeded_layer_key = -1
	_rebuild_bed_fossils()
	_trigger_camera_descent()
	_update_era_visuals()


func _trigger_camera_descent() -> void:
	if not is_inside_tree():
		return
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_scroll_offset_y = STRATUM_DESCENT_PX
	_camera_tween = create_tween()
	_camera_tween.tween_property(self, "_camera_scroll_offset_y", 0.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _on_era_changed(_era_idx: int) -> void:
	_seeded_layer_key = -1
	_rebuild_bed_fossils()
	_update_era_visuals()


func _on_color_progress_changed(_progress: float) -> void:
	_update_era_visuals()
	_update_sky_color()


func _on_danger_level_changed(_level: float) -> void:
	_update_sky_color()
	_update_era_visuals()


## Desenha o histórico de camadas já escavadas acima da jazida atual no perfil geológico.
func _on_excavated_backdrop_draw() -> void:
	var w: float = _excavated_backdrop.size.x
	var h: float = _excavated_backdrop.size.y
	if w <= 10.0 or h <= 10.0:
		return

	# Brilho de abertura superior (boca do poço / horizonte)
	var horizon_col: Color = PALETTE.sample_horizon_color(GameState.depth, GameState.current_era_index, GameState.danger_level)
	_excavated_backdrop.draw_rect(Rect2(0.0, h * 0.42, w, h * 0.58), horizon_col.darkened(0.15))

	if _excavated_history.is_empty():
		# Superfície aberta com folhagem na borda da trincheira
		var canopy_col: Color = PALETTE.sample_canopy_color(GameState.depth, GameState.current_era_index, GameState.danger_level)
		for x: int in range(72, int(w) - 72, 46):
			_excavated_backdrop.draw_circle(Vector2(float(x), h - 12.0), 16.0, canopy_col.darkened(0.2))
			_excavated_backdrop.draw_circle(Vector2(float(x) + 14.0, h - 16.0), 12.0, canopy_col)
		return

	# Desenha até 3 camadas anteriores escavadas no topo da trincheira (de cima para baixo, mais antigas no topo)
	var band_h: float = 46.0
	var count: int = _excavated_history.size()
	var start_y: float = h - float(count) * band_h - 8.0
	var font: Font = ThemeDB.fallback_font
	for idx: int in range(count):
		var entry: Dictionary = _excavated_history[idx]
		var y0: float = start_y + float(idx) * band_h
		var base_col: Color = entry["color"] as Color
		var d: int = int(entry["depth"])
		# Paredes laterais de rocha escavada + cavidade mais escura no centro
		_excavated_backdrop.draw_rect(Rect2(0.0, y0, w, band_h), base_col)
		_excavated_backdrop.draw_rect(Rect2(58.0, y0 + 2.0, w - 116.0, band_h - 4.0), base_col.darkened(0.45))
		# Nichos de fósseis já extraídos naquela camada
		for n_idx: int in range(3):
			var nx: float = 130.0 + float(n_idx) * ((w - 260.0) / 2.5) + fmod(float(d * 53 + n_idx * 37), 60.0)
			_excavated_backdrop.draw_circle(Vector2(nx, y0 + band_h * 0.52), 11.0, Color(0.08, 0.05, 0.03, 0.55))
		# Viga horizontal de contenção
		_excavated_backdrop.draw_rect(Rect2(48.0, y0 + band_h - 4.0, w - 96.0, 4.0), Color(0.36, 0.21, 0.10, 0.85))
		if font != null:
			var label_txt: String = "-%dm · %s (escavada)" % [d, String(entry["era_name"])]
			_excavated_backdrop.draw_string(font, Vector2(78.0, y0 + 26.0), label_txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.95, 0.87, 0.70, 0.62))


## Desenha paredes laterais do corte geológico, escoras de madeira, escada de corda e régua de profundidade.
func _on_trench_walls_draw() -> void:
	var w: float = _trench_walls_overlay.size.x
	var h: float = _trench_walls_overlay.size.y
	if w <= 20.0 or h <= 20.0:
		return

	var wall_w: float = 52.0
	var wall_col := Color(0.16, 0.095, 0.052, 0.94)
	var timber_col := Color(0.44, 0.26, 0.12, 1.0)
	var timber_hi := Color(0.64, 0.41, 0.19, 1.0)

	# Paredes laterais de corte de terra/rocha
	_trench_walls_overlay.draw_rect(Rect2(0.0, 0.0, wall_w, h), wall_col)
	_trench_walls_overlay.draw_rect(Rect2(w - wall_w, 0.0, wall_w, h), wall_col)

	# Escoras verticais de madeira
	_trench_walls_overlay.draw_rect(Rect2(wall_w - 8.0, 0.0, 8.0, h), timber_col)
	_trench_walls_overlay.draw_rect(Rect2(wall_w - 8.0, 0.0, 2.0, h), timber_hi)
	_trench_walls_overlay.draw_rect(Rect2(w - wall_w, 0.0, 8.0, h), timber_col)
	_trench_walls_overlay.draw_rect(Rect2(w - wall_w + 6.0, 0.0, 2.0, h), timber_hi)

	# Escada de corda paleontológica descendo pela parede esquerda
	var rope_col := Color(0.76, 0.60, 0.36, 0.90)
	_trench_walls_overlay.draw_line(Vector2(20.0, 152.0), Vector2(20.0, h - 18.0), rope_col, 2.0)
	_trench_walls_overlay.draw_line(Vector2(38.0, 152.0), Vector2(38.0, h - 18.0), rope_col, 2.0)
	for ry: int in range(166, int(h) - 18, 26):
		_trench_walls_overlay.draw_line(Vector2(18.0, float(ry)), Vector2(40.0, float(ry)), timber_hi, 3.0)

	# Dormentes/suportes transversais nos encontros das camadas + cesto do guincho à direita
	for beam_y: float in [282.0, 558.0, 680.0]:
		_trench_walls_overlay.draw_rect(Rect2(wall_w - 8.0, beam_y - 5.0, 34.0, 10.0), timber_col)
		_trench_walls_overlay.draw_rect(Rect2(w - wall_w - 26.0, beam_y - 5.0, 34.0, 10.0), timber_col)

	# Régua de cota na parede direita
	var font: Font = ThemeDB.fallback_font
	for tick_i: int in range(5):
		var ty: float = 282.0 + float(tick_i) * 122.0
		if ty > h - 20.0:
			break
		_trench_walls_overlay.draw_line(Vector2(w - wall_w + 10.0, ty), Vector2(w - 8.0, ty), PALETTE.amber_highlight, 2.0)
		if font != null:
			_trench_walls_overlay.draw_string(font, Vector2(w - wall_w + 10.0, ty - 4.0), "-%dm" % (GameState.depth + tick_i), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, PALETTE.parchment_text)


func _draw_sublayer_texture(rect: ColorRect, offset: int) -> void:
	var sz: Vector2 = rect.size
	if sz.x <= 20.0 or sz.y <= 10.0:
		return
	var seam := Color(0.08, 0.05, 0.03, 0.25)
	var hi := Color(0.96, 0.78, 0.45, 0.09)
	rect.draw_line(Vector2(54.0, 2.0), Vector2(sz.x - 54.0, 2.0), seam, 2.0)
	var band_y: float = sz.y * 0.52
	rect.draw_line(Vector2(60.0, band_y), Vector2(sz.x - 60.0, band_y), hi, 1.5)
	for i: int in range(6):
		var px: float = 95.0 + float(i) * ((sz.x - 190.0) / 5.0)
		var py: float = 24.0 + fmod(float((i + offset) * 43), maxf(sz.y - 44.0, 12.0))
		rect.draw_rect(Rect2(px, py, 12.0 + float((i + offset) % 3) * 6.0, 4.0), seam)


## Desenha a jazida sedimentar ativa com silhuetas de fósseis soterrados, áreas escovadas e rastro de poeira.
func _on_rock_draw() -> void:
	var sz: Vector2 = _rock_bg.size
	var ratio: float = 1.0 - (_hp_bar.value / maxf(_hp_bar.max_value, 1.0))

	var strata_dark: Color = Color(0.10, 0.06, 0.03, 0.22)
	var strata_light: Color = Color(0.95, 0.80, 0.52, 0.08)
	for s: int in range(1, 5):
		var y_pos: float = sz.y * (float(s) / 5.0)
		_rock_bg.draw_line(Vector2(52.0, y_pos), Vector2(sz.x - 52.0, y_pos), strata_dark, 2.0)
		_rock_bg.draw_line(Vector2(52.0, y_pos + 3.0), Vector2(sz.x - 52.0, y_pos + 3.0), strata_light, 1.5)

	for spot: Dictionary in _scrub_spots:
		var npos: Vector2 = spot["norm"] as Vector2
		var cpos := Vector2(npos.x * sz.x, npos.y * sz.y)
		_rock_bg.draw_circle(cpos, float(spot["r"]), Color(0.14, 0.08, 0.04, 0.26))

	for f: Dictionary in _bed_fossils:
		var center := Vector2(float(f["nx"]) * sz.x, float(f["ny"]) * sz.y)
		var reveal: float = clampf(0.14 + ratio * 1.10 + float(f["scrub"]), 0.14, 1.0)
		_draw_fossil_silhouette(center, int(f["kind"]), float(f["scale"]), float(f["rot"]), reveal)

	if ratio > 0.22:
		var cracks: int = clampi(int(ratio * 7.0), 1, 7)
		var seam_col: Color = Color(0.96, 0.68, 0.22, 0.25 + ratio * 0.45)
		for i: int in range(cracks):
			var seed_x: float = fmod(float(i * 151 + 29), 100.0) / 100.0
			var start := Vector2(sz.x * (0.14 + seed_x * 0.72), 4.0)
			var mid := start + Vector2(sin(float(i) * 2.1) * 32.0, sz.y * ratio * 0.42)
			var end_pt := mid + Vector2(cos(float(i) * 1.7) * 36.0, sz.y * ratio * 0.36)
			_rock_bg.draw_line(start, mid, seam_col, 2.2)
			_rock_bg.draw_line(mid, end_pt, seam_col, 1.8)

	for p: Dictionary in _brush_puffs:
		var alpha: float = clampf(float(p["life"]) / float(p["max_life"]), 0.0, 1.0) * 0.65
		_rock_bg.draw_circle(p["pos"] as Vector2, float(p["radius"]), Color(0.92, 0.78, 0.54, alpha))

	if _is_hovering_bed and _brush_tex != null and _brush_cursor_pos.x >= 0.0 and _brush_cursor_pos.y <= sz.y:
		_rock_bg.draw_set_transform(_brush_cursor_pos + Vector2(6.0, -8.0), _brush_tilt - 0.18, Vector2(1.15, 1.15))
		_rock_bg.draw_texture(_brush_tex, Vector2(-12.0, -14.0), Color(1.0, 0.96, 0.85, 0.92))
		_rock_bg.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_fossil_silhouette(center: Vector2, kind: int, sc: float, rot: float, reveal: float) -> void:
	var veil_col: Color = Color(0.20, 0.13, 0.07, 0.45)
	var bone_col: Color = veil_col.lerp(Color(0.97, 0.90, 0.72, 0.95), reveal)
	var rim_col: Color = Color(0.16, 0.09, 0.04, 0.55 + reveal * 0.35)
	_rock_bg.draw_set_transform(center, rot, Vector2(sc, sc))

	if reveal > 0.30:
		_rock_bg.draw_circle(Vector2.ZERO, 28.0, Color(0.10, 0.06, 0.03, (reveal - 0.25) * 0.45))

	match kind:
		0:
			_rock_bg.draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 16, rim_col, 4.0)
			_rock_bg.draw_arc(Vector2.ZERO, 17.0, 0.2, TAU * 0.85, 14, bone_col, 4.5)
			_rock_bg.draw_arc(Vector2(2.0, 0.0), 10.0, 0.5, TAU * 0.8, 10, bone_col, 3.5)
			_rock_bg.draw_circle(Vector2(2.0, 0.0), 3.5, rim_col)
		1:
			_rock_bg.draw_line(Vector2(-24.0, 0.0), Vector2(24.0, 0.0), rim_col, 5.0)
			_rock_bg.draw_line(Vector2(-24.0, 0.0), Vector2(24.0, 0.0), bone_col, 3.0)
			for r: int in range(-2, 3):
				var rx: float = float(r) * 9.0
				_rock_bg.draw_arc(Vector2(rx, -2.0), 12.0, 0.25, PI - 0.25, 8, bone_col, 2.8)
				_rock_bg.draw_arc(Vector2(rx, 2.0), 12.0, PI + 0.25, TAU - 0.25, 8, bone_col, 2.8)
		2:
			var skull := PackedVector2Array([
				Vector2(-24.0, -8.0), Vector2(18.0, -14.0), Vector2(26.0, 0.0),
				Vector2(14.0, 10.0), Vector2(-18.0, 12.0),
			])
			_rock_bg.draw_colored_polygon(skull, bone_col)
			_rock_bg.draw_circle(Vector2(4.0, -4.0), 4.5, rim_col)
			_rock_bg.draw_circle(Vector2(-10.0, -2.0), 3.2, rim_col)
		3:
			_rock_bg.draw_circle(Vector2(0.0, 8.0), 8.0, bone_col)
			_rock_bg.draw_line(Vector2(-4.0, 4.0), Vector2(-16.0, -14.0), bone_col, 4.2)
			_rock_bg.draw_line(Vector2(0.0, 2.0), Vector2(0.0, -20.0), bone_col, 4.5)
			_rock_bg.draw_line(Vector2(4.0, 4.0), Vector2(16.0, -14.0), bone_col, 4.2)
		_:
			var amber_col: Color = Color(0.55, 0.28, 0.08, 0.5).lerp(Color(0.98, 0.70, 0.20, 0.96), reveal)
			_rock_bg.draw_circle(Vector2.ZERO, 17.0, Color(1.0, 0.72, 0.22, reveal * 0.25))
			_rock_bg.draw_rect(Rect2(-11.0, -14.0, 22.0, 28.0), amber_col)
			_rock_bg.draw_rect(Rect2(-4.0, -6.0, 8.0, 10.0), Color(0.24, 0.11, 0.04, 0.85))
			_rock_bg.draw_rect(Rect2(-7.0, -10.0, 4.0, 7.0), Color(1.0, 0.95, 0.76, reveal * 0.8))

	_rock_bg.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _on_loot_dropped(res_id: StringName, amount: float, world_pos: Vector2) -> void:
	if _active_Preset_labels >= MAX_FLOATING_LABELS:
		return
	var unit: String = "Ossos"
	var col: Color = Color(0.98, 0.94, 0.82)
	if res_id == GameState.RES_ROCKS:
		unit = "Rochas"
		col = Color(0.92, 0.76, 0.56)
	elif res_id == GameState.RES_MINERALS:
		unit = "Minérios"
		col = Color(0.45, 0.88, 1.0)
	_spawn_floating_text("+%s %s" % [GameState.format_number(amount), unit], world_pos, col)


func _on_fragment_dropped(dino_id: StringName, world_pos: Vector2) -> void:
	var data: DinoData = GameState.get_dino(dino_id)
	var dname: String = data.display_name if data != null else String(dino_id)
	_spawn_floating_text("+1 Fóssil: %s" % dname, world_pos, Color(1.0, 0.84, 0.25))


func _on_precise_strike_resolved(result: StringName, bonus_damage: float) -> void:
	if result == &"perfect":
		_shake_strength = maxf(_shake_strength, 8.0)
		_spawn_floating_text("GOLPE PRECISO! +%s" % GameState.format_number(bonus_damage), global_position + size * Vector2(0.5, 0.56), Color(1.0, 0.88, 0.28))
	elif result == &"good":
		_shake_strength = maxf(_shake_strength, 5.0)
		_spawn_floating_text("RESSONÂNCIA! +%s" % GameState.format_number(bonus_damage), global_position + size * Vector2(0.5, 0.56), Color(0.58, 0.96, 0.54))


func _spawn_floating_text(text: String, global_pos: Vector2, color: Color) -> void:
	_active_Preset_labels += 1
	var lbl := Label.new()
	lbl.text = text
	lbl.modulate = color
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floating_container.add_child(lbl)

	var local_pos: Vector2 = _floating_container.get_global_transform_with_canvas().affine_inverse() * global_pos
	if local_pos.x <= 10.0 and local_pos.y <= 10.0:
		local_pos = _rock_button.position + _rock_button.size * 0.5
	local_pos += Vector2(randf_range(-40.0, 40.0), randf_range(-15.0, 15.0))
	lbl.position = local_pos

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", local_pos.y - 52.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.75).set_delay(0.15)
	tw.chain().tween_callback(func() -> void:
		_active_Preset_labels = maxi(_active_Preset_labels - 1, 0)
		lbl.queue_free()
	)
