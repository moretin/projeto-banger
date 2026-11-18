class_name WorldBuilding
extends Control
## Construção desenhada em traço branco (estilo Gnorp Apologue) apoiada no chão.
## Clicar abre o painel de upgrades da categoria diretamente acima dela.

signal clicked(building: WorldBuilding)

enum Kind { WORKSHOP, HATCHERY, FACTORY, BUNKER, AMBER }

var kind: Kind = Kind.WORKSHOP
var title: String = ""
var subtitle: String = ""
## Categoria de UpgradeData (-1 = incubadora de dinos, -2 = templo de âmbar).
var category: int = -1
var has_affordable: bool = false

var _hover: bool = false
var _t: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func() -> void: _hover = true)
	mouse_exited.connect(func() -> void: _hover = false)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
		accept_event()


func get_anchor_top() -> Vector2:
	return global_position + Vector2(size.x * 0.5, 0.0)


func _draw() -> void:
	var fg: Color = UITheme.G_FG
	var bg: Color = UITheme.G_BG
	var w: float = size.x
	var h: float = size.y

	match kind:
		Kind.WORKSHOP:
			_draw_workshop(w, h, fg, bg)
		Kind.HATCHERY:
			_draw_hatchery(w, h, fg, bg)
		Kind.FACTORY:
			_draw_factory(w, h, fg, bg)
		Kind.BUNKER:
			_draw_bunker(w, h, fg, bg)
		Kind.AMBER:
			_draw_amber(w, h, fg, bg)

	# Placa com o nome
	var font: Font = get_theme_default_font()
	var fs: int = 14
	var tw: float = font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var label_pos := Vector2((w - tw) * 0.5, h + 22.0)
	if _hover:
		draw_rect(Rect2(label_pos + Vector2(-6, -15), Vector2(tw + 12, 20)), fg, true)
		draw_string(font, label_pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, bg)
	else:
		draw_string(font, label_pos, title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.G_DIM)

	# Indicador de upgrade disponível
	if has_affordable:
		var bob: float = round(sin(_t * 5.0) * 3.0)
		var cx: float = w * 0.5
		var top: float = -26.0 + bob
		draw_rect(Rect2(cx - 2, top, 4, 10), UITheme.G_GOOD, true)
		draw_rect(Rect2(cx - 6, top + 4, 12, 2), UITheme.G_GOOD, true)
		draw_rect(Rect2(cx - 4, top + 2, 8, 2), UITheme.G_GOOD, true)


func _outline(r: Rect2, col: Color, fill: Color) -> void:
	draw_rect(r, fill, true)
	draw_rect(r, col, false, 2.0)


func _draw_workshop(w: float, h: float, fg: Color, bg: Color) -> void:
	var body := Rect2(8, h * 0.38, w - 16, h * 0.62)
	_outline(body, fg, bg)
	# Telhado
	var roof := PackedVector2Array([Vector2(0, h * 0.40), Vector2(w * 0.5, 4), Vector2(w, h * 0.40)])
	draw_colored_polygon(roof, bg)
	draw_polyline(PackedVector2Array([roof[0], roof[1], roof[2], roof[0]]), fg, 2.0)
	# Porta e janela
	_outline(Rect2(w * 0.18, h * 0.62, w * 0.22, h * 0.38), fg, bg)
	_outline(Rect2(w * 0.55, h * 0.55, w * 0.28, h * 0.22), fg, bg)
	draw_rect(Rect2(w * 0.69 - 1, h * 0.55, 2, h * 0.22), fg, true)
	# Picareta pendurada
	var px: float = w * 0.5
	var py: float = h * 0.20
	draw_rect(Rect2(px - 1, py, 2, 18), fg, true)
	draw_rect(Rect2(px - 9, py, 18, 3), fg, true)


func _draw_hatchery(w: float, h: float, fg: Color, bg: Color) -> void:
	var base := Rect2(0, h * 0.70, w, h * 0.30)
	_outline(base, fg, bg)
	var center := Vector2(w * 0.5, h * 0.72)
	var r: float = minf(w * 0.42, h * 0.68)
	var pts := PackedVector2Array()
	for i: int in range(13):
		var a: float = PI + PI * float(i) / 12.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, bg)
	draw_polyline(pts, fg, 2.0)
	# Ovo com rachadura pulsando
	var egg_y: float = center.y - r * 0.45 + round(sin(_t * 2.0) * 2.0)
	_outline(Rect2(center.x - 10, egg_y, 20, 26), fg, bg)
	draw_line(Vector2(center.x - 6, egg_y + 10), Vector2(center.x, egg_y + 14), fg, 2.0)
	draw_line(Vector2(center.x, egg_y + 14), Vector2(center.x + 6, egg_y + 9), fg, 2.0)
	# Ovos pequenos na base
	for i: int in range(3):
		_outline(Rect2(w * 0.15 + float(i) * 16.0, h * 0.77, 10, 14), fg, bg)


func _draw_factory(w: float, h: float, fg: Color, bg: Color) -> void:
	var body := Rect2(0, h * 0.45, w, h * 0.55)
	_outline(body, fg, bg)
	# Dentes de serra do telhado
	var saw := PackedVector2Array()
	var teeth: int = 3
	for i: int in range(teeth):
		var x0: float = w * float(i) / float(teeth)
		var x1: float = w * float(i + 1) / float(teeth)
		saw.append(Vector2(x0, h * 0.45))
		saw.append(Vector2(x1, h * 0.28))
		saw.append(Vector2(x1, h * 0.45))
	draw_polyline(saw, fg, 2.0)
	# Chaminé + fumaça animada
	_outline(Rect2(w * 0.78, h * 0.05, 14, h * 0.28), fg, bg)
	for i: int in range(3):
		var k: float = fmod(_t * 0.6 + float(i) * 0.33, 1.0)
		var sx: float = w * 0.78 + 7.0 + k * 22.0
		var sy: float = h * 0.04 - k * 40.0
		var s: float = round(4.0 + k * 8.0)
		draw_rect(Rect2(sx - s * 0.5, sy - s * 0.5, s, s), Color(fg, 1.0 - k), false, 2.0)
	# Janelas
	for i: int in range(3):
		_outline(Rect2(w * 0.10 + float(i) * w * 0.28, h * 0.58, w * 0.16, h * 0.16), fg, bg)
	# Engrenagem girando na porta
	var gc := Vector2(w * 0.5, h * 0.86)
	var ang: float = _t * 2.0
	for i: int in range(4):
		var a: float = ang + float(i) * PI * 0.5
		draw_line(gc, gc + Vector2(cos(a), sin(a)) * 9.0, fg, 2.0)


func _draw_bunker(w: float, h: float, fg: Color, bg: Color) -> void:
	var body := PackedVector2Array([
		Vector2(0, h), Vector2(w * 0.10, h * 0.45), Vector2(w * 0.90, h * 0.45), Vector2(w, h)
	])
	draw_colored_polygon(body, bg)
	draw_polyline(PackedVector2Array([body[0], body[1], body[2], body[3]]), fg, 2.0)
	# Fenda de observação
	draw_rect(Rect2(w * 0.25, h * 0.62, w * 0.50, 6), fg, true)
	# Radar girando
	var base := Vector2(w * 0.72, h * 0.45)
	draw_line(base, base + Vector2(0, -h * 0.28), fg, 2.0)
	var dish := base + Vector2(0, -h * 0.30)
	var sweep: float = sin(_t * 1.8) * 14.0
	draw_line(dish + Vector2(-14, -4 + sweep * 0.2), dish + Vector2(14, 4 - sweep * 0.2), fg, 3.0)
	if fmod(_t, 1.2) < 0.2:
		draw_rect(Rect2(dish.x - 2, dish.y - 12, 4, 4), UITheme.G_BAD, true)


func _draw_amber(w: float, h: float, fg: Color, bg: Color) -> void:
	# Obelisco
	var ob := PackedVector2Array([
		Vector2(w * 0.20, h), Vector2(w * 0.32, h * 0.25), Vector2(w * 0.5, h * 0.12),
		Vector2(w * 0.68, h * 0.25), Vector2(w * 0.80, h)
	])
	draw_colored_polygon(ob, bg)
	draw_polyline(PackedVector2Array([ob[0], ob[1], ob[2], ob[3], ob[4], ob[0]]), fg, 2.0)
	# Orbe de âmbar flutuando
	var oy: float = h * 0.40 + round(sin(_t * 2.4) * 3.0)
	draw_rect(Rect2(w * 0.5 - 7, oy, 14, 14), UITheme.G_AMBER, true)
	draw_rect(Rect2(w * 0.5 - 7, oy, 14, 14), fg, false, 2.0)
	draw_rect(Rect2(w * 0.5 - 3, oy + 3, 3, 3), fg, true)
