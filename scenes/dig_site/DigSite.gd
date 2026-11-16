class_name DigSite
extends Control
## Corte Lateral do Solo (esquerda/centro da tela).
##
## • Renderiza o céu (que avermelha com `danger_level` e ganha cor com `color_progress`).
## • Renderiza a camada geológica ativa (com rachaduras procedurais conforme perde HP)
##   e as camadas inferiores em corte.
## • Captura cliques do jogador e emite `Events.dig_hit`.
## • Exibe números flutuantes de loot (`Events.loot_dropped` / `Events.fragment_dropped`)
##   com limite de instâncias para manter 60+ FPS.

const MAX_FLOATING_LABELS: int = 32

@onready var _sky_rect: ColorRect = %SkyRect
@onready var _surface_grass: ColorRect = %SurfaceGrass
@onready var _rock_button: Control = %RockHitArea
@onready var _rock_bg: ColorRect = %RockBg
@onready var _sub_layer_1: ColorRect = %SubLayer1
@onready var _sub_layer_2: ColorRect = %SubLayer2
@onready var _era_title_label: Label = %EraTitleLabel
@onready var _era_desc_label: Label = %EraDescLabel
@onready var _hp_bar: ProgressBar = %LayerHpBar
@onready var _hp_label: Label = %LayerHpLabel
@onready var _floating_container: Control = %FloatingContainer
@onready var _dino_stage: Node2D = %DinoStage
@onready var _to_surface_button: Button = %ToSurfaceButton

var _shake_strength: float = 0.0
var _active_Preset_labels: int = 0


func _ready() -> void:
	_rock_button.gui_input.connect(_on_rock_gui_input)
	_rock_bg.draw.connect(_on_rock_draw)
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
	Events.game_loaded.connect(_refresh_all)

	_refresh_all()


func _process(delta: float) -> void:
	if _shake_strength > 0.01:
		_shake_strength = lerpf(_shake_strength, 0.0, minf(delta * 14.0, 1.0))
		_rock_bg.position = Vector2(
			randf_range(-_shake_strength, _shake_strength),
			randf_range(-_shake_strength, _shake_strength)
		)
	else:
		_shake_strength = 0.0
		_rock_bg.position = Vector2.ZERO


## Nó onde a cena de Dinos (B4) ou VFX (B7) pode ser anexada no corte do solo.
func get_dino_stage() -> Node2D:
	return _dino_stage


func _refresh_all() -> void:
	_update_era_visuals()
	_update_sky_color()
	_on_layer_hp_changed(GameState.layer_hp, GameState.layer_max_hp)


func _update_era_visuals() -> void:
	var era: EraData = GameState.get_current_era()
	if era == null:
		return
	var cp: float = GameState.color_progress
	var rock_col: Color = era.get_rock_color(cp)
	_rock_bg.color = rock_col
	_sub_layer_1.color = rock_col.darkened(0.18)
	_sub_layer_2.color = rock_col.darkened(0.34)
	_surface_grass.color = Color(0.36, 0.35, 0.30).lerp(Color(0.32, 0.68, 0.28), cp)

	_era_title_label.text = "%s  —  Camada %d / %d  (Profundidade: %dm)" % [
		era.display_name,
		GameState.current_layer_index + 1,
		era.layers_count,
		GameState.depth,
	]
	_era_desc_label.text = era.description
	_rock_bg.queue_redraw()


func _update_sky_color() -> void:
	var cp: float = GameState.color_progress
	var danger: float = GameState.danger_level
	var calm_muted: Color = Color(0.24, 0.24, 0.26)
	var calm_vivid: Color = Color(0.26, 0.48, 0.72)
	var sky_base: Color = calm_muted.lerp(calm_vivid, cp)
	var danger_sky: Color = Color(0.68, 0.16, 0.12)
	_sky_rect.color = sky_base.lerp(danger_sky, clampf(danger, 0.0, 1.0))


func _on_rock_gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var dmg: float = GameState.get_click_damage()
		var crit_chance: float = clampf(GameState.get_stat(GameState.STAT_CLICK_CRIT_CHANCE, 0.05), 0.0, 0.95)
		var is_crit: bool = randf() < crit_chance
		if is_crit:
			dmg *= 2.5
		_shake_strength = maxf(_shake_strength, 5.0 if is_crit else 2.5)
		Events.dig_hit.emit(dmg, _rock_button.get_global_transform_with_canvas() * mb.position, is_crit)


func _on_layer_hp_changed(current_hp: float, max_hp: float) -> void:
	_hp_bar.max_value = maxf(max_hp, 1.0)
	_hp_bar.value = clampf(current_hp, 0.0, max_hp)
	_hp_label.text = "🪨 Rocha: %s / %s HP" % [
		GameState.format_number(current_hp),
		GameState.format_number(max_hp),
	]
	_rock_bg.queue_redraw()


func _on_layer_broken(_era_idx: int, _layer_idx: int, _depth: int) -> void:
	_shake_strength = 10.0
	_update_era_visuals()


func _on_era_changed(_era_idx: int) -> void:
	_update_era_visuals()


func _on_color_progress_changed(_progress: float) -> void:
	_update_era_visuals()
	_update_sky_color()


func _on_danger_level_changed(_level: float) -> void:
	_update_sky_color()


## Desenha rachaduras procedurais na rocha conforme o HP diminui.
func _on_rock_draw() -> void:
	var ratio: float = 1.0 - (_hp_bar.value / maxf(_hp_bar.max_value, 1.0))
	if ratio <= 0.05:
		return
	var sz: Vector2 = _rock_bg.size
	var crack_count: int = clampi(int(ratio * 10.0), 1, 10)
	var col: Color = Color(0.1, 0.08, 0.06, 0.65)
	for i: int in range(crack_count):
		var seed_x: float = fmod(float(i * 137 + 43), 100.0) / 100.0
		var start: Vector2 = Vector2(sz.x * (0.1 + seed_x * 0.8), 0.0)
		var mid: Vector2 = start + Vector2(sin(float(i) * 2.1) * 45.0, sz.y * ratio * 0.5)
		var end_pt: Vector2 = mid + Vector2(cos(float(i) * 1.7) * 55.0, sz.y * ratio * 0.45)
		_rock_bg.draw_line(start, mid, col, 3.0)
		_rock_bg.draw_line(mid, end_pt, col, 2.0)


func _on_loot_dropped(res_id: StringName, amount: float, world_pos: Vector2) -> void:
	if _active_Preset_labels >= MAX_FLOATING_LABELS:
		return
	var icon: String = "🦴"
	var col: Color = Color(0.98, 0.94, 0.82)
	if res_id == GameState.RES_ROCKS:
		icon = "🪨"
		col = Color(0.92, 0.76, 0.56)
	elif res_id == GameState.RES_MINERALS:
		icon = "💎"
		col = Color(0.45, 0.88, 1.0)
	_spawn_floating_text("+%s %s" % [GameState.format_number(amount), icon], world_pos, col)


func _on_fragment_dropped(dino_id: StringName, world_pos: Vector2) -> void:
	var data: DinoData = GameState.get_dino(dino_id)
	var dname: String = data.display_name if data != null else String(dino_id)
	_spawn_floating_text("+1 🧩 %s!" % dname, world_pos, Color(1.0, 0.84, 0.25))


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
