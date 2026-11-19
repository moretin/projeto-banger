extends Control
## Atlas desenhado em coordenadas de pixel. Os marcos usam as mesmas cotas do terreno.

const INK: Color = Color("#262638")
const CLAY: Color = Color("#ad6654")
const DUNE: Color = Color("#d39169")
const SAND: Color = Color("#e8b580")
const METEOR_REDRAW_FPS: float = 14.0

var _meteor_anim_t: float = 0.0
var _meteor_frame: int = -1
var _last_danger: float = -1.0


func _ready() -> void:
	Events.danger_level_changed.connect(_on_danger_changed)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var d: float = clampf(GameState.danger_level, 0.0, 1.0)
	var danger_changed: bool = not is_equal_approx(d, _last_danger)
	if not GameState.meteor_active and not danger_changed:
		return
	_last_danger = d
	_meteor_anim_t += delta
	var frame: int = floori(_meteor_anim_t * METEOR_REDRAW_FPS)
	if danger_changed or frame != _meteor_frame:
		_meteor_frame = frame
		queue_redraw()


func _on_danger_changed(_danger: float) -> void:
	queue_redraw()


func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, size / Vector2(480, 240))
	var danger: float = GameState.danger_level
	draw_rect(Rect2(0, 0, 480, 240), Color("#a6cebf").lerp(Color("#db947c"), danger))
	draw_rect(Rect2(0, 40, 480, 33), Color("#c5dac0").lerp(Color("#e6b08c"), danger))
	draw_rect(Rect2(0, 72, 480, 43), Color("#e4ddae").lerp(Color("#efc49b"), danger))
	# Disco solar com as bordas escalonadas e nuvens baixas.
	draw_rect(Rect2(302, 18, 20, 28), Color("#fff0bd"))
	draw_rect(Rect2(298, 22, 28, 20), Color("#fff0bd"))
	for i: int in range(9):
		var x: int = (i * 83 + 31) % 490
		var y: int = 16 + (i * 37) % 48
		draw_rect(Rect2(x, y, 22 + i % 4 * 6, 2), Color("#e6e9cc"))
		draw_rect(Rect2(x + 8, y - 2, 13, 2), Color("#e6e9cc"))
	# Meteoro ao fundo no céu distante, atrás das montanhas, estruturas, janelas e HUD.
	_draw_background_meteor(danger)
	_ridge(PackedVector2Array([Vector2(0,80),Vector2(38,68),Vector2(54,68),Vector2(75,83),Vector2(111,62),Vector2(136,62),Vector2(159,88),Vector2(216,70),Vector2(232,54),Vector2(253,54),Vector2(272,76),Vector2(335,91),Vector2(375,59),Vector2(406,59),Vector2(436,80),Vector2(480,62)]), Color("#92aaa0"))
	_ridge(PackedVector2Array([Vector2(0,100),Vector2(24,90),Vector2(52,91),Vector2(76,110),Vector2(123,90),Vector2(145,92),Vector2(166,104),Vector2(208,86),Vector2(247,86),Vector2(274,96),Vector2(298,88),Vector2(320,88),Vector2(349,105),Vector2(391,92),Vector2(427,99),Vector2(451,84),Vector2(480,84)]), Color("#628b81"))
	for i: int in range(70):
		var x: int = (i * 61) % 480
		var y: int = 104 + (i * 23) % 16
		draw_rect(Rect2(x, y-6, 2, 8), Color("#56796d"))
		draw_rect(Rect2(x-3, y-7, 8, 3), Color("#56796d"))
	_ridge(PackedVector2Array([Vector2(0,104),Vector2(40,110),Vector2(91,117),Vector2(133,137),Vector2(184,131),Vector2(226,109),Vector2(267,113),Vector2(308,101),Vector2(336,105),Vector2(363,125),Vector2(407,117),Vector2(444,114),Vector2(480,126)]), Color("#759178"))
	_ridge(PackedVector2Array([Vector2(0,129),Vector2(43,120),Vector2(77,121),Vector2(111,145),Vector2(146,161),Vector2(186,157),Vector2(225,132),Vector2(250,130),Vector2(290,115),Vector2(333,114),Vector2(362,138),Vector2(405,139),Vector2(448,133),Vector2(480,142)]), SAND)
	# Trilha clara de sedimento liga as quatro bancadas e o ninho central.
	var trail: PackedVector2Array = PackedVector2Array([Vector2(0,141),Vector2(60,132),Vector2(102,151),Vector2(163,175),Vector2(209,160),Vector2(236,137),Vector2(270,136),Vector2(316,120),Vector2(355,139),Vector2(407,152),Vector2(480,146)])
	draw_polyline(trail, Color("#ca8c68"), 5)
	draw_polyline(trail, Color("#f5cd90"), 2)
	for i: int in range(150):
		var x: int = (i * 113) % 479
		var y: int = 172 + (i * 31) % 32
		draw_rect(Rect2(x, y, 1 + i % 4, 1), DUNE)
	var lip: PackedVector2Array = PackedVector2Array([Vector2(0,177),Vector2(45,180),Vector2(80,177),Vector2(105,180),Vector2(140,193),Vector2(176,193),Vector2(210,182),Vector2(254,183),Vector2(290,173),Vector2(323,172),Vector2(359,183),Vector2(400,181),Vector2(445,187),Vector2(480,182)])
	for band: int in range(4):
		var color: Color = [CLAY, Color("#864d4a"), Color("#5b3e45"), INK][band]
		_ridge(lip, color)
		for j: int in range(lip.size()):
			lip[j].y += 6 + (j + band) % 5
	for i: int in range(39):
		var x: int = (i * 131) % 478
		var y: int = 211 + (i * 19) % 27
		draw_rect(Rect2(x, y, 2 + i % 6, 1), Color("#57424b"))
	# Uma coluna vertebral embutida na parede da cratera.
	for i: int in range(11):
		var y: float = 202 + roundf(sin(float(i) * 0.30) * 3)
		draw_rect(Rect2(64 + i * 3, y, 2, 2), Color("#d3a782"))
		if i % 2 == 0:
			draw_rect(Rect2(64 + i * 3, y + 2, 1, 4), Color("#b88870"))


func _draw_background_meteor(danger: float) -> void:
	var d: float = clampf(danger, 0.0, 1.0)
	if not GameState.meteor_active and d <= 0.0:
		return
	var start_pos: Vector2 = Vector2(385.0, 16.0)
	var end_pos: Vector2 = Vector2(345.0, 56.0)
	var pos: Vector2 = start_pos.lerp(end_pos, d)
	var radius: float = lerpf(2.5, 24.0, pow(d, 1.15))
	var tail_dir: Vector2 = (start_pos - end_pos).normalized()
	var lead_dir: Vector2 = -tail_dir
	var perp: Vector2 = Vector2(-tail_dir.y, tail_dir.x)
	var shimmer: float = sin(_meteor_anim_t * 6.5)
	var pulse: float = sin(_meteor_anim_t * 3.8)
	var tail_len: float = radius * lerpf(2.2, 3.6, d)

	# Halo atmosférico suave atrás do meteoro no céu distante (nunca cobre a tela toda).
	draw_circle(pos, radius * (2.15 + 0.14 * pulse), Color(0.95, 0.44, 0.16, lerpf(0.14, 0.24, d)))

	# Rastro de plasma incandescente subindo para a direita com oscilação suave.
	var tail_steps: int = 7
	for step_idx: int in range(tail_steps, 0, -1):
		var t: float = float(step_idx) / float(tail_steps)
		var wobble: float = sin(_meteor_anim_t * 7.5 - float(step_idx) * 1.1) * radius * 0.12 * t
		var seg_pos: Vector2 = pos + tail_dir * (tail_len * t) + perp * wobble
		var outer_r: float = maxf(1.0, radius * (1.08 - t * 0.72))
		var inner_r: float = maxf(0.6, radius * (0.62 - t * 0.48))
		var outer_a: float = (1.0 - t * 0.78) * lerpf(0.28, 0.56, d)
		var inner_a: float = (1.0 - t * 0.82) * lerpf(0.40, 0.72, d)
		draw_circle(seg_pos, outer_r, Color(0.92, 0.39, 0.18, outer_a))
		if step_idx <= 5:
			draw_circle(seg_pos, inner_r, Color(0.98, 0.75, 0.34, inner_a))

	# Lascas pixeladas de chama acompanhando o rastro no céu.
	var streak_count: int = 3
	for s_idx: int in range(streak_count):
		var st: float = 0.25 + float(s_idx) * 0.24
		var side: float = -1.0 if s_idx % 2 == 0 else 1.0
		var flick: float = sin(_meteor_anim_t * 9.0 + float(s_idx) * 2.1)
		var spos: Vector2 = pos + tail_dir * (tail_len * st) + perp * (side * radius * (0.34 + 0.12 * flick))
		if spos.y >= 1.0 and spos.y <= 60.0 and spos.x <= 462.0:
			var sw: float = maxf(1.0, roundf(radius * 0.24))
			var sh: float = maxf(1.0, roundf(radius * 0.14))
			var scol: Color = Color(1.0, 0.87, 0.56, lerpf(0.40, 0.78, d)) if s_idx == 0 else Color(0.93, 0.67, 0.28, lerpf(0.35, 0.70, d))
			draw_rect(Rect2(roundf(spos.x), roundf(spos.y), sw, sh), scol)

	# Fagulhas sutis derivando apenas no céu superior atrás das montanhas.
	var ember_count: int = 2 + int(roundf(d * 8.0))
	for ei: int in range(ember_count):
		var seed_f: float = float(ei) * 1.73
		var cycle: float = fposmod(_meteor_anim_t * (0.55 + float(ei % 3) * 0.22) + seed_f, 1.0)
		var spread: float = sin(seed_f * 3.1 + cycle * 4.0) * (2.5 + radius * 0.65)
		var dist_along: float = radius * 0.7 + cycle * (tail_len * 1.15 + 6.0)
		var epos: Vector2 = pos + tail_dir * dist_along + perp * spread
		if epos.y > 62.0 or epos.y < 1.0 or epos.x > 462.0:
			continue
		var esize: float = 1.0 if radius < 8.0 else (1.5 if ei % 2 == 0 else 2.0)
		var ealpha: float = (1.0 - cycle) * lerpf(0.45, 0.88, d)
		var ecol: Color = Color(1.0, 0.84, 0.44, ealpha) if ei % 3 == 0 else Color(0.95, 0.48, 0.20, ealpha)
		draw_rect(Rect2(roundf(epos.x), roundf(epos.y), esize, esize), ecol)

	# Halo laranja quente e aro externo incandescente.
	draw_circle(pos, radius * (1.35 + 0.06 * shimmer), Color(0.95, 0.45, 0.16, lerpf(0.32, 0.48, d)))
	draw_circle(pos, radius, Color("#edaa48").lerp(Color("#e86c32"), d * 0.45))
	draw_circle(pos + lead_dir * (radius * 0.18), radius * 0.82, Color("#ffdf9f").lerp(Color("#f49c42"), 0.35))

	# Núcleo rochoso escuro recortado com crateras sutis em pixel art.
	var core_pos: Vector2 = pos + tail_dir * (radius * 0.12)
	var core_r: float = maxf(1.2, radius * 0.72)
	draw_circle(core_pos, core_r, Color("#4a2d2d"))
	if radius < 5.0:
		# Brilho distante tipo estrela/bólido quando ainda pequeno no horizonte.
		draw_circle(pos + lead_dir * (radius * 0.25), maxf(0.8, radius * 0.38), Color(1.0, 0.94, 0.74, 0.92))
	else:
		draw_circle(core_pos + Vector2(-core_r * 0.22, -core_r * 0.18), core_r * 0.62, Color("#3a2228"))
		draw_circle(core_pos + Vector2(core_r * 0.28, core_r * 0.12), core_r * 0.46, Color("#5b3733"))
	if radius >= 6.0:
		var px: float = maxf(1.0, roundf(radius * 0.14))
		draw_rect(Rect2(roundf(core_pos.x - core_r * 0.42), roundf(core_pos.y - core_r * 0.24), px * 1.4, px * 1.2), Color("#261820"))
		draw_rect(Rect2(roundf(core_pos.x + core_r * 0.10), roundf(core_pos.y + core_r * 0.15), px * 1.2, px), Color("#261820"))
		draw_rect(Rect2(roundf(core_pos.x - core_r * 0.12), roundf(core_pos.y + core_r * 0.28), px, px), Color("#7d483b"))
	if radius >= 11.0:
		var px2: float = maxf(1.0, roundf(radius * 0.11))
		draw_rect(Rect2(roundf(core_pos.x + core_r * 0.22), roundf(core_pos.y - core_r * 0.36), px2 * 1.3, px2), Color("#261820"))
		draw_rect(Rect2(roundf(core_pos.x - core_r * 0.34), roundf(core_pos.y + core_r * 0.06), px2, px2), Color(0.93, 0.67, 0.28, 0.65))


func _ridge(top: PackedVector2Array, color: Color) -> void:
	top.append(Vector2(480, 240))
	top.append(Vector2(0, 240))
	draw_colored_polygon(top, color)
