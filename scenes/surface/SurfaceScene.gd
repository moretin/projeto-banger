class_name SurfaceScene
extends Control
## Cenário 1: Superfície (onde o jogo começa).
##
## • Rocha Laranja inicial no centro: o jogador clica para quebrar e despertar o
##   Dinossauro Principal em Pixel Art.
## • Personagem Principal (HeroDino): sprite 16×16 em Pixel Art nítido (filtro NEAREST)
##   que patrulha e anima na superfície após nascer.
## • Escombros de Pedra: 4 estruturas em ruínas na superfície que usam Rochas (🪨,
##   obtidas escavando no cenário abaixo) para serem reconstruídas e funcionam como
##   upgrades permanentes da run para cada área.
## • Botão inferior "▼ ESCAVAÇÃO": transiciona suavemente para o cenário da Escavação.

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

@onready var _sky_rect: ColorRect = %SurfaceSky
@onready var _ground_rect: ColorRect = %SurfaceGround
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
var _rubble_cards: Dictionary[StringName, Dictionary] = {}


func _ready() -> void:
	_hero_sprite.texture = _create_pixel_dino_texture()
	_hero_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_orange_rock_box.gui_input.connect(_on_orange_rock_gui_input)
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
	Events.run_started.connect(_on_run_started)
	Events.game_loaded.connect(_refresh_all)

	_refresh_all()


func _process(delta: float) -> void:
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
	_hero_sprite.flip_h = (_hero_dir < 0.0)


func _refresh_all() -> void:
	var broken: bool = GameState.orange_rock_broken
	_orange_rock_box.visible = not broken
	_hero_dino_stage.visible = broken
	_to_dig_button.disabled = false
	if not broken:
		_to_dig_button.text = "▼ ESCAVAÇÃO  (Quebre a Rocha Laranja primeiro ou desça agora)"
	else:
		_to_dig_button.text = "⛏️ ▼ IR PARA A ESCAVAÇÃO ▼"

	_on_orange_rock_hp_changed(GameState.orange_rock_hp, GameState.ORANGE_ROCK_MAX_HP)
	_refresh_rubble_spots()
	_update_sky_and_ground()


func _update_sky_and_ground() -> void:
	var cp: float = GameState.color_progress
	var danger: float = GameState.danger_level
	var sky_calm: Color = Color(0.28, 0.30, 0.35).lerp(Color(0.32, 0.58, 0.85), cp)
	_sky_rect.color = sky_calm.lerp(Color(0.72, 0.18, 0.14), danger)
	_ground_rect.color = Color(0.35, 0.33, 0.28).lerp(Color(0.34, 0.66, 0.30), cp)


func _on_orange_rock_gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_rock_shake = 7.0
		var hit_pos: Vector2 = _orange_rock_box.get_global_transform_with_canvas() * mb.position
		Events.orange_rock_hit.emit(GameState.get_click_damage(), hit_pos)
		Events.dig_hit.emit(0.0, hit_pos, true)  # dispara som/partícula via VfxAudioManager


func _on_orange_rock_hp_changed(hp: float, max_hp: float) -> void:
	_orange_rock_hp_bar.max_value = maxf(max_hp, 1.0)
	_orange_rock_hp_bar.value = clampf(hp, 0.0, max_hp)
	_orange_rock_hp_label.text = "🟠 Rocha Laranja: %d / %d  (Clique para quebrar!)" % [
		ceili(hp),
		ceili(max_hp),
	]
	_orange_rock_canvas.queue_redraw()


func _on_orange_rock_broken() -> void:
	_orange_rock_box.visible = false
	_hero_dino_stage.visible = true
	_hero_speech_label.text = "🦖 Rawr! Estou livre! Vamos escavar rochas lá embaixo para reconstruir os escombros!"
	_to_dig_button.text = "⛏️ ▼ IR PARA A ESCAVAÇÃO ▼"
	_refresh_rubble_spots()


## Desenha a Rocha Laranja em estilo pixel/facetado com rachaduras conforme o HP cai.
func _on_orange_rock_draw() -> void:
	var sz: Vector2 = _orange_rock_canvas.size
	var cx: float = sz.x * 0.5
	var cy: float = sz.y * 0.52

	# Sombra no chão
	_orange_rock_canvas.draw_rect(Rect2(cx - 72.0, cy + 46.0, 144.0, 18.0), Color(0.12, 0.10, 0.08, 0.55))
	# Corpo pixelado da Rocha Laranja
	_orange_rock_canvas.draw_rect(Rect2(cx - 64.0, cy - 36.0, 128.0, 86.0), Color(0.92, 0.46, 0.12))
	_orange_rock_canvas.draw_rect(Rect2(cx - 52.0, cy - 52.0, 104.0, 20.0), Color(0.98, 0.58, 0.18))
	_orange_rock_canvas.draw_rect(Rect2(cx - 44.0, cy - 28.0, 42.0, 28.0), Color(1.0, 0.72, 0.28))
	_orange_rock_canvas.draw_rect(Rect2(cx - 64.0, cy + 30.0, 128.0, 20.0), Color(0.72, 0.32, 0.08))

	var dmg_ratio: float = 1.0 - (_orange_rock_hp_bar.value / maxf(_orange_rock_hp_bar.max_value, 1.0))
	if dmg_ratio > 0.05:
		var cracks: int = clampi(int(dmg_ratio * 6.0) + 1, 1, 6)
		for i: int in range(cracks):
			var p0 := Vector2(cx - 30.0 + float(i) * 12.0, cy - 40.0)
			var p1 := p0 + Vector2((float(i % 2) - 0.5) * 28.0, 38.0 * dmg_ratio)
			var p2 := p1 + Vector2((0.5 - float(i % 2)) * 24.0, 36.0 * dmg_ratio)
			_orange_rock_canvas.draw_line(p0, p1, Color(0.18, 0.08, 0.04), 4.0)
			_orange_rock_canvas.draw_line(p1, p2, Color(0.18, 0.08, 0.04), 3.0)


func _build_rubble_spots() -> void:
	for child: Node in _rubble_grid.get_children():
		child.queue_free()
	_rubble_cards.clear()

	for rubble_id: StringName in GameState.RUBBLE_ORDER:
		var def: Dictionary = GameState.RUBBLE_DEFS[rubble_id]
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.custom_minimum_size = Vector2(180.0, 175.0)

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
		visual.custom_minimum_size = Vector2(0.0, 44.0)
		visual.color = Color(0.35, 0.33, 0.31)
		vbox.add_child(visual)

		var state_lbl := Label.new()
		state_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		state_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		state_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		state_lbl.add_theme_font_size_override("font_size", 13)
		visual.add_child(state_lbl)

		var title_lbl := Label.new()
		title_lbl.text = String(def["title"])
		title_lbl.add_theme_font_size_override("font_size", 15)
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(title_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = String(def["desc"])
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.80, 0.82, 0.85))
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(desc_lbl)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0.0, 36.0)
		btn.focus_mode = Control.FOCUS_NONE
		var captured_id: StringName = rubble_id
		btn.pressed.connect(func() -> void:
			Events.rubble_rebuild_requested.emit(captured_id)
		)
		vbox.add_child(btn)

		_rubble_grid.add_child(panel)
		_rubble_cards[rubble_id] = {
			"visual": visual,
			"state_lbl": state_lbl,
			"title_lbl": title_lbl,
			"btn": btn,
		}


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
		var state_lbl: Label = card["state_lbl"] as Label
		var title_lbl: Label = card["title_lbl"] as Label
		var btn: Button = card["btn"] as Button

		title_lbl.text = "%s (Nv. %d)" % [String(def["title"]), lvl]
		if lvl == 0:
			visual.color = Color(0.32, 0.30, 0.28)
			state_lbl.text = "🪨 [ ESCOMBROS DE PEDRA ]"
			btn.text = "Reconstruir · 🪨 %s" % GameState.format_number(cost)
		else:
			visual.color = (def["color"] as Color).darkened(0.25)
			state_lbl.text = "🏛️ [ RECONSTRUÍDO · Nv.%d ]" % lvl
			btn.text = "Melhorar · 🪨 %s" % GameState.format_number(cost)
		btn.disabled = not can_buy


func _on_rubble_rebuilt(_rubble_id: StringName, _new_level: int) -> void:
	_refresh_rubble_spots()


func _on_resource_changed(res_id: StringName, _amount: float, _delta: float) -> void:
	if res_id == GameState.RES_ROCKS:
		_refresh_rubble_spots()


func _on_color_progress_changed(_progress: float) -> void:
	_update_sky_and_ground()


func _on_danger_level_changed(_level: float) -> void:
	_update_sky_and_ground()


func _on_run_started(_run: int) -> void:
	_refresh_all()


## Cria a textura 16×16 em Pixel Art do Dinossauro Principal.
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
