class_name SurfaceScene
extends Control

const LANDMARK: Script = preload("res://scenes/surface/FieldLandmark.gd")
# Coordenadas dos pés de cada marco no atlas de 480 × 240 por bioma.
const BIOME_SITES: Dictionary = {
	&"amber_basin": {
		&"rubble_forge": Vector2(58, 134),
		&"rubble_nest": Vector2(158, 168),
		&"egg": Vector2(238, 142),
		&"rubble_silo": Vector2(318, 128),
		&"rubble_bunker": Vector2(416, 148),
	},
	&"forest": {
		&"forest_grove": Vector2(142, 152),
		&"forest_sanctuary": Vector2(332, 158),
	},
	&"snow": {
		&"snow_glacier": Vector2(146, 154),
		&"snow_observatory": Vector2(334, 148),
	},
}
const SITES: Dictionary = {
	&"rubble_forge": Vector2(58, 134),
	&"rubble_nest": Vector2(158, 168),
	&"egg": Vector2(238, 142),
	&"rubble_silo": Vector2(318, 128),
	&"rubble_bunker": Vector2(416, 148),
	&"forest_grove": Vector2(142, 152),
	&"forest_sanctuary": Vector2(332, 158),
	&"snow_glacier": Vector2(146, 154),
	&"snow_observatory": Vector2(334, 148),
}
const WORKBENCH_TOOLTIPS: Dictionary = {
	&"rubble_forge": "Upgrades da Pedreira",
	&"rubble_nest": "Upgrades do Pesqueiro",
	&"rubble_silo": "Upgrades da Torre dos Ventos",
	&"rubble_bunker": "Universidade & Reviver",
	&"forest_grove": "Upgrades do Bosque",
	&"forest_sanctuary": "Upgrades da Clareira",
	&"snow_glacier": "Upgrades da Geleira",
	&"snow_observatory": "Upgrades do Santuário",
}
const HERO_SPEED: float = 148.0
const PROXIMITY_RADIUS: float = 48.0
const EDGE_LEFT_TRIGGER_X: float = 14.0
const EDGE_RIGHT_TRIGGER_X: float = 466.0
const EDGE_FOREST_MIN_X: float = 20.0
const EDGE_SNOW_MAX_X: float = 460.0
const SPAWN_LEFT_X: float = 28.0
const SPAWN_RIGHT_X: float = 452.0
const FALLBACK_MIN_Y: float = 132.0
const FALLBACK_MAX_Y: float = 204.0
const BIOME_FADE_DURATION: float = 0.18
const MAX_FLOATING_LABELS: int = 24
const ITEM_BUILD_STATION: StringName = &"__build_station"
const ITEM_HIRE_WORKER: StringName = &"__hire_worker"
const ITEM_EXPAND_STATION: StringName = &"__expand_station"
const STATION_REVIVE_ITEM: StringName = &"__revive_station_dino"
const REVIVE_ORIGIN_PREFIX: String = "__revive_origin:"
const INFO_CARD_KEY: StringName = &"__info_notice"
const DIMMED_MODULATE: Color = Color(0.58, 0.56, 0.54, 0.68)


class HeroAvatar:
	extends Control
	const ACTION_DURATION: float = 0.34
	const DRAW_WIDTH: float = 125.0
	const WALK_FRAMES: int = 4
	const WALK_FPS: float = 10.0
	const FOOT_OFFSET_Y: float = 20.0

	var facing_left: bool = false
	var walking: bool = false
	var assisting_built: bool = false
	var phase: float = 0.0
	var action_timer: float = 0.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		focus_mode = Control.FOCUS_NONE
		texture_filter = Control.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		if not GameState.orange_rock_broken:
			return
		var cx: float = size.x * 0.5
		var cy: float = size.y - FOOT_OFFSET_Y
		var facing_sign: float = -1.0 if facing_left else 1.0
		var hop: float = 0.0
		var lunge_x: float = 0.0
		var rot: float = 0.0
		var sx: float = 1.0
		var sy: float = 1.0

		if action_timer > 0.0:
			var act_t: float = clampf(1.0 - action_timer / ACTION_DURATION, 0.0, 1.0)
			var impulse: float = sin(act_t * PI)
			lunge_x = facing_sign * impulse * 14.0
			hop = impulse * 4.5
			rot = facing_sign * 0.22 * impulse
			sx = 1.0 + 0.16 * impulse
			sy = 1.0 - 0.14 * impulse
		elif walking:
			var stride: float = sin(phase * 14.0)
			hop = roundf(absf(stride) * 6.0)
			rot = facing_sign * (0.06 + stride * 0.05)
			var stretch: float = absf(stride)
			sx = 1.0 - 0.045 * stretch
			sy = 1.0 + 0.055 * stretch
		elif assisting_built:
			var work_wave: float = sin(phase * 4.2)
			hop = maxf(work_wave, 0.0) * 2.5
			rot = facing_sign * maxf(work_wave, 0.0) * 0.08
			sx = 1.0 + work_wave * 0.035
			sy = 1.0 - work_wave * 0.035
		else:
			var breath: float = sin(phase * 2.4)
			sx = 1.0 - breath * 0.025
			sy = 1.0 + breath * 0.035
			rot = sin(phase * 1.9) * 0.02

		var draw_w: float = DRAW_WIDTH
		if walking:
			var walk_sheet: Texture2D = AmberTheme.get_compsognathus_walk_sheet()
			if walk_sheet != null:
				var sheet_sz: Vector2 = walk_sheet.get_size()
				var cell_w: float = sheet_sz.x / float(WALK_FRAMES)
				var cell_h: float = sheet_sz.y
				var draw_h: float = draw_w * (cell_h / maxf(cell_w, 1.0))
				var frame_idx: int = posmod(floori(phase * WALK_FPS), WALK_FRAMES)
				var src_rect: Rect2 = Rect2(float(frame_idx) * cell_w, 0.0, cell_w, cell_h)
				draw_set_transform(Vector2(cx + lunge_x, cy - hop), rot, Vector2(facing_sign * sx, sy))
				draw_texture_rect_region(walk_sheet, Rect2(-draw_w * 0.5, -draw_h, draw_w, draw_h), src_rect)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				return

		var idle_sprite: Texture2D = AmberTheme.get_dino_sprite(&"compsognathus")
		if idle_sprite != null:
			var tex_sz: Vector2 = idle_sprite.get_size()
			var draw_h: float = draw_w * (tex_sz.y / maxf(tex_sz.x, 1.0))
			draw_set_transform(Vector2(cx + lunge_x, cy - hop), rot, Vector2(facing_sign * sx, sy))
			draw_texture_rect(idle_sprite, Rect2(-draw_w * 0.5, -draw_h, draw_w, draw_h), false)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


class CardRow:
	extends RefCounted
	var key: StringName = &""
	var item_id: StringName = &""
	var panel: PanelContainer = null
	var margin: MarginContainer = null
	var icon_slot: PanelContainer = null
	var icon_rect: TextureRect = null
	var title_lbl: Label = null
	var desc_lbl: Label = null
	var buy_btn: Button = null
	var progress_bar: ProgressBar = null
	var status_lbl: Label = null
	var is_dimmed: bool = false


@onready var _map: Control = %Map
@onready var _basin_name: Label = $Map/BasinName
@onready var _biome_fade: ColorRect = %BiomeFade
@onready var _dock: PanelContainer = %Dock
@onready var _site_name: Label = %SiteName
@onready var _stock: Label = %Stock
@onready var _groups: HBoxContainer = %Groups
@onready var _items_scroll: ScrollContainer = %ItemsScroll
@onready var _items_list: VBoxContainer = %ItemsList
@onready var _actions: HBoxContainer = %ActionRow
@onready var _quantity: Button = %Quantity
@onready var _field_action_btn: Button = %ToDigSiteButton

var _landmarks: Dictionary = {}
var _site: StringName = &""
var _section: StringName = &""
var _items: Array[StringName] = []
var _refresh_pending: bool = false

var _card_rows: Dictionary = {}
var _built_site: StringName = &""
var _built_section: StringName = &""
var _built_keys: Array[StringName] = []
var _rendered_fossil_queue: Array[StringName] = []
var _active_fossil_bar: ProgressBar = null
var _active_fossil_status: Label = null
var _emitting_buy_item_id: StringName = &""

var _style_card_active: StyleBoxFlat = null
var _style_card_highlight: StyleBoxFlat = null
var _style_card_dimmed: StyleBoxFlat = null
var _style_icon_slot: StyleBoxFlat = null
var _style_fossil_bar_bg: StyleBoxFlat = null
var _style_fossil_bar_fill: StyleBoxFlat = null
var _style_tab_normal: StyleBoxFlat = null
var _style_tab_hover: StyleBoxFlat = null
var _style_tab_pressed: StyleBoxFlat = null
var _style_tab_focus: StyleBoxFlat = null

var _hero_avatar: HeroAvatar = null
var _hero_map_pos: Vector2 = Vector2(238.0, 158.0)
var _hero_facing_left: bool = false
var _hero_walking: bool = false
var _hero_anim_phase: float = 0.0
var _hero_action_timer: float = 0.0
var _active_floating_labels: int = 0
var _pending_biome_spawn: Vector2 = Vector2.ZERO
var _has_pending_biome_spawn: bool = false
var _biome_fade_tween: Tween = null


func _ready() -> void:
	_ensure_input_actions()
	_init_card_styles()
	for id: Variant in SITES:
		var spot: FieldLandmark = LANDMARK.new() as FieldLandmark
		spot.station = StringName(id)
		spot.name = String(id)
		_map.add_child(spot)
		_landmarks[id] = spot
		spot.pressed.connect(_on_landmark_clicked.bind(StringName(id)))

	_hero_avatar = HeroAvatar.new()
	_hero_avatar.name = "HeroAvatar"
	_hero_avatar.size = Vector2(196.0, 112.0)
	_map.add_child(_hero_avatar)

	_map.resized.connect(_layout_landmarks)
	_quantity.pressed.connect(GameState.cycle_buy_multiplier)
	_field_action_btn.pressed.connect(_on_field_action_pressed)
	Events.scenario_changed.connect(_on_scenario_changed)
	Events.biome_changed.connect(_on_biome_changed)
	Events.station_research_requested.connect(_visit_lab)
	Events.resource_changed.connect(_queue_refresh.unbind(3))
	Events.buy_multiplier_changed.connect(_queue_refresh.unbind(1))
	Events.rubble_rebuilt.connect(_queue_refresh.unbind(2))
	Events.upgrade_purchased.connect(_queue_refresh.unbind(2))
	Events.dino_count_changed.connect(_queue_refresh.unbind(2))
	Events.fragments_changed.connect(_queue_refresh.unbind(2))
	Events.era_changed.connect(_queue_refresh.unbind(1))
	Events.orange_rock_hp_changed.connect(_refresh_egg.unbind(2))
	Events.orange_rock_broken.connect(_on_orange_rock_broken)
	Events.loot_dropped.connect(_on_loot_dropped)
	Events.fragment_dropped.connect(_on_fragment_dropped)
	Events.run_started.connect(_reset_visit.unbind(1))
	Events.game_loaded.connect(_reset_visit)
	_layout_landmarks()
	_reset_visit()
	_grab_current_biome_focus.call_deferred()


func _init_card_styles() -> void:
	_style_card_active = StyleBoxFlat.new()
	_style_card_active.bg_color = Color(0.20, 0.185, 0.275, 0.94)
	_style_card_active.border_color = Color(0.68, 0.50, 0.28, 0.85)
	_style_card_active.set_border_width_all(1)
	_style_card_active.set_corner_radius_all(6)

	_style_card_highlight = StyleBoxFlat.new()
	_style_card_highlight.bg_color = Color(0.24, 0.20, 0.26, 0.96)
	_style_card_highlight.border_color = Color(0.96, 0.76, 0.32, 0.95)
	_style_card_highlight.set_border_width_all(2)
	_style_card_highlight.set_corner_radius_all(6)

	_style_card_dimmed = StyleBoxFlat.new()
	_style_card_dimmed.bg_color = Color(0.115, 0.110, 0.150, 0.80)
	_style_card_dimmed.border_color = Color(0.32, 0.30, 0.34, 0.55)
	_style_card_dimmed.set_border_width_all(1)
	_style_card_dimmed.set_corner_radius_all(6)

	_style_icon_slot = StyleBoxFlat.new()
	_style_icon_slot.bg_color = Color(0.26, 0.18, 0.11, 0.95)
	_style_icon_slot.border_color = Color(0.84, 0.62, 0.34, 0.90)
	_style_icon_slot.set_border_width_all(1)
	_style_icon_slot.set_corner_radius_all(5)

	_style_fossil_bar_bg = StyleBoxFlat.new()
	_style_fossil_bar_bg.bg_color = Color(0.10, 0.08, 0.12, 0.95)
	_style_fossil_bar_bg.border_color = Color(0.60, 0.44, 0.22, 0.90)
	_style_fossil_bar_bg.set_border_width_all(1)
	_style_fossil_bar_bg.set_corner_radius_all(4)

	_style_fossil_bar_fill = StyleBoxFlat.new()
	_style_fossil_bar_fill.bg_color = Color(0.95, 0.72, 0.24, 0.98)
	_style_fossil_bar_fill.set_corner_radius_all(3)

	_style_tab_normal = StyleBoxFlat.new()
	_style_tab_normal.bg_color = Color("#f3e6cc")
	_style_tab_normal.border_color = Color("#261820")
	_style_tab_normal.set_border_width_all(2)
	_style_tab_normal.set_corner_radius_all(6)
	_style_tab_normal.shadow_color = Color(0.0, 0.0, 0.0, 0.28)
	_style_tab_normal.shadow_size = 2
	_style_tab_normal.shadow_offset = Vector2(0.0, 2.0)

	_style_tab_hover = StyleBoxFlat.new()
	_style_tab_hover.bg_color = Color("#fff3d4")
	_style_tab_hover.border_color = Color("#261820")
	_style_tab_hover.set_border_width_all(2)
	_style_tab_hover.set_corner_radius_all(6)

	_style_tab_pressed = StyleBoxFlat.new()
	_style_tab_pressed.bg_color = Color("#ffd67a")
	_style_tab_pressed.border_color = Color("#261820")
	_style_tab_pressed.set_border_width_all(2)
	_style_tab_pressed.set_corner_radius_all(6)

	_style_tab_focus = StyleBoxFlat.new()
	_style_tab_focus.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	_style_tab_focus.border_color = Color("#1488ff")
	_style_tab_focus.set_border_width_all(2)
	_style_tab_focus.set_corner_radius_all(6)


func _process(delta: float) -> void:
	if not is_visible_in_tree() or GameState.is_impacting or GameState.is_prestige_modal_open:
		return
	var dir: Vector2 = Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if dir.length_squared() > 0.001:
		move_hero_by_vector(dir, delta)
	else:
		_hero_walking = false
	_hero_anim_phase += delta
	_hero_action_timer = maxf(_hero_action_timer - delta, 0.0)
	_sync_hero_avatar()
	if _site == &"rubble_bunker":
		_update_university_live_ui()


func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or GameState.is_impacting or GameState.is_prestige_modal_open:
		return
	var ek: InputEventKey = event as InputEventKey
	if ek != null and ek.pressed and not ek.echo and ek.physical_keycode == KEY_E:
		_on_field_action_pressed()
		get_viewport().set_input_as_handled()


static func _ensure_input_actions() -> void:
	var bindings: Dictionary = {
		&"move_left": KEY_A,
		&"move_right": KEY_D,
		&"move_up": KEY_W,
		&"move_down": KEY_S,
	}
	for action_name: Variant in bindings:
		var act: StringName = action_name as StringName
		if not InputMap.has_action(act):
			InputMap.add_action(act)
		var key_code: Key = bindings[act] as Key
		var has_key: bool = false
		for ev: InputEvent in InputMap.action_get_events(act):
			var ek: InputEventKey = ev as InputEventKey
			if ek != null and (ek.physical_keycode == key_code or ek.keycode == key_code):
				has_key = true
				break
		if not has_key:
			var key_ev := InputEventKey.new()
			key_ev.physical_keycode = key_code
			InputMap.action_add_event(act, key_ev)


func _get_site_biome(site_id: StringName) -> StringName:
	for biome_key: Variant in BIOME_SITES:
		var biome_id: StringName = biome_key as StringName
		var sites_dict: Dictionary = BIOME_SITES[biome_id] as Dictionary
		if sites_dict.has(site_id):
			return biome_id
	return GameState.BIOME_AMBER


func _get_walkable_y_bounds(biome: StringName, map_x: float) -> Vector2:
	var min_y: float = FALLBACK_MIN_Y
	var max_y: float = FALLBACK_MAX_Y
	if _map != null and _map.has_method(&"get_walkable_min_y"):
		min_y = float(_map.call(&"get_walkable_min_y", biome, map_x))
	if _map != null and _map.has_method(&"get_walkable_max_y"):
		max_y = float(_map.call(&"get_walkable_max_y", biome, map_x))
	if max_y < min_y:
		max_y = min_y
	return Vector2(min_y, max_y)


func _clamp_hero_to_ground(pos: Vector2, biome: StringName = GameState.current_biome) -> Vector2:
	var min_x: float = EDGE_FOREST_MIN_X if biome == GameState.BIOME_FOREST else EDGE_LEFT_TRIGGER_X
	var max_x: float = EDGE_SNOW_MAX_X if biome == GameState.BIOME_SNOW else EDGE_RIGHT_TRIGGER_X
	var cx: float = clampf(pos.x, min_x, max_x)
	var y_bounds: Vector2 = _get_walkable_y_bounds(biome, cx)
	var cy: float = clampf(pos.y, y_bounds.x, y_bounds.y)
	return Vector2(cx, cy)


func move_hero_by_vector(direction: Vector2, delta: float) -> void:
	if not GameState.orange_rock_broken or direction.length_squared() <= 0.0001:
		_hero_walking = false
		return
	var norm_dir: Vector2 = direction.normalized()
	_hero_walking = true
	if absf(norm_dir.x) > 0.05:
		_hero_facing_left = norm_dir.x < 0.0
	var cur_biome: StringName = GameState.current_biome
	var next_x: float = _hero_map_pos.x + norm_dir.x * HERO_SPEED * delta
	var next_y: float = _hero_map_pos.y + norm_dir.y * HERO_SPEED * delta

	if cur_biome == GameState.BIOME_AMBER:
		if next_x <= EDGE_LEFT_TRIGGER_X and norm_dir.x < -0.1:
			_transition_to_biome(GameState.BIOME_FOREST, SPAWN_RIGHT_X, next_y)
			return
		if next_x >= EDGE_RIGHT_TRIGGER_X and norm_dir.x > 0.1:
			_transition_to_biome(GameState.BIOME_SNOW, SPAWN_LEFT_X, next_y)
			return
		next_x = clampf(next_x, EDGE_LEFT_TRIGGER_X, EDGE_RIGHT_TRIGGER_X)
	elif cur_biome == GameState.BIOME_FOREST:
		if next_x >= EDGE_RIGHT_TRIGGER_X and norm_dir.x > 0.1:
			_transition_to_biome(GameState.BIOME_AMBER, SPAWN_LEFT_X, next_y)
			return
		next_x = clampf(next_x, EDGE_FOREST_MIN_X, EDGE_RIGHT_TRIGGER_X)
	elif cur_biome == GameState.BIOME_SNOW:
		if next_x <= EDGE_LEFT_TRIGGER_X and norm_dir.x < -0.1:
			_transition_to_biome(GameState.BIOME_AMBER, SPAWN_RIGHT_X, next_y)
			return
		next_x = clampf(next_x, EDGE_LEFT_TRIGGER_X, EDGE_SNOW_MAX_X)
	else:
		next_x = clampf(next_x, EDGE_FOREST_MIN_X, EDGE_SNOW_MAX_X)

	var y_bounds: Vector2 = _get_walkable_y_bounds(cur_biome, next_x)
	next_y = clampf(next_y, y_bounds.x, y_bounds.y)
	_hero_map_pos = Vector2(next_x, next_y)
	_sync_hero_avatar()
	_update_hero_proximity()


## Posiciona o protagonista junto a uma estrutura via caminhada de proximidade (usado por testes e acessibilidade).
func move_hero_to_station(station: StringName) -> void:
	if not SITES.has(station):
		return
	var target_biome: StringName = _get_site_biome(station)
	if GameState.current_biome != target_biome:
		GameState.set_current_biome(target_biome)
	var raw_pos: Vector2 = (SITES[station] as Vector2) + Vector2(0.0, 14.0)
	var target_pos: Vector2 = _clamp_hero_to_ground(raw_pos, target_biome)
	_hero_facing_left = target_pos.x < _hero_map_pos.x
	_hero_map_pos = target_pos
	_sync_hero_avatar()
	if station == &"egg":
		_reset_visit()
	else:
		if GameState.hero_station != station:
			GameState.set_hero_station(station)
		if _site != station:
			_visit(station)


func select_section(section: StringName) -> void:
	if _site != &"":
		_select_section(section)


func get_item_card(item_id: StringName) -> PanelContainer:
	for row_val: Variant in _card_rows.values():
		var row: CardRow = row_val as CardRow
		if row != null and row.item_id == item_id and is_instance_valid(row.panel):
			return row.panel
	return null


func get_item_buy_button(item_id: StringName) -> Button:
	for row_val: Variant in _card_rows.values():
		var row: CardRow = row_val as CardRow
		if row != null and row.item_id == item_id and is_instance_valid(row.buy_btn):
			return row.buy_btn
	return null


func is_item_card_dimmed(item_id: StringName) -> bool:
	for row_val: Variant in _card_rows.values():
		var row: CardRow = row_val as CardRow
		if row != null and row.item_id == item_id:
			return row.is_dimmed
	return false


func is_tab_alert_visible(section: StringName) -> bool:
	var btn: Button = _groups.get_node_or_null(NodePath(String(section))) as Button
	if btn == null:
		return false
	var badge: Control = btn.get_node_or_null("Content/AlertBadge") as Control
	return badge != null and badge.visible


func _transition_to_biome(target_biome: StringName, spawn_x: float, preferred_y: float) -> void:
	_pending_biome_spawn = Vector2(spawn_x, preferred_y)
	_has_pending_biome_spawn = true
	GameState.set_current_biome(target_biome)
	if _has_pending_biome_spawn:
		_has_pending_biome_spawn = false


func _on_biome_changed(biome_id: StringName) -> void:
	_site = &""
	_section = &""
	_items.clear()
	_clear_cards()
	if GameState.hero_station != &"":
		GameState.set_hero_station(&"")
	if _has_pending_biome_spawn:
		_hero_map_pos = _clamp_hero_to_ground(_pending_biome_spawn, biome_id)
		_has_pending_biome_spawn = false
	else:
		_hero_map_pos = _clamp_hero_to_ground(_hero_map_pos, biome_id)
	_sync_biome_visuals(true)
	_sync_hero_avatar()
	_refresh()
	_restore_focus_if_cleared()


func _sync_biome_visuals(play_fade: bool) -> void:
	var biome: StringName = GameState.current_biome
	var active_sites: Dictionary = BIOME_SITES.get(biome, BIOME_SITES[GameState.BIOME_AMBER]) as Dictionary
	for id_val: Variant in _landmarks:
		var id: StringName = id_val as StringName
		var spot: FieldLandmark = _landmarks[id] as FieldLandmark
		spot.visible = active_sites.has(id)
		if spot.visible:
			spot.refresh()
	if _basin_name != null:
		_basin_name.text = String(GameState.BIOME_NAMES.get(biome, "Bacia do Âmbar"))
	if _map != null:
		_map.queue_redraw()
	if play_fade:
		_play_biome_fade(biome)


func _play_biome_fade(biome: StringName) -> void:
	if _biome_fade == null or not is_inside_tree():
		return
	if _biome_fade_tween != null and _biome_fade_tween.is_valid():
		_biome_fade_tween.kill()
	var tint: Color = Color(0.11, 0.08, 0.06, 0.52)
	if biome == GameState.BIOME_FOREST:
		tint = Color(0.06, 0.12, 0.08, 0.52)
	elif biome == GameState.BIOME_SNOW:
		tint = Color(0.10, 0.16, 0.22, 0.52)
	_biome_fade.color = tint
	_biome_fade.visible = true
	_biome_fade_tween = create_tween()
	_biome_fade_tween.tween_property(_biome_fade, "color:a", 0.0, BIOME_FADE_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_biome_fade_tween.tween_callback(func() -> void:
		if is_instance_valid(_biome_fade):
			_biome_fade.visible = false
	)


func _restore_focus_if_cleared() -> void:
	if not is_visible_in_tree() or GameState.is_prestige_modal_open:
		return
	var vp: Viewport = get_viewport()
	if vp != null and vp.gui_get_focus_owner() == null:
		_grab_current_biome_focus()


func _grab_current_biome_focus() -> void:
	if _site != &"" and _landmarks.has(_site):
		var site_btn: Button = _landmarks[_site] as Button
		if site_btn.visible:
			site_btn.grab_focus()
			return
	if GameState.current_biome == GameState.BIOME_AMBER and _landmarks.has(&"egg"):
		(_landmarks[&"egg"] as Button).grab_focus()
		return
	var stations: Array[StringName] = GameState.get_stations_for_biome(GameState.current_biome)
	if not stations.is_empty() and _landmarks.has(stations[0]):
		(_landmarks[stations[0]] as Button).grab_focus()


func _on_landmark_clicked(id: StringName) -> void:
	if id == &"egg":
		var egg: FieldLandmark = _landmarks[id] as FieldLandmark
		if not GameState.orange_rock_broken:
			egg.pulse = 1.0
			Events.orange_rock_hit.emit(GameState.get_click_damage(), egg.get_global_rect().get_center())
		_sync_hero_avatar()
		_refresh()
		return
	if not GameState.RUBBLE_DEFS.has(id):
		return
	# Não teleporta o dinossauro nem abre upgrades à distância ao clicar na estrutura.
	var title: String = String(GameState.RUBBLE_DEFS[id]["title"])
	if not GameState.orange_rock_broken:
		Events.notification_requested.emit("Choque o Ovo de Âmbar primeiro!", null)
	elif _site != id:
		Events.notification_requested.emit("Caminhe com WASD até %s para abrir os upgrades!" % title, null)


func _update_hero_proximity() -> void:
	var nearest: StringName = _find_nearest_station(_hero_map_pos)
	if nearest != &"":
		if GameState.hero_station != nearest:
			GameState.set_hero_station(nearest)
		if _site != nearest:
			_visit(nearest)
	else:
		if GameState.hero_station != &"":
			GameState.set_hero_station(&"")
		if _site != &"":
			_site = &""
			_section = &""
			_items.clear()
			_clear_cards()
			_refresh()
			_restore_focus_if_cleared()


func _find_nearest_station(map_pos: Vector2) -> StringName:
	var best_id: StringName = &""
	var best_dist: float = PROXIMITY_RADIUS
	for id: StringName in GameState.get_stations_for_biome(GameState.current_biome):
		if not SITES.has(id):
			continue
		var dist: float = map_pos.distance_to(SITES[id] as Vector2)
		if dist <= best_dist:
			best_dist = dist
			best_id = id
	return best_id


func _sync_hero_avatar() -> void:
	if _hero_avatar == null:
		return
	_hero_avatar.visible = GameState.orange_rock_broken
	if not GameState.orange_rock_broken:
		return
	var map_sz: Vector2 = _map.size
	if map_sz.x <= 10.0 or map_sz.y <= 10.0:
		return
	var screen_foot: Vector2 = (_hero_map_pos / Vector2(480.0, 240.0)) * map_sz
	_hero_avatar.position = (screen_foot - Vector2(_hero_avatar.size.x * 0.5, _hero_avatar.size.y - HeroAvatar.FOOT_OFFSET_Y)).round()
	_hero_avatar.facing_left = _hero_facing_left
	_hero_avatar.walking = _hero_walking
	_hero_avatar.assisting_built = (GameState.hero_station != &"" and GameState.is_station_built(GameState.hero_station))
	_hero_avatar.phase = _hero_anim_phase
	_hero_avatar.action_timer = _hero_action_timer
	_hero_avatar.queue_redraw()


func _layout_landmarks() -> void:
	for id: Variant in _landmarks:
		var button: Control = _landmarks[id] as Control
		var foot: Vector2 = (SITES[id] as Vector2) / Vector2(480.0, 240.0) * _map.size
		var width: float = _map.size.x * (0.13 if id == &"egg" else 0.187)
		var art_height: float = minf(width * 0.76, _map.size.y * 0.30)
		button.size = Vector2(width, art_height + 35.0)
		button.position = (foot - Vector2(width * 0.5, art_height * 0.92)).round()
	_sync_hero_avatar()
	_position_floating_bench()


func _position_floating_bench() -> void:
	if _dock == null or _site == &"" or not _landmarks.has(_site):
		return
	var spot: Control = _landmarks[_site] as Control
	_dock.reset_size()
	var min_sz: Vector2 = _dock.get_combined_minimum_size()
	var max_w: float = maxf(size.x - 24.0, 320.0)
	var bench_w: float = minf(maxf(min_sz.x, 610.0), max_w)
	var bench_h: float = clampf(min_sz.y, 180.0, 270.0)
	var bench_size: Vector2 = Vector2(bench_w, bench_h)
	_dock.size = bench_size
	var target_x: float = spot.position.x + spot.size.x * 0.5 - bench_size.x * 0.5
	var target_y: float = spot.position.y + spot.size.y + 6.0
	if target_y + bench_size.y > size.y - 12.0:
		target_y = spot.position.y - bench_size.y - 8.0
	var max_x: float = maxf(size.x - bench_size.x - 12.0, 12.0)
	var max_y: float = maxf(size.y - bench_size.y - 12.0, 12.0)
	_dock.position = Vector2(clampf(target_x, 12.0, max_x), clampf(target_y, 12.0, max_y)).round()


func _on_scenario_changed(scenario: StringName) -> void:
	if scenario == &"surface":
		_grab_current_biome_focus()


func _on_orange_rock_broken() -> void:
	_hero_map_pos = _clamp_hero_to_ground((SITES[&"egg"] as Vector2) + Vector2(0.0, 16.0), GameState.BIOME_AMBER)
	_refresh_egg()
	_sync_hero_avatar()
	_refresh()
	_restore_focus_if_cleared()


func _reset_visit() -> void:
	_site = &""
	_section = &""
	_items.clear()
	_clear_cards()
	_sync_biome_visuals(false)
	var default_spawn: Vector2 = (SITES[&"egg"] as Vector2) + Vector2(0.0, 16.0) if GameState.current_biome == GameState.BIOME_AMBER else Vector2(240.0, 168.0)
	_hero_map_pos = _clamp_hero_to_ground(default_spawn, GameState.current_biome)
	GameState.set_hero_station(&"")
	_refresh_egg()
	_sync_hero_avatar()
	_refresh()
	_restore_focus_if_cleared()


func _visit(id: StringName) -> void:
	_site = id
	_build_groups()
	_select_section(&"site")
	_position_floating_bench()


func _visit_lab() -> void:
	Events.scenario_transition_requested.emit(&"surface")
	move_hero_to_station(&"rubble_bunker")
	_select_section(&"amber")
	(_landmarks[_site] as Button).grab_focus()


func _build_groups() -> void:
	for child: Node in _groups.get_children():
		child.free()
	_add_group(&"site", _get_tab_tooltip(_site, &"site"))
	if _site == &"rubble_bunker":
		_add_group(&"fossils", _get_tab_tooltip(_site, &"fossils"))
	_add_group(&"upgrades", _get_tab_tooltip(_site, &"upgrades"))
	if _site == &"rubble_bunker":
		_add_group(&"amber", _get_tab_tooltip(_site, &"amber"))


func _get_tab_icon_key(station: StringName, section: StringName) -> StringName:
	match section:
		&"site":
			return &"site"
		&"fossils":
			return &"fossils"
		&"amber":
			return &"amber"
		&"upgrades":
			match station:
				&"rubble_forge":
					return &"tools"
				&"rubble_nest":
					return &"dinos"
				&"rubble_silo":
					return &"scouts"
				&"rubble_bunker":
					return &"university"
				&"forest_grove", &"forest_sanctuary":
					return &"forest"
				&"snow_glacier", &"snow_observatory":
					return &"snow"
	return &"site"


func _get_tab_tooltip(station: StringName, section: StringName) -> String:
	match section:
		&"site":
			return "Estrutura & Equipe"
		&"fossils":
			var raw_cnt: int = GameState.raw_fossil_queue.size()
			return "Fósseis (%d)" % raw_cnt if raw_cnt > 0 else "Fósseis"
		&"amber":
			return "Âmbar Permanente"
		&"upgrades":
			return String(WORKBENCH_TOOLTIPS.get(station, "Upgrades"))
	return String(section)


func _add_group(id: StringName, tooltip: String) -> void:
	var button: Button = Button.new()
	button.name = String(id)
	button.text = ""
	button.tooltip_text = tooltip
	button.accessibility_name = tooltip
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(56.0, 38.0)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal", _style_tab_normal)
	button.add_theme_stylebox_override("hover", _style_tab_hover)
	button.add_theme_stylebox_override("pressed", _style_tab_pressed)
	button.add_theme_stylebox_override("hover_pressed", _style_tab_pressed)
	button.add_theme_stylebox_override("focus", _style_tab_focus)
	button.pressed.connect(_select_section.bind(id))

	var content: HBoxContainer = HBoxContainer.new()
	content.name = "Content"
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 2)
	button.add_child(content)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.custom_minimum_size = Vector2(22.0, 22.0)
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_rect.texture = AmberTheme.get_tab_icon(_get_tab_icon_key(_site, id))
	content.add_child(icon_rect)

	var alert_lbl: Label = Label.new()
	alert_lbl.name = "AlertBadge"
	alert_lbl.text = "!"
	alert_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	alert_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	alert_lbl.add_theme_font_size_override("font_size", 16)
	alert_lbl.add_theme_color_override("font_color", Color("#1488ff"))
	alert_lbl.add_theme_color_override("font_outline_color", Color("#0b182c"))
	alert_lbl.add_theme_constant_override("outline_size", 3)
	alert_lbl.visible = false
	content.add_child(alert_lbl)

	_groups.add_child(button)


func _update_group_labels() -> void:
	for child: Node in _groups.get_children():
		var btn: Button = child as Button
		if btn == null:
			continue
		var section_id: StringName = StringName(btn.name)
		btn.set_pressed_no_signal(section_id == _section)
		var tip: String = _get_tab_tooltip(_site, section_id)
		btn.tooltip_text = tip
		btn.accessibility_name = tip
		var badge: Label = btn.get_node_or_null("Content/AlertBadge") as Label
		if badge != null:
			badge.visible = _has_affordable_item_in_section(_site, section_id)


func _has_affordable_item_in_section(station: StringName, section: StringName) -> bool:
	if station == &"" or not GameState.RUBBLE_DEFS.has(station):
		return false
	var def: Dictionary = GameState.RUBBLE_DEFS[station] as Dictionary
	match section:
		&"site":
			if GameState.can_rebuild_rubble(station):
				return true
			if GameState.can_hire_station_worker(station):
				return true
			if GameState.is_station_built(station) and GameState.has_station_worker(station):
				var gear_id: StringName = StringName(def.get("gear", &""))
				if gear_id != &"" and GameState.can_purchase_upgrade(gear_id):
					return true
			if GameState.is_station_built(station) and GameState.can_revive_station_dino(station):
				return true
			return false
		&"fossils":
			return false
		&"upgrades":
			if station == &"rubble_bunker":
				for origin_station: StringName in GameState.RUBBLE_ORDER:
					var r_dino: StringName = GameState.get_station_revive_dino_id(origin_station)
					if r_dino != &"" and GameState.get_fragments(r_dino) > 0 and GameState.can_revive_station_dino(origin_station):
						return true
			if GameState.is_station_built(station):
				var category: UpgradeData.Category = def["category"]
				for upg: UpgradeData in GameState.get_upgrades_by_category(category):
					var lvl: int = GameState.get_upgrade_level(upg.id)
					if not upg.is_maxed(lvl) and GameState.is_upgrade_unlocked(upg.id) and GameState.can_purchase_upgrade(upg.id):
						return true
			return false
		&"amber":
			for upg: UpgradeData in GameState.get_upgrades_by_category(UpgradeData.Category.AMBER):
				var lvl: int = GameState.get_upgrade_level(upg.id)
				if not upg.is_maxed(lvl) and GameState.is_upgrade_unlocked(upg.id) and GameState.can_purchase_upgrade(upg.id):
					return true
			return false
	return false


func _select_section(section: StringName) -> void:
	_section = section
	_items_scroll.scroll_vertical = 0
	_update_group_labels()
	_refresh()


func _refresh_egg() -> void:
	(_landmarks[&"egg"] as FieldLandmark).refresh()


func _queue_refresh() -> void:
	if not _refresh_pending:
		_refresh_pending = true
		_refresh.call_deferred()


func _clear_cards() -> void:
	for child: Node in _items_list.get_children():
		var item_meta: StringName = StringName(child.get_meta(&"item_id", &""))
		if _emitting_buy_item_id != &"" and item_meta == _emitting_buy_item_id:
			_items_list.remove_child(child)
			child.queue_free()
		else:
			child.free()
	_card_rows.clear()
	_built_keys.clear()
	_built_site = &""
	_built_section = &""
	_rendered_fossil_queue.clear()
	_active_fossil_bar = null
	_active_fossil_status = null


func _refresh() -> void:
	_refresh_pending = false
	for key: Variant in _landmarks:
		var spot: FieldLandmark = _landmarks[key] as FieldLandmark
		spot.selected = (key == _site or key == GameState.hero_station)
		spot.queue_redraw()
	_dock.visible = _site != &""
	_groups.visible = _site != &""
	_actions.visible = _site != &""
	_update_field_action_button()
	if _site == &"":
		return

	_update_header_text()
	_update_group_labels()
	_quantity.visible = (_section != &"fossils")
	_quantity.text = "Lote ×%d" % GameState.buy_multiplier if GameState.buy_multiplier > 0 else "Lote máx."

	_sync_section_cards()
	_position_floating_bench()
	_position_floating_bench.call_deferred()


func _update_header_text() -> void:
	var def: Dictionary = GameState.RUBBLE_DEFS[_site] as Dictionary
	var product: StringName = StringName(def["product"])
	var is_built: bool = GameState.is_station_built(_site)
	var has_worker: bool = GameState.has_station_worker(_site)
	_site_name.text = String(def["title"])
	if not is_built:
		var cost_res: StringName = GameState.get_rubble_cost_resource(_site)
		var cost_res_name: String = String(GameState.RESOURCE_NAMES.get(cost_res, cost_res)).capitalize()
		if _site == &"rubble_bunker":
			_stock.text = "Não construída · Custo: %s %s · Brutos: %d" % [
				GameState.format_number(GameState.get_rubble_cost(_site)),
				cost_res_name,
				GameState.raw_fossil_queue.size(),
			]
		else:
			_stock.text = "Não construída · Custo: %s %s" % [GameState.format_number(GameState.get_rubble_cost(_site)), cost_res_name]
		return
	var effective_rate: float = GameState.get_station_effective_rate(_site)
	var worker_tag: String = String(def["worker"]) if has_worker else "Manual"
	var hero_tag: String = " + 🦖" if GameState.hero_station == _site and GameState.orange_rock_broken else ""
	if _site == &"rubble_bunker":
		var raw_cnt: int = GameState.raw_fossil_queue.size()
		var clean_pct: int = roundi(GameState.fossil_cleaning_progress * 100.0)
		_stock.text = "%s%s · %s ciência (+%.1f/s) · Brutos: %d (%d%%)" % [
			worker_tag, hero_tag, GameState.format_number(GameState.get_resource(product)),
			effective_rate, raw_cnt, clean_pct,
		]
	else:
		var t2_prod: StringName = StringName(def["tier2_product"])
		var t2_rate: float = GameState.get_station_tier2_rate(_site)
		var t2_name: String = String(GameState.RESOURCE_NAMES.get(t2_prod, t2_prod))
		var t2_txt: String = " · +%s/s %s" % [GameState.format_number(t2_rate), t2_name] if t2_rate > 0.0 else ""
		_stock.text = "%s%s · %s %s (+%.1f/s)%s" % [
			worker_tag, hero_tag, GameState.format_number(GameState.get_resource(product)),
			String(GameState.RESOURCE_NAMES.get(product, product)), effective_rate, t2_txt,
		]


func _collect_section_items() -> Array[StringName]:
	var out: Array[StringName] = []
	var def: Dictionary = GameState.RUBBLE_DEFS[_site] as Dictionary
	match _section:
		&"site":
			out.append(ITEM_BUILD_STATION)
			if GameState.is_station_built(_site):
				out.append(ITEM_HIRE_WORKER)
				if GameState.has_station_worker(_site):
					out.append(ITEM_EXPAND_STATION)
					var gear_id: StringName = StringName(def["gear"])
					if GameState.get_upgrade(gear_id) != null:
						out.append(gear_id)
				out.append(STATION_REVIVE_ITEM)
		&"fossils":
			for dino_id: StringName in GameState.raw_fossil_queue:
				out.append(dino_id)
		_:
			if _site == &"rubble_bunker" and _section == &"upgrades":
				for origin_station: StringName in GameState.RUBBLE_ORDER:
					var r_dino: StringName = GameState.get_station_revive_dino_id(origin_station)
					if r_dino != &"" and GameState.get_fragments(r_dino) > 0:
						out.append(StringName(REVIVE_ORIGIN_PREFIX + String(origin_station)))
			if _section == &"amber" or GameState.is_station_built(_site):
				var category: UpgradeData.Category = UpgradeData.Category.AMBER if _section == &"amber" else def["category"]
				for upgrade: UpgradeData in GameState.get_upgrades_by_category(category):
					var lvl: int = GameState.get_upgrade_level(upgrade.id)
					if upgrade.is_maxed(lvl) or GameState.is_upgrade_unlocked(upgrade.id):
						out.append(upgrade.id)
	return out


func _compute_row_keys(items: Array[StringName]) -> Array[StringName]:
	var keys: Array[StringName] = []
	if _section == &"fossils":
		if items.is_empty():
			keys.append(INFO_CARD_KEY)
		else:
			for idx: int in range(items.size()):
				keys.append(StringName("fossil_%d_%s" % [idx, String(items[idx])]))
		return keys
	if items.is_empty():
		keys.append(INFO_CARD_KEY)
		return keys
	for item_id: StringName in items:
		keys.append(item_id)
	return keys


func _sync_section_cards() -> void:
	_items = _collect_section_items()
	var desired_keys: Array[StringName] = _compute_row_keys(_items)
	var needs_rebuild: bool = (
		_built_site != _site
		or _built_section != _section
		or _built_keys != desired_keys
	)
	if needs_rebuild:
		var same_view: bool = (_built_site == _site and _built_section == _section)
		var prev_scroll: int = _items_scroll.scroll_vertical if same_view else 0
		var can_diff_reuse: bool = (
			same_view
			and _section != &"fossils"
			and not _items.is_empty()
			and not _card_rows.has(INFO_CARD_KEY)
		)
		if can_diff_reuse:
			var desired_set: Dictionary = {}
			for key: StringName in desired_keys:
				desired_set[key] = true
			var stale_keys: Array[StringName] = []
			for existing_k: Variant in _card_rows:
				var ek: StringName = existing_k as StringName
				if not desired_set.has(ek):
					stale_keys.append(ek)
			for sk: StringName in stale_keys:
				var stale_row: CardRow = _card_rows[sk] as CardRow
				_card_rows.erase(sk)
				if stale_row != null and is_instance_valid(stale_row.panel):
					if _emitting_buy_item_id != &"" and stale_row.item_id == _emitting_buy_item_id:
						_items_list.remove_child(stale_row.panel)
						stale_row.panel.queue_free()
					else:
						stale_row.panel.free()
			for idx: int in range(_items.size()):
				var item_id: StringName = _items[idx]
				var row: CardRow = _card_rows.get(item_id, null) as CardRow
				if row == null:
					row = _create_action_card(item_id)
					_card_rows[item_id] = row
					_items_list.add_child(row.panel)
				_items_list.move_child(row.panel, idx)
			_built_keys = desired_keys.duplicate()
		else:
			_clear_cards()
			_built_site = _site
			_built_section = _section
			_built_keys = desired_keys.duplicate()
			if _section == &"fossils":
				_build_fossil_rows()
			elif _items.is_empty():
				_build_info_row()
			else:
				for item_id: StringName in _items:
					var row: CardRow = _create_action_card(item_id)
					_card_rows[item_id] = row
					_items_list.add_child(row.panel)
		_items_scroll.set_deferred("scroll_vertical", prev_scroll)

	if _section == &"fossils":
		_rendered_fossil_queue = GameState.raw_fossil_queue.duplicate()
		_update_fossil_rows_in_place()
	elif _items.is_empty():
		_update_info_row()
	else:
		for item_id: StringName in _items:
			var row: CardRow = _card_rows.get(item_id, null) as CardRow
			if row != null:
				_update_action_card(row)


func _create_action_card(item_id: StringName) -> CardRow:
	var row := CardRow.new()
	row.key = item_id
	row.item_id = item_id

	var panel := PanelContainer.new()
	var safe_name: String = String(item_id).replace(":", "_")
	panel.name = "Card_%s" % safe_name
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style_card_active)
	panel.set_meta(&"item_id", item_id)
	panel.set_meta(&"is_dimmed", false)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.name = "Row"
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	var icon_slot := PanelContainer.new()
	icon_slot.name = "IconSlot"
	icon_slot.custom_minimum_size = Vector2(34.0, 34.0)
	icon_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_slot.add_theme_stylebox_override("panel", _style_icon_slot)
	hbox.add_child(icon_slot)

	var icon_rect := TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.custom_minimum_size = Vector2(28.0, 28.0)
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_slot.add_child(icon_rect)

	var info := VBoxContainer.new()
	info.name = "Info"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 2)
	hbox.add_child(info)

	var title_lbl := Label.new()
	title_lbl.name = "Title"
	title_lbl.add_theme_font_size_override("font_size", 14)
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.name = "Description"
	desc_lbl.custom_minimum_size = Vector2(310.0, 0.0)
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.82, 0.80, 0.76, 1.0))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.max_lines_visible = 2
	desc_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	info.add_child(desc_lbl)

	var buy_btn := Button.new()
	buy_btn.name = "BuyButton"
	buy_btn.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	buy_btn.custom_minimum_size = Vector2(162.0, 42.0)
	buy_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy_btn.add_theme_font_size_override("font_size", 12)
	buy_btn.add_theme_constant_override("icon_max_width", 20)
	buy_btn.pressed.connect(_on_item_buy_pressed.bind(item_id))
	hbox.add_child(buy_btn)

	row.panel = panel
	row.margin = margin
	row.icon_slot = icon_slot
	row.icon_rect = icon_rect
	row.title_lbl = title_lbl
	row.desc_lbl = desc_lbl
	row.buy_btn = buy_btn
	return row


func _apply_card_visual_state(row: CardRow, dimmed: bool, highlighted: bool = false) -> void:
	row.is_dimmed = dimmed
	row.panel.set_meta(&"is_dimmed", dimmed)
	if dimmed:
		row.panel.modulate = DIMMED_MODULATE
		row.panel.add_theme_stylebox_override("panel", _style_card_dimmed)
		row.margin.add_theme_constant_override("margin_top", 4)
		row.margin.add_theme_constant_override("margin_bottom", 4)
		row.desc_lbl.max_lines_visible = 1
		row.buy_btn.custom_minimum_size = Vector2(162.0, 32.0)
	else:
		row.panel.modulate = Color.WHITE
		row.panel.add_theme_stylebox_override("panel", _style_card_highlight if highlighted else _style_card_active)
		row.margin.add_theme_constant_override("margin_top", 5)
		row.margin.add_theme_constant_override("margin_bottom", 5)
		row.desc_lbl.max_lines_visible = 2
		row.buy_btn.custom_minimum_size = Vector2(162.0, 42.0)


func _set_card_icon(row: CardRow, tex: Texture2D) -> void:
	row.icon_rect.texture = tex
	row.icon_slot.visible = tex != null


func _set_btn_price(btn: Button, action: String, currency: StringName, cost: float, affordable: bool) -> void:
	btn.icon = AmberTheme.get_resource_icon(currency)
	btn.text = "%s\n%s %s" % [action, GameState.format_number(cost), String(GameState.RESOURCE_NAMES[currency])]
	btn.disabled = not affordable
	btn.tooltip_text = "Saldo: %s %s" % [GameState.format_number(GameState.get_resource(currency)), String(GameState.RESOURCE_NAMES[currency])]


func _set_btn_status(btn: Button, label: String, icon_tex: Texture2D = null) -> void:
	btn.icon = icon_tex
	btn.text = label
	btn.tooltip_text = label
	btn.disabled = true


func _get_worker_icon(station: StringName) -> Texture2D:
	if station == &"rubble_forge":
		var pachy: Texture2D = AmberTheme.get_dino_sprite(&"pachycephalosaurus")
		if pachy != null:
			return pachy
	if station == &"rubble_silo":
		var ptero: Texture2D = AmberTheme.get_dino_sprite(&"pterodactyl")
		if ptero != null:
			return ptero
	var worker_icon: Texture2D = StationWorkerArt.get_icon(station)
	if worker_icon != null:
		return worker_icon
	var def: Dictionary = GameState.RUBBLE_DEFS[station] as Dictionary
	var product: StringName = StringName(def["product"])
	return AmberTheme.get_resource_icon(product)


func _update_action_card(row: CardRow) -> void:
	var item_id: StringName = row.item_id
	var def: Dictionary = GameState.RUBBLE_DEFS[_site] as Dictionary
	var product: StringName = StringName(def["product"])
	var prod_name: String = String(GameState.RESOURCE_NAMES.get(product, product))

	if item_id == ITEM_BUILD_STATION:
		var is_built: bool = GameState.is_station_built(_site)
		var build_res: StringName = GameState.get_rubble_cost_resource(_site) if not is_built else StringName(def.get("build_resource", GameState.RES_ROCKS))
		_set_card_icon(row, AmberTheme.get_resource_icon(build_res))
		if is_built:
			_apply_card_visual_state(row, true)
			row.title_lbl.text = "✓ %s construída" % String(def["title"])
			row.desc_lbl.text = "Estrutura erguida. Você já pode farmar %s aqui com [E]." % prod_name
			_set_btn_status(row.buy_btn, "Comprado", null)
		else:
			_apply_card_visual_state(row, false)
			row.title_lbl.text = "Construir %s" % String(def["title"])
			row.desc_lbl.text = "Ergue a estrutura no bioma para liberar farm manual de %s e recrutamento de %s." % [prod_name, String(def["worker"])]
			_set_btn_price(row.buy_btn, "Construir", build_res, GameState.get_rubble_cost(_site), GameState.can_rebuild_rubble(_site))
		return

	if item_id == ITEM_HIRE_WORKER:
		var has_worker: bool = GameState.has_station_worker(_site)
		var worker_name: String = String(def["worker"])
		_set_card_icon(row, _get_worker_icon(_site))
		if has_worker:
			_apply_card_visual_state(row, true)
			row.title_lbl.text = "✓ %s recrutado" % worker_name
			row.desc_lbl.text = "%s automatiza a coleta de %s (+%.1f/s base)." % [worker_name, prod_name, float(def["rate"])]
			_set_btn_status(row.buy_btn, "Comprado", null)
		else:
			_apply_card_visual_state(row, false, true)
			row.title_lbl.text = "Recrutar %s" % worker_name
			row.desc_lbl.text = String(def.get("worker_desc", "%s coleta %s automaticamente (+%.1f/s base)." % [worker_name, prod_name, float(def["rate"])]))
			_set_btn_price(row.buy_btn, "Recrutar", product, GameState.get_station_worker_cost(_site), GameState.can_hire_station_worker(_site))
		return

	if item_id == ITEM_EXPAND_STATION:
		var level: int = GameState.get_rubble_level(_site)
		var expand_res: StringName = GameState.get_rubble_cost_resource(_site)
		_set_card_icon(row, AmberTheme.get_resource_icon(expand_res))
		_apply_card_visual_state(row, false)
		row.title_lbl.text = "Ampliar posto · Nv. %d" % level
		row.desc_lbl.text = "%s. Produção automática +%.1f %s/s por nível." % [String(def["desc"]), float(def["rate"]), prod_name]
		_set_btn_price(row.buy_btn, "Ampliar", expand_res, GameState.get_rubble_cost(_site), GameState.can_rebuild_rubble(_site))
		return

	if item_id == STATION_REVIVE_ITEM:
		_update_revive_card(row, _site, false)
		return

	if String(item_id).begins_with(REVIVE_ORIGIN_PREFIX):
		var origin_station: StringName = StringName(String(item_id).trim_prefix(REVIVE_ORIGIN_PREFIX))
		_update_revive_card(row, origin_station, true)
		return

	_update_upgrade_card(row, item_id)


func _update_revive_card(row: CardRow, origin_station: StringName, show_origin: bool) -> void:
	if not GameState.RUBBLE_DEFS.has(origin_station):
		return
	var odef: Dictionary = GameState.RUBBLE_DEFS[origin_station] as Dictionary
	var dino_id: StringName = GameState.get_station_revive_dino_id(origin_station)
	var revived: int = GameState.get_station_revived_count(origin_station)
	var frags: int = GameState.get_fragments(dino_id)
	var req: int = GameState.STATION_REVIVE_FOSSILS_REQUIRED
	var t2_prod: StringName = StringName(odef["tier2_product"])
	var t2_label: String = String(GameState.RESOURCE_NAMES.get(t2_prod, t2_prod)).capitalize()
	if origin_station == &"rubble_bunker":
		t2_label = "Ciência Avançada (+60% limpeza, +35% global)"
	elif origin_station == &"forest_sanctuary":
		t2_label = "Frutas (+50% produção global)"
	elif origin_station == &"snow_observatory":
		t2_label = "Cristais (+15% escudo, +50% Âmbar)"
	var t2_rate: float = float(odef.get("tier2_rate", 0.0))
	var rmult: float = float(odef.get("revive_mult", 2.5))
	var rname: String = String(odef["revive_name"])
	var otitle: String = String(odef["title"])

	var dino_tex: Texture2D = AmberTheme.get_dino_sprite(dino_id)
	if dino_tex == null:
		dino_tex = AmberTheme.get_icon(&"fragment")
	_set_card_icon(row, dino_tex)
	_apply_card_visual_state(row, false, frags > 0)

	if show_origin:
		var suffix: String = " · ×%d" % revived if revived > 0 else ""
		row.title_lbl.text = "%s (%s)%s" % [rname, otitle, suffix]
		row.desc_lbl.text = "Estrutura de origem: %s · Fósseis limpos: %d / %d · Gera %s." % [otitle, frags, req, t2_label]
	else:
		var suffix: String = " · ×%d" % revived if revived > 0 else ""
		row.title_lbl.text = "Reviver %s%s" % [rname, suffix]
		row.desc_lbl.text = "Fósseis limpos: %d / %d · Gera %s (+%.2f/s) e ×%.1f produção." % [frags, req, t2_label, t2_rate, rmult]

	if not GameState.is_station_built(origin_station):
		_set_btn_status(row.buy_btn, "Construa %s" % otitle, null)
	elif frags < req:
		_set_btn_status(row.buy_btn, "Fósseis %d / %d" % [frags, req], AmberTheme.get_icon(&"fragment"))
	else:
		var oprod: StringName = StringName(odef["product"])
		_set_btn_price(row.buy_btn, "Reviver", oprod, GameState.get_station_revive_cost(origin_station), GameState.can_revive_station_dino(origin_station))


func _update_upgrade_card(row: CardRow, id: StringName) -> void:
	var data: UpgradeData = GameState.get_upgrade(id)
	if data == null:
		return
	var level: int = GameState.get_upgrade_level(id)
	var is_maxed: bool = data.is_maxed(level)
	var icon_tex: Texture2D = data.icon if data.icon != null else AmberTheme.get_resource_icon(data.cost_resource)
	_set_card_icon(row, icon_tex)

	var desc_text: String = data.description
	if data.required_station != &"":
		desc_text += " Produção local +%d%% por nível." % roundi(GameState.FIELD_GEAR_YIELD_BONUS * 100.0)
	row.desc_lbl.text = desc_text

	if is_maxed:
		_apply_card_visual_state(row, true)
		row.title_lbl.text = "✓ %s" % data.display_name if data.max_level == 1 else "✓ %s · Nv. %d" % [data.display_name, level]
		_set_btn_status(row.buy_btn, "Comprado" if data.max_level == 1 else "Máximo", null)
	elif not GameState.is_upgrade_unlocked(id):
		_apply_card_visual_state(row, false)
		row.title_lbl.text = data.display_name if data.max_level == 1 else "%s · Nv. %d" % [data.display_name, level]
		if data.required_station != &"":
			_set_btn_status(row.buy_btn, "Recrute o dino", null)
		elif GameState.current_era_index < data.required_era_index:
			_set_btn_status(row.buy_btn, "Alcance %s" % GameState.eras[data.required_era_index].display_name, null)
		else:
			var req_upg: UpgradeData = GameState.get_upgrade(data.required_upgrade)
			var req_name: String = req_upg.display_name if req_upg != null else String(data.required_upgrade)
			_set_btn_status(row.buy_btn, "Requer %s" % req_name, null)
	else:
		_apply_card_visual_state(row, false)
		row.title_lbl.text = data.display_name if data.max_level == 1 else "%s · Nv. %d" % [data.display_name, level]
		var count: int = maxi(1, GameState.resolve_purchase_amount(id))
		var action_lbl: String = "Comprar" if data.max_level == 1 else "Equipar +%d" % count
		_set_btn_price(row.buy_btn, action_lbl, data.cost_resource, GameState.get_purchase_cost(id), GameState.can_purchase_upgrade(id))


func _build_info_row() -> void:
	var row := CardRow.new()
	row.key = INFO_CARD_KEY
	row.item_id = INFO_CARD_KEY

	var panel := PanelContainer.new()
	panel.name = "InfoCard"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style_card_dimmed)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.name = "Row"
	hbox.add_theme_constant_override("separation", 8)
	margin.add_child(hbox)

	var icon_slot := PanelContainer.new()
	icon_slot.name = "IconSlot"
	icon_slot.custom_minimum_size = Vector2(34.0, 34.0)
	icon_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_slot.add_theme_stylebox_override("panel", _style_icon_slot)
	hbox.add_child(icon_slot)

	var icon_rect := TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.custom_minimum_size = Vector2(28.0, 28.0)
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_slot.add_child(icon_rect)

	var info := VBoxContainer.new()
	info.name = "Info"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	hbox.add_child(info)

	var title_lbl := Label.new()
	title_lbl.name = "Title"
	title_lbl.add_theme_font_size_override("font_size", 14)
	info.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.name = "Description"
	desc_lbl.custom_minimum_size = Vector2(310.0, 0.0)
	desc_lbl.add_theme_font_size_override("font_size", 12)
	desc_lbl.add_theme_color_override("font_color", Color(0.82, 0.80, 0.76, 1.0))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(desc_lbl)

	row.panel = panel
	row.margin = margin
	row.icon_slot = icon_slot
	row.icon_rect = icon_rect
	row.title_lbl = title_lbl
	row.desc_lbl = desc_lbl
	_card_rows[INFO_CARD_KEY] = row
	_items_list.add_child(panel)


func _update_info_row() -> void:
	var row: CardRow = _card_rows.get(INFO_CARD_KEY, null) as CardRow
	if row == null:
		return
	var def: Dictionary = GameState.RUBBLE_DEFS[_site] as Dictionary
	if _section == &"fossils":
		_set_card_icon(row, AmberTheme.get_icon(&"fragment"))
		row.title_lbl.text = "Nenhum fóssil bruto na bancada"
		row.desc_lbl.text = "Colete recursos nas estruturas dos biomas para encontrar fósseis brutos. Cada limpeza leva %ds base e libera dinossauros especialistas." % roundi(GameState.BASE_FOSSIL_CLEAN_SECONDS)
	elif not GameState.is_station_built(_site):
		_set_card_icon(row, AmberTheme.get_resource_icon(GameState.get_rubble_cost_resource(_site)))
		row.title_lbl.text = "Estrutura ainda não construída"
		row.desc_lbl.text = "Construa %s na aba de Estrutura para desbloquear estes upgrades." % String(def["title"])
	else:
		_set_card_icon(row, _get_worker_icon(_site))
		row.title_lbl.text = "Recrute o dinossauro trabalhador"
		row.desc_lbl.text = "Recrute %s na aba de Estrutura para desbloquear os próximos upgrades." % String(def["worker"])


func _build_fossil_rows() -> void:
	_active_fossil_bar = null
	_active_fossil_status = null
	if GameState.raw_fossil_queue.is_empty():
		_build_info_row()
		_update_info_row()
		return
	for idx: int in range(GameState.raw_fossil_queue.size()):
		var dino_id: StringName = GameState.raw_fossil_queue[idx]
		var row_key: StringName = StringName("fossil_%d_%s" % [idx, String(dino_id)])
		var row: CardRow = _create_fossil_row(row_key, dino_id, idx)
		_card_rows[row_key] = row
		_items_list.add_child(row.panel)
		if idx == 0:
			_active_fossil_bar = row.progress_bar
			_active_fossil_status = row.status_lbl


func _create_fossil_row(row_key: StringName, dino_id: StringName, queue_idx: int) -> CardRow:
	var row := CardRow.new()
	row.key = row_key
	row.item_id = dino_id

	var panel := PanelContainer.new()
	panel.name = "FossilRow_%d" % queue_idx
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _style_card_highlight if queue_idx == 0 else _style_card_active)
	panel.set_meta(&"dino_id", dino_id)
	panel.set_meta(&"queue_index", queue_idx)

	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 5)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 5)
	panel.add_child(margin)

	var hbox := HBoxContainer.new()
	hbox.name = "Row"
	hbox.add_theme_constant_override("separation", 10)
	margin.add_child(hbox)

	var icon_slot := PanelContainer.new()
	icon_slot.name = "IconSlot"
	icon_slot.custom_minimum_size = Vector2(36.0, 36.0)
	icon_slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon_slot.add_theme_stylebox_override("panel", _style_icon_slot)
	hbox.add_child(icon_slot)

	var icon_rect := TextureRect.new()
	icon_rect.name = "Icon"
	icon_rect.custom_minimum_size = Vector2(28.0, 28.0)
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tex: Texture2D = AmberTheme.get_dino_sprite(dino_id)
	if tex == null:
		tex = AmberTheme.get_icon(&"fragment")
	icon_rect.texture = tex
	icon_slot.add_child(icon_rect)

	var info := VBoxContainer.new()
	info.name = "Info"
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_theme_constant_override("separation", 4)
	hbox.add_child(info)

	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 8)
	info.add_child(header)

	var dino_data: DinoData = GameState.get_dino(dino_id)
	var dino_name: String = dino_data.display_name if dino_data != null else String(dino_id).capitalize()
	var origin_station: StringName = GameState.get_station_for_dino(dino_id)
	var origin_title: String = String(GameState.RUBBLE_DEFS[origin_station]["title"]) if origin_station != &"" and GameState.RUBBLE_DEFS.has(origin_station) else "Bacia do Âmbar"

	var title_lbl := Label.new()
	title_lbl.name = "Title"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	title_lbl.text = "Fóssil de %s · %s" % [dino_name, origin_title]
	header.add_child(title_lbl)

	var status_lbl := Label.new()
	status_lbl.name = "StatusLabel"
	status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_lbl.add_theme_font_size_override("font_size", 12)
	status_lbl.add_theme_color_override("font_color", Color(0.98, 0.84, 0.42, 1.0) if queue_idx == 0 else Color(0.78, 0.76, 0.72, 1.0))
	header.add_child(status_lbl)

	var bar := ProgressBar.new()
	bar.name = "CleanProgress"
	bar.min_value = 0.0
	bar.max_value = 100.0
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(220.0, 16.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("background", _style_fossil_bar_bg)
	bar.add_theme_stylebox_override("fill", _style_fossil_bar_fill)
	info.add_child(bar)

	row.panel = panel
	row.margin = margin
	row.icon_slot = icon_slot
	row.icon_rect = icon_rect
	row.title_lbl = title_lbl
	row.status_lbl = status_lbl
	row.progress_bar = bar
	return row


func _update_fossil_rows_in_place() -> void:
	if GameState.raw_fossil_queue.is_empty():
		_update_info_row()
		return
	var uni_built: bool = GameState.is_station_built(&"rubble_bunker")
	var speed: float = GameState.get_university_cleaning_speed()
	var queued_secs: int = ceili(GameState.BASE_FOSSIL_CLEAN_SECONDS / maxf(speed, 1.0)) if uni_built and speed > 0.0 else roundi(GameState.BASE_FOSSIL_CLEAN_SECONDS)
	for idx: int in range(GameState.raw_fossil_queue.size()):
		var dino_id: StringName = GameState.raw_fossil_queue[idx]
		var row_key: StringName = StringName("fossil_%d_%s" % [idx, String(dino_id)])
		var row: CardRow = _card_rows.get(row_key, null) as CardRow
		if row == null or row.progress_bar == null or row.status_lbl == null:
			continue
		if not uni_built:
			row.progress_bar.value = 0.0
			row.status_lbl.text = "Construa a Universidade"
		elif idx == 0:
			var pct: float = clampf(GameState.fossil_cleaning_progress * 100.0, 0.0, 100.0)
			var rem_secs: int = ceili(GameState.get_university_clean_remaining_seconds())
			row.progress_bar.value = pct
			row.status_lbl.text = "Limpeza: %d%% (%ds)" % [roundi(pct), rem_secs]
		else:
			row.progress_bar.value = 0.0
			row.status_lbl.text = "Na fila (%ds)" % queued_secs


func _update_university_live_ui() -> void:
	var queue_changed: bool = GameState.raw_fossil_queue != _rendered_fossil_queue
	if _section == &"fossils":
		if queue_changed:
			_refresh()
			return
		if not GameState.raw_fossil_queue.is_empty():
			var uni_built: bool = GameState.is_station_built(&"rubble_bunker")
			if is_instance_valid(_active_fossil_bar) and is_instance_valid(_active_fossil_status):
				if not uni_built:
					_active_fossil_bar.value = 0.0
					_active_fossil_status.text = "Construa a Universidade"
				else:
					var pct: float = clampf(GameState.fossil_cleaning_progress * 100.0, 0.0, 100.0)
					var rem_secs: int = ceili(GameState.get_university_clean_remaining_seconds())
					_active_fossil_bar.value = pct
					_active_fossil_status.text = "Limpeza: %d%% (%ds)" % [roundi(pct), rem_secs]
			_update_header_text()
	else:
		if queue_changed:
			_rendered_fossil_queue = GameState.raw_fossil_queue.duplicate()
			_update_group_labels()
		if not GameState.raw_fossil_queue.is_empty():
			_update_header_text()


func _update_field_action_button() -> void:
	if not GameState.orange_rock_broken:
		_field_action_btn.disabled = false
		_field_action_btn.text = "Golpear Ovo [E]"
		return
	var active_site: StringName = _site if _site != &"" else GameState.hero_station
	if active_site != &"" and GameState.RUBBLE_DEFS.has(active_site):
		if not GameState.is_station_built(active_site):
			_field_action_btn.disabled = true
			_field_action_btn.text = "Construa a estrutura primeiro"
			return
		_field_action_btn.disabled = false
		if active_site == &"rubble_bunker":
			_field_action_btn.text = "Limpar & Estudar [E]"
		else:
			var prod: StringName = StringName(GameState.RUBBLE_DEFS[active_site]["product"])
			_field_action_btn.text = "Farmar %s [E]" % String(GameState.RESOURCE_NAMES[prod]).capitalize()
	else:
		_field_action_btn.disabled = false
		_field_action_btn.text = "Ajudar [E]"


func _on_field_action_pressed() -> void:
	var action_pos: Vector2 = (_landmarks[&"egg"] as Control).get_global_rect().get_center()
	if not GameState.orange_rock_broken:
		(_landmarks[&"egg"] as FieldLandmark).pulse = 1.0
		GameState.hero_farm_action(&"egg", action_pos)
		return
	var target_station: StringName = _site if GameState.RUBBLE_DEFS.has(_site) else GameState.hero_station
	if target_station == &"":
		for st: StringName in GameState.get_stations_for_biome(GameState.current_biome):
			if GameState.is_station_built(st):
				target_station = st
				break
		if target_station == &"":
			target_station = &"rubble_forge"
	if _landmarks.has(target_station):
		var landmark: FieldLandmark = _landmarks[target_station] as FieldLandmark
		landmark.pulse = 1.0
		action_pos = landmark.get_global_rect().get_center()
	_hero_action_timer = HeroAvatar.ACTION_DURATION
	_sync_hero_avatar()
	GameState.hero_farm_action(target_station, action_pos)
	_refresh()


func _on_item_buy_pressed(item_id: StringName) -> void:
	var btn: Button = get_item_buy_button(item_id)
	if btn == null or btn.disabled:
		return
	_emitting_buy_item_id = item_id
	if item_id == ITEM_BUILD_STATION or item_id == ITEM_EXPAND_STATION:
		Events.rubble_rebuild_requested.emit(_site)
	elif item_id == ITEM_HIRE_WORKER:
		GameState.hire_station_worker(_site)
	elif item_id == STATION_REVIVE_ITEM:
		GameState.revive_station_dino(_site)
	elif String(item_id).begins_with(REVIVE_ORIGIN_PREFIX):
		var origin_station: StringName = StringName(String(item_id).trim_prefix(REVIVE_ORIGIN_PREFIX))
		if GameState.revive_station_dino(origin_station) and _landmarks.has(origin_station):
			(_landmarks[origin_station] as FieldLandmark).pulse = 1.0
	else:
		Events.upgrade_purchase_requested.emit(item_id, GameState.buy_multiplier)
	if _landmarks.has(_site):
		(_landmarks[_site] as FieldLandmark).pulse = 1.0
	_refresh()
	_emitting_buy_item_id = &""


func _on_loot_dropped(res_id: StringName, amount: float, world_pos: Vector2) -> void:
	if not is_visible_in_tree() or _active_floating_labels >= MAX_FLOATING_LABELS:
		return
	var unit: String = String(GameState.RESOURCE_NAMES.get(res_id, res_id)).capitalize()
	var col: Color = AmberTheme.get_resource_color(res_id)
	_spawn_floating_text("+%s %s" % [GameState.format_number(amount), unit], world_pos, col)


func _on_fragment_dropped(dino_id: StringName, world_pos: Vector2) -> void:
	if not is_visible_in_tree():
		return
	var data: DinoData = GameState.get_dino(dino_id)
	var dname: String = data.display_name if data != null else String(dino_id)
	_spawn_floating_text("+1 Fóssil limpo: %s" % dname, world_pos, Color(1.0, 0.84, 0.25))


func _spawn_floating_text(text: String, global_pos: Vector2, color: Color) -> void:
	_active_floating_labels += 1
	var lbl := Label.new()
	lbl.text = text
	lbl.modulate = color
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_outline_color", Color(0.14, 0.10, 0.08, 0.92))
	lbl.add_theme_constant_override("outline_size", 4)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.add_child(lbl)

	var local_pos: Vector2 = _map.get_global_transform_with_canvas().affine_inverse() * global_pos
	if local_pos.x <= 10.0 and local_pos.y <= 10.0:
		local_pos = _map.size * 0.5
	local_pos += Vector2(randf_range(-34.0, 34.0), randf_range(-26.0, -8.0))
	lbl.position = local_pos

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", local_pos.y - 44.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.75).set_delay(0.15)
	tw.chain().tween_callback(func() -> void:
		_active_floating_labels = maxi(_active_floating_labels - 1, 0)
		lbl.queue_free()
	)
