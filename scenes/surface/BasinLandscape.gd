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

var _ground_shape: PackedVector2Array = PackedVector2Array(TERRAIN)
var _ground_uv: PackedVector2Array = PackedVector2Array()
var _trail: PackedVector2Array = PackedVector2Array()
var _forest_shape: PackedVector2Array = PackedVector2Array()
var _forest_trail: PackedVector2Array = PackedVector2Array()
var _snow_shape: PackedVector2Array = PackedVector2Array()
var _snow_trail: PackedVector2Array = PackedVector2Array()
var _meteor_anim_t: float = 0.0
var _meteor_frame: int = -1
var _last_danger: float = -1.0
var _last_biome: StringName = &""


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for point: Vector2 in TERRAIN:
		_ground_uv.append((point - GROUND_RECT.position) / GROUND_RECT.size)

	_trail = _bake_smooth_path(FOOTPATH)
	_forest_shape = _build_ground_polygon(FOREST_TERRAIN_TOP)
	_forest_trail = _bake_smooth_path(FOREST_FOOTPATH)
	_snow_shape = _build_ground_polygon(SNOW_TERRAIN_TOP)
	_snow_trail = _bake_smooth_path(SNOW_FOOTPATH)

	Events.danger_level_changed.connect(_on_danger_changed)
	Events.biome_changed.connect(_on_biome_changed)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	var d: float = clampf(GameState.danger_level, 0.0, 1.0)
	var biome: StringName = _get_active_biome()
	var danger_changed: bool = not is_equal_approx(d, _last_danger)
	var biome_changed: bool = biome != _last_biome
	var has_ambient_motion: bool = (biome == &"forest" or biome == &"snow")
	if not GameState.meteor_active and not danger_changed and not biome_changed and not has_ambient_motion:
		return
	_last_danger = d
	_last_biome = biome
	_meteor_anim_t += delta
	var fps: float = METEOR_REDRAW_FPS if GameState.meteor_active else AMBIENT_REDRAW_FPS
	var frame: int = floori(_meteor_anim_t * fps)
	if danger_changed or biome_changed or frame != _meteor_frame:
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
	draw_set_transform(Vector2.ZERO, 0.0, size / MAP_SIZE)
	var danger: float = clampf(GameState.danger_level, 0.0, 1.0)
	var biome: StringName = _get_active_biome()
	if biome == &"forest":
		_draw_forest(danger)
	elif biome == &"snow":
		_draw_snow(danger)
	else:
		_draw_amber_basin(danger)


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
	_draw_edge_marker("◀ Floresta", Vector2(10.0, 146.0), true, Color("#3a2822"), Color("#8db870"), Color("#fff2cc"))
	_draw_edge_marker("Neve ▶", Vector2(470.0, 152.0), false, Color("#263547"), Color("#94d0f0"), Color("#ecf8ff"))


func _draw_forest(danger: float) -> void:
	var warm_mix: float = danger * 0.58
	# 1. Céu filtrado pela copa esmeralda-dourada.
	var sky_bands: Array[Color] = [
		Color("#1e4438").lerp(Color("#6b3b34"), warm_mix),
		Color("#2e5f49").lerp(Color("#934f3d"), warm_mix),
		Color("#467e59").lerp(Color("#be6d4a"), warm_mix),
		Color("#74a068").lerp(Color("#db8d5c"), warm_mix),
		Color("#b6bd7a").lerp(Color("#eea96d"), warm_mix),
		Color("#e5d495").lerp(Color("#ffc484"), warm_mix),
	]
	var band_h: float = 136.0 / float(sky_bands.size())
	for bi: int in range(sky_bands.size()):
		draw_rect(Rect2(0.0, float(bi) * band_h, MAP_SIZE.x, band_h + 1.5), sky_bands[bi])

	# Raios suaves de sol atravessando a névoa da floresta.
	var beam_col: Color = Color(1.0, 0.94, 0.68, 0.10)
	for ray_i: int in range(4):
		var rx: float = 75.0 + float(ray_i) * 105.0
		var beam := PackedVector2Array([
			Vector2(rx, 0.0), Vector2(rx + 28.0, 0.0),
			Vector2(rx - 22.0, 130.0), Vector2(rx - 52.0, 130.0),
		])
		draw_colored_polygon(beam, beam_col)

	# Nuvens douradas suaves atrás das sequoias.
	var cloud_col: Color = Color("#f6e5ad", 0.42).lerp(Color("#ffc399", 0.48), warm_mix)
	draw_rect(Rect2(138.0, 34.0, 44.0, 7.0), cloud_col)
	draw_rect(Rect2(146.0, 29.0, 26.0, 6.0), cloud_col)
	draw_rect(Rect2(308.0, 26.0, 52.0, 8.0), cloud_col)
	draw_rect(Rect2(320.0, 21.0, 28.0, 6.0), cloud_col)

	# 2. Meteoro distante atrás das montanhas e sequoias.
	_draw_background_meteor(danger)

	# 3. Cadeia de serras enevoadas verde-petróleo.
	var far_ridge_col: Color = Color("#2e5a54").lerp(Color("#5e4d4d"), danger * 0.45)
	var far_rim_col: Color = Color("#6f9c74").lerp(Color("#b68b6c"), danger * 0.45)
	var far_ridge := PackedVector2Array([
		Vector2(0.0, 96.0), Vector2(46.0, 76.0), Vector2(98.0, 82.0), Vector2(154.0, 64.0),
		Vector2(216.0, 78.0), Vector2(276.0, 68.0), Vector2(342.0, 80.0), Vector2(410.0, 62.0),
		Vector2(480.0, 74.0), Vector2(480.0, 145.0), Vector2(0.0, 145.0),
	])
	draw_colored_polygon(far_ridge, far_ridge_col)
	for ri: int in range(8):
		draw_line(far_ridge[ri], far_ridge[ri + 1], far_rim_col, 1.5)

	# 4. Silhuetas de sequoias gigantes e copas pré-históricas.
	var trunk_far: Color = Color("#243f3a").lerp(Color("#473837"), danger * 0.35)
	var canopy_dark: Color = Color("#1e4838").lerp(Color("#3d3e34"), danger * 0.35)
	var canopy_mid: Color = Color("#2e6647").lerp(Color("#5d5d3f"), danger * 0.35)
	var canopy_lit: Color = Color("#5b9454").lerp(Color("#93834d"), danger * 0.35)
	var redwood_xs: Array[float] = [54.0, 108.0, 186.0, 244.0, 296.0, 378.0, 434.0]
	for ti: int in range(redwood_xs.size()):
		var tx: float = redwood_xs[ti]
		var tw: float = 9.0 + float(ti % 3) * 3.0
		var top_y: float = 42.0 + float((ti * 17) % 24)
		draw_rect(Rect2(tx - tw * 0.5, top_y, tw, 138.0 - top_y), trunk_far)
		draw_rect(Rect2(tx - tw * 0.5 + 1.0, top_y, 2.0, 138.0 - top_y), Color("#466452", 0.55))
		draw_circle(Vector2(tx, top_y + 10.0), 18.0 + float(ti % 2) * 5.0, canopy_dark)
		draw_circle(Vector2(tx - 10.0, top_y + 16.0), 13.0, canopy_mid)
		draw_circle(Vector2(tx + 9.0, top_y + 14.0), 12.0, canopy_mid)
		draw_circle(Vector2(tx - 3.0, top_y + 5.0), 10.0, canopy_lit)

	# Folhagens e samambaias na base das árvores (mesmo ritmo visual de amber_ridges.png).
	for fi: int in range(18):
		var fx: float = float(fi) * 28.0 + 6.0
		var fy: float = 114.0 + sin(float(fi) * 1.4) * 5.0
		draw_circle(Vector2(fx, fy), 14.0, canopy_dark)
		draw_circle(Vector2(fx + 6.0, fy - 4.0), 9.0, canopy_mid)
		draw_rect(Rect2(fx - 4.0, fy - 11.0, 8.0, 2.0), canopy_lit)

	# 5. Solo caminhável coberto de musgo + clareiras de sol + raízes.
	var turf_base: Color = Color("#4c7946").lerp(Color("#736b44"), danger * 0.35)
	draw_colored_polygon(_forest_shape, turf_base)
	draw_polyline(PackedVector2Array(FOREST_TERRAIN_TOP), Color("#254229", 0.85), 2.5)
	draw_polyline(PackedVector2Array(FOREST_TERRAIN_TOP), Color("#7ab360", 0.72), 1.2)

	# Faixas de musgo sombreado e poças de luz filtrada pela copa.
	var dapple_lit: Color = Color("#74a558", 0.55)
	var dapple_sun: Color = Color("#a8c96b", 0.42)
	var dapple_shade: Color = Color("#365a36", 0.50)
	var patches: Array[Vector3] = [
		Vector3(96.0, 146.0, 28.0), Vector3(162.0, 154.0, 34.0), Vector3(236.0, 178.0, 38.0),
		Vector3(316.0, 152.0, 32.0), Vector3(392.0, 174.0, 30.0), Vector3(446.0, 146.0, 24.0),
	]
	for p: Vector3 in patches:
		draw_rect(Rect2(p.x - p.z, p.y - 5.0, p.z * 2.0, 10.0), dapple_lit)
		draw_rect(Rect2(p.x - p.z * 0.55, p.y - 3.0, p.z * 1.1, 5.0), dapple_sun)
	draw_rect(Rect2(24.0, 184.0, 128.0, 12.0), dapple_shade)
	draw_rect(Rect2(276.0, 188.0, 160.0, 11.0), dapple_shade)

	# Trilha de terra quente ligando as estruturas até a Bacia do Âmbar à direita.
	draw_polyline(_forest_trail, Color("#573726", 0.48), 9.0)
	draw_polyline(_forest_trail, Color("#996945", 0.85), 6.0)
	draw_polyline(_forest_trail, Color("#c79363", 0.60), 2.5)

	# Samambaias, pedras com musgo e pequenas flores silvestres espalhadas.
	var tufts: Array[Vector2] = [
		Vector2(66.0, 138.0), Vector2(92.0, 182.0), Vector2(188.0, 144.0),
		Vector2(226.0, 192.0), Vector2(272.0, 146.0), Vector2(368.0, 186.0),
		Vector2(412.0, 136.0), Vector2(448.0, 178.0),
	]
	for idx: int in range(tufts.size()):
		var pt: Vector2 = tufts[idx]
		draw_rect(Rect2(pt.x - 4.0, pt.y, 9.0, 2.0), Color("#26442d"))
		draw_rect(Rect2(pt.x - 3.0, pt.y - 2.0, 3.0, 2.0), Color("#5e9952"))
		draw_rect(Rect2(pt.x + 1.0, pt.y - 3.0, 3.0, 3.0), Color("#7eb862"))
		if idx % 2 == 0:
			draw_rect(Rect2(pt.x + 5.0, pt.y - 1.0, 2.0, 2.0), Color("#f2d56e") if idx % 4 == 0 else Color("#ea767b"))

	# Corte geológico inferior (mesma identidade visual em camadas de amber_ground.png).
	draw_rect(Rect2(0.0, 208.0, MAP_SIZE.x, 4.0), Color("#2c4a2e"))
	draw_rect(Rect2(0.0, 211.0, MAP_SIZE.x, 9.0), Color("#5c3a2a"))
	draw_rect(Rect2(0.0, 220.0, MAP_SIZE.x, 10.0), Color("#422822"))
	draw_rect(Rect2(0.0, 230.0, MAP_SIZE.x, 10.0), Color("#2a1e26"))
	for seg_i: int in range(16):
		var sx: float = float(seg_i) * 32.0
		draw_rect(Rect2(sx + 6.0, 211.0, 12.0, 2.0), Color("#3c643b"))
		draw_rect(Rect2(sx + 10.0, 215.0, 8.0, 2.0), Color("#7a4d36"))
		draw_rect(Rect2(sx + 18.0, 224.0, 4.0, 2.0), Color("#edaa48", 0.55) if seg_i % 3 == 0 else Color("#5e3c32"))

	# 6. Barreira fechada à esquerda: troncos colossais de sequoia ancestral + raízes.
	draw_rect(Rect2(0.0, 0.0, 20.0, 216.0), Color("#46251f"))
	draw_rect(Rect2(14.0, 0.0, 6.0, 214.0), Color("#69392c"))
	draw_rect(Rect2(18.0, 0.0, 2.5, 212.0), Color("#94583c"))
	draw_rect(Rect2(20.0, 0.0, 2.0, 212.0), INK)
	# Fendas de casca e raízes avançando no chão esquerdo.
	for by: int in range(6, 204, 14):
		draw_rect(Rect2(4.0, float(by), 3.0, 9.0), Color("#2f1817"))
		draw_rect(Rect2(11.0, float(by + 4), 2.0, 8.0), Color("#3a1f1c"))
	var root_poly := PackedVector2Array([
		Vector2(0.0, 174.0), Vector2(20.0, 182.0), Vector2(36.0, 196.0),
		Vector2(42.0, 206.0), Vector2(0.0, 208.0),
	])
	draw_colored_polygon(root_poly, Color("#593026"))
	draw_polyline(PackedVector2Array([Vector2(18.0, 182.0), Vector2(35.0, 196.0), Vector2(41.0, 205.0)]), Color("#94583c"), 1.5)
	# Copa densa pendente no canto superior esquerdo.
	draw_circle(Vector2(16.0, 18.0), 34.0, canopy_dark)
	draw_circle(Vector2(34.0, 8.0), 22.0, canopy_mid)
	draw_circle(Vector2(26.0, 22.0), 14.0, canopy_lit)

	# Esporos dourados flutuando suavemente na floresta.
	for sp_i: int in range(10):
		var seed_f: float = float(sp_i) * 1.91
		var px: float = fposmod(46.0 + seed_f * 41.0 + sin(_meteor_anim_t * 0.8 + seed_f) * 8.0, 446.0) + 18.0
		var py: float = 128.0 + fposmod(seed_f * 27.0 - _meteor_anim_t * (5.0 + float(sp_i % 3) * 2.0), 74.0)
		var alpha: float = 0.35 + 0.35 * sin(_meteor_anim_t * 2.4 + seed_f)
		draw_rect(Rect2(roundf(px), roundf(py), 1.5, 1.5), Color(0.97, 0.94, 0.56, alpha))

	# 7. Placa de passagem à direita de volta para a Bacia do Âmbar.
	_draw_edge_marker("Bacia do Âmbar ▶", Vector2(470.0, 146.0), false, Color("#402a20"), Color("#edaa48"), Color("#fff3cf"))


func _draw_snow(danger: float) -> void:
	var warm_mix: float = danger * 0.55
	# 1. Céu crepuscular glacial (esquenta para coral com o meteoro).
	var sky_bands: Array[Color] = [
		Color("#1f2e4f").lerp(Color("#6b3648"), warm_mix),
		Color("#2e4870").lerp(Color("#8e4c54"), warm_mix),
		Color("#496e96").lerp(Color("#b66a65"), warm_mix),
		Color("#749ec2").lerp(Color("#d88e7c"), warm_mix),
		Color("#a8cae0").lerp(Color("#eeb29c"), warm_mix),
		Color("#d6e9f5").lerp(Color("#ffd2bc"), warm_mix),
	]
	var band_h: float = 136.0 / float(sky_bands.size())
	for bi: int in range(sky_bands.size()):
		draw_rect(Rect2(0.0, float(bi) * band_h, MAP_SIZE.x, band_h + 1.5), sky_bands[bi])

	# Aurora boreal sutil ondulando no céu polar.
	for au_i: int in range(22):
		var ax: float = 28.0 + float(au_i) * 14.0
		var wave: float = sin(_meteor_anim_t * 1.1 + float(au_i) * 0.42) * 5.0
		var ay: float = 16.0 + wave
		var au_a: float = (0.14 + 0.08 * sin(_meteor_anim_t * 1.7 + float(au_i) * 0.6)) * (1.0 - danger * 0.45)
		draw_rect(Rect2(ax, ay, 11.0, 12.0), Color(0.45, 0.95, 0.84, au_a))
		draw_rect(Rect2(ax + 3.0, ay - 5.0, 8.0, 7.0), Color(0.64, 0.72, 1.0, au_a * 0.75))

	# 2. Meteoro distante atrás dos picos nevados.
	_draw_background_meteor(danger)

	# 3. Picos alpinos recortados e geleiras ao fundo.
	var peak_shade: Color = Color("#48668a").lerp(Color("#7c5d69"), danger * 0.45)
	var peak_lit: Color = Color("#cfe5f5").lerp(Color("#f2cec4"), danger * 0.42)
	var peaks := PackedVector2Array([
		Vector2(0.0, 106.0), Vector2(36.0, 68.0), Vector2(78.0, 88.0), Vector2(126.0, 48.0),
		Vector2(174.0, 84.0), Vector2(228.0, 58.0), Vector2(278.0, 86.0), Vector2(338.0, 44.0),
		Vector2(394.0, 78.0), Vector2(442.0, 56.0), Vector2(480.0, 74.0),
		Vector2(480.0, 145.0), Vector2(0.0, 145.0),
	])
	draw_colored_polygon(peaks, peak_shade)

	# Faces nevadas iluminadas em cada pico.
	var summits: Array[Vector2] = [
		Vector2(36.0, 68.0), Vector2(126.0, 48.0), Vector2(228.0, 58.0),
		Vector2(338.0, 44.0), Vector2(442.0, 56.0),
	]
	for sm: Vector2 in summits:
		var snow_face := PackedVector2Array([
			sm, sm + Vector2(22.0, 26.0), sm + Vector2(4.0, 18.0), sm + Vector2(-8.0, 22.0),
		])
		draw_colored_polygon(snow_face, peak_lit)

	# Pinheiros nevados na base das montanhas.
	var pine_col: Color = Color("#284357")
	var pine_snow: Color = Color("#e3f2fc")
	for pi: int in range(15):
		var px: float = 18.0 + float(pi) * 30.0
		var py: float = 122.0 + sin(float(pi) * 1.3) * 4.0
		var tree := PackedVector2Array([
			Vector2(px, py - 18.0), Vector2(px + 8.0, py + 4.0), Vector2(px - 8.0, py + 4.0),
		])
		draw_colored_polygon(tree, pine_col)
		var cap := PackedVector2Array([
			Vector2(px, py - 18.0), Vector2(px + 4.5, py - 8.0), Vector2(px - 4.5, py - 8.0),
		])
		draw_colored_polygon(cap, pine_snow)

	# 4. Planalto de neve ampla e caminhável.
	var snow_base: Color = Color("#dcebf6").lerp(Color("#f0d8cf"), danger * 0.28)
	draw_colored_polygon(_snow_shape, snow_base)
	draw_polyline(PackedVector2Array(SNOW_TERRAIN_TOP), Color("#6c95b8", 0.75), 2.5)
	draw_polyline(PackedVector2Array(SNOW_TERRAIN_TOP), Color("#f4fbff", 0.90), 1.3)

	# Ondulações de neve, reflexos cristalinos e riacho congelado.
	draw_rect(Rect2(12.0, 136.0, 120.0, 8.0), Color("#eef7fe", 0.72))
	draw_rect(Rect2(292.0, 130.0, 134.0, 9.0), Color("#eef7fe", 0.72))
	draw_rect(Rect2(36.0, 182.0, 150.0, 12.0), Color("#b4cfe4", 0.55))
	draw_rect(Rect2(280.0, 180.0, 148.0, 12.0), Color("#b4cfe4", 0.55))

	# Riacho de gelo azul-cristalino cruzando o vale inferior.
	var creek := PackedVector2Array([
		Vector2(174.0, 137.0), Vector2(218.0, 156.0), Vector2(248.0, 182.0), Vector2(236.0, 206.0),
		Vector2(212.0, 206.0), Vector2(222.0, 182.0), Vector2(194.0, 158.0), Vector2(158.0, 137.0),
	])
	draw_colored_polygon(creek, Color("#7eb7dc", 0.76))
	draw_line(Vector2(176.0, 144.0), Vector2(218.0, 168.0), Color("#dcf6ff", 0.75), 1.5)
	draw_line(Vector2(224.0, 178.0), Vector2(220.0, 198.0), Color("#eefaff", 0.65), 1.5)

	# Trilha compactada na neve vinda da Bacia do Âmbar à esquerda.
	draw_polyline(_snow_trail, Color("#88acc7", 0.55), 8.5)
	draw_polyline(_snow_trail, Color("#bcd7ea", 0.85), 5.5)
	draw_polyline(_snow_trail, Color("#e8f5fd", 0.72), 2.2)

	# Rochas geladas e cristais de gelo no terreno.
	var ice_nodes: Array[Vector2] = [
		Vector2(56.0, 174.0), Vector2(106.0, 140.0), Vector2(276.0, 142.0),
		Vector2(382.0, 184.0), Vector2(414.0, 142.0),
	]
	for ic: Vector2 in ice_nodes:
		draw_rect(Rect2(ic.x - 4.0, ic.y, 9.0, 3.0), Color("#6288ab"))
		draw_rect(Rect2(ic.x - 3.0, ic.y - 2.0, 6.0, 3.0), Color("#a8d6f0"))
		draw_rect(Rect2(ic.x - 2.0, ic.y - 3.0, 3.0, 2.0), Color("#f4fbff"))

	# Corte geológico glacial inferior.
	draw_rect(Rect2(0.0, 207.0, MAP_SIZE.x, 4.0), Color("#94bedb"))
	draw_rect(Rect2(0.0, 211.0, MAP_SIZE.x, 9.0), Color("#5888af"))
	draw_rect(Rect2(0.0, 220.0, MAP_SIZE.x, 10.0), Color("#324968"))
	draw_rect(Rect2(0.0, 230.0, MAP_SIZE.x, 10.0), Color("#1f273e"))
	for seg_i: int in range(15):
		var sx: float = float(seg_i) * 34.0
		draw_rect(Rect2(sx + 6.0, 211.0, 10.0, 2.0), Color("#cde9fa", 0.65))
		draw_rect(Rect2(sx + 14.0, 223.0, 6.0, 2.0), Color("#8be2ff", 0.50) if seg_i % 2 == 0 else Color("#466487"))

	# 5. Barreira fechada à direita: paredão monumental de geleira cristalina.
	var glacier_wall := PackedVector2Array([
		Vector2(458.0, 0.0), Vector2(480.0, 0.0), Vector2(480.0, 216.0),
		Vector2(442.0, 210.0), Vector2(448.0, 178.0), Vector2(454.0, 140.0),
		Vector2(450.0, 96.0), Vector2(458.0, 52.0),
	])
	draw_colored_polygon(glacier_wall, Color("#5684ab"))
	var glacier_facet := PackedVector2Array([
		Vector2(458.0, 12.0), Vector2(474.0, 0.0), Vector2(474.0, 206.0),
		Vector2(452.0, 198.0), Vector2(458.0, 146.0), Vector2(455.0, 94.0),
	])
	draw_colored_polygon(glacier_facet, Color("#93c8e8"))
	var glacier_rim := PackedVector2Array([
		Vector2(458.0, 0.0), Vector2(458.0, 52.0), Vector2(450.0, 96.0),
		Vector2(454.0, 140.0), Vector2(448.0, 178.0), Vector2(442.0, 210.0),
	])
	draw_polyline(glacier_rim, INK, 1.8)
	draw_line(Vector2(461.0, 18.0), Vector2(458.0, 186.0), Color("#e8f8ff", 0.72), 1.5)

	# Flocos de neve caindo suavemente e brilhos de gelo.
	for fl_i: int in range(14):
		var seed_f: float = float(fl_i) * 2.17
		var fx: float = fposmod(seed_f * 37.0 + sin(_meteor_anim_t * 1.4 + seed_f) * 9.0, 444.0) + 10.0
		var fy: float = fposmod(seed_f * 29.0 + _meteor_anim_t * (12.0 + float(fl_i % 3) * 4.0), 196.0) + 6.0
		var fsz: float = 1.5 if fl_i % 2 == 0 else 1.0
		draw_rect(Rect2(roundf(fx), roundf(fy), fsz, fsz), Color(0.96, 0.99, 1.0, 0.68))

	# 6. Placa de passagem à esquerda de volta para a Bacia do Âmbar.
	_draw_edge_marker("◀ Bacia do Âmbar", Vector2(10.0, 152.0), true, Color("#3a2822"), Color("#edaa48"), Color("#fff3cf"))


## Desenha uma placa sutil em pixel art nas bordas laterais para sinalizar passagem entre biomas.
func _draw_edge_marker(
		label_text: String,
		map_anchor: Vector2,
		align_left: bool,
		bg_col: Color,
		border_col: Color,
		text_col: Color
) -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var scale_v: Vector2 = size / MAP_SIZE
	var bob: float = sin(_meteor_anim_t * 3.0) * 2.5
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

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var rect := Rect2(roundf(box_x), roundf(box_y), roundf(box_w), roundf(box_h))
	draw_rect(Rect2(rect.position + Vector2(0.0, 2.0), rect.size), Color(0.08, 0.05, 0.06, 0.45))
	draw_rect(rect, Color(bg_col.r, bg_col.g, bg_col.b, 0.88))
	draw_rect(rect, Color(border_col.r, border_col.g, border_col.b, 0.92), false, 2.0)
	var text_pos := Vector2(rect.position.x + pad_x, rect.position.y + pad_y + font.get_ascent(font_sz) - 1.0)
	draw_string_outline(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_sz, 3, INK)
	draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_sz, text_col)
	draw_set_transform(Vector2.ZERO, 0.0, scale_v)


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
