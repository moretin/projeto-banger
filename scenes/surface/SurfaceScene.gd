class_name SurfaceScene
extends Control
## Cenário 1: Superfície — Acampamento de Campo (onde o jogo começa).
##
## • Ovo de Âmbar Primordial no centro: o jogador clica ou escova para chocar e despertar o
##   Compsognato Principal em Pixel Art.
## • Estações do Acampamento de Campo: 4 estruturas de expedição na superfície reconstruídas com Rochas.
## • Botão inferior "DESCER À JAZIDA": transiciona para o Corte Geológico Vertical.

const PALETTE: AmberPalette = preload("res://scenes/ui/amber_palette.tres")

const PIXEL_DINO_ROWS: PackedStringArray = [
	"......GGGGGG....",
	".....GGGGGGGG...",
	".....GGWGGGGGG..",
	".....GGGGGGGGGG.",
	".....GGGGGGGG...",
	".....GGGGLL.....",
	"...GGGGGGGG.....",
	"..GGGGGGGGGGG...",
	".GGGGGGGGGG.G...",
	"GGGGGGGGGGG.....",
	"GG.GGGGGGGG.....",
	"...GGGGGGGG.....",
	"....GGG..GGG....",
	"....GG....GG....",
	"....LL....LL....",
	"................",
]

const CAMP_STATION_NAMES: Dictionary = {
	&"rubble_forge": "Tenda de Ferramentas",
	&"rubble_nest": "Incubadora de Campo",
	&"rubble_silo": "Torre Estratigráfica",
	&"rubble_bunker": "Bastião Anti-Impacto",
}

@onready var _sky_rect: ColorRect = %SurfaceSky
@onready var _horizon_glow: ColorRect = %HorizonGlow
@onready var _ground_rect: ColorRect = %SurfaceGround
@onready var _subsoil_strip: ColorRect = %SubSoilStrip
@onready var _header_icon: TextureRect = %HeaderIcon
@onready var _rubble_section_icon: TextureRect = %RubbleSectionIcon
@onready var _orange_rock_box: Control = %OrangeRockBox
@onready var _orange_rock_canvas: Control = %OrangeRockCanvas
@onready var _orange_rock_hp_bar: ProgressBar = %OrangeRockHpBar
@onready var _orange_rock_hp_label: Label = %OrangeRockHpLabel
@onready var _hero_dino_stage: Control = %HeroDinoStage
@onready var _hero_sprite: TextureRect = %HeroDinoSprite
@onready var _hero_speech_label: Label = %HeroSpeechLabel
@onready var _rubble_grid: HBoxContainer = %RubbleRow
@onready var _to_dig_button: Button = %ToDigSiteButton

var _rock_shake: float = 0.0
var _hero_x: float = 420.0
var _hero_dir: float = 1.0
var _hero_phase: float = 0.0
var _rubble_cards: Dictionary = {}
var _egg_hover: bool = false
var _egg_pulse_t: float = 0.0


func _ready() -> void:
	_hero_sprite.texture = _get_hero_texture()
	_hero_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_header_icon.texture = AmberTheme.get_icon(&"camp")
	_rubble_section_icon.texture = AmberTheme.get_icon(&"rocks")
	_to_dig_button.icon = AmberTheme.get_icon(&"brush")

	_orange_rock_box.gui_input.connect(_on_orange_rock_gui_input)
	_orange_rock_box.mouse_entered.connect(func() -> void: _egg_hover = true)
	_orange_rock_box.mouse_exited.connect(func() -> void: _egg_hover = false)
	_orange_rock_canvas.draw.connect(_on_orange_rock_draw)
	_to_dig_button.pressed.connect(func() -> void:
		Events.scenario_transition_requested.emit(&"dig_site")
	)

	_build_rubble_spots()

	Events.orange_rock_hp_changed.connect(_on_orange_rock_hp_changed)
	Events.orange_rock_broken.connect(_on_orange_rock_broken)
	Events.rubble_rebuilt.connect(_on_rubble_rebuilt)
	Events.resource_changed.connect(_on_resource_changed)
	Events.color_progress_changed.connect(_on_color_progress_changed)
	Events.danger_level_changed.connect(_on_danger_level_changed)
	Events.era_changed.connect(_on_era_changed)
	Events.layer_broken.connect(_on_layer_broken)
	Events.run_started.connect(_on_run_started)
	Events.game_loaded.connect(_refresh_all)

	_refresh_all()


func _process(delta: float) -> void:
	_egg_pulse_t += delta
	if not GameState.orange_rock_broken and _orange_rock_box.visible:
		_orange_rock_canvas.queue_redraw()
	if _rock_shake > 0.01:
		_rock_shake = lerpf(_rock_shake, 0.0, minf(delta * 15.0, 1.0))
		_orange_rock_canvas.position = Vector2(
			randf_range(-_rock_shake, _rock_shake),
			randf_range(-_rock_shake, _rock_shake)
		)
	else:
		_rock_shake = 0.0
		_orange_rock_canvas.position = Vector2.ZERO

	if GameState.orange_rock_broken:
		_animate_hero_dino(delta)


func _animate_hero_dino(delta: float) -> void:
	var stage_w: float = maxf(_hero_dino_stage.size.x, 500.0)
	_hero_phase += delta * 7.5
	_hero_x += _hero_dir * 75.0 * delta
	if _hero_x < 60.0:
		_hero_x = 60.0
		_hero_dir = 1.0
	elif _hero_x > stage_w - 140.0:
		_hero_x = stage_w - 140.0
		_hero_dir = -1.0

	var hop: float = absf(sin(_hero_phase)) * 10.0
	_hero_sprite.position = Vector2(_hero_x, 24.0 - hop)
	_hero_sprite.flip_h = (_hero_dir > 0.0)


func _refresh_all() -> void:
	var broken: bool = GameState.orange_rock_broken
	_orange_rock_box.visible = not broken
	_hero_dino_stage.visible = broken
	_to_dig_button.disabled = false
	if not broken:
		_to_dig_button.text = "DESCER À JAZIDA  (Choque o Ovo de Âmbar primeiro ou desça agora)"
	else:
		_to_dig_button.text = "DESCER À JAZIDA ESTRATIGRÁFICA"

	_on_orange_rock_hp_changed(GameState.orange_rock_hp, GameState.ORANGE_ROCK_MAX_HP)
	_refresh_rubble_spots()
	_update_sky_and_ground()


func _update_sky_and_ground() -> void:
	var danger: float = GameState.danger_level
	_sky_rect.color = PALETTE.sample_sky_color(GameState.depth, GameState.current_era_index, danger)
	_horizon_glow.color = PALETTE.sample_horizon_color(GameState.depth, GameState.current_era_index, danger)
	_ground_rect.color = PALETTE.sample_ground_color(GameState.depth, GameState.current_era_index, danger)
	_subsoil_strip.color = _ground_rect.color.darkened(0.32)


func _on_orange_rock_gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_rock_shake = 7.0
		var hit_pos: Vector2 = _orange_rock_box.get_global_transform_with_canvas() * mb.position
		Events.orange_rock_hit.emit(GameState.get_click_damage(), hit_pos)


func _on_orange_rock_hp_changed(hp: float, max_hp: float) -> void:
	_orange_rock_hp_bar.max_value = maxf(max_hp, 1.0)
	_orange_rock_hp_bar.value = clampf(hp, 0.0, max_hp)
	_orange_rock_hp_label.text = "Ovo de Âmbar: %d / %d  (Clique ou escove para chocar!)" % [
		ceili(hp),
		ceili(max_hp),
	]
	_orange_rock_canvas.queue_redraw()


func _on_orange_rock_broken() -> void:
	_orange_rock_box.visible = false
	_hero_dino_stage.visible = true
	_hero_speech_label.text = "Compsognato chocado! Desça à jazida para escovar fósseis e reunir Rochas para o Acampamento."
	_to_dig_button.text = "DESCER À JAZIDA ESTRATIGRÁFICA"
	_refresh_rubble_spots()


## Desenha o Ovo de Âmbar Translúcido com ninho de sedimento, inclusão fóssil e fissuras luminosas.
func _on_orange_rock_draw() -> void:
	var sz: Vector2 = _orange_rock_canvas.size
	var cx: float = sz.x * 0.5
	var cy: float = sz.y * 0.54

	# Sombra e ninho de folhas/sedimento
	_orange_rock_canvas.draw_rect(Rect2(cx - 88.0, cy + 40.0, 176.0, 20.0), Color(0.14, 0.09, 0.05, 0.65))
	_orange_rock_canvas.draw_rect(Rect2(cx - 74.0, cy + 32.0, 148.0, 16.0), Color(0.45, 0.29, 0.14, 0.95))

	var pulse: float = 1.0 + sin(_egg_pulse_t * 3.0) * 0.03 + (0.04 if _egg_hover else 0.0)
	var rx: float = 46.0 * pulse
	var ry: float = 58.0 * pulse

	# Aura translúcida do âmbar
	_orange_rock_canvas.draw_circle(Vector2(cx, cy - 6.0), rx * 1.35, Color(1.0, 0.68, 0.20, 0.16))
	# Casca externa (sépia/dourado pixelado em blocos arredondados de ovo)
	_orange_rock_canvas.draw_rect(Rect2(cx - rx * 0.85, cy - ry * 0.72, rx * 1.7, ry * 1.42), Color(0.76, 0.40, 0.11, 1.0))
	_orange_rock_canvas.draw_rect(Rect2(cx - rx * 0.64, cy - ry * 0.92, rx * 1.28, ry * 1.72), Color(0.92, 0.54, 0.16, 1.0))
	_orange_rock_canvas.draw_rect(Rect2(cx - rx * 0.42, cy - ry * 1.04, rx * 0.84, ry * 0.35), Color(0.98, 0.72, 0.26, 1.0))
	# Núcleo translúcido interno + embrião silhueta
	_orange_rock_canvas.draw_rect(Rect2(cx - rx * 0.48, cy - ry * 0.52, rx * 0.96, ry * 1.04), Color(1.0, 0.78, 0.32, 0.82))
	_orange_rock_canvas.draw_rect(Rect2(cx - 14.0, cy - 18.0, 26.0, 28.0), Color(0.32, 0.16, 0.07, 0.75))
	_orange_rock_canvas.draw_rect(Rect2(cx - 22.0, cy + 4.0, 20.0, 12.0), Color(0.32, 0.16, 0.07, 0.75))
	# Brilho especular
	_orange_rock_canvas.draw_rect(Rect2(cx - rx * 0.45, cy - ry * 0.68, 14.0, 20.0), Color(1.0, 0.96, 0.78, 0.85))

	var dmg_ratio: float = 1.0 - (_orange_rock_hp_bar.value / maxf(_orange_rock_hp_bar.max_value, 1.0))
	if dmg_ratio > 0.05:
		var cracks: int = clampi(int(dmg_ratio * 6.0) + 1, 1, 6)
		for i: int in range(cracks):
			var p0: Vector2 = Vector2(cx - 24.0 + float(i) * 10.0, cy - 42.0)
			var p1: Vector2 = p0 + Vector2((float(i % 2) - 0.5) * 24.0, 34.0 * dmg_ratio)
			var p2: Vector2 = p1 + Vector2((0.5 - float(i % 2)) * 20.0, 32.0 * dmg_ratio)
			_orange_rock_canvas.draw_line(p0, p1, Color(1.0, 0.94, 0.65, 0.95), 3.0)
			_orange_rock_canvas.draw_line(p1, p2, Color(0.24, 0.10, 0.04, 0.95), 2.5)


func _build_rubble_spots() -> void:
	for child: Node in _rubble_grid.get_children():
		child.queue_free()
	_rubble_cards.clear()

	for rubble_id: StringName in GameState.RUBBLE_ORDER:
		var def: Dictionary = GameState.RUBBLE_DEFS[rubble_id]
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size = Vector2(180.0, 180.0)

		var margin := MarginContainer.new()
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_top", 8)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_bottom", 8)
		panel.add_child(margin)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 5)
		margin.add_child(vbox)

		var visual := ColorRect.new()
		visual.custom_minimum_size = Vector2(0.0, 46.0)
		visual.color = Color(0.28, 0.19, 0.12)
		vbox.add_child(visual)

		var canvas := Control.new()
		canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.add_child(canvas)

		var state_lbl := Label.new()
		state_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		state_lbl.add_theme_font_size_override("font_size", 12)
		visual.add_child(state_lbl)

		var title_lbl := Label.new()
		title_lbl.text = _get_station_title(rubble_id, String(def["title"]))
		title_lbl.add_theme_font_size_override("font_size", 15)
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(title_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = String(def["desc"])
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.86, 0.80, 0.68))
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(desc_lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0.0, 36.0)
		btn.focus_mode = Control.FOCUS_NONE
		btn.icon = AmberTheme.get_icon(&"rocks")
		var captured_id: StringName = rubble_id
		btn.pressed.connect(func() -> void:
			Events.rubble_rebuild_requested.emit(captured_id)
		)
		vbox.add_child(btn)

		canvas.draw.connect(func() -> void:
			_draw_station_art(canvas, captured_id, def["color"] as Color)
		)

		_rubble_grid.add_child(panel)
		_rubble_cards[rubble_id] = {
			"visual": visual,
			"canvas": canvas,
			"state_lbl": state_lbl,
			"title_lbl": title_lbl,
			"btn": btn,
		}


func _draw_station_art(canvas: Control, rubble_id: StringName, accent: Color) -> void:
	var lvl: int = GameState.get_rubble_level(rubble_id)
	var w: float = canvas.size.x
	var h: float = canvas.size.y
	if lvl <= 0:
		# Lona dobrada + estacas no terreno
		canvas.draw_rect(Rect2(14.0, h - 12.0, w - 28.0, 6.0), Color(0.45, 0.30, 0.16, 0.7))
		canvas.draw_rect(Rect2(w * 0.5 - 26.0, h - 20.0, 52.0, 10.0), Color(0.55, 0.40, 0.24, 0.65))
	else:
		# Tenda / estação armada no acampamento
		var tent_col: Color = accent.lerp(Color(0.95, 0.82, 0.52), 0.35)
		var pts := PackedVector2Array([
			Vector2(w * 0.18, h - 6.0),
			Vector2(w * 0.50, 6.0),
			Vector2(w * 0.82, h - 6.0),
		])
		canvas.draw_colored_polygon(pts, tent_col.darkened(0.35))
		canvas.draw_rect(Rect2(w * 0.45, 16.0, 14.0, h - 22.0), Color(0.18, 0.10, 0.05, 0.85))


static func _get_station_title(rubble_id: StringName, fallback: String) -> String:
	return String(CAMP_STATION_NAMES.get(rubble_id, fallback))


func _refresh_rubble_spots() -> void:
	for rubble_id: StringName in GameState.RUBBLE_ORDER:
		if not _rubble_cards.has(rubble_id):
			continue
		var def: Dictionary = GameState.RUBBLE_DEFS[rubble_id]
		var card: Dictionary = _rubble_cards[rubble_id]
		var lvl: int = GameState.get_rubble_level(rubble_id)
		var cost: float = GameState.get_rubble_cost(rubble_id)
		var can_buy: bool = GameState.can_rebuild_rubble(rubble_id)

		var visual: ColorRect = card["visual"] as ColorRect
		var canvas: Control = card["canvas"] as Control
		var state_lbl: Label = card["state_lbl"] as Label
		var title_lbl: Label = card["title_lbl"] as Label
		var btn: Button = card["btn"] as Button

		title_lbl.text = "%s (Nv. %d)" % [_get_station_title(rubble_id, String(def["title"])), lvl]
		if lvl == 0:
			visual.color = Color(0.28, 0.19, 0.12)
			state_lbl.text = "[ ACAMPAMENTO · LOTE VAZIO ]"
			btn.text = "Montar · %s Rochas" % GameState.format_number(cost)
		else:
			visual.color = (def["color"] as Color).darkened(0.45)
			state_lbl.text = "[ ESTAÇÃO ATIVA · NV.%d ]" % lvl
			btn.text = "Expandir · %s Rochas" % GameState.format_number(cost)
		btn.disabled = not can_buy
		canvas.queue_redraw()


func _on_rubble_rebuilt(_rubble_id: StringName, _new_level: int) -> void:
	_refresh_rubble_spots()


func _on_resource_changed(res_id: StringName, _amount: float, _delta: float) -> void:
	if res_id == GameState.RES_ROCKS:
		_refresh_rubble_spots()


func _on_color_progress_changed(_progress: float) -> void:
	_update_sky_and_ground()


func _on_danger_level_changed(_level: float) -> void:
	_update_sky_and_ground()


func _on_era_changed(_idx: int) -> void:
	_update_sky_and_ground()


func _on_layer_broken(_era_idx: int, _layer_idx: int, _depth: int) -> void:
	_update_sky_and_ground()


func _on_run_started(_run: int) -> void:
	_refresh_all()


func _get_hero_texture() -> Texture2D:
	var data: DinoData = GameState.get_dino(&"compsognathus")
	var tex: Texture2D = AmberTheme.get_dino_sprite(&"compsognathus", data.sprite if data != null else null)
	if tex != null:
		return tex
	return _create_pixel_dino_texture()


static func _create_pixel_dino_texture() -> ImageTexture:
	var img: Image = Image.create(16, 16, false, Image.FORMAT_RGBA8)
	var body_col := Color(0.32, 0.82, 0.36, 1.0)
	var belly_col := Color(0.78, 0.95, 0.58, 1.0)
	var eye_col := Color(0.98, 0.98, 0.98, 1.0)

	for y: int in range(PIXEL_DINO_ROWS.size()):
		var row: String = PIXEL_DINO_ROWS[y]
		for x: int in range(mini(row.length(), 16)):
			var ch: String = row.substr(x, 1)
			match ch:
				"G":
					img.set_pixel(x, y, body_col)
				"L":
					img.set_pixel(x, y, belly_col)
				"W":
					img.set_pixel(x, y, eye_col)
				_:
					img.set_pixel(x, y, Color(0, 0, 0, 0))
	return ImageTexture.create_from_image(img)
