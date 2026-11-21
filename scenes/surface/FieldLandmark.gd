class_name FieldLandmark
extends Button
## O alvo de interação cobre a própria construção. A placa acompanha o desenho.

const INK: Color = Color("#302d38")
const DARK_INK: Color = Color("#261820")
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
const PROCEDURAL_STATIONS: Array[StringName] = [
	&"forest_grove",
	&"forest_sanctuary",
	&"snow_glacier",
	&"snow_observatory",
]

var station: StringName
var selected: bool = false
var phase: float = 0.0
var _frame: int = -1
var pulse: float = 0.0
var _caption: Label
var _built_cached: bool = false
var _last_origin: Vector2 = Vector2.ZERO
var _last_factor: float = 1.0


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
	var flash_active: bool = (station != &"egg" and GameState.get_station_fossil_flash(station) > 0.0)
	if not _built_cached and not was_pulsing and not flash_active:
		return
	var frame: int = floori(phase * ART_FPS)
	if frame != _frame:
		_frame = frame
		queue_redraw()


func _draw() -> void:
	var art_size: Vector2 = Vector2(size.x, size.y - 35.0)
	var factor: float = minf(art_size.x / 84.0, art_size.y / 64.0)
	if factor <= 0.0:
		return
	var origin: Vector2 = Vector2((size.x - 84.0 * factor) / 2.0, art_size.y - factor * 64.0)
	if pulse > 0.0:
		origin.y -= roundf(sin(pulse * PI) * 2.0) * factor
	_last_origin = origin
	_last_factor = factor
	draw_set_transform(origin, 0.0, Vector2.ONE * factor)
	if station == &"egg":
		_nest()
	elif STATION_ART.has(station) or station in PROCEDURAL_STATIONS:
		var level: int = GameState.get_rubble_level(station)
		_draw_station(level)
		if level > 0 and GameState.has_station_worker(station):
			var has_gear: bool = false
			if GameState.RUBBLE_DEFS.has(station):
				var def: Dictionary = GameState.RUBBLE_DEFS[station] as Dictionary
				var gear_id: StringName = StringName(def.get("gear", &""))
				has_gear = gear_id != &"" and GameState.get_upgrade_level(gear_id) > 0
			StationWorkerArt.draw(self, station, phase, has_gear, false, origin, factor)
		var revived: int = GameState.get_station_revived_count(station)
		if revived > 0:
			StationWorkerArt.draw(self, station, phase, false, true, origin, factor)
		var flash_left: float = GameState.get_station_fossil_flash(station)
		if flash_left > 0.0:
			_draw_fossil_badge(flash_left)
	if selected or has_focus() or is_hovered():
		_box(15.0, 60.0, 54.0, 2.0, AMBER if selected else INK)
		_box(36.0, 61.0, 12.0, 2.0, CREAM)


func _box(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)


func _nest() -> void:
	var frame_x: int = 168 if GameState.orange_rock_broken else 0
	draw_texture_rect_region(AMBER_NEST, Rect2(0.0, 0.0, 84.0, 64.0), Rect2(float(frame_x), 0.0, 168.0, 128.0))
	if GameState.orange_rock_broken:
		return
	var crack: Color = Color("#743720")
	if GameState.orange_rock_hp < 7.0:
		draw_polyline(PackedVector2Array([Vector2(47.0, 17.0), Vector2(45.0, 23.0), Vector2(48.0, 29.0), Vector2(44.0, 32.0)]), crack, 1.0)
	if GameState.orange_rock_hp < 4.0:
		draw_polyline(PackedVector2Array([Vector2(44.0, 32.0), Vector2(45.0, 38.0), Vector2(38.0, 42.0), Vector2(40.0, 49.0)]), crack, 1.0)
		draw_line(Vector2(44.0, 36.0), Vector2(50.0, 39.0), crack, 1.0)


func _draw_station(level: int) -> void:
	if STATION_ART.has(station):
		var variants: Array = STATION_ART[station] as Array
		var texture: Texture2D = variants[1 if level > 0 else 0] as Texture2D
		draw_texture_rect(texture, Rect2(0.0, 0.0, 84.0, 64.0), false)
		if level <= 0:
			return
		match station:
			&"rubble_forge":
				if GameState.get_upgrade_level(&"tools_metal_pick") > 0:
					_draw_glint(Vector2(19.0, 32.0), 0.0)
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
					_draw_glint(Vector2(44.0, 13.0), 0.5)
		if level >= 2:
			_draw_supply_crate(Vector2(71.0 if station != &"rubble_silo" else 57.0, 53.0))
		return

	# Estruturas em pixel art detalhado dos novos biomas (Floresta Ancestral e Cordilheira Nevada).
	match station:
		&"forest_grove":
			_draw_forest_grove(level)
		&"forest_sanctuary":
			_draw_forest_sanctuary(level)
		&"snow_glacier":
			_draw_snow_glacier(level)
		&"snow_observatory":
			_draw_snow_observatory(level)


## 1) Bosque das Sequoias — Serraria de Sequoias & Guindaste de Madeira.
func _draw_forest_grove(level: int) -> void:
	# Sombra de base no solo musgoso.
	_box(9.0, 55.0, 66.0, 4.0, Color(0.11, 0.14, 0.10, 0.45))
	var bark_dark: Color = Color("#542d24")
	var bark_mid: Color = Color("#7c4433")
	var bark_lit: Color = Color("#a86545")
	var moss_dark: Color = Color("#2d5a3b")
	var moss_lit: Color = Color("#65a358")
	var roof_teal: Color = Color("#397365")
	var roof_hi: Color = Color("#63a691")

	if level <= 0:
		# Fundação não construída: grande toco de sequoia com veio de resina + toras e estacas.
		_box(12.0, 36.0, 26.0, 21.0, DARK_INK)
		_box(13.0, 37.0, 24.0, 19.0, bark_dark)
		_box(15.0, 38.0, 16.0, 17.0, bark_mid)
		_box(17.0, 39.0, 7.0, 14.0, bark_lit)
		# Corte superior do toco com anéis dourados.
		_box(14.0, 35.0, 22.0, 4.0, DARK_INK)
		_box(15.0, 36.0, 20.0, 2.0, Color("#dfa86e"))
		_box(19.0, 36.0, 10.0, 1.0, AMBER)
		# Musgo e raízes ao redor.
		_box(10.0, 52.0, 8.0, 5.0, bark_dark)
		_box(11.0, 51.0, 5.0, 2.0, moss_lit)
		_box(34.0, 52.0, 7.0, 5.0, bark_mid)
		_box(35.0, 51.0, 5.0, 2.0, moss_dark)
		# Veio de resina dourada escorrendo no tronco.
		_box(27.0, 43.0, 3.0, 6.0, AMBER)
		_box(28.0, 44.0, 1.0, 4.0, CREAM)
		# Estacas de obra e pilha de toras à direita.
		for sx: float in [44.0, 56.0, 68.0]:
			_box(sx, 46.0, 3.0, 11.0, DARK_INK)
			_box(sx + 1.0, 47.0, 1.0, 9.0, TIMBER)
		draw_line(Vector2(45.5, 49.0), Vector2(57.5, 50.0), CREAM, 1.0)
		draw_line(Vector2(57.5, 50.0), Vector2(69.5, 49.0), CREAM, 1.0)
		_box(46.0, 52.0, 18.0, 5.0, DARK_INK)
		_box(47.0, 53.0, 16.0, 3.0, bark_lit)
		_box(47.0, 55.0, 16.0, 1.0, bark_dark)
		return

	# Construída: grande tronco de sequoia + plataforma de serraria + guindaste com polia.
	# Tronco maciço esquerdo com copa esmeralda.
	_box(11.0, 15.0, 22.0, 42.0, DARK_INK)
	_box(12.0, 16.0, 20.0, 40.0, bark_dark)
	_box(14.0, 16.0, 13.0, 39.0, bark_mid)
	_box(16.0, 17.0, 6.0, 37.0, bark_lit)
	for ry: float in [22.0, 32.0, 42.0, 50.0]:
		_box(15.0, ry, 2.0, 5.0, bark_dark)
		_box(24.0, ry + 2.0, 2.0, 4.0, Color("#3d1f1b"))
	# Copa frondosa no topo da sequoia.
	draw_circle(Vector2(21.0, 13.0), 12.0, DARK_INK)
	draw_circle(Vector2(21.0, 13.0), 11.0, moss_dark)
	draw_circle(Vector2(15.0, 15.0), 8.0, Color("#3f7b4b"))
	draw_circle(Vector2(26.0, 14.0), 8.0, Color("#3f7b4b"))
	draw_circle(Vector2(19.0, 10.0), 6.5, moss_lit)
	# Veio de resina brilhante no tronco.
	_box(25.0, 35.0, 4.0, 9.0, AMBER)
	_box(26.0, 36.0, 2.0, 5.0, CREAM)

	# Deck de madeira elevado + teto verde-patina da serraria.
	_box(28.0, 38.0, 31.0, 19.0, DARK_INK)
	_box(29.0, 39.0, 29.0, 17.0, Color("#3b2220"))
	# Pilares e deck horizontal.
	_box(30.0, 39.0, 4.0, 17.0, TIMBER)
	_box(53.0, 39.0, 4.0, 17.0, TIMBER)
	_box(28.0, 44.0, 31.0, 4.0, DARK_INK)
	_box(29.0, 45.0, 29.0, 2.0, TIMBER)
	# Telhado inclinado verde-musgo com moldura de madeira.
	var roof := PackedVector2Array([
		Vector2(24.0, 36.0), Vector2(44.0, 25.0), Vector2(63.0, 36.0),
		Vector2(61.0, 39.0), Vector2(26.0, 39.0),
	])
	draw_colored_polygon(roof, DARK_INK)
	var roof_in := PackedVector2Array([
		Vector2(26.0, 36.0), Vector2(44.0, 27.0), Vector2(61.0, 36.0),
		Vector2(59.0, 38.0), Vector2(28.0, 38.0),
	])
	draw_colored_polygon(roof_in, roof_teal)
	draw_line(Vector2(28.0, 35.0), Vector2(44.0, 27.5), roof_hi, 1.5)
	draw_line(Vector2(44.0, 27.5), Vector2(59.0, 35.0), Color("#265249"), 1.5)

	# Lâmina de serra girando suavemente na plataforma.
	var saw_r: float = 4.5
	var saw_c := Vector2(43.0, 44.0)
	draw_circle(saw_c, saw_r + 1.0, DARK_INK)
	draw_circle(saw_c, saw_r, Color("#b8c8d4"))
	var tooth_ang: float = phase * 5.0
	for ti: int in range(4):
		var a: float = tooth_ang + float(ti) * PI * 0.5
		draw_line(saw_c + Vector2(cos(a), sin(a)) * 1.5, saw_c + Vector2(cos(a), sin(a)) * 4.2, Color("#eef6fa"), 1.0)
	draw_circle(saw_c, 1.4, WOOD)

	# Braço do guindaste de madeira + polia com tora balançando.
	_box(55.0, 22.0, 4.0, 35.0, DARK_INK)
	_box(56.0, 23.0, 2.0, 33.0, TIMBER)
	_box(53.0, 21.0, 19.0, 4.0, DARK_INK)
	_box(54.0, 22.0, 17.0, 2.0, TIMBER)
	var sway: float = sin(phase * 2.2) * 1.6
	draw_line(Vector2(68.0, 25.0), Vector2(68.0 + sway, 36.0), CREAM, 1.0)
	_box(64.0 + sway, 36.0, 8.0, 5.0, DARK_INK)
	_box(65.0 + sway, 37.0, 6.0, 3.0, bark_lit)
	_box(66.0 + sway, 38.0, 4.0, 1.0, AMBER)

	# Lanterna de âmbar quente no poste e pilha de madeira na base.
	var glow_a: float = 0.25 + 0.12 * sin(phase * 3.5)
	draw_circle(Vector2(32.0, 41.0), 4.5, Color(1.0, 0.80, 0.30, glow_a))
	_box(31.0, 40.0, 2.5, 3.0, AMBER)
	_box(31.5, 40.5, 1.5, 1.5, CREAM)
	_box(35.0, 52.0, 15.0, 5.0, DARK_INK)
	_box(36.0, 53.0, 13.0, 3.0, bark_lit)
	_box(37.0, 53.0, 11.0, 1.0, CREAM)

	# Esporos/folhinhas douradas derivando ao redor da copa.
	for si: int in range(3):
		var t: float = fposmod(phase * 0.42 + float(si) * 0.33, 1.0)
		var sx: float = 16.0 + float(si) * 18.0 + sin(t * TAU) * 3.0
		var sy: float = 28.0 - t * 14.0
		_box(roundf(sx), roundf(sy), 1.5, 1.5, Color(0.95, 0.90, 0.48, sin(t * PI) * 0.78))

	_draw_glint(Vector2(27.0, 38.0), 0.2)
	if level >= 2:
		_draw_supply_crate(Vector2(69.0, 53.0))


## 2) Clareira das Samambaias — Santuário Botânico & Altar de Pedra Brilhante.
func _draw_forest_sanctuary(level: int) -> void:
	_box(9.0, 55.0, 66.0, 4.0, Color(0.10, 0.14, 0.10, 0.45))
	var stone_dark: Color = Color("#5d514b")
	var stone_mid: Color = Color("#948472")
	var stone_lit: Color = Color("#cfc0a5")
	var fern_dark: Color = Color("#24573a")
	var fern_mid: Color = Color("#468d53")
	var fern_lit: Color = Color("#88cb69")
	var berry_red: Color = Color("#db465d")
	var berry_hi: Color = Color("#ff98a8")

	if level <= 0:
		# Fundação não construída: círculo de pedras antigas cobertas de musgo e brotos de frutas.
		_box(16.0, 46.0, 52.0, 11.0, DARK_INK)
		_box(17.0, 47.0, 50.0, 9.0, stone_dark)
		_box(19.0, 47.0, 46.0, 4.0, stone_mid)
		_box(22.0, 47.0, 38.0, 2.0, stone_lit)
		# Pedras rúnicas quebradas.
		_box(21.0, 37.0, 9.0, 12.0, DARK_INK)
		_box(22.0, 38.0, 7.0, 10.0, stone_mid)
		_box(23.0, 38.0, 3.0, 8.0, stone_lit)
		_box(53.0, 39.0, 8.0, 10.0, DARK_INK)
		_box(54.0, 40.0, 6.0, 8.0, stone_mid)
		# Arbustos de samambaia e frutinhas silvestres.
		for bx: float in [14.0, 35.0, 60.0]:
			draw_circle(Vector2(bx + 4.0, 51.0), 5.0, fern_dark)
			draw_circle(Vector2(bx + 3.0, 49.0), 3.5, fern_mid)
			_box(bx + 2.0, 48.0, 2.0, 2.0, berry_red)
			_box(bx + 5.0, 50.0, 2.0, 2.0, berry_hi)
		return

	# Construída: arco santuário de pedra antiga + dossel de samambaias + altar brilhante + cestos de frutas.
	# Base escalonada de pedra.
	_box(13.0, 49.0, 58.0, 8.0, DARK_INK)
	_box(14.0, 50.0, 56.0, 6.0, stone_dark)
	_box(15.0, 50.0, 54.0, 3.0, stone_mid)
	_box(22.0, 45.0, 40.0, 6.0, DARK_INK)
	_box(23.0, 46.0, 38.0, 4.0, stone_mid)
	_box(24.0, 46.0, 36.0, 2.0, stone_lit)

	# Pilares gêmeos com arco superior.
	_box(20.0, 21.0, 9.0, 29.0, DARK_INK)
	_box(21.0, 22.0, 7.0, 27.0, stone_mid)
	_box(22.0, 22.0, 3.0, 26.0, stone_lit)
	_box(55.0, 21.0, 9.0, 29.0, DARK_INK)
	_box(56.0, 22.0, 7.0, 27.0, stone_mid)
	_box(57.0, 22.0, 3.0, 26.0, stone_lit)

	# Arco de pedra ligando os pilares.
	var arch := PackedVector2Array([
		Vector2(18.0, 23.0), Vector2(30.0, 12.0), Vector2(54.0, 12.0), Vector2(66.0, 23.0),
		Vector2(63.0, 26.0), Vector2(52.0, 18.0), Vector2(32.0, 18.0), Vector2(21.0, 26.0),
	])
	draw_colored_polygon(arch, DARK_INK)
	var arch_in := PackedVector2Array([
		Vector2(20.0, 23.0), Vector2(31.0, 13.5), Vector2(53.0, 13.5), Vector2(64.0, 23.0),
		Vector2(61.0, 24.5), Vector2(51.0, 17.0), Vector2(33.0, 17.0), Vector2(23.0, 24.5),
	])
	draw_colored_polygon(arch_in, stone_mid)
	draw_line(Vector2(21.0, 22.0), Vector2(31.0, 14.0), stone_lit, 1.5)
	draw_line(Vector2(31.0, 14.0), Vector2(53.0, 14.0), stone_lit, 1.5)

	# Dossel exuberante de samambaias e cachos de frutas vermelhas sobre o arco.
	for fx: float in [21.0, 31.0, 42.0, 53.0, 63.0]:
		var fy: float = 16.0 if fx == 42.0 else (18.0 if fx == 31.0 or fx == 53.0 else 23.0)
		draw_circle(Vector2(fx, fy), 6.5, DARK_INK)
		draw_circle(Vector2(fx, fy), 5.5, fern_dark)
		draw_circle(Vector2(fx - 1.0, fy - 1.0), 4.0, fern_mid)
		_box(fx - 2.0, fy - 3.5, 4.0, 2.0, fern_lit)

	# Frutas luminosas pendendo da folhagem.
	var berries: Array[Vector2] = [
		Vector2(24.0, 24.0), Vector2(33.0, 19.0), Vector2(49.0, 19.0), Vector2(59.0, 24.0),
		Vector2(15.0, 49.0), Vector2(66.0, 49.0),
	]
	for bp: Vector2 in berries:
		_box(bp.x - 1.0, bp.y - 1.0, 4.0, 4.0, DARK_INK)
		_box(bp.x, bp.y, 2.5, 2.5, berry_red)
		_box(bp.x, bp.y, 1.0, 1.0, berry_hi)

	# Altar central com bacia botânica bioluminescente.
	_box(35.0, 34.0, 14.0, 13.0, DARK_INK)
	_box(36.0, 35.0, 12.0, 11.0, stone_mid)
	_box(37.0, 35.0, 5.0, 10.0, stone_lit)
	var pulse_g: float = 0.5 + 0.5 * sin(phase * 3.0)
	draw_circle(Vector2(42.0, 31.0), 7.5 + pulse_g * 1.5, Color(0.45, 0.92, 0.56, 0.20 + pulse_g * 0.14))
	_box(36.0, 31.0, 12.0, 4.0, DARK_INK)
	_box(37.0, 31.5, 10.0, 2.5, Color("#6ee892"))
	_box(39.0, 30.5, 6.0, 2.0, Color("#f7ffba"))

	# Suporte lateral com cesto trançado de frutas.
	_box(11.0, 42.0, 8.0, 11.0, DARK_INK)
	_box(12.0, 43.0, 6.0, 9.0, WOOD)
	_box(12.0, 43.0, 6.0, 3.0, TIMBER)
	_box(13.0, 41.0, 4.0, 3.0, berry_red)
	_box(14.0, 41.0, 2.0, 1.0, berry_hi)

	# Esporos bioluminescentes subindo suavemente do altar.
	for sp_i: int in range(4):
		var t: float = fposmod(phase * 0.48 + float(sp_i) * 0.25, 1.0)
		var sx: float = 36.0 + float(sp_i) * 4.0 + sin(t * TAU + float(sp_i)) * 2.5
		var sy: float = 32.0 - t * 18.0
		_box(roundf(sx), roundf(sy), 1.5, 1.5, Color(0.68, 1.0, 0.72, sin(t * PI) * 0.85))

	_draw_glint(Vector2(42.0, 28.0), 0.7)
	if level >= 2:
		_draw_supply_crate(Vector2(69.0, 53.0))


## 3) Geleira Cristalina — Perfuradora de Gelo & Arco Glacial.
func _draw_snow_glacier(level: int) -> void:
	_box(9.0, 55.0, 66.0, 4.0, Color(0.14, 0.22, 0.34, 0.40))
	var ice_deep: Color = Color("#3e6d99")
	var ice_mid: Color = Color("#6eaed6")
	var ice_lit: Color = Color("#b5e3fa")
	var ice_spec: Color = Color("#f0fbff")

	if level <= 0:
		# Fundação não construída: afloramento de gelo azul + estacas congeladas e trilhos do trenó.
		var mound := PackedVector2Array([
			Vector2(12.0, 56.0), Vector2(18.0, 38.0), Vector2(32.0, 33.0),
			Vector2(44.0, 42.0), Vector2(52.0, 56.0),
		])
		draw_colored_polygon(mound, DARK_INK)
		var mound_in := PackedVector2Array([
			Vector2(14.0, 55.0), Vector2(19.0, 39.5), Vector2(32.0, 35.0),
			Vector2(43.0, 43.0), Vector2(50.0, 55.0),
		])
		draw_colored_polygon(mound_in, ice_mid)
		var facet := PackedVector2Array([
			Vector2(19.0, 39.5), Vector2(32.0, 35.0), Vector2(34.0, 50.0), Vector2(21.0, 52.0),
		])
		draw_colored_polygon(facet, ice_lit)
		draw_line(Vector2(20.0, 40.0), Vector2(32.0, 36.0), ice_spec, 1.5)
		# Veio cristalino brilhante.
		_box(33.0, 44.0, 6.0, 3.0, Color("#88f2ff"))
		_box(35.0, 44.0, 2.0, 2.0, ice_spec)
		# Estacas e trenó vazio esperando montagem.
		for sx: float in [52.0, 66.0]:
			_box(sx, 45.0, 3.0, 11.0, DARK_INK)
			_box(sx + 1.0, 46.0, 1.0, 9.0, TIMBER)
		draw_line(Vector2(53.5, 48.0), Vector2(67.5, 49.0), ice_spec, 1.0)
		_box(51.0, 53.0, 18.0, 4.0, DARK_INK)
		_box(52.0, 54.0, 16.0, 2.0, Color("#9bb3c7"))
		return

	# Construída: grande arco glacial translúcido + torre de perfuração de madeira/latão com broca giratória.
	var left_spire := PackedVector2Array([
		Vector2(10.0, 56.0), Vector2(13.0, 24.0), Vector2(24.0, 13.0),
		Vector2(34.0, 20.0), Vector2(30.0, 56.0),
	])
	draw_colored_polygon(left_spire, DARK_INK)
	var left_in := PackedVector2Array([
		Vector2(12.0, 55.0), Vector2(15.0, 25.0), Vector2(24.0, 15.0),
		Vector2(32.0, 21.0), Vector2(28.0, 55.0),
	])
	draw_colored_polygon(left_in, ice_deep)
	var left_lit := PackedVector2Array([
		Vector2(15.0, 25.0), Vector2(24.0, 15.0), Vector2(25.0, 48.0), Vector2(16.0, 52.0),
	])
	draw_colored_polygon(left_lit, ice_lit)
	draw_line(Vector2(15.5, 25.0), Vector2(24.0, 15.5), ice_spec, 1.5)

	var right_spire := PackedVector2Array([
		Vector2(54.0, 56.0), Vector2(52.0, 24.0), Vector2(61.0, 16.0),
		Vector2(70.0, 28.0), Vector2(73.0, 56.0),
	])
	draw_colored_polygon(right_spire, DARK_INK)
	var right_in := PackedVector2Array([
		Vector2(56.0, 55.0), Vector2(54.0, 25.0), Vector2(61.0, 18.0),
		Vector2(68.0, 29.0), Vector2(71.0, 55.0),
	])
	draw_colored_polygon(right_in, ice_mid)
	draw_line(Vector2(54.5, 25.0), Vector2(61.0, 18.5), ice_spec, 1.5)

	# Ponte glacial unindo os dois pináculos.
	_box(24.0, 16.0, 38.0, 7.0, DARK_INK)
	_box(25.0, 17.0, 36.0, 5.0, ice_mid)
	_box(26.0, 17.0, 34.0, 2.0, ice_lit)

	# Estrutura de madeira e latão da broca de gelo no vão central.
	_box(31.0, 21.0, 4.0, 35.0, DARK_INK)
	_box(32.0, 22.0, 2.0, 33.0, TIMBER)
	_box(49.0, 21.0, 4.0, 35.0, DARK_INK)
	_box(50.0, 22.0, 2.0, 33.0, TIMBER)
	_box(30.0, 22.0, 24.0, 5.0, DARK_INK)
	_box(31.0, 23.0, 22.0, 3.0, WOOD)
	_box(32.0, 23.0, 20.0, 1.0, AMBER)

	# Broca espiral animada perfurando o núcleo de gelo brilhante.
	_box(39.0, 26.0, 6.0, 24.0, DARK_INK)
	_box(40.0, 27.0, 4.0, 22.0, Color("#96b2c7"))
	var scroll: float = fposmod(phase * 14.0, 4.0)
	for sy: int in range(0, 20, 4):
		var ry: float = 28.0 + fposmod(float(sy) + scroll, 20.0)
		_box(40.0, ry, 4.0, 1.5, ice_spec)
	# Núcleo ciano pulsante na base da broca.
	var core_p: float = 0.5 + 0.5 * sin(phase * 4.5)
	draw_circle(Vector2(42.0, 52.0), 6.0 + core_p * 1.5, Color(0.50, 0.94, 1.0, 0.25 + core_p * 0.16))
	_box(35.0, 50.0, 14.0, 6.0, DARK_INK)
	_box(36.0, 51.0, 12.0, 4.0, Color("#73e4ff"))
	_box(38.0, 51.5, 8.0, 2.0, ice_spec)

	# Trenó carregado com cubos de gelo lapidados à esquerda.
	_box(13.0, 49.0, 14.0, 7.0, DARK_INK)
	_box(14.0, 50.0, 12.0, 5.0, ice_lit)
	_box(15.0, 50.0, 5.0, 3.0, ice_spec)
	_box(13.0, 54.0, 14.0, 2.0, TIMBER)

	# Flocos de neve e estilhaços de gelo.
	for fl_i: int in range(4):
		var t: float = fposmod(phase * 0.65 + float(fl_i) * 0.25, 1.0)
		var fx: float = 18.0 + float(fl_i) * 15.0 + sin(t * TAU) * 2.5
		var fy: float = 12.0 + t * 38.0
		_box(roundf(fx), roundf(fy), 1.5, 1.5, Color(0.94, 0.99, 1.0, sin(t * PI) * 0.85))

	_draw_glint(Vector2(24.0, 18.0), 0.1)
	_draw_glint(Vector2(61.0, 21.0), 1.4)
	if level >= 2:
		_draw_supply_crate(Vector2(69.0, 53.0))


## 4) Santuário Ártico — Observatório Polar com Cúpula e Prisma da Aurora.
func _draw_snow_observatory(level: int) -> void:
	_box(8.0, 55.0, 68.0, 4.0, Color(0.14, 0.20, 0.32, 0.42))
	var wall_dark: Color = Color("#4a5c73")
	var wall_mid: Color = Color("#879eb5")
	var wall_lit: Color = Color("#d2e3f0")
	var dome_dark: Color = Color("#2a5b66")
	var dome_mid: Color = Color("#428791")
	var dome_lit: Color = Color("#76c2c7")
	var glow_win: Color = Color("#ffbf4a")
	var glow_core: Color = Color("#fff3bd")

	if level <= 0:
		# Fundação não construída: base octogonal de pedra nevada + pedestal de cristal quebrado.
		_box(14.0, 45.0, 56.0, 12.0, DARK_INK)
		_box(15.0, 46.0, 54.0, 10.0, wall_dark)
		_box(17.0, 46.0, 50.0, 4.0, wall_mid)
		_box(18.0, 45.0, 48.0, 2.0, Color("#eef7fe"))
		# Pedestal central rachado com fragmento de prisma.
		_box(36.0, 35.0, 12.0, 12.0, DARK_INK)
		_box(37.0, 36.0, 10.0, 10.0, wall_mid)
		_box(38.0, 36.0, 4.0, 9.0, wall_lit)
		_box(40.0, 31.0, 4.0, 5.0, Color("#8cefff"))
		# Costelas da cúpula caídas ao lado.
		_box(18.0, 51.0, 13.0, 4.0, dome_dark)
		_box(19.0, 51.0, 11.0, 2.0, dome_mid)
		return

	# Construída: observatório polar em cúpula de cobre-turquesa com janelas douradas e Prisma da Aurora!
	# Raios suaves de aurora emanando do topo do prisma.
	var aurora_p: float = 0.5 + 0.5 * sin(phase * 2.4)
	var beam := PackedVector2Array([
		Vector2(37.0, 11.0), Vector2(47.0, 11.0),
		Vector2(57.0, 0.0), Vector2(27.0, 0.0),
	])
	draw_colored_polygon(beam, Color(0.54, 0.96, 0.88, 0.14 + aurora_p * 0.12))
	draw_circle(Vector2(42.0, 10.0), 8.5 + aurora_p * 2.0, Color(0.68, 0.86, 1.0, 0.22 + aurora_p * 0.14))

	# Cúpula segmentada de cobre-turquesa.
	draw_circle(Vector2(42.0, 28.0), 17.0, DARK_INK)
	draw_circle(Vector2(42.0, 28.0), 16.0, dome_dark)
	draw_circle(Vector2(40.0, 27.0), 13.5, dome_mid)
	draw_circle(Vector2(37.0, 24.0), 8.5, dome_lit)
	# Fenda do telescópio / cúpula nevada.
	_box(39.0, 13.0, 6.0, 14.0, DARK_INK)
	_box(40.0, 14.0, 4.0, 12.0, Color("#243952"))
	_box(28.0, 26.0, 28.0, 3.0, Color("#eef7fe"))

	# Prisma da Aurora levitando sobre a cúpula.
	var bob: float = sin(phase * 3.0) * 1.6
	var py: float = 9.0 + bob
	var prism_out := PackedVector2Array([
		Vector2(42.0, py - 5.5), Vector2(47.0, py), Vector2(42.0, py + 5.5), Vector2(37.0, py),
	])
	draw_colored_polygon(prism_out, DARK_INK)
	var prism_in := PackedVector2Array([
		Vector2(42.0, py - 4.2), Vector2(45.6, py), Vector2(42.0, py + 4.2), Vector2(38.4, py),
	])
	draw_colored_polygon(prism_in, Color("#88eeff").lerp(Color("#b69cff"), aurora_p))
	var prism_hi := PackedVector2Array([
		Vector2(42.0, py - 4.2), Vector2(42.0, py + 4.2), Vector2(38.4, py),
	])
	draw_colored_polygon(prism_hi, Color("#e8feff"))

	# Corpo principal do observatório (paredes de pedra polar + alas laterais).
	_box(13.0, 33.0, 58.0, 23.0, DARK_INK)
	_box(14.0, 34.0, 56.0, 21.0, wall_dark)
	_box(15.0, 34.0, 54.0, 19.0, wall_mid)
	_box(16.0, 34.0, 20.0, 18.0, wall_lit)
	# Beiral nevado nas alas.
	_box(11.0, 31.0, 62.0, 4.0, DARK_INK)
	_box(12.0, 32.0, 60.0, 2.0, Color("#edf8ff"))

	# Pórtico central e janelas arqueadas em âmbar quente (ecoando a Universidade!).
	_box(33.0, 35.0, 18.0, 21.0, DARK_INK)
	_box(34.0, 36.0, 16.0, 19.0, TIMBER)
	_box(36.0, 38.0, 12.0, 17.0, DARK_INK)
	_box(37.0, 39.0, 10.0, 16.0, Color("#573126"))
	_box(39.0, 41.0, 6.0, 11.0, glow_win)
	_box(40.0, 42.0, 4.0, 6.0, glow_core)
	# Janelas laterais brilhantes.
	for wx: float in [20.0, 58.0]:
		_box(wx - 1.0, 39.0, 8.0, 11.0, DARK_INK)
		_box(wx, 40.0, 6.0, 9.0, glow_win)
		_box(wx + 1.0, 41.0, 4.0, 5.0, glow_core)
		_box(wx + 2.5, 40.0, 1.0, 9.0, DARK_INK)
	# Degraus de pedra nevada na base.
	_box(28.0, 54.0, 28.0, 3.0, DARK_INK)
	_box(29.0, 54.5, 26.0, 2.0, wall_lit)

	# Flocos de neve cintilantes e brilhos de cristal.
	for fl_i: int in range(4):
		var t: float = fposmod(phase * 0.55 + float(fl_i) * 0.27, 1.0)
		var fx: float = 14.0 + float(fl_i) * 18.0 + sin(t * TAU) * 2.0
		var fy: float = 8.0 + t * 42.0
		_box(roundf(fx), roundf(fy), 1.5, 1.5, Color(0.92, 0.98, 1.0, sin(t * PI) * 0.80))

	_draw_glint(Vector2(42.0, py), 0.3)
	_draw_glint(Vector2(24.0, 34.0), 1.7)
	if level >= 2:
		_draw_supply_crate(Vector2(70.0, 53.0))


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
	var duration: float = maxf(GameState.STATION_FOSSIL_FLASH_DURATION, 0.1)
	var elapsed: float = clampf(duration - flash_left, 0.0, duration)
	var progress: float = clampf(elapsed / duration, 0.0, 1.0)
	var fade_in: float = clampf(elapsed / 0.08, 0.0, 1.0)
	var fade_out: float = clampf(flash_left / 0.70, 0.0, 1.0)
	var alpha: float = minf(fade_in, fade_out)

	# Escala de entrada com quique suave (0.5 -> 1.08 -> 1.0) + respiração leve.
	var pop_scale: float = 1.0
	if elapsed < 0.18:
		pop_scale = lerpf(0.50, 1.08, ease(elapsed / 0.18, 0.35))
	elif elapsed < 0.34:
		pop_scale = lerpf(1.08, 1.00, (elapsed - 0.18) / 0.16)
	else:
		pop_scale = 1.00 + sin(elapsed * 5.2) * 0.025

	var float_y: float = -progress * 7.5 - absf(sin(elapsed * 4.2)) * 1.4
	var center: Vector2 = Vector2(42.0, 14.0 + float_y)

	# 1. Halo radial dourado-âmbar suave + raios cintilantes sutis atrás do fóssil.
	var pulse_w: float = sin(phase * 8.0)
	draw_circle(center, (17.5 + pulse_w * 1.2) * pop_scale, Color(1.0, 0.72, 0.20, alpha * 0.18))
	draw_circle(center, (13.0 + pulse_w * 0.8) * pop_scale, Color(1.0, 0.86, 0.36, alpha * 0.34))
	draw_circle(center, 9.5 * pop_scale, Color(1.0, 0.95, 0.70, alpha * 0.30))
	for ray_i: int in range(4):
		var ang: float = phase * 1.2 + float(ray_i) * PI * 0.25
		var dir_v := Vector2(cos(ang), sin(ang))
		draw_line(
			center - dir_v * (14.5 * pop_scale),
			center + dir_v * (14.5 * pop_scale),
			Color(1.0, 0.92, 0.56, alpha * 0.28),
			1.0,
		)

	# 2. Partículas pixeladas douradas subindo ao redor do bloco de fóssil.
	for mi: int in range(7):
		var seed_f: float = float(mi) * 1.37
		var mote_t: float = fposmod(elapsed * 0.75 + seed_f * 0.41, 1.0)
		var mx: float = center.x + sin(seed_f * 4.2 + mote_t * 3.0) * 13.5
		var my: float = center.y + 8.0 - mote_t * 22.0
		var m_alpha: float = alpha * sin(mote_t * PI) * 0.92
		var m_sz: float = 1.5 if mi % 2 == 0 else 1.0
		var m_col: Color = Color(1.0, 0.96, 0.78, m_alpha) if mi % 2 == 0 else Color(1.0, 0.80, 0.28, m_alpha)
		_box(roundf(mx), roundf(my), m_sz, m_sz, m_col)

	# 3. Bloco de fóssil pixel art (usa textura oficial do AmberTheme com fallback artesanal).
	var block_sz: float = 24.0 * pop_scale
	var block_rect := Rect2(center - Vector2(block_sz * 0.5, block_sz * 0.5), Vector2(block_sz, block_sz))
	var fossil_tex: Texture2D = AmberTheme.get_fossil_found_texture()
	if fossil_tex != null:
		draw_texture_rect(fossil_tex, block_rect, false, Color(1.0, 1.0, 1.0, alpha))
	else:
		_draw_fossil_block_fallback(block_rect, alpha)

	# 4. Texto "Fóssil Encontrado!" centralizado logo ACIMA da animação (em espaço de controle nítido).
	var font: Font = ThemeDB.fallback_font
	if font != null:
		var label_text: String = "Fóssil Encontrado!"
		var font_sz: int = clampi(roundi(13.0 + _last_factor * 0.85), 14, 18)
		var measured_w: float = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_sz).x
		var text_w: float = maxf(measured_w + 18.0, 160.0)
		var mid_x: float = _last_origin.x + center.x * _last_factor
		var top_y: float = _last_origin.y + (center.y - block_sz * 0.52) * _last_factor - 6.0
		var text_pos := Vector2(roundf(mid_x - text_w * 0.5), roundf(top_y))
		var outline_col := Color(DARK_INK.r, DARK_INK.g, DARK_INK.b, alpha)
		var text_col := Color(1.0, 0.957, 0.769, alpha)  # #fff4c4

		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_string(font, text_pos + Vector2(0.0, 1.5), label_text, HORIZONTAL_ALIGNMENT_CENTER, text_w, font_sz, Color(0.10, 0.05, 0.07, alpha * 0.75))
		draw_string_outline(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, text_w, font_sz, 5, outline_col)
		draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, text_w, font_sz, text_col)
		draw_set_transform(_last_origin, 0.0, Vector2.ONE * _last_factor)


func _draw_fossil_block_fallback(rect: Rect2, alpha: float) -> void:
	var s: float = rect.size.x / 24.0
	var p: Vector2 = rect.position
	_box(p.x, p.y, 24.0 * s, 24.0 * s, Color(DARK_INK.r, DARK_INK.g, DARK_INK.b, alpha))
	_box(p.x + 1.0 * s, p.y + 1.0 * s, 22.0 * s, 22.0 * s, Color(0.47, 0.29, 0.23, alpha))
	_box(p.x + 2.0 * s, p.y + 2.0 * s, 20.0 * s, 6.0 * s, Color(0.85, 0.61, 0.43, alpha))
	_box(p.x + 2.0 * s, p.y + 8.0 * s, 20.0 * s, 14.0 * s, Color(0.68, 0.42, 0.32, alpha))
	_box(p.x + 2.0 * s, p.y + 2.0 * s, 20.0 * s, 1.5 * s, Color(0.93, 0.67, 0.28, alpha))
	var bone_col := Color(0.99, 0.94, 0.80, alpha)
	var bone_sh := Color(0.84, 0.75, 0.58, alpha)
	_box(p.x + 6.0 * s, p.y + 11.0 * s, 12.0 * s, 3.0 * s, bone_col)
	_box(p.x + 5.0 * s, p.y + 9.5 * s, 3.0 * s, 2.5 * s, bone_col)
	_box(p.x + 5.0 * s, p.y + 13.0 * s, 3.0 * s, 2.5 * s, bone_sh)
	_box(p.x + 16.0 * s, p.y + 9.5 * s, 3.0 * s, 2.5 * s, bone_col)
	_box(p.x + 16.0 * s, p.y + 13.0 * s, 3.0 * s, 2.5 * s, bone_sh)
	_box(p.x + 9.0 * s, p.y + 6.0 * s, 6.0 * s, 3.0 * s, Color(1.0, 0.88, 0.54, alpha))
