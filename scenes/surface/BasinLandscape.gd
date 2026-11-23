extends Control
## Camadas multi-bioma da Superfície (Floresta Ancestral, Bacia do Âmbar, Cordilheira Nevada)
## e colisão exata do terreno caminhável no atlas lógico de 480 × 240.

const MAP_SIZE: Vector2 = Vector2(480.0, 240.0)
const WALKABLE_TOP_MARGIN: float = 6.0

const SKY: Texture2D = preload("res://assets/sprites/surface/background/amber_sky.png")
const RIDGES: Texture2D = preload("res://assets/sprites/surface/background/amber_ridges.png")
const GROUND: Texture2D = preload("res://assets/sprites/surface/background/amber_ground.png")
const SKY_RECT: Rect2 = Rect2(0.0, 0.0, 480.0, 127.0)
const RIDGE_RECT: Rect2 = Rect2(0.0, -46.0, 480.0, 220.0)
const GROUND_RECT: Rect2 = Rect2(0.0, 100.0, 480.0, 148.0)
const BIOME_HORIZON_RECT: Rect2 = Rect2(0.0, 0.0, 480.0, 144.0)
const BIOME_GROUND_RECT: Rect2 = Rect2(0.0, 120.0, 480.0, 120.0)
const FOREST_SKY: Texture2D = preload("res://assets/sprites/surface/background/forest_sky.png")
const FOREST_RIDGES: Texture2D = preload("res://assets/sprites/surface/background/forest_ridges.png")
const FOREST_GROUND: Texture2D = preload("res://assets/sprites/surface/background/forest_ground.png")
const SNOW_SKY: Texture2D = preload("res://assets/sprites/surface/background/snow_sky.png")
const SNOW_RIDGES: Texture2D = preload("res://assets/sprites/surface/background/snow_ridges.png")
const SNOW_GROUND: Texture2D = preload("res://assets/sprites/surface/background/snow_ground.png")

## Borda superior do chão caminhável da Bacia do Âmbar (expandida para acomodar
## as estruturas sobre terreno sólido e amplo até a borda do cânion em y ~ 206).
const TERRAIN_TOP: Array[Vector2] = [
	Vector2(0.0, 122.0), Vector2(44.0, 114.0), Vector2(78.0, 114.0), Vector2(114.0, 134.0),
	Vector2(148.0, 145.0), Vector2(186.0, 143.0), Vector2(224.0, 124.0), Vector2(252.0, 122.0),
	Vector2(292.0, 110.0), Vector2(334.0, 109.0), Vector2(364.0, 128.0), Vector2(406.0, 129.0),
	Vector2(448.0, 125.0), Vector2(480.0, 130.0),
]
const TERRAIN: Array[Vector2] = [
	Vector2(0.0, 122.0), Vector2(44.0, 114.0), Vector2(78.0, 114.0), Vector2(114.0, 134.0),
	Vector2(148.0, 145.0), Vector2(186.0, 143.0), Vector2(224.0, 124.0), Vector2(252.0, 122.0),
	Vector2(292.0, 110.0), Vector2(334.0, 109.0), Vector2(364.0, 128.0), Vector2(406.0, 129.0),
	Vector2(448.0, 125.0), Vector2(480.0, 130.0), Vector2(480.0, 240.0), Vector2(0.0, 240.0),
]
const FOOTPATH: Array[Vector2] = [
	Vector2(0.0, 146.0), Vector2(58.0, 138.0), Vector2(106.0, 154.0), Vector2(158.0, 174.0),
	Vector2(206.0, 162.0), Vector2(238.0, 146.0), Vector2(276.0, 144.0), Vector2(318.0, 132.0),
	Vector2(362.0, 148.0), Vector2(416.0, 155.0), Vector2(480.0, 152.0),
]

## Floresta Ancestral (esquerda da Bacia do Âmbar).
const FOREST_TERRAIN_TOP: Array[Vector2] = [
	Vector2(0.0, 128.0), Vector2(62.0, 123.0), Vector2(114.0, 124.0), Vector2(142.0, 126.0),
	Vector2(198.0, 134.0), Vector2(252.0, 136.0), Vector2(304.0, 130.0), Vector2(332.0, 128.0),
	Vector2(394.0, 127.0), Vector2(442.0, 124.0), Vector2(480.0, 122.0),
]
const FOREST_FOOTPATH: Array[Vector2] = [
	Vector2(56.0, 158.0), Vector2(102.0, 154.0), Vector2(142.0, 158.0), Vector2(206.0, 166.0),
	Vector2(268.0, 168.0), Vector2(332.0, 163.0), Vector2(404.0, 154.0), Vector2(480.0, 146.0),
]

## Cordilheira Nevada (direita da Bacia do Âmbar).
const SNOW_TERRAIN_TOP: Array[Vector2] = [
	Vector2(0.0, 130.0), Vector2(64.0, 126.0), Vector2(116.0, 127.0), Vector2(146.0, 129.0),
	Vector2(214.0, 137.0), Vector2(268.0, 132.0), Vector2(314.0, 123.0), Vector2(334.0, 122.0),
	Vector2(396.0, 125.0), Vector2(444.0, 129.0), Vector2(480.0, 132.0),
]
const SNOW_FOOTPATH: Array[Vector2] = [
	Vector2(0.0, 152.0), Vector2(72.0, 156.0), Vector2(146.0, 160.0), Vector2(216.0, 168.0),
	Vector2(278.0, 160.0), Vector2(334.0, 154.0), Vector2(390.0, 158.0), Vector2(432.0, 162.0),
]

const METEOR_REDRAW_FPS: float = 14.0
const AMBIENT_REDRAW_FPS: float = 10.0
const INK: Color = Color("#261820")
const ARK_ANCHOR: Vector2 = Vector2(308.0, 196.0)

var _ground_shape: PackedVector2Array = PackedVector2Array(TERRAIN)
var _ground_uv: PackedVector2Array = PackedVector2Array()
var _trail: PackedVector2Array = PackedVector2Array()
var _egg_to_quarry_trail: PackedVector2Array = PackedVector2Array()
var _forest_shape: PackedVector2Array = PackedVector2Array()
var _forest_uv: PackedVector2Array = PackedVector2Array()
var _forest_trail: PackedVector2Array = PackedVector2Array()
var _snow_shape: PackedVector2Array = PackedVector2Array()
var _snow_uv: PackedVector2Array = PackedVector2Array()
var _snow_trail: PackedVector2Array = PackedVector2Array()
var _meteor_anim_t: float = 0.0
var _meteor_frame: int = -1
var _last_danger: float = -1.0
var _last_biome: StringName = &""
var _last_quarry_clue: bool = false
var _last_slab_broken: bool = false
var _last_forest_built: bool = false
var _edge_overlay: Control = null
var _pending_edge_markers: Array[Dictionary] = []


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_edge_overlay = Control.new()
	_edge_overlay.name = "EdgeMarkersOverlay"
	_edge_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_edge_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_edge_overlay.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_edge_overlay.draw.connect(_on_edge_overlay_draw)
	add_child(_edge_overlay)
	move_child(_edge_overlay, 0)
	for point: Vector2 in TERRAIN:
		_ground_uv.append((point - GROUND_RECT.position) / GROUND_RECT.size)

	_trail = _bake_smooth_path(FOOTPATH)
	_egg_to_quarry_trail = _build_egg_to_quarry_trail(_trail)
	_forest_shape = _build_ground_polygon(FOREST_TERRAIN_TOP)
	_forest_uv = _build_ground_uv(_forest_shape)
	_forest_trail = _bake_smooth_path(FOREST_FOOTPATH)
	_snow_shape = _build_ground_polygon(SNOW_TERRAIN_TOP)
	_snow_uv = _build_ground_uv(_snow_shape)
	_snow_trail = _bake_smooth_path(SNOW_FOOTPATH)

	Events.danger_level_changed.connect(_on_danger_changed)
	Events.biome_changed.connect(_on_biome_changed)
	Events.orange_rock_broken.connect(queue_redraw)
	Events.quarry_vein_opened.connect(queue_redraw)
	Events.rubble_rebuilt.connect(queue_redraw.unbind(2))
	Events.ark_module_built.connect(queue_redraw.unbind(2))
	Events.fossil_found.connect(queue_redraw.unbind(2))
	Events.run_started.connect(queue_redraw.unbind(1))
	Events.game_loaded.connect(queue_redraw)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var d: float = clampf(GameState.danger_level, 0.0, 1.0)
	var biome: StringName = _get_active_biome()
	var clue_now: bool = GameState.quarry_clue_active
	var slab_now: bool = GameState.is_quarry_slab_broken()
	var forest_now: bool = GameState.is_station_built(&"forest_grove")
	var danger_changed: bool = not is_equal_approx(d, _last_danger)
	var biome_changed: bool = biome != _last_biome
	var world_changed: bool = (clue_now != _last_quarry_clue) or (slab_now != _last_slab_broken) or (forest_now != _last_forest_built)
	var has_amber_motion: bool = (biome == &"amber_basin" and (clue_now or (slab_now and not forest_now)))
	var has_ambient_motion: bool = (biome == &"forest" or biome == &"snow" or has_amber_motion)
	if not GameState.meteor_active and not danger_changed and not biome_changed and not world_changed and not has_ambient_motion:
		return
	_last_danger = d
	_last_biome = biome
	_last_quarry_clue = clue_now
	_last_slab_broken = slab_now
	_last_forest_built = forest_now
	_meteor_anim_t += delta
	var fps: float = METEOR_REDRAW_FPS if GameState.meteor_active else AMBIENT_REDRAW_FPS
	var frame: int = floori(_meteor_anim_t * fps)
	if danger_changed or biome_changed or world_changed or frame != _meteor_frame:
		_meteor_frame = frame
		queue_redraw()


func _on_danger_changed(_danger: float) -> void:
	queue_redraw()


func _on_biome_changed(_biome_id: StringName) -> void:
	_last_biome = _get_active_biome()
	queue_redraw()


## Retorna o menor Y seguro onde os pés do protagonista podem pisar em `biome` no `map_x`,
## interpolando a borda superior do polígono de chão com folga anti-sobreposição.
func get_walkable_min_y(biome: StringName, map_x: float) -> float:
	var profile: Array[Vector2] = TERRAIN_TOP
	if biome == &"forest":
		profile = FOREST_TERRAIN_TOP
	elif biome == &"snow":
		profile = SNOW_TERRAIN_TOP
	return _sample_terrain_top_y(profile, map_x) + WALKABLE_TOP_MARGIN


## Retorna o maior Y seguro antes da borda do desfiladeiro/corte inferior.
func get_walkable_max_y(biome: StringName, map_x: float) -> float:
	var x: float = clampf(map_x, 0.0, MAP_SIZE.x)
	if biome == &"forest":
		return 206.0 + sin(x * 0.025) * 1.5
	if biome == &"snow":
		return 205.0 + cos(x * 0.022) * 1.5
	return 206.0 + sin(x * 0.020) * 1.5


func _get_active_biome() -> StringName:
	return GameState.current_biome if GameState.current_biome != &"" else GameState.BIOME_AMBER


static func _build_ground_polygon(top_edge: Array[Vector2]) -> PackedVector2Array:
	var poly: PackedVector2Array = PackedVector2Array()
	for pt: Vector2 in top_edge:
		poly.append(pt)
	poly.append(Vector2(MAP_SIZE.x, MAP_SIZE.y))
	poly.append(Vector2(0.0, MAP_SIZE.y))
	return poly


static func _build_ground_uv(polygon: PackedVector2Array) -> PackedVector2Array:
	var uv: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in polygon:
		uv.append((point - BIOME_GROUND_RECT.position) / BIOME_GROUND_RECT.size)
	return uv


static func _bake_smooth_path(points: Array[Vector2]) -> PackedVector2Array:
	var path: Curve2D = Curve2D.new()
	path.bake_interval = 3.0
	for i: int in range(points.size()):
		var tangent: Vector2 = (
			points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]
		) * 0.14
		path.add_point(points[i], -tangent, tangent)
	return path.get_baked_points()


static func _sample_terrain_top_y(profile: Array[Vector2], map_x: float) -> float:
	if profile.is_empty():
		return 130.0
	var x: float = clampf(map_x, 0.0, MAP_SIZE.x)
	if x <= profile[0].x:
		return profile[0].y
	var last_idx: int = profile.size() - 1
	if x >= profile[last_idx].x:
		return profile[last_idx].y
	for i: int in range(last_idx):
		var a: Vector2 = profile[i]
		var b: Vector2 = profile[i + 1]
		if x >= a.x and x <= b.x:
			var span: float = maxf(b.x - a.x, 0.0001)
			var t: float = clampf((x - a.x) / span, 0.0, 1.0)
			return lerpf(a.y, b.y, t)
	return profile[last_idx].y


func _draw() -> void:
	if size.x <= 1.0 or size.y <= 1.0:
		return
	_pending_edge_markers.clear()
	draw_set_transform(Vector2.ZERO, 0.0, size / MAP_SIZE)
	var danger: float = clampf(GameState.danger_level, 0.0, 1.0)
	var biome: StringName = _get_active_biome()
	if biome == &"forest":
		_draw_forest(danger)
	elif biome == &"snow":
		_draw_snow(danger)
	else:
		_draw_amber_basin(danger)
	if _edge_overlay != null:
		_edge_overlay.queue_redraw()


func _draw_amber_basin(danger: float) -> void:
	var sky_tint: Color = Color.WHITE.lerp(Color("#ff9d82"), danger)
	var ridge_tint: Color = Color.WHITE.lerp(Color("#ffd0b2"), danger)
	var ground_tint: Color = Color.WHITE.lerp(Color("#ffd1b0"), danger)
	draw_texture_rect(SKY, SKY_RECT, false, sky_tint)
	# O relevo oculta o meteoro quando o halo cruza o horizonte.
	_draw_background_meteor(danger)
	draw_texture_rect(RIDGES, RIDGE_RECT, false, ridge_tint)
	draw_colored_polygon(_ground_shape, ground_tint, _ground_uv, GROUND)
	draw_polyline(_trail, Color(0.55, 0.34, 0.20, 0.28), 6.0)
	draw_polyline(_trail, Color(0.95, 0.74, 0.46, 0.56), 3.2)
	_draw_ark_clearing()
	if GameState.quarry_clue_active:
		_draw_quarry_trail_clue()

	var forest_label: String = "◀ Floresta"
	var forest_bg: Color = Color("#3a2822")
	var forest_border: Color = Color("#8db870")
	var forest_text: Color = Color("#fff2cc")
	if GameState.is_quarry_slab_broken() and not GameState.is_station_built(&"forest_grove"):
		forest_label = "◀ Floresta (15 Metal)"
		var highlight_p: float = 0.5 + 0.5 * sin(_meteor_anim_t * 3.6)
		forest_bg = Color("#4a2d1e")
		forest_border = Color("#edaa48").lerp(Color("#ffd875"), highlight_p * 0.55)
		forest_text = Color("#fff5d4")
	_draw_edge_marker(forest_label, Vector2(10.0, 158.0), true, forest_bg, forest_border, forest_text)
	_draw_edge_marker("Neve ▶", Vector2(470.0, 152.0), false, Color("#263547"), Color("#94d0f0"), Color("#ecf8ff"))


func _draw_ark_clearing() -> void:
	var spur: PackedVector2Array = PackedVector2Array([
		Vector2(265.0, 146.0), Vector2(278.0, 151.0), Vector2(286.0, 160.0),
		Vector2(296.0, 176.0), Vector2(305.0, 189.0), ARK_ANCHOR,
	])
	draw_polyline(spur, Color(0.55, 0.34, 0.20, 0.24), 5.0)
	draw_polyline(spur, Color(0.95, 0.74, 0.46, 0.42), 2.6)
	var contact_shadow: PackedVector2Array = _build_ellipse_polygon(ARK_ANCHOR, 26.0, 5.0, 20)
	draw_colored_polygon(contact_shadow, Color(0.30, 0.15, 0.12, 0.22))


func _draw_quarry_trail_clue() -> void:
	# Ondas sísmicas sutis irradiando da Pedreira pela trilha.
	var ripple_origins: Array[Vector2] = [Vector2(58.0, 136.0), Vector2(106.0, 154.0)]
	for idx: int in range(ripple_origins.size()):
		var t: float = fposmod(_meteor_anim_t * 0.58 + float(idx) * 0.5, 1.0)
		var rx: float = lerpf(7.0, 26.0, t)
		var ry: float = rx * 0.35
		var ring: PackedVector2Array = _build_ellipse_polygon(ripple_origins[idx], rx, ry, 20)
		ring.append(ring[0])
		draw_polyline(ring, Color(0.98, 0.79, 0.42, (1.0 - t) * 0.34), 1.2)

	# Partículas pulsantes guiando o olhar do Ovo até a Pedreira ao longo da trilha.
	if _egg_to_quarry_trail.size() < 2:
		return
	for mi: int in range(6):
		var progress: float = fposmod(_meteor_anim_t * 0.34 + float(mi) / 6.0, 1.0)
		var pos: Vector2 = _sample_polyline_point(_egg_to_quarry_trail, progress)
		var alpha: float = sin(progress * PI) * (0.65 + 0.30 * sin(_meteor_anim_t * 5.0 + float(mi)))
		draw_circle(pos, 2.8, Color(0.96, 0.72, 0.28, alpha * 0.28))
		draw_rect(Rect2(roundf(pos.x - 1.0), roundf(pos.y - 1.0), 2.0, 2.0), Color(1.0, 0.90, 0.62, alpha))
		var tail_pos: Vector2 = _sample_polyline_point(_egg_to_quarry_trail, maxf(progress - 0.035, 0.0))
		draw_rect(Rect2(roundf(tail_pos.x), roundf(tail_pos.y), 1.5, 1.5), Color(0.95, 0.69, 0.28, alpha * 0.65))


static func _build_egg_to_quarry_trail(trail: PackedVector2Array) -> PackedVector2Array:
	var segment: PackedVector2Array = PackedVector2Array()
	for idx: int in range(trail.size() - 1, -1, -1):
		var pt: Vector2 = trail[idx]
		if pt.x >= 56.0 and pt.x <= 240.0:
			segment.append(pt)
	return segment


static func _build_ellipse_polygon(center: Vector2, rx: float, ry: float, steps: int = 24) -> PackedVector2Array:
	var poly: PackedVector2Array = PackedVector2Array()
	for i: int in range(steps):
		var ang: float = float(i) / float(steps) * TAU
		poly.append(center + Vector2(cos(ang) * rx, sin(ang) * ry))
	return poly


static func _sample_polyline_point(points: PackedVector2Array, progress: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if points.size() == 1:
		return points[0]
	var clamped: float = clampf(progress, 0.0, 1.0)
	var scaled: float = clamped * float(points.size() - 1)
	var i0: int = mini(floori(scaled), points.size() - 2)
	var frac: float = scaled - float(i0)
	return points[i0].lerp(points[i0 + 1], frac)


func _draw_forest(danger: float) -> void:
	_draw_biome_layers(FOREST_SKY, FOREST_RIDGES, FOREST_GROUND, _forest_shape, _forest_uv, danger)
	draw_polyline(_forest_trail, Color("#523d27", 0.64), 7.0)
	draw_polyline(_forest_trail, Color("#b58b5b", 0.58), 3.0)

	# Esporos dourados sobre o chão.
	for sp_i: int in range(10):
		var seed_f: float = float(sp_i) * 1.91
		var px: float = fposmod(46.0 + seed_f * 41.0 + sin(_meteor_anim_t * 0.8 + seed_f) * 8.0, 446.0) + 18.0
		var py: float = 128.0 + fposmod(seed_f * 27.0 - _meteor_anim_t * (5.0 + float(sp_i % 3) * 2.0), 74.0)
		var alpha: float = 0.35 + 0.35 * sin(_meteor_anim_t * 2.4 + seed_f)
		draw_rect(Rect2(roundf(px), roundf(py), 1.5, 1.5), Color(0.97, 0.94, 0.56, alpha))

	_draw_edge_marker("Bacia do Âmbar ▶", Vector2(470.0, 146.0), false, Color("#402a20"), Color("#edaa48"), Color("#fff3cf"))


func _draw_snow(danger: float) -> void:
	_draw_biome_layers(SNOW_SKY, SNOW_RIDGES, SNOW_GROUND, _snow_shape, _snow_uv, danger)
	draw_polyline(_snow_trail, Color("#719dbf", 0.45), 7.0)
	draw_polyline(_snow_trail, Color("#dbf3ff", 0.64), 3.0)

	# Flocos sobre as camadas, inclusive diante da montanha.
	for fl_i: int in range(14):
		var seed_f: float = float(fl_i) * 2.17
		var fx: float = fposmod(seed_f * 37.0 + sin(_meteor_anim_t * 1.4 + seed_f) * 9.0, 444.0) + 10.0
		var fy: float = fposmod(seed_f * 29.0 + _meteor_anim_t * (12.0 + float(fl_i % 3) * 4.0), 196.0) + 6.0
		var fsz: float = 1.5 if fl_i % 2 == 0 else 1.0
		draw_rect(Rect2(roundf(fx), roundf(fy), fsz, fsz), Color(0.96, 0.99, 1.0, 0.68))

	_draw_edge_marker("◀ Bacia do Âmbar", Vector2(10.0, 152.0), true, Color("#3a2822"), Color("#edaa48"), Color("#fff3cf"))


func _draw_biome_layers(
		sky: Texture2D,
		ridges: Texture2D,
		ground: Texture2D,
		shape: PackedVector2Array,
		uv: PackedVector2Array,
		danger: float
) -> void:
	var horizon_tint: Color = Color.WHITE.lerp(Color("#ffb58e"), danger * 0.7)
	draw_texture_rect(sky, BIOME_HORIZON_RECT, false, horizon_tint)
	_draw_background_meteor(danger)
	draw_texture_rect(ridges, BIOME_HORIZON_RECT, false, horizon_tint)
	var ground_tint: Color = Color.WHITE.lerp(Color("#ffd1b0"), danger * 0.55)
	draw_colored_polygon(shape, ground_tint, uv, ground)


## Registra uma placa sutil nas bordas laterais para desenho nítido no EdgeMarkersOverlay.
func _draw_edge_marker(
		label_text: String,
		map_anchor: Vector2,
		align_left: bool,
		bg_col: Color,
		border_col: Color,
		text_col: Color
) -> void:
	_pending_edge_markers.append({
		"label_text": label_text,
		"map_anchor": map_anchor,
		"align_left": align_left,
		"bg_col": bg_col,
		"border_col": border_col,
		"text_col": text_col,
	})


func _on_edge_overlay_draw() -> void:
	if _edge_overlay == null:
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var scale_v: Vector2 = size / MAP_SIZE
	var bob: float = sin(_meteor_anim_t * 3.0) * 2.5
	for entry: Dictionary in _pending_edge_markers:
		var label_text: String = String(entry["label_text"])
		var map_anchor: Vector2 = entry["map_anchor"] as Vector2
		var align_left: bool = bool(entry["align_left"])
		var bg_col: Color = entry["bg_col"] as Color
		var border_col: Color = entry["border_col"] as Color
		var text_col: Color = entry["text_col"] as Color

		var anchor_px: Vector2 = Vector2(map_anchor.x * scale_v.x, map_anchor.y * scale_v.y)
		var font_sz: int = clampi(roundi(11.0 + scale_v.y * 0.75), 12, 16)
		var text_sz: Vector2 = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_sz)
		var pad_x: float = 10.0
		var pad_y: float = 5.0
		var box_w: float = text_sz.x + pad_x * 2.0
		var box_h: float = text_sz.y + pad_y * 2.0
		var box_x: float = clampf(
			(anchor_px.x + bob) if align_left else (anchor_px.x - box_w - bob),
			8.0,
			maxf(size.x - box_w - 8.0, 8.0),
		)
		var box_y: float = clampf(anchor_px.y - box_h * 0.5, 8.0, maxf(size.y - box_h - 8.0, 8.0))

		var rect := Rect2(roundf(box_x), roundf(box_y), roundf(box_w), roundf(box_h))
		_edge_overlay.draw_rect(Rect2(rect.position + Vector2(0.0, 2.0), rect.size), Color(0.08, 0.05, 0.06, 0.45))
		_edge_overlay.draw_rect(rect, Color(bg_col.r, bg_col.g, bg_col.b, 0.88))
		_edge_overlay.draw_rect(rect, Color(border_col.r, border_col.g, border_col.b, 0.92), false, 2.0)
		var text_pos := Vector2(rect.position.x + pad_x, rect.position.y + pad_y + font.get_ascent(font_sz) - 1.0)
		_edge_overlay.draw_string_outline(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_sz, 3, INK)
		_edge_overlay.draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_sz, text_col)


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
		draw_circle(pos + lead_dir * (radius * 0.25), maxf(0.8, radius * 0.38), Color(1.0, 0.94, 0.74, 0.92))
	else:
		draw_circle(core_pos + Vector2(-core_r * 0.22, -core_r * 0.18), core_r * 0.62, Color("#3a2228"))
		draw_circle(core_pos + Vector2(core_r * 0.28, core_r * 0.12), core_r * 0.46, Color("#5b3733"))
	if radius >= 6.0:
		var px: float = maxf(1.0, roundf(radius * 0.14))
		draw_rect(Rect2(roundf(core_pos.x - core_r * 0.42), roundf(core_pos.y - core_r * 0.24), px * 1.4, px * 1.2), INK)
		draw_rect(Rect2(roundf(core_pos.x + core_r * 0.10), roundf(core_pos.y + core_r * 0.15), px * 1.2, px), INK)
		draw_rect(Rect2(roundf(core_pos.x - core_r * 0.12), roundf(core_pos.y + core_r * 0.28), px, px), Color("#7d483b"))
	if radius >= 11.0:
		var px2: float = maxf(1.0, roundf(radius * 0.11))
		draw_rect(Rect2(roundf(core_pos.x + core_r * 0.22), roundf(core_pos.y - core_r * 0.36), px2 * 1.3, px2), INK)
		draw_rect(Rect2(roundf(core_pos.x - core_r * 0.34), roundf(core_pos.y + core_r * 0.06), px2, px2), Color(0.93, 0.67, 0.28, 0.65))
