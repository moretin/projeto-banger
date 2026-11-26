class_name ValleyBackdrop
extends Node2D
## Cenário panorâmico pré-histórico de 3200 x 1080 em escala nativa nítida (1774x887)
## com parallax suave nas camadas de céu e montanhas, detalhes orgânicos no chão e cinzas no ar.

const SKY_TEX: Texture2D = preload("res://assets/sprites/surface/background/amber_sky.png")
const RIDGES_TEX: Texture2D = preload("res://assets/sprites/surface/background/amber_ridges.png")
const GROUND_TEX: Texture2D = preload("res://assets/sprites/surface/background/amber_ground.png")

const WORLD_MIN_X: float = -360.0
const WORLD_MAX_X: float = 3600.0
const TEX_W: float = 1774.0
const TEX_H: float = 887.0
const ASH_COUNT: int = 48

var _sky_layer: Node2D = null
var _ridge_layer: Node2D = null
var _ground_layer: Node2D = null
var _sky_overlay: Node2D = null
var _ground_details: Node2D = null
var _ash_overlay: Node2D = null

var _sky_sprites: Array[Sprite2D] = []
var _ridge_sprites: Array[Sprite2D] = []
var _ground_sprites: Array[Sprite2D] = []
var _ash_particles: Array[Dictionary] = []
var _ground_pebbles: Array[Dictionary] = []
var _time: float = 0.0
var _danger_ratio: float = 0.0
var _camera_x: float = 800.0


func _ready() -> void:
	_build_backdrop_layers()
	_init_ground_details()
	_init_ash_particles()


func _exit_tree() -> void:
	_sky_sprites.clear()
	_ridge_sprites.clear()
	_ground_sprites.clear()
	_ash_particles.clear()
	_ground_pebbles.clear()


func set_camera_x(cam_x: float) -> void:
	_camera_x = cam_x
	if _sky_layer != null:
		_sky_layer.position.x = (_camera_x - 800.0) * 0.72
	if _sky_overlay != null:
		_sky_overlay.position.x = (_camera_x - 800.0) * 0.72
	if _ridge_layer != null:
		_ridge_layer.position.x = (_camera_x - 800.0) * 0.42


func _process(delta: float) -> void:
	_time += delta
	var max_dur: float = maxf(GnorpGame.BASE_RUN_DURATION, 1.0)
	var target_danger: float = clampf(1.0 - (GnorpGame.meteor_time_left / max_dur), 0.0, 1.0)
	if GnorpGame.run_state == "victory" or GnorpGame.run_state == "endless":
		target_danger = 0.12
	_danger_ratio = lerpf(_danger_ratio, target_danger, minf(delta * 3.0, 1.0))

	var sky_tint: Color = Color.WHITE.lerp(Color(1.0, 0.76, 0.58, 1.0), _danger_ratio * 0.65)
	var ridge_tint: Color = Color.WHITE.lerp(Color(1.0, 0.82, 0.68, 1.0), _danger_ratio * 0.50)
	var ground_tint: Color = Color.WHITE.lerp(Color(1.0, 0.86, 0.76, 1.0), _danger_ratio * 0.35)
	for sp: Sprite2D in _sky_sprites:
		sp.modulate = sky_tint
	for sp: Sprite2D in _ridge_sprites:
		sp.modulate = ridge_tint
	for sp: Sprite2D in _ground_sprites:
		sp.modulate = ground_tint

	for p: Dictionary in _ash_particles:
		var speed_x: float = float(p["vx"]) * (1.0 + _danger_ratio * 0.9)
		var speed_y: float = float(p["vy"])
		var px: float = float(p["x"]) + speed_x * delta
		var py: float = float(p["y"]) + speed_y * delta
		if px > WORLD_MAX_X:
			px = WORLD_MIN_X
		elif px < WORLD_MIN_X:
			px = WORLD_MAX_X
		if py < 50.0:
			py = GnorpGame.GROUND_Y - 6.0
		elif py > GnorpGame.GROUND_Y - 4.0:
			py = 70.0
		p["x"] = px
		p["y"] = py

	if _sky_overlay != null:
		_sky_overlay.queue_redraw()
	if _ash_overlay != null:
		_ash_overlay.queue_redraw()


func _build_backdrop_layers() -> void:
	var sky_base := Polygon2D.new()
	sky_base.z_index = -30
	sky_base.polygon = PackedVector2Array([
		Vector2(-1800.0, -160.0),
		Vector2(5400.0, -160.0),
		Vector2(5400.0, GnorpGame.GROUND_Y + 40.0),
		Vector2(-1800.0, GnorpGame.GROUND_Y + 40.0),
	])
	sky_base.vertex_colors = PackedColorArray([
		Color(0.32, 0.17, 0.19, 1.0),
		Color(0.32, 0.17, 0.19, 1.0),
		Color(0.92, 0.62, 0.36, 1.0),
		Color(0.92, 0.62, 0.36, 1.0),
	])
	add_child(sky_base)

	_sky_layer = Node2D.new()
	_sky_layer.name = "SkyTiles"
	_sky_layer.z_index = -25
	add_child(_sky_layer)

	_sky_overlay = Node2D.new()
	_sky_overlay.name = "AtmosphericGlow"
	_sky_overlay.z_index = -22
	_sky_overlay.draw.connect(_on_draw_sky_overlay)
	add_child(_sky_overlay)

	_ridge_layer = Node2D.new()
	_ridge_layer.name = "RidgeTiles"
	_ridge_layer.z_index = -18
	add_child(_ridge_layer)

	var subsoil := Polygon2D.new()
	subsoil.z_index = -12
	subsoil.polygon = PackedVector2Array([
		Vector2(-600.0, GnorpGame.GROUND_Y + 40.0),
		Vector2(4200.0, GnorpGame.GROUND_Y + 40.0),
		Vector2(4200.0, 1240.0),
		Vector2(-600.0, 1240.0),
	])
	subsoil.color = Color(0.24, 0.15, 0.16, 1.0)
	add_child(subsoil)

	_ground_layer = Node2D.new()
	_ground_layer.name = "GroundTiles"
	_ground_layer.z_index = -10
	add_child(_ground_layer)

	# 3 painéis nativos lado a lado espelhados (5322px totais) para cobrir 3200px + parallax sem costuras.
	for i: int in range(3):
		var tx_sky: float = -1050.0 + float(i) * TEX_W
		var tx_ground: float = -180.0 + float(i) * TEX_W
		var flip_tile: bool = (i % 2) == 1

		var sky_sp := Sprite2D.new()
		sky_sp.texture = SKY_TEX
		sky_sp.centered = false
		sky_sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sky_sp.scale = Vector2.ONE
		sky_sp.position = Vector2(tx_sky, -110.0)
		sky_sp.flip_h = flip_tile
		_sky_layer.add_child(sky_sp)
		_sky_sprites.append(sky_sp)

		var ridge_sp := Sprite2D.new()
		ridge_sp.texture = RIDGES_TEX
		ridge_sp.centered = false
		ridge_sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ridge_sp.scale = Vector2(1.0, 0.94)
		ridge_sp.position = Vector2(tx_sky + 120.0, GnorpGame.GROUND_Y - 765.0)
		ridge_sp.flip_h = flip_tile
		_ridge_layer.add_child(ridge_sp)
		_ridge_sprites.append(ridge_sp)

		var ground_sp := Sprite2D.new()
		ground_sp.texture = GROUND_TEX
		ground_sp.centered = false
		ground_sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ground_sp.scale = Vector2(1.0, 0.72)
		ground_sp.position = Vector2(tx_ground, GnorpGame.GROUND_Y - 125.0)
		ground_sp.flip_h = flip_tile
		_ground_layer.add_child(ground_sp)
		_ground_sprites.append(ground_sp)

	_ground_details = Node2D.new()
	_ground_details.name = "GroundOrganicDetails"
	_ground_details.z_index = -6
	_ground_details.draw.connect(_on_draw_ground_details)
	add_child(_ground_details)

	_ash_overlay = Node2D.new()
	_ash_overlay.name = "AmberAshParticles"
	_ash_overlay.z_index = 14
	_ash_overlay.draw.connect(_on_draw_ash_overlay)
	add_child(_ash_overlay)


func _init_ground_details() -> void:
	_ground_pebbles.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42077
	for i: int in range(84):
		var px: float = rng.randf_range(90.0, 3110.0)
		var py: float = GnorpGame.GROUND_Y + rng.randf_range(-16.0, 42.0)
		var kind: int = i % 3
		_ground_pebbles.append({
			"x": px,
			"y": py,
			"w": rng.randf_range(6.0, 18.0),
			"h": rng.randf_range(3.0, 7.0),
			"kind": kind,
		})
	if _ground_details != null:
		_ground_details.queue_redraw()


func _init_ash_particles() -> void:
	_ash_particles.clear()
	for i: int in range(ASH_COUNT):
		_ash_particles.append({
			"x": randf_range(WORLD_MIN_X, WORLD_MAX_X),
			"y": randf_range(75.0, GnorpGame.GROUND_Y - 8.0),
			"vx": randf_range(10.0, 34.0),
			"vy": randf_range(-11.0, -3.0),
			"size": randf_range(2.0, 4.2),
			"phase": randf_range(0.0, TAU),
			"ember": (i % 3) == 0,
		})


func _on_draw_sky_overlay() -> void:
	if _sky_overlay == null:
		return
	# Halo atmosférico sutil que esquenta conforme o Meteoro se aproxima, preservando o sol da arte original.
	var sun_center := Vector2(1890.0, 175.0)
	var pulse: float = sin(_time * 1.2) * 8.0
	var glow_alpha: float = 0.05 + _danger_ratio * 0.08
	var danger_col: Color = Color(1.0, 0.66, 0.28, glow_alpha).lerp(Color(1.0, 0.36, 0.16, glow_alpha + 0.04), _danger_ratio)
	_sky_overlay.draw_circle(sun_center, 220.0 + pulse, danger_col)


func _on_draw_ground_details() -> void:
	if _ground_details == null:
		return
	for d: Dictionary in _ground_pebbles:
		var x: float = float(d["x"])
		var y: float = float(d["y"])
		var w: float = float(d["w"])
		var h: float = float(d["h"])
		var kind: int = int(d["kind"])
		if kind == 0:
			# Pequena pedra cálida integrada à areia
			_ground_details.draw_rect(Rect2(x, y, w, h), Color(0.56, 0.35, 0.22, 0.55))
			_ground_details.draw_rect(Rect2(x + 1.0, y, w * 0.65, 2.0), Color(0.82, 0.56, 0.34, 0.45))
		elif kind == 1:
			# Fenda mineral no solo
			_ground_details.draw_line(Vector2(x, y), Vector2(x + w, y + h * 0.45), Color(0.42, 0.22, 0.15, 0.42), 2.0)
		else:
			# Tufo rasteiro pré-histórico
			var pts := PackedVector2Array([
				Vector2(x - 4.0, y), Vector2(x - 6.0, y - 7.0), Vector2(x, y - 2.0),
				Vector2(x + 3.0, y - 9.0), Vector2(x + 6.0, y)
			])
			_ground_details.draw_colored_polygon(pts, Color(0.42, 0.46, 0.24, 0.52))


func _on_draw_ash_overlay() -> void:
	if _ash_overlay == null:
		return
	for p: Dictionary in _ash_particles:
		var pos := Vector2(float(p["x"]), float(p["y"]))
		var sz: float = float(p["size"])
		var ph: float = float(p["phase"])
		var alpha: float = 0.26 + 0.32 * (0.5 + 0.5 * sin(_time * 2.4 + ph))
		var is_ember: bool = bool(p["ember"])
		var col: Color
		if is_ember:
			col = Color(1.0, 0.62, 0.20, alpha + _danger_ratio * 0.22)
		else:
			col = Color(1.0, 0.88, 0.58, alpha * 0.82)
		_ash_overlay.draw_circle(pos, sz * 0.55, col)
