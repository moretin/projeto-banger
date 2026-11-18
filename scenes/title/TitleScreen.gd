class_name TitleScreen
extends Control
## Tela Inicial estilo Gnorp Apologue.
## Exibe céu estrelado escuro, linha do solo, silhueta da rocha à direita,
## T-Rex em pixel-art e botões minimalistas com inversão no hover.

signal play_requested

@onready var _top_stats_box: PanelContainer = %TopStatsBox
@onready var _amber_label: Label = %AmberLabel
@onready var _era_label: Label = %EraLabel
@onready var _hero_box: PanelContainer = %HeroBox
@onready var _title_label: Label = %TitleLabel
@onready var _subtitle_label: Label = %SubtitleLabel
@onready var _trex_sprite: TextureRect = %TrexSprite

@onready var _play_btn: Button = %PlayButton
@onready var _new_game_btn: Button = %NewRunButton
@onready var _amber_tree_btn: Button = %AmberTreeButton
@onready var _settings_btn: Button = %SettingsButton

var _time: float = 0.0
var _confirm_new: bool = false
var _stars: Array[Vector3] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for _i: int in range(70):
		_stars.append(Vector3(randf(), randf() * 0.78, randf() * TAU))

	_apply_styles()
	var trex_tex: Texture2D = UITheme.load_sprite("trex.png")
	if trex_tex != null and _trex_sprite != null:
		_trex_sprite.texture = trex_tex
		_trex_sprite.flip_h = true
		_trex_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	_play_btn.pressed.connect(_on_play_pressed)
	_new_game_btn.pressed.connect(_on_new_game_pressed)
	_amber_tree_btn.pressed.connect(func() -> void: Events.prestige_modal_requested.emit())
	_settings_btn.pressed.connect(func() -> void: Events.settings_modal_requested.emit())

	Events.resource_changed.connect(func(_r: StringName, _a: float, _d: float) -> void: _refresh_info())
	Events.era_changed.connect(func(_e: int) -> void: _refresh_info())
	Events.game_loaded.connect(_refresh_info)
	_refresh_info()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	queue_redraw()


func _draw() -> void:
	var vp: Vector2 = size
	if vp.x <= 10.0 or vp.y <= 10.0:
		return
	var fg: Color = UITheme.G_FG
	draw_rect(Rect2(Vector2.ZERO, vp), UITheme.G_BG, true)

	var ground_y: float = round(vp.y - 64.0)
	for s: Vector3 in _stars:
		var a: float = 0.22 + 0.35 * (0.5 + 0.5 * sin(_time * 1.4 + s.z))
		draw_rect(Rect2(round(s.x * vp.x), round(s.y * ground_y), 2, 2), Color(fg, a), true)

	# Chão escuro + linha branca
	draw_rect(Rect2(0, ground_y, vp.x, vp.y - ground_y), UITheme.G_BG_DEEP, true)
	draw_rect(Rect2(0, ground_y, vp.x, 3), fg, true)

	# Silhueta da rocha em degraus à direita
	var rock_left: float = round(vp.x * 0.74)
	var col_w: float = 12.0
	var cols: int = ceili((vp.x - rock_left) / col_w) + 1
	var prev: float = 0.0
	for c: int in range(cols):
		var t: float = float(c) / float(maxi(cols - 1, 1))
		var h: float = snappedf(vp.y * 0.48 * smoothstep(0.0, 0.7, t), 8.0)
		var x: float = rock_left + float(c) * col_w
		if h > 0.0:
			draw_rect(Rect2(x, ground_y - h, col_w + 1.0, h), fg, true)
			if h > prev:
				draw_rect(Rect2(x, ground_y - h, 4, h - prev), Color("#5FE3E8"), true)
		prev = h


func _apply_styles() -> void:
	_top_stats_box.add_theme_stylebox_override("panel", UITheme.make_gnorp_box(UITheme.G_BG, UITheme.G_FG, 2, 12, 8))
	_hero_box.add_theme_stylebox_override("panel", UITheme.make_gnorp_box(UITheme.G_BG, UITheme.G_FG, 2, 24, 14))
	UITheme.style_gnorp_label(_amber_label, 15, UITheme.G_AMBER)
	UITheme.style_gnorp_label(_era_label, 14, UITheme.G_DIM)
	UITheme.style_gnorp_label(_title_label, 44, UITheme.G_FG)
	UITheme.style_gnorp_label(_subtitle_label, 15, UITheme.G_DIM)

	UITheme.style_gnorp_button(_play_btn, 18, UITheme.G_GOOD)
	UITheme.style_gnorp_button(_new_game_btn, 15, UITheme.G_FG)
	UITheme.style_gnorp_button(_amber_tree_btn, 15, UITheme.G_AMBER)
	UITheme.style_gnorp_button(_settings_btn, 15, UITheme.G_FG)


func _refresh_info() -> void:
	_confirm_new = false
	_new_game_btn.text = "↻ novo jogo (zerar save)"
	var amber: float = GameState.get_resource(GameState.RES_AMBER)
	_amber_label.text = "%s âmbar · recorde: %dm · run #%d" % [
		GameState.format_number(amber),
		GameState.max_depth_ever,
		GameState.run_number,
	]
	var era: EraData = GameState.get_current_era()
	var era_name: String = era.display_name.to_lower() if era != null else "holoceno"
	_era_label.text = "era: %s · meteoro: %s" % [era_name, GameState.format_time(GameState.meteor_time_left)]

	var has_progress: bool = GameState.run_number > 1 or GameState.run_total_bones > 0.0 or amber > 0.0
	_play_btn.text = "▶ continuar run #%d" % GameState.run_number if has_progress else "▶ iniciar escavação"


func _on_play_pressed() -> void:
	visible = false
	play_requested.emit()


func _on_new_game_pressed() -> void:
	if not _confirm_new:
		_confirm_new = true
		_new_game_btn.text = "⚠ confirmar? clique de novo"
		return
	SaveManager.delete_save()
	_confirm_new = false
	visible = false
	play_requested.emit()
