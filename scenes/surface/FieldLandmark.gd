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
const STONE: Color = Color("#9c8578")
const STONE_LIGHT: Color = Color("#c2a693")
const CAPTION_BUILT_COLOR: Color = Color("#fff1ce")
const CAPTION_UNBUILT_COLOR: Color = Color("#d8cbb8")

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
	pulse = maxf(0.0, pulse - delta * 3.0)
	var frame: int = floori(phase * 30.0)
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
		if GameState.is_station_built(station) and GameState.has_station_worker(station):
			var def: Dictionary = GameState.RUBBLE_DEFS[station] as Dictionary
			var gear_id: StringName = def["gear"] as StringName
			_worker(GameState.get_upgrade_level(gear_id) > 0, origin, factor)
		var revived: int = GameState.get_station_revived_count(station)
		if revived > 0:
			_revived_dino_worker(revived)
		var flash_left: float = GameState.get_station_fossil_flash(station)
		if flash_left > 0.0:
			_draw_fossil_badge(flash_left)
	if selected or has_focus() or is_hovered():
		_box(15, 60, 54, 2, AMBER if selected else INK)
		_box(36, 61, 12, 2, CREAM)


func _box(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)


func _nest() -> void:
	_box(22, 53, 39, 4, WOOD)
	_box(26, 50, 30, 3, TIMBER)
	if GameState.orange_rock_broken:
		# Cascas abertas do ovo de âmbar após o protagonista despertar e caminhar pela bacia.
		_box(28, 43, 10, 7, INK)
		_box(29, 44, 8, 6, AMBER)
		_box(30, 45, 3, 2, CREAM)
		_box(43, 45, 11, 6, INK)
		_box(44, 46, 9, 4, Color("#d87d3b"))
		_box(48, 44, 4, 3, AMBER)
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
	if level <= 0:
		_quarry_unbuilt()
		return
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
	if GameState.get_upgrade_level(&"tools_diamond_chisel") > 0:
		_box(6, 51, 5, 5, INK)
		_box(7, 52, 3, 3, Color("#6fe8ff"))
	if GameState.get_upgrade_level(&"tools_metal_pick") > 0 or GameState.get_station_revived_count(&"rubble_forge") > 0:
		_box(68, 52, 9, 4, INK)
		_box(69, 53, 7, 2, Color("#9bb0c4"))
		_box(71, 50, 5, 3, Color("#cddbe8"))
	if level > 0:
		_box(46, 16, 3, 35, WOOD)
		_box(43, 16, 20, 3, TIMBER)
		var rope_len: int = 14 + roundi((sin(phase * 2.6) + 1.0) * 3.0)
		_box(60, 19, 1, rope_len, INK)
		_box(57, 19 + rope_len - 1, 7, 5, AMBER)
		if level >= 2:
			var cart_x: float = 16.0 + roundf((sin(phase * 1.6) + 1.0) * 8.0)
			_box(cart_x, 51, 9, 5, INK)
			_box(cart_x + 1, 52, 7, 3, TIMBER)
			_box(cart_x + 2, 50, 5, 2, AMBER)
		if sin(phase * 3.2) > 0.78:
			_box(69, 37, 2, 2, CREAM)
			_box(72, 42, 3, 2, TIMBER)


func _quarry_unbuilt() -> void:
	# Pequeno monte de rochas soltas e estacas de marcação antes da Pedreira existir.
	_box(20, 48, 38, 9, INK)
	_box(25, 43, 26, 9, INK)
	_box(31, 39, 14, 7, INK)
	_box(22, 49, 34, 7, Color("#795565"))
	_box(26, 44, 24, 7, Color("#946666"))
	_box(32, 40, 12, 5, Color("#ad7669"))
	_box(34, 41, 6, 2, Color("#c68c73"))
	_box(29, 47, 5, 1, CREAM)
	_box(43, 50, 4, 1, CREAM)
	# Pedregulhos espalhados nas bordas.
	_box(12, 53, 6, 4, INK)
	_box(13, 54, 4, 2, Color("#946666"))
	_box(61, 52, 7, 5, INK)
	_box(62, 53, 5, 3, Color("#ad7669"))
	# Estacas de madeira e corda de demarcação do terreno.
	_box(16, 45, 2, 12, WOOD)
	_box(16, 44, 2, 2, TIMBER)
	_box(66, 45, 2, 12, WOOD)
	_box(66, 44, 2, 2, TIMBER)
	_box(18, 47, 10, 1, CREAM)
	_box(54, 47, 12, 1, CREAM)
	_box(48, 48, 2, 9, WOOD)
	_box(48, 47, 2, 2, TIMBER)


func _lake(level: int) -> void:
	if level <= 0:
		_lake_unbuilt()
		return
	_box(5, 47, 73, 8, WATER)
	_box(12, 43, 53, 13, TEAL)
	_box(17, 42, 35, 2, Color("#9ac9af"))
	_box(10, 55, 58, 2, WATER)
	_box(17, 57, 43, 1, TEAL)
	var slow_frame: int = maxi(_frame / 3, 0)
	for i: int in range(5):
		_box(13 + i*11, 48 + (i + slow_frame / 4) % 4, 6, 1, Color("#b6ddbf"))
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
	if GameState.get_upgrade_level(&"dinos_scale_armor") > 0 or GameState.get_station_revived_count(&"rubble_nest") > 0:
		_box(44, 34, 6, 7, INK)
		_box(45, 35, 4, 5, Color("#56d694"))
		_box(46, 36, 2, 2, CREAM)
	if level > 0:
		_box(62, 24, 2, 16, WOOD)
		_box(54, 22, 20, 3, INK)
		_box(57, 19, 15, 4, Color("#d77755"))
		_box(60, 17, 9, 3, AMBER)
		_box(65, 35, 5, 5, TIMBER)
		var lantern_bob: float = roundf(sin(phase * 4.0))
		_box(51, 35 + lantern_bob, 3, 4, AMBER)
		if sin(phase * 3.2) < -0.5:
			_box(43, 42, 4, 2, CREAM)
			_box(47, 41, 1, 2, AMBER)


func _lake_unbuilt() -> void:
	# Bacia rasa lamacenta com pequena poça, juncos e estacas de obra (sem píer, guarda-sol ou lanterna).
	var anim_f: int = maxi(_frame / 3, 0)
	_box(11, 49, 62, 8, Color("#8c6252"))
	_box(15, 47, 52, 9, Color("#785249"))
	_box(18, 55, 46, 2, Color("#6b4942"))
	# Pequena poça rasa de água parada no centro da depressão.
	_box(22, 50, 34, 5, WATER)
	_box(26, 49, 24, 4, TEAL)
	_box(28 + (anim_f / 5) % 4, 50, 5, 1, Color("#b6ddbf"))
	_box(41 - (anim_f / 6) % 3, 52, 4, 1, Color("#9ac9af"))
	# Juncos silvestres na margem esquerda e direita.
	for i: int in range(4):
		_box(11 + i * 3, 42 - (i % 2) * 3, 1, 9, MOSS)
		_box(11 + i * 3, 39 - (i % 2) * 3, 2, 3, WOOD)
	for i: int in range(2):
		_box(66 + i * 3, 44 - i * 2, 1, 8, MOSS)
		_box(66 + i * 3, 42 - i * 2, 2, 2, WOOD)
	# Estacas de construção e tábuas empilhadas no chão marcando o futuro píer.
	_box(54, 43, 2, 13, WOOD)
	_box(54, 42, 2, 2, TIMBER)
	_box(69, 44, 2, 12, WOOD)
	_box(69, 43, 2, 2, TIMBER)
	_box(56, 46, 13, 1, CREAM)
	_box(57, 53, 10, 3, INK)
	_box(58, 53, 8, 2, TIMBER)
	_box(59, 51, 7, 2, WOOD)


func _tower(level: int) -> void:
	if level <= 0:
		_tower_unbuilt()
		return
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
	var slow_f: int = maxi(_frame / 3, 0)
	if GameState.get_upgrade_level(&"dinos_sky_scouts") > 0:
		# Poleiro e flâmula dos Batedores das Dunas junto à torre.
		_box(64, 34, 2, 21, WOOD)
		_box(60, 34, 10, 2, TIMBER)
		_box(66, 36, 7 + slow_f % 2, 4, AMBER)
		_box(67, 37, 4, 2, CREAM)
	if GameState.get_upgrade_level(&"dinos_beak_talons") > 0 or GameState.get_station_revived_count(&"rubble_silo") > 0:
		_box(13, 48, 9, 7, INK)
		_box(14, 49, 7, 5, TIMBER)
		_box(15, 47, 2, 3, CREAM)
		_box(19, 47, 2, 3, AMBER)
	_box(42, 9, 12, 4, Color("#df825a"))
	_box(53, 11, 5, 3, AMBER)
	if level > 0:
		_box(22, 19, 38, 3, WOOD)
		for i: int in range(5):
			_box(24+i*8, 19, 2, 7, TIMBER)
		var vane_w: int = 4 + ((slow_f / 2) % 6)
		_box(36, 2, 9, 3, TEAL)
		_box(40, 0, 2, 10, TEAL)
		_box(41 - vane_w / 2, 1, vane_w, 2, CREAM)


func _tower_unbuilt() -> void:
	# Sapatas de fundação de pedra, vigas de madeira caídas e rolos de corda no chão (sem torre alta).
	_box(20, 51, 14, 6, INK)
	_box(21, 52, 12, 4, STONE)
	_box(22, 52, 10, 1, STONE_LIGHT)
	_box(46, 51, 14, 6, INK)
	_box(47, 52, 12, 4, STONE)
	_box(48, 52, 10, 1, STONE_LIGHT)
	# Vigas de madeira empilhadas e espalhadas sobre o solo.
	_box(25, 47, 24, 4, INK)
	_box(26, 48, 22, 2, TIMBER)
	_box(30, 44, 18, 4, INK)
	_box(31, 45, 16, 2, WOOD)
	_box(32, 45, 14, 1, TIMBER)
	_box(16, 54, 10, 3, WOOD)
	_box(17, 54, 8, 1, TIMBER)
	# Rolo de corda enrolado no canto direito.
	_box(62, 50, 9, 6, INK)
	_box(63, 51, 7, 4, AMBER)
	_box(65, 52, 3, 2, WOOD)
	_box(64, 51, 5, 1, CREAM)
	# Estaca baixa com fitinha de vento para sinalizar o terreno.
	var anim_f: int = maxi(_frame / 3, 0)
	_box(13, 45, 2, 11, WOOD)
	_box(15, 45, 4 + (anim_f % 2), 2, Color("#df825a"))
	_box(15, 47, 3, 1, AMBER)


func _college(level: int) -> void:
	if level <= 0:
		_college_unbuilt()
		return
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
	var slow_f: int = maxi(_frame / 3, 0)
	if GameState.get_upgrade_level(&"uni_fossil_luck") > 0 or GameState.get_upgrade_level(&"uni_clean_double") > 0:
		_box(7, 42, 6, 13, WOOD)
		_box(8, 37, 4, 5, INK)
		_box(9, 38, 2, 3, Color("#ffd54f") if (slow_f % 4) < 2 else CREAM)
	for i: int in range(2):
		_box(23+i*30, 36, 6, 8, INK)
		var win_col: Color = CREAM if (not GameState.raw_fossil_queue.is_empty() and (slow_f % 4) < 2) else (AMBER if level > 0 else MOSS)
		_box(24+i*30, 37, 3, 4, win_col)
	_box(32, 53, 20, 3, TIMBER)
	if level > 0:
		_box(48, 12, 3, 8, WOOD)
		_box(45, 10, 10, 4, INK)
		_box(53, 8, 5, 5, TEAL)
		_box(56, 8, 2, 4, CREAM)
		for book: int in range(3):
			_box(65, 51 - book*3, 7 - book, 2, TEAL if book % 2 == 0 else CREAM)
		# Bancada externa de limpeza de fósseis brutos (escova se move quando há fila ou upgrade).
		_box(56, 48, 12, 3, TIMBER)
		_box(58, 51, 2, 5, WOOD)
		_box(64, 51, 2, 5, WOOD)
		if not GameState.raw_fossil_queue.is_empty() or GameState.get_upgrade_level(&"uni_cleaning_speed") > 0:
			var scrub_x: float = 58.0 + roundf((sin(phase * 8.0) + 1.0) * 3.0)
			_box(scrub_x, 45, 5, 3, CREAM)
			_box(scrub_x + 1, 44, 3, 1, AMBER)


func _college_unbuilt() -> void:
	# Alicerce de pedra delineado no chão, caixotes, planta enrolada e placa de obra (sem prédio da Universidade).
	_box(15, 51, 54, 6, INK)
	_box(16, 52, 52, 4, STONE)
	_box(19, 53, 46, 3, Color("#a67a63"))
	_box(17, 52, 14, 1, STONE_LIGHT)
	_box(53, 52, 14, 1, STONE_LIGHT)
	_box(34, 54, 16, 3, STONE_LIGHT)
	_box(36, 55, 12, 2, STONE)
	# Caixotes de expedição empilhados à esquerda.
	_box(18, 45, 12, 9, INK)
	_box(19, 46, 10, 7, WOOD)
	_box(20, 47, 8, 5, TIMBER)
	_box(19, 49, 10, 1, WOOD)
	_box(23, 46, 2, 7, WOOD)
	_box(22, 41, 8, 5, INK)
	_box(23, 42, 6, 3, TIMBER)
	_box(25, 42, 2, 3, AMBER)
	# Planta arquitetônica (blueprint) enrolada no chão.
	_box(35, 48, 15, 5, INK)
	_box(36, 49, 13, 3, TEAL)
	_box(37, 49, 11, 1, CREAM)
	_box(42, 48, 2, 5, AMBER)
	# Placa de obra / marco da futura Universidade à direita.
	_box(60, 44, 2, 11, WOOD)
	_box(55, 39, 12, 7, INK)
	_box(56, 40, 10, 5, TIMBER)
	_box(57, 41, 8, 1, CREAM)
	_box(57, 43, 5, 1, TEAL)


func _worker(equipped: bool, canvas_origin: Vector2, canvas_factor: float) -> void:
	if station == &"rubble_forge":
		var pachy_tex: Texture2D = AmberTheme.get_dino_sprite(&"pachycephalosaurus")
		if pachy_tex != null:
			_draw_pachy_miner(pachy_tex, equipped, canvas_origin, canvas_factor)
			return
	elif station == &"rubble_silo":
		var ptero_tex: Texture2D = AmberTheme.get_dino_sprite(&"pterodactyl")
		if ptero_tex != null:
			_draw_ptero_scout(ptero_tex, equipped, canvas_origin, canvas_factor)
			return
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


func _draw_pachy_miner(tex: Texture2D, equipped: bool, canvas_origin: Vector2, canvas_factor: float) -> void:
	var tex_sz: Vector2 = tex.get_size()
	var draw_w: float = 28.0
	var draw_h: float = draw_w * (tex_sz.y / maxf(tex_sz.x, 1.0))
	var cycle: float = fmod(phase * 1.15, 1.0)
	var dx: float = 0.0
	var rot: float = 0.0
	var sx: float = 1.0
	var sy: float = 1.0
	var impact_strength: float = 0.0

	if cycle < 0.38:
		var t: float = cycle / 0.38
		var wind: float = sin(t * PI * 0.5)
		dx = wind * 4.0
		rot = wind * 0.14
		sx = 1.0 - wind * 0.06
		sy = 1.0 + wind * 0.05
	elif cycle < 0.52:
		var t: float = (cycle - 0.38) / 0.14
		var slam: float = sin(t * PI * 0.5)
		dx = lerpf(4.0, -6.0, slam)
		rot = lerpf(0.14, -0.26, slam)
		sx = 1.0 + 0.14 * slam
		sy = 1.0 - 0.12 * slam
	else:
		var t: float = (cycle - 0.52) / 0.48
		var rec: float = pow(1.0 - t, 2.0)
		dx = -6.0 * rec
		rot = -0.26 * rec + sin(phase * 3.0) * 0.02 * (1.0 - rec)
		sx = 1.0 + 0.08 * rec
		sy = 1.0 - 0.06 * rec

	if cycle >= 0.48 and cycle <= 0.72:
		impact_strength = clampf(1.0 - absf(cycle - 0.56) / 0.16, 0.0, 1.0)

	var px: float = 69.0 + dx
	var py: float = 57.0
	_box(px - 10.0, 56.0, 20.0, 2.0, Color(0.12, 0.09, 0.08, 0.35))
	draw_set_transform(canvas_origin + Vector2(px, py) * canvas_factor, rot, Vector2(-sx, sy) * canvas_factor)
	draw_texture_rect(tex, Rect2(-draw_w * 0.5, -draw_h, draw_w, draw_h), false)
	draw_set_transform(canvas_origin, 0.0, Vector2.ONE * canvas_factor)

	if equipped:
		var crest_x: float = px - 7.0
		var crest_y: float = py - draw_h + 2.0
		_box(crest_x, crest_y, 5.0, 2.0, AMBER)
		_box(crest_x + 1.0, crest_y - 1.0, 3.0, 1.0, CREAM)

	if impact_strength > 0.05:
		var hit_x: float = 54.0
		var hit_y: float = 43.0
		var burst_t: float = clampf((cycle - 0.48) / 0.24, 0.0, 1.0)
		var spark_c: Color = Color(CREAM.r, CREAM.g, CREAM.b, impact_strength)
		var stone_c: Color = Color("#c68c73")
		stone_c.a = impact_strength
		var amber_c: Color = Color(AMBER.r, AMBER.g, AMBER.b, impact_strength)
		draw_rect(Rect2(hit_x - 2.0, hit_y - 2.0, 4.0, 4.0), amber_c if equipped else spark_c)
		draw_rect(Rect2(hit_x - 3.0 - burst_t * 6.0, hit_y - 2.0 - burst_t * 5.0, 2.0, 2.0), spark_c)
		draw_rect(Rect2(hit_x - 1.0 - burst_t * 4.0, hit_y + 1.0 + burst_t * 4.0, 2.0, 2.0), stone_c)
		draw_rect(Rect2(hit_x + 1.0 + burst_t * 3.0, hit_y - 3.0 - burst_t * 6.0, 2.0, 2.0), amber_c if equipped else stone_c)


func _draw_ptero_scout(tex: Texture2D, equipped: bool, canvas_origin: Vector2, canvas_factor: float) -> void:
	var tex_sz: Vector2 = tex.get_size()
	var draw_w: float = 26.0
	var draw_h: float = draw_w * (tex_sz.y / maxf(tex_sz.x, 1.0))
	var fx: float = 41.0 + sin(phase * 1.45) * 25.0
	var fy: float = 15.0 + sin(phase * 2.9) * 5.0
	var vx: float = cos(phase * 1.45)
	var dir: float = 1.0 if vx >= 0.0 else -1.0
	var flap: float = sin(phase * 8.5)
	var sx: float = 1.0 - flap * 0.05
	var sy: float = 1.0 + flap * 0.16
	var rot: float = dir * (cos(phase * 2.9) * 0.16 + flap * 0.05)

	# Sombra suave no chão acompanhando a patrulha aérea e rastros de vento.
	_box(fx - 5.0, 56.0, 10.0, 2.0, Color(0.12, 0.09, 0.08, 0.20))
	for s_i: int in range(2):
		var streak_x: float = fx - dir * (11.0 + float(s_i) * 5.0)
		var streak_y: float = fy + float(s_i) * 3.0 - 2.0
		_box(streak_x, streak_y, 4.0, 1.0, Color(CREAM.r, CREAM.g, CREAM.b, 0.45 - float(s_i) * 0.15))

	# Pena solta planando em direção à torre.
	var feather_t: float = fmod(phase * 0.55, 1.0)
	var feather_x: float = 41.0 + sin(phase * 3.0) * 8.0 - feather_t * 4.0
	var feather_y: float = lerpf(18.0, 44.0, feather_t)
	_box(feather_x, feather_y, 2.0, 1.0, Color(CREAM.r, CREAM.g, CREAM.b, 1.0 - feather_t))

	draw_set_transform(canvas_origin + Vector2(fx, fy) * canvas_factor, rot, Vector2(dir * sx, sy) * canvas_factor)
	draw_texture_rect(tex, Rect2(-draw_w * 0.5, -draw_h * 0.5, draw_w, draw_h), false)
	draw_set_transform(canvas_origin, 0.0, Vector2.ONE * canvas_factor)

	if equipped:
		var glint_col: Color = Color(TEAL.r, TEAL.g, TEAL.b, 0.90)
		_box(fx + dir * 4.0, fy - 3.0, 2.0, 2.0, glint_col)
		_box(fx + dir * 6.0, fy - 4.0, 2.0, 1.0, CREAM)


func _revived_dino_worker(_revived_level: int) -> void:
	var beat: float = sin(phase * 4.4)
	match station:
		&"rubble_forge":
			# Anquilossauro blindado golpeando a rocha com a clava da cauda para gerar Metal.
			var ax: float = 20.0 + roundf(beat * 2.0)
			var ay: float = 48.0
			_box(ax - 7, ay, 13, 6, INK)
			_box(ax - 6, ay + 1, 11, 4, Color("#60737f"))
			_box(ax - 4, ay - 1, 3, 2, AMBER)
			_box(ax, ay - 1, 3, 2, AMBER)
			_box(ax + 5, ay + 1, 5, 4, Color("#788f9c"))
			_box(ax + 8, ay + 2, 1, 1, INK)
			var club_y: float = ay + 2.0 - roundf(maxf(beat, 0.0) * 4.0)
			_box(ax - 12, club_y, 5, 2, Color("#788f9c"))
			_box(ax - 15, club_y - 1, 4, 4, INK)
			_box(ax - 14, club_y, 2, 2, Color("#cddbe8"))
		&"rubble_nest":
			# Dilofossauro com crista dupla e gola vibrante pescando Escamas no lago.
			var dx: float = 34.0 + roundf(sin(phase * 2.4) * 9.0)
			var dy: float = 43.0 + roundf(absf(beat) * 2.0)
			_box(dx - 8, dy + 2, 11, 4, INK)
			_box(dx - 7, dy + 2, 9, 3, Color("#2f9c88"))
			_box(dx + 1, dy - 4, 4, 6, Color("#2f9c88"))
			_box(dx + 2, dy - 7, 6, 4, Color("#3eb89f"))
			_box(dx + 2, dy - 9, 5, 2, Color("#e85d3f"))
			_box(dx + 4, dy - 10, 2, 2, AMBER)
			_box(dx, dy - 5, 2, 5, Color("#f2a649"))
			_box(dx + 6, dy - 6, 1, 1, INK)
		&"rubble_silo":
			# Velociraptor emplumado saltando nos degraus da torre caçando Bicos de Ave.
			var vx: float = 52.0 + roundf(cos(phase * 3.8) * 6.0)
			var vy: float = 24.0 - roundf(absf(beat) * 5.0)
			_box(vx - 8, vy + 2, 7, 2, Color("#cf5338"))
			_box(vx - 3, vy + 1, 9, 4, INK)
			_box(vx - 2, vy + 1, 8, 3, Color("#e66a42"))
			_box(vx + 3, vy - 4, 6, 4, Color("#e66a42"))
			_box(vx + 4, vy - 5, 4, 2, AMBER)
			_box(vx + 7, vy - 3, 1, 1, INK)
			_box(vx + 2, vy + 5, 2, 3, CREAM)
		&"rubble_bunker":
			# Braquiossauro majestoso com pescoço longo supervisionando a Universidade.
			var bx: float = 70.0
			var by: float = 42.0
			var sway: float = roundf(sin(phase * 1.8) * 2.0)
			_box(bx - 6, by + 4, 13, 7, INK)
			_box(bx - 5, by + 5, 11, 5, Color("#49a892"))
			_box(bx - 4, by + 11, 3, 4, Color("#388574"))
			_box(bx + 2, by + 11, 3, 4, Color("#388574"))
			_box(bx + 2 + sway * 0.5, by - 10, 4, 16, Color("#49a892"))
			_box(bx + 2 + sway, by - 14, 7, 4, Color("#60c9ad"))
			_box(bx + 3 + sway, by - 15, 3, 2, AMBER)
			_box(bx + 7 + sway, by - 13, 1, 1, INK)


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
