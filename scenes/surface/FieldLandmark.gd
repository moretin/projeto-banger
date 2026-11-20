class_name FieldLandmark
extends Button
## O alvo de interação cobre a própria construção. A placa acompanha o desenho.

const INK: Color = Color("#302d38")
const WOOD: Color = Color("#815446")
const TIMBER: Color = Color("#c38459")
const CREAM: Color = Color("#ffdf9f")
const AMBER: Color = Color("#edaa48")
const CAPTION_BUILT_COLOR: Color = Color("#fff1ce")
const CAPTION_UNBUILT_COLOR: Color = Color("#d8cbb8")
const ART_FPS: float = 24.0
const AMBER_NEST: Texture2D = preload("res://assets/sprites/surface/structures/amber_nest.png")
const STATION_ART: Dictionary = {
	&"rubble_forge": [
		preload("res://assets/sprites/surface/structures/quarry_foundation.png"),
		preload("res://assets/sprites/surface/structures/quarry_built.png"),
	],
	&"rubble_nest": [
		preload("res://assets/sprites/surface/structures/lake_foundation.png"),
		preload("res://assets/sprites/surface/structures/lake_built.png"),
	],
	&"rubble_silo": [
		preload("res://assets/sprites/surface/structures/tower_foundation.png"),
		preload("res://assets/sprites/surface/structures/tower_built.png"),
	],
	&"rubble_bunker": [
		preload("res://assets/sprites/surface/structures/university_foundation.png"),
		preload("res://assets/sprites/surface/structures/university_built.png"),
	],
}

var station: StringName
var selected: bool = false
var phase: float = 0.0
var _frame: int = -1
var pulse: float = 0.0
var _caption: Label
var _built_cached: bool = false


func _ready() -> void:
	flat = true
	texture_filter = Control.TEXTURE_FILTER_NEAREST
	for style: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_caption = Label.new()
	add_child(_caption)
	_caption.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_caption.offset_top = -35
	_caption.offset_bottom = 0
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_theme_font_size_override("font_size", 18)
	_caption.add_theme_color_override("font_color", CAPTION_BUILT_COLOR)
	_caption.add_theme_color_override("font_outline_color", INK)
	_caption.add_theme_constant_override("outline_size", 6)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	Events.rubble_rebuilt.connect(_on_rubble_rebuilt)
	Events.run_started.connect(_on_run_or_load_changed.unbind(1))
	Events.game_loaded.connect(_on_run_or_load_changed)
	refresh()


func refresh() -> void:
	if _caption == null:
		return
	if station == &"egg":
		_caption.text = "Ninho de âmbar" if GameState.orange_rock_broken else "Ovo de âmbar · %d/%d" % [ceili(GameState.orange_rock_hp), int(GameState.ORANGE_ROCK_MAX_HP)]
		_caption.add_theme_color_override("font_color", CAPTION_BUILT_COLOR)
		_caption.add_theme_font_size_override("font_size", 18)
	elif GameState.RUBBLE_DEFS.has(station):
		var def: Dictionary = GameState.RUBBLE_DEFS[station] as Dictionary
		var title: String = String(def["title"])
		var built: bool = GameState.is_station_built(station)
		_built_cached = built
		if built:
			_caption.text = title
			_caption.add_theme_color_override("font_color", CAPTION_BUILT_COLOR)
			_caption.add_theme_font_size_override("font_size", 18)
		else:
			_caption.text = "%s (Construir)" % title
			_caption.add_theme_color_override("font_color", CAPTION_UNBUILT_COLOR)
			_caption.add_theme_font_size_override("font_size", 15)
	tooltip_text = _caption.text
	accessibility_name = _caption.text
	queue_redraw()


func _on_rubble_rebuilt(rubble_id: StringName, _new_level: int) -> void:
	if rubble_id == station:
		refresh()


func _on_run_or_load_changed() -> void:
	refresh()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if station != &"egg" and GameState.RUBBLE_DEFS.has(station):
		var built_now: bool = GameState.is_station_built(station)
		if built_now != _built_cached:
			refresh()
	phase += delta
	var was_pulsing: bool = pulse > 0.0
	pulse = maxf(0.0, pulse - delta * 3.0)
	if not _built_cached and not was_pulsing:
		return
	var frame: int = floori(phase * ART_FPS)
	if frame != _frame:
		_frame = frame
		queue_redraw()


func _draw() -> void:
	var art_size: Vector2 = Vector2(size.x, size.y - 35)
	var factor: float = minf(art_size.x / 84.0, art_size.y / 64.0)
	if factor <= 0:
		return
	var origin: Vector2 = Vector2((size.x - 84 * factor) / 2, art_size.y - factor * 64)
	if pulse > 0.0:
		origin.y -= roundf(sin(pulse * PI) * 2) * factor
	draw_set_transform(origin, 0, Vector2.ONE * factor)
	if station == &"egg":
		_nest()
	elif STATION_ART.has(station):
		var level: int = GameState.get_rubble_level(station)
		_draw_station(level)
		if level > 0 and GameState.has_station_worker(station):
			var def: Dictionary = GameState.RUBBLE_DEFS[station] as Dictionary
			var gear_id: StringName = def["gear"] as StringName
			StationWorkerArt.draw(self, station, phase, GameState.get_upgrade_level(gear_id) > 0, false, origin, factor)
		var revived: int = GameState.get_station_revived_count(station)
		if revived > 0:
			StationWorkerArt.draw(self, station, phase, false, true, origin, factor)
		var flash_left: float = GameState.get_station_fossil_flash(station)
		if flash_left > 0.0:
			_draw_fossil_badge(flash_left)
	if selected or has_focus() or is_hovered():
		_box(15, 60, 54, 2, AMBER if selected else INK)
		_box(36, 61, 12, 2, CREAM)


func _box(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)


func _nest() -> void:
	var frame_x: int = 168 if GameState.orange_rock_broken else 0
	draw_texture_rect_region(AMBER_NEST, Rect2(0, 0, 84, 64), Rect2(frame_x, 0, 168, 128))
	if GameState.orange_rock_broken:
		return
	var crack: Color = Color("#743720")
	if GameState.orange_rock_hp < 7:
		draw_polyline(PackedVector2Array([Vector2(47, 17), Vector2(45, 23), Vector2(48, 29), Vector2(44, 32)]), crack, 1.0)
	if GameState.orange_rock_hp < 4:
		draw_polyline(PackedVector2Array([Vector2(44, 32), Vector2(45, 38), Vector2(38, 42), Vector2(40, 49)]), crack, 1.0)
		draw_line(Vector2(44, 36), Vector2(50, 39), crack, 1.0)


func _draw_station(level: int) -> void:
	var variants: Array = STATION_ART[station] as Array
	var texture: Texture2D = variants[1 if level > 0 else 0] as Texture2D
	draw_texture_rect(texture, Rect2(0, 0, 84, 64), false)
	if level <= 0:
		return

	match station:
		&"rubble_forge":
			if GameState.get_upgrade_level(&"tools_metal_pick") > 0:
				_draw_glint(Vector2(19, 32), 0.0)
		&"rubble_nest":
			for i: int in range(3):
				var ripple: float = fmod(phase * 0.55 + float(i) / 3.0, 1.0)
				var length: float = roundf(2.0 + ripple * 7.0)
				var x: float = 22.0 + float(i) * 12.0 - length * 0.5
				_box(x, 47.0 + float(i) * 2.0, length, 1.0, Color(0.68, 0.91, 0.81, sin(ripple * PI) * 0.32))
		&"rubble_silo":
			var gust: float = fmod(phase * 0.75, 1.0)
			_box(61.0 + roundf(gust * 13.0), 8.0, 3.0, 1.0, Color(1.0, 0.85, 0.59, sin(gust * PI) * 0.65))
		&"rubble_bunker":
			if not GameState.raw_fossil_queue.is_empty():
				_draw_glint(Vector2(44, 13), 0.5)

	if level >= 2:
		_draw_supply_crate(Vector2(71.0 if station != &"rubble_silo" else 57.0, 53.0))


func _draw_supply_crate(pos: Vector2) -> void:
	_box(pos.x, pos.y, 8.0, 5.0, INK)
	_box(pos.x + 1.0, pos.y, 6.0, 1.0, CREAM)
	_box(pos.x + 1.0, pos.y + 1.0, 6.0, 3.0, TIMBER)
	_box(pos.x + 3.0, pos.y + 2.0, 2.0, 2.0, WOOD)


func _draw_glint(at: Vector2, offset: float) -> void:
	var strength: float = pow(maxf(sin(phase * 3.0 + offset), 0.0), 4.0)
	var sparkle: Color = Color(1.0, 0.91, 0.64, strength)
	_box(at.x - 1.5, at.y, 4.0, 1.0, sparkle)
	_box(at.x, at.y - 1.5, 1.0, 4.0, sparkle)


func _draw_fossil_badge(flash_left: float) -> void:
	var progress: float = 1.0 - clampf(flash_left / GameState.STATION_FOSSIL_FLASH_DURATION, 0.0, 1.0)
	var alpha: float = clampf(flash_left / 0.85, 0.0, 1.0)
	var float_y: float = -progress * 8.0 - absf(sin(phase * 6.0)) * 2.0
	var bx: float = 31.0
	var by: float = 2.0 + float_y
	# Brilho dourado pulsante em torno do quadrado de terra com fósseis.
	var glow_col: Color = Color(1.0, 0.86, 0.28, alpha * (0.42 + 0.22 * sin(phase * 10.0)))
	draw_circle(Vector2(bx + 11.0, by + 11.0), 15.0 + sin(phase * 8.0) * 1.5, glow_col)
	_box(bx - 2, by - 2, 26, 26, Color(1.0, 0.84, 0.24, alpha * 0.95))
	_box(bx, by, 22, 22, Color(0.18, 0.11, 0.07, alpha))
	_box(bx + 2, by + 2, 18, 18, Color(0.50, 0.31, 0.18, alpha))
	# Ossos fossilizados dentro do quadrado de terra.
	var bone_col: Color = Color(0.98, 0.93, 0.80, alpha)
	_box(bx + 5, by + 9, 12, 3, bone_col)
	_box(bx + 4, by + 8, 3, 2, bone_col)
	_box(bx + 4, by + 11, 3, 2, bone_col)
	_box(bx + 15, by + 8, 3, 2, bone_col)
	_box(bx + 15, by + 11, 3, 2, bone_col)
	_box(bx + 8, by + 5, 6, 3, Color(0.99, 0.88, 0.54, alpha))
