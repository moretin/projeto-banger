class_name FieldLandmark
extends Button
## O alvo de interação cobre a própria construção. A placa acompanha o desenho.

const INK: Color = Color("#302d38")
const WOOD: Color = Color("#815446")
const TIMBER: Color = Color("#c38459")
const CREAM: Color = Color("#ffdf9f")
const MOSS: Color = Color("#567866")
const TEAL: Color = Color("#589d95")
const WATER: Color = Color("#38757c")
const AMBER: Color = Color("#edaa48")

var station: StringName
var selected: bool = false
var phase: float = 0.0
var _frame: int = -1
var pulse: float = 0.0
var _caption: Label


func _ready() -> void:
	flat = true
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
	_caption.add_theme_color_override("font_color", Color("#fff1ce"))
	_caption.add_theme_color_override("font_outline_color", INK)
	_caption.add_theme_constant_override("outline_size", 6)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	refresh()


func refresh() -> void:
	if station == &"egg":
		_caption.text = "Compsognato" if GameState.orange_rock_broken else "Ovo de âmbar · %d/%d" % [ceili(GameState.orange_rock_hp), int(GameState.ORANGE_ROCK_MAX_HP)]
	else:
		_caption.text = GameState.RUBBLE_DEFS[station]["title"]
	tooltip_text = _caption.text
	accessibility_name = _caption.text
	queue_redraw()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	phase += delta
	pulse = maxf(0, pulse - delta * 3.0)
	var frame: int = floori(phase * 10.0)
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
	_box(7, 57, 70, 3, Color("#a47961"))
	if station == &"egg":
		_nest()
	else:
		var level: int = GameState.get_rubble_level(station)
		match station:
			&"rubble_forge": _quarry(level)
			&"rubble_nest": _lake(level)
			&"rubble_silo": _tower(level)
			&"rubble_bunker": _college(level)
		if level > 0:
			_worker(GameState.get_upgrade_level(GameState.RUBBLE_DEFS[station]["gear"]) > 0)
	if selected or has_focus() or is_hovered():
		_box(17, 60, 50, 1, INK)
		_box(38, 61, 8, 1, CREAM)


func _box(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)


func _nest() -> void:
	_box(22, 53, 39, 4, WOOD)
	_box(26, 50, 30, 3, TIMBER)
	if GameState.orange_rock_broken:
		var hop: float = roundf(absf(sin(phase * 3)) * 2)
		draw_texture_rect(AmberTheme.get_dino_sprite(&"compsognathus"), Rect2(21, 16-hop, 42, 39), false)
		return
	_box(30, 30, 22, 18, INK)
	_box(33, 24, 16, 27, INK)
	_box(36, 21, 10, 4, INK)
	_box(32, 31, 18, 16, Color("#d87d3b"))
	_box(35, 25, 12, 23, AMBER)
	_box(36, 27, 3, 7, CREAM)
	_box(39, 37, 7, 5, WOOD)
	if GameState.orange_rock_hp < 7:
		_box(43, 25, 2, 7, WOOD)
		_box(41, 31, 3, 2, WOOD)
	if GameState.orange_rock_hp < 4:
		_box(40, 32, 2, 6, WOOD)


func _quarry(level: int) -> void:
	_box(9, 43, 60, 13, INK)
	_box(15, 33, 46, 14, INK)
	_box(20, 24, 34, 16, INK)
	_box(27, 17, 20, 12, INK)
	_box(28, 19, 17, 9, Color("#c68c73"))
	_box(22, 26, 29, 11, Color("#ad7669"))
	_box(16, 35, 43, 11, Color("#946666"))
	_box(11, 45, 56, 9, Color("#795565"))
	draw_colored_polygon(PackedVector2Array([Vector2(28,20),Vector2(39,20),Vector2(34,27),Vector2(23,31)]), Color("#dda184"))
	draw_colored_polygon(PackedVector2Array([Vector2(39,26),Vector2(49,26),Vector2(51,35),Vector2(45,35)]), Color("#8f6264"))
	_box(26, 33, 14, 1, Color("#da9878"))
	_box(35, 45, 21, 1, Color("#a9766b"))
	for i: int in range(5):
		_box(24+i*6, 41-i%3*5, 4, 1, CREAM)
	_box(16, 40, 3, 15, TIMBER)
	_box(29, 40, 3, 15, TIMBER)
	_box(14, 39, 20, 3, WOOD)
	_box(20, 42, 8, 12, INK)
	if GameState.get_upgrade_level(&"tools_sharp_pickaxe") > 0:
		for i: int in range(6):
			_box(8+i, 49-i, 2, 2, TIMBER)
		_box(10, 42, 8, 2, INK)
		_box(15, 43, 4, 2, CREAM)
	if level > 0:
		_box(46, 16, 3, 35, WOOD)
		_box(43, 16, 20, 3, TIMBER)
		_box(60, 19, 1, 17, INK)
		_box(57, 35, 7, 5, AMBER)
		if sin(phase * 3.2) > 0.78:
			_box(69, 37, 2, 2, CREAM)
			_box(72, 42, 3, 2, TIMBER)


func _lake(level: int) -> void:
	_box(5, 47, 73, 8, WATER)
	_box(12, 43, 53, 13, TEAL)
	_box(17, 42, 35, 2, Color("#9ac9af"))
	_box(10, 55, 58, 2, WATER)
	_box(17, 57, 43, 1, TEAL)
	for i: int in range(5):
		_box(13 + i*11, 48 + (i + _frame / 4) % 4, 6, 1, Color("#b6ddbf"))
	for i: int in range(5):
		_box(8+i*2, 39-i%3*2, 1, 9, MOSS)
		_box(8+i*2, 36-i%3*2, 2, 4, WOOD)
	_box(50, 40, 23, 3, WOOD)
	_box(53, 43, 2, 11, WOOD)
	_box(68, 43, 2, 11, WOOD)
	for plank: int in range(4):
		_box(51 + plank*5, 39, 4, 1, TIMBER)
	if GameState.get_upgrade_level(&"dinos_pack_instinct") > 0:
		_box(69, 48, 9, 4, WOOD)
		_box(70, 45, 3, 4, CREAM)
		_box(74, 44, 3, 5, AMBER)
	if level > 0:
		_box(62, 24, 2, 16, WOOD)
		_box(54, 22, 20, 3, INK)
		_box(57, 19, 15, 4, Color("#d77755"))
		_box(60, 17, 9, 3, AMBER)
		_box(65, 35, 5, 5, TIMBER)
		if sin(phase * 3.2) < -0.5:
			_box(43, 42, 4, 2, CREAM)
			_box(47, 41, 1, 2, AMBER)


func _tower(level: int) -> void:
	_box(27, 29, 4, 27, WOOD)
	_box(49, 29, 4, 27, WOOD)
	_box(22, 53, 12, 3, INK)
	_box(46, 53, 12, 3, INK)
	for i: int in range(7):
		_box(30 + i*3, 31+i*3, 4, 3, TIMBER)
		_box(49 - i*3, 31+i*3, 4, 3, TIMBER)
	_box(23, 26, 35, 5, INK)
	_box(24, 25, 33, 2, CREAM)
	_box(40, 9, 2, 16, WOOD)
	_box(56, 32, 1, 23, WOOD)
	_box(60, 32, 1, 23, WOOD)
	for rung: int in range(6):
		_box(56, 32 + rung*4, 5, 1, TIMBER)
	if GameState.get_upgrade_level(&"machines_pneumatic_drill") > 0:
		_box(62, 38, 8, 5, INK)
		_box(64, 35, 4, 4, AMBER)
		_box(65, 43, 2, 9 + _frame % 3, INK)
		_box(62, 54, 8, 1, TIMBER)
	_box(42, 9, 12, 4, Color("#df825a"))
	_box(53, 11, 5, 3, AMBER)
	if level > 0:
		_box(22, 19, 38, 3, WOOD)
		for i: int in range(5):
			_box(24+i*8, 19, 2, 7, TIMBER)
		_box(36, 2, 9, 3, TEAL)
		_box(40, 0, 2, 10, TEAL)


func _college(level: int) -> void:
	_box(17, 32, 50, 23, INK)
	_box(19, 32, 46, 20, Color("#d69a75"))
	_box(14, 29, 55, 4, WOOD)
	_box(18, 25, 46, 5, TEAL)
	_box(24, 20, 34, 5, WATER)
	_box(30, 16, 22, 4, WATER)
	_box(36, 14, 10, 2, TEAL)
	_box(36, 37, 11, 17, WOOD)
	_box(38, 39, 7, 15, INK)
	_box(40, 18, 2, 2, CREAM)
	for column: int in range(4):
		_box(18 + column*15, 33, 2, 19, TIMBER)
	for tile: int in range(6):
		_box(21 + tile*7, 26, 5, 1, MOSS)
	if GameState.get_upgrade_level(&"defense_reinforced_bunker") > 0:
		for block: int in range(4):
			_box(11 + block*4, 50 + block%2, 4, 4, Color("#687987"))
	if GameState.get_upgrade_level(&"amber_ark_project") > 0:
		_box(36, 7, 8, 7, INK)
		_box(38, 5, 4, 8, AMBER)
		_box(38, 6, 2, 3, CREAM)
	for i: int in range(2):
		_box(23+i*30, 36, 6, 8, INK)
		_box(24+i*30, 37, 3, 4, AMBER if level > 0 else MOSS)
	_box(32, 53, 20, 3, TIMBER)
	if level > 0:
		_box(48, 12, 3, 8, WOOD)
		_box(45, 10, 10, 4, INK)
		_box(53, 8, 5, 5, TEAL)
		_box(56, 8, 2, 4, CREAM)
		for book: int in range(3):
			_box(65, 51 - book*3, 7 - book, 2, TEAL if book % 2 == 0 else CREAM)


func _worker(equipped: bool) -> void:
	var beat: float = sin(phase * 3.2)
	var x: float = 58 + roundf(beat * 4)
	var y: float = 49
	var skin: Color = Color("#cf9376")
	if station == &"rubble_silo":
		x = 17 + roundf(sin(phase * 1.7) * 12)
		y = 12 + roundf(beat * 4)
		_box(x-4, y-2, 10, 5, INK)
		_box(x-2, y-2, 7, 3, AMBER)
		_box(x+2, y-5, 6, 4, INK)
		_box(x+4, y-5, 3, 2, Color("#e9a56f"))
		_box(x+7, y-3, 6, 2, CREAM)
		for i: int in range(4):
			_box(x-1-i*3, y-2-i*roundf(beat*1.8), 5, 4-i*0.6, INK)
			_box(x-i*3, y-2-i*roundf(beat*1.8), 3, 2, Color("#df805b"))
		if equipped:
			_box(x+5, y-4, 2, 2, TEAL)
		return
	if station == &"rubble_nest":
		x = 26 + roundf(beat * 6)
		y = 39 + roundf(maxf(beat, 0) * 5)
		skin = Color("#da9767")
	elif station == &"rubble_bunker":
		x = 17 + roundf(beat * 2)
		skin = Color("#936886")
	_box(x-12, y, 5, 2, INK)
	_box(x-10, y+1, 8, 2, skin)
	_box(x-6, y+2, 13, 5, INK)
	_box(x-6, y+1, 12, 4, skin)
	_box(x+2, y-3, 4, 6, skin)
	_box(x+4, y-6, 7, 5, skin)
	_box(x+4, y-7, 6, 1, INK)
	_box(x+7, y-2, 4, 1, CREAM)
	_box(x+8, y-5, 1, 1, INK)
	_box(x-4+roundf(beat), y+6, 2, 3, INK)
	_box(x+3-roundf(beat), y+6, 2, 3, INK)
	match station:
		&"rubble_forge":
			_box(x+3, y-8, 6, 3, AMBER if equipped else CREAM)
			if equipped:
				_box(x+2, y-6, 10, 2, INK)
		&"rubble_nest":
			_box(x+9, y-4, 8, 3, INK)
			_box(x+9, y-4, 7, 2, skin)
			_box(x-4, y, 4, 2, CREAM)
			if equipped:
				_box(x-8, y+8, 6, 2, AMBER)
				_box(x+1, y+8, 6, 2, AMBER)
		&"rubble_bunker":
			_box(x+7, y+3, 9, 4, INK)
			_box(x+8, y+3, 3, 2, CREAM)
			_box(x+12, y+2, 3, 3, CREAM)
			if equipped:
				_box(x+9, y-5, 3, 3, TEAL)
