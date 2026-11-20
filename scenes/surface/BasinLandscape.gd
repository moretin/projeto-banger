extends Control
## Camadas da Bacia do Âmbar no mesmo atlas de coordenadas dos marcos.

const MAP_SIZE: Vector2 = Vector2(480.0, 240.0)
const SKY: Texture2D = preload("res://assets/sprites/surface/background/amber_sky.png")
const RIDGES: Texture2D = preload("res://assets/sprites/surface/background/amber_ridges.png")
const GROUND: Texture2D = preload("res://assets/sprites/surface/background/amber_ground.png")
const SKY_RECT: Rect2 = Rect2(0.0, 0.0, 480.0, 127.0)
const RIDGE_RECT: Rect2 = Rect2(0.0, -46.0, 480.0, 220.0)
const GROUND_RECT: Rect2 = Rect2(0.0, 102.0, 480.0, 138.0)
const TERRAIN: Array[Vector2] = [
	Vector2(0, 129), Vector2(43, 120), Vector2(77, 121), Vector2(111, 145),
	Vector2(146, 161), Vector2(186, 157), Vector2(225, 132), Vector2(250, 130),
	Vector2(290, 115), Vector2(333, 114), Vector2(362, 138), Vector2(405, 139),
	Vector2(448, 133), Vector2(480, 142), Vector2(480, 240), Vector2(0, 240),
]
const FOOTPATH: Array[Vector2] = [
	Vector2(0, 141), Vector2(60, 132), Vector2(102, 151), Vector2(163, 175),
	Vector2(209, 160), Vector2(236, 137), Vector2(270, 136), Vector2(316, 120),
	Vector2(355, 139), Vector2(407, 152), Vector2(480, 146),
]
const METEOR_REDRAW_FPS: float = 14.0

var _ground_shape: PackedVector2Array = PackedVector2Array(TERRAIN)
var _ground_uv: PackedVector2Array = PackedVector2Array()
var _trail: PackedVector2Array = PackedVector2Array()
var _meteor_anim_t: float = 0.0
var _meteor_frame: int = -1
var _last_danger: float = -1.0


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for point: Vector2 in TERRAIN:
		_ground_uv.append((point - GROUND_RECT.position) / GROUND_RECT.size)

	var path: Curve2D = Curve2D.new()
	path.bake_interval = 3.0
	for i: int in range(FOOTPATH.size()):
		var tangent: Vector2 = (
			FOOTPATH[mini(i + 1, FOOTPATH.size() - 1)] - FOOTPATH[maxi(i - 1, 0)]
		) * 0.14
		path.add_point(FOOTPATH[i], -tangent, tangent)
	_trail = path.get_baked_points()
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
	draw_set_transform(Vector2.ZERO, 0.0, size / MAP_SIZE)
	var danger: float = clampf(GameState.danger_level, 0.0, 1.0)
	var sky_tint: Color = Color.WHITE.lerp(Color("#ff9d82"), danger)
	var ridge_tint: Color = Color.WHITE.lerp(Color("#ffd0b2"), danger)
	var ground_tint: Color = Color.WHITE.lerp(Color("#ffd1b0"), danger)
	draw_texture_rect(SKY, SKY_RECT, false, sky_tint)
	# O relevo oculta o meteoro quando o halo cruza o horizonte.
	_draw_background_meteor(danger)
	draw_texture_rect(RIDGES, RIDGE_RECT, false, ridge_tint)
	draw_colored_polygon(_ground_shape, ground_tint, _ground_uv, GROUND)
	draw_polyline(_trail, Color(0.92, 0.69, 0.43, 0.50), 3.0)


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
