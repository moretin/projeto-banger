class_name ValleyWorld
extends Node2D
## Mundo panorâmico horizontal (3200 x 1080) do reboot Gnorp-like.
## Contém: Camera2D com edge-panning amplo por mouse + guarda da HUD, Monólito de Âmbar,
## Pilha de Estilhaços dinâmica, Depósito, Meteoro rachando sob fogo, 6 Estruturas integradas
## via shader atmosférico + dressing de solo, enxame físico e áudio procedural.

const STRUCTURE_SHADER: Shader = preload("res://scenes/reboot/structure_blend.gdshader")
const AMBER_NEST_TEX: Texture2D = preload("res://assets/sprites/surface/structures/amber_nest.png")
const MONOLITH_ROCK_TEX: Texture2D = preload("res://assets/sprites/surface/structures/quarry_vein_stages.png")
const DEPOSIT_TEX: Texture2D = preload("res://assets/sprites/surface/structures/ark_stages.png")

const STRUCT_VISUALS: Dictionary = {
	"pachy_nest": {
		"built": "res://assets/sprites/surface/structures/amber_nest.png",
		"built_region": Rect2(168.0, 0.0, 168.0, 128.0),
		"foundation": "res://assets/sprites/surface/structures/ark_stages.png",
		"found_region": Rect2(0.0, 0.0, 168.0, 128.0),
		"scale": 1.40,
		"recolor": false,
	},
	"compy_den": {
		"built": "res://assets/sprites/surface/structures/fern_built.png",
		"built_region": Rect2(),
		"foundation": "res://assets/sprites/surface/structures/fern_foundation.png",
		"found_region": Rect2(),
		"scale": 1.48,
		"recolor": false,
	},
	"ptero_perch": {
		"built": "res://assets/sprites/surface/structures/tower_built.png",
		"built_region": Rect2(),
		"foundation": "res://assets/sprites/surface/structures/tower_foundation.png",
		"found_region": Rect2(),
		"scale": 1.65,
		"recolor": false,
	},
	"ankylo_lair": {
		"built": "res://assets/sprites/surface/structures/quarry_built.png",
		"built_region": Rect2(),
		"foundation": "res://assets/sprites/surface/structures/quarry_foundation.png",
		"found_region": Rect2(),
		"scale": 1.88,
		"recolor": false,
	},
	"trex_altar": {
		"built": "res://assets/sprites/surface/structures/university_built.png",
		"built_region": Rect2(),
		"foundation": "res://assets/sprites/surface/structures/university_foundation.png",
		"found_region": Rect2(),
		"scale": 1.74,
		"recolor": false,
	},
	"meteor_cannon": {
		"built": "res://assets/sprites/surface/structures/arctic_built.png",
		"built_region": Rect2(),
		"foundation": "res://assets/sprites/surface/structures/arctic_foundation.png",
		"found_region": Rect2(),
		"scale": 1.72,
		"recolor": true,
	},
}

const STRUCT_GROUND_Y: float = GnorpGame.GROUND_Y - 12.0
const EDGE_PAN_RATIO: float = 0.24
const EDGE_PAN_SPEED: float = 1150.0
const METEOR_WORLD_X: float = 2780.0
const METEOR_START_Y: float = 140.0
const METEOR_IMPACT_Y: float = 660.0
const MAX_POPUPS: int = 40
const MAX_FLYING_SHARDS: int = 64
const MAX_BEAMS: int = 20
const MAX_SHOCKWAVES: int = 12

var ui_blocking_pan: bool = false

var _camera: Camera2D = null
var _camera_target_x: float = 640.0
var _camera_base_x: float = 640.0
var _has_mouse_moved: bool = false
var _shake_trauma: float = 0.0
var _hud_top_guard: float = 82.0
var _hud_bottom_guard: float = 224.0
var _pan_left_strength: float = 0.0
var _pan_right_strength: float = 0.0
var _can_pan_left: bool = false
var _can_pan_right: bool = false
var _hover_target: String = ""
var _last_cursor_shape: int = Input.CURSOR_ARROW

var _backdrop: ValleyBackdrop = null
var _swarm_stage: DinoSwarmStage = null
var _audio: RebootAudio = null

var _monolith_root: Node2D = null
var _monolith_aura: Node2D = null
var _monolith_sprite: Sprite2D = null
var _monolith_mat: ShaderMaterial = null
var _monolith_squash: float = 0.0

var _pile_draw: Node2D = null
var _pile_pulse: float = 0.0

var _deposit_root: Node2D = null
var _deposit_sprite: Sprite2D = null
var _deposit_pulse: float = 0.0

var _meteor_node: Node2D = null
var _meteor_y: float = METEOR_START_Y
var _meteor_flash: float = 0.0
var _meteor_destroyed: bool = false
var _run_max_duration: float = 240.0

var _structures_layer: Node2D = null
var _struct_nodes: Dictionary = {}
var _struct_materials: Array[ShaderMaterial] = []
var _cannon_barrel: Node2D = null
var _cannon_recoil: float = 0.0

var _vfx_draw: Node2D = null
var _flying_shards: Array[Dictionary] = []
var _beams: Array[Dictionary] = []
var _shockwaves: Array[Dictionary] = []
var _explosion_particles: Array[Dictionary] = []

var _popup_layer: Node2D = null
var _popup_pool: Array[Label] = []
var _popup_cursor: int = 0
var _popup_active: Array[Dictionary] = []

var _tex_cache: Dictionary = {}
var _time: float = 0.0
var _connected: bool = false


func _ready() -> void:
	_setup_camera()
	_setup_subsystems()
	_setup_monolith()
	_setup_pile()
	_setup_deposit()
	_setup_structures()
	_setup_meteor()
	_setup_vfx_and_popups()
	_connect_signals()
	_refresh_structures_visuals()


func _exit_tree() -> void:
	_disconnect_signals()
	_flying_shards.clear()
	_beams.clear()
	_shockwaves.clear()
	_explosion_particles.clear()
	_popup_active.clear()
	_popup_pool.clear()
	_struct_nodes.clear()
	_struct_materials.clear()
	_monolith_mat = null
	_tex_cache.clear()
	if DisplayServer.get_name() != "headless" and _last_cursor_shape != Input.CURSOR_ARROW:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func focus_world_x(x: float) -> void:
	var half_w: float = _get_half_viewport_width()
	_camera_target_x = clampf(x, half_w, maxf(GnorpGame.WORLD_WIDTH - half_w, half_w))


func set_viewport_blocking(blocked: bool) -> void:
	ui_blocking_pan = blocked
	if blocked:
		_pan_left_strength = 0.0
		_pan_right_strength = 0.0


func set_hud_pan_guards(top_px: float, bottom_px: float) -> void:
	_hud_top_guard = maxf(top_px, 0.0)
	_hud_bottom_guard = maxf(bottom_px, 0.0)


func get_pan_indicator_state() -> Dictionary:
	return {
		"can_left": _can_pan_left,
		"can_right": _can_pan_right,
		"left_strength": _pan_left_strength,
		"right_strength": _pan_right_strength,
	}


func add_trauma(amount: float) -> void:
	_shake_trauma = clampf(_shake_trauma + amount, 0.0, 1.0)


func _setup_camera() -> void:
	_camera = Camera2D.new()
	_camera.name = "ValleyCamera"
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(GnorpGame.WORLD_WIDTH)
	_camera.limit_bottom = 1080
	_camera.zoom = Vector2.ONE
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	_camera.enabled = true
	var half_w: float = _get_half_viewport_width()
	_camera_target_x = clampf(640.0, half_w, maxf(GnorpGame.WORLD_WIDTH - half_w, half_w))
	_camera_base_x = _camera_target_x
	_camera.position = Vector2(_camera_base_x, 540.0)
	add_child(_camera)


func _get_half_viewport_width() -> float:
	if is_inside_tree() and get_viewport() != null:
		var vp_w: float = get_viewport_rect().size.x
		if vp_w > 100.0:
			return minf(vp_w * 0.5, GnorpGame.WORLD_WIDTH * 0.5)
	return 800.0


func _setup_subsystems() -> void:
	_backdrop = ValleyBackdrop.new()
	_backdrop.name = "ValleyBackdrop"
	add_child(_backdrop)

	_swarm_stage = DinoSwarmStage.new()
	_swarm_stage.name = "DinoSwarmStage"
	_swarm_stage.z_index = 6
	_swarm_stage.request_camera_shake.connect(add_trauma)
	_swarm_stage.ptero_meteor_shot_visual.connect(_on_ptero_meteor_beam)
	add_child(_swarm_stage)

	_audio = RebootAudio.new()
	_audio.name = "RebootAudio"
	add_child(_audio)


func _make_structure_material(recolor_amber: bool = false, uv_y: Vector2 = Vector2(0.0, 1.0)) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = STRUCTURE_SHADER
	mat.set_shader_parameter("sunset_tint", Vector3(1.04, 0.94, 0.84))
	mat.set_shader_parameter("sunset_strength", 0.28)
	mat.set_shader_parameter("ground_color", Vector3(0.68, 0.43, 0.25))
	mat.set_shader_parameter("ground_blend_height", 0.09)
	mat.set_shader_parameter("ground_blend_strength", 0.42)
	mat.set_shader_parameter("recolor_ice_to_amber", 1.0 if recolor_amber else 0.0)
	mat.set_shader_parameter("hit_flash", 0.0)
	mat.set_shader_parameter("region_uv_y", uv_y)
	_struct_materials.append(mat)
	return mat


func _add_ground_dressing(parent: Node2D, half_w: float, seed_val: int) -> void:
	var shadow := Polygon2D.new()
	shadow.polygon = _make_ellipse(half_w, 16.0, 20)
	shadow.color = Color(0.22, 0.11, 0.08, 0.44)
	shadow.position = Vector2(0.0, 5.0)
	shadow.z_index = -1
	parent.add_child(shadow)

	var sand_bed := Polygon2D.new()
	sand_bed.polygon = _make_ellipse(half_w * 0.84, 11.0, 18)
	sand_bed.color = Color(0.72, 0.46, 0.26, 0.42)
	sand_bed.position = Vector2(0.0, 2.0)
	sand_bed.z_index = -1
	parent.add_child(sand_bed)

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for i: int in range(6):
		var px: float = rng.randf_range(-half_w * 0.72, half_w * 0.72)
		var py: float = rng.randf_range(-3.0, 6.0)
		var pebble := Polygon2D.new()
		var pw: float = rng.randf_range(5.0, 11.0)
		var ph: float = rng.randf_range(3.0, 6.0)
		pebble.polygon = PackedVector2Array([
			Vector2(-pw, 0.0), Vector2(-pw * 0.6, -ph), Vector2(pw * 0.5, -ph * 0.9), Vector2(pw, 0.0)
		])
		pebble.color = Color(0.54, 0.32, 0.20, 0.85) if (i % 2) == 0 else Color(0.74, 0.48, 0.28, 0.80)
		pebble.position = Vector2(px, py)
		pebble.z_index = 1
		parent.add_child(pebble)


func _setup_monolith() -> void:
	_monolith_root = Node2D.new()
	_monolith_root.name = "AmberMonolith"
	_monolith_root.position = Vector2(GnorpGame.ROCK_X, STRUCT_GROUND_Y)
	_monolith_root.z_index = 4
	add_child(_monolith_root)

	_add_ground_dressing(_monolith_root, 128.0, 1001)

	_monolith_aura = Node2D.new()
	_monolith_aura.name = "MonolithAura"
	_monolith_aura.position = Vector2(0.0, -96.0)
	_monolith_aura.z_index = -1
	_monolith_aura.draw.connect(_on_draw_monolith_aura)
	_monolith_root.add_child(_monolith_aura)

	_monolith_mat = _make_structure_material(false, Vector2(0.0, 1.0))

	# Rochas laterais recortadas ancorando o Monólito no solo do vale.
	var flank_left := Sprite2D.new()
	flank_left.texture = MONOLITH_ROCK_TEX
	flank_left.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flank_left.region_enabled = true
	flank_left.region_rect = Rect2(0.0, 0.0, 52.0, 48.0)
	flank_left.scale = Vector2(2.0, 2.0)
	flank_left.position = Vector2(-104.0, -34.0)
	flank_left.material = _make_structure_material(false, Vector2(0.0, 1.0))
	_monolith_root.add_child(flank_left)

	var flank_right := Sprite2D.new()
	flank_right.texture = MONOLITH_ROCK_TEX
	flank_right.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flank_right.region_enabled = true
	flank_right.region_rect = Rect2(52.0, 0.0, 52.0, 48.0)
	flank_right.scale = Vector2(1.85, 1.85)
	flank_right.position = Vector2(102.0, -30.0)
	flank_right.material = _make_structure_material(false, Vector2(0.0, 1.0))
	_monolith_root.add_child(flank_right)

	# Grande Ovo/Monólito de Âmbar (metade esquerda de amber_nest.png).
	_monolith_sprite = Sprite2D.new()
	_monolith_sprite.texture = AMBER_NEST_TEX
	_monolith_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_monolith_sprite.region_enabled = true
	_monolith_sprite.region_rect = Rect2(0.0, 0.0, 168.0, 128.0)
	_monolith_sprite.scale = Vector2(1.75, 1.75)
	_monolith_sprite.position = Vector2(0.0, -104.0)
	_monolith_sprite.material = _monolith_mat
	_monolith_root.add_child(_monolith_sprite)


func _setup_pile() -> void:
	_pile_draw = Node2D.new()
	_pile_draw.name = "FragmentPile"
	_pile_draw.position = Vector2(GnorpGame.PILE_X, GnorpGame.GROUND_Y + 2.0)
	_pile_draw.z_index = 4
	_pile_draw.draw.connect(_on_draw_pile)
	add_child(_pile_draw)


func _setup_deposit() -> void:
	_deposit_root = Node2D.new()
	_deposit_root.name = "FragmentDeposit"
	_deposit_root.position = Vector2(GnorpGame.DEPOSIT_X, STRUCT_GROUND_Y)
	_deposit_root.z_index = 3
	add_child(_deposit_root)

	_add_ground_dressing(_deposit_root, 108.0, 2002)

	_deposit_sprite = Sprite2D.new()
	_deposit_sprite.texture = DEPOSIT_TEX
	_deposit_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_deposit_sprite.region_enabled = true
	_deposit_sprite.region_rect = Rect2(168.0, 0.0, 168.0, 128.0)
	_deposit_sprite.scale = Vector2(1.55, 1.55)
	_deposit_sprite.position = Vector2(0.0, -90.0)
	_deposit_sprite.material = _make_structure_material(false, Vector2(0.0, 1.0))
	_deposit_root.add_child(_deposit_sprite)


func _setup_structures() -> void:
	_structures_layer = Node2D.new()
	_structures_layer.name = "ValleyStructures"
	_structures_layer.z_index = 2
	add_child(_structures_layer)

	var list: Array[Dictionary] = GnorpGame.get_structure_list()
	var seed_counter: int = 3000
	for s_def: Dictionary in list:
		seed_counter += 17
		var sid: String = String(s_def["id"])
		var wx: float = float(s_def["world_x"])
		var vis: Dictionary = STRUCT_VISUALS.get(sid, {}) as Dictionary
		var sc: float = float(vis.get("scale", 1.55))
		var recolor: bool = bool(vis.get("recolor", false))
		var built_path: String = String(vis.get("built", ""))
		var found_path: String = String(vis.get("foundation", ""))
		var built_reg: Rect2 = vis.get("built_region", Rect2()) as Rect2
		var found_reg: Rect2 = vis.get("found_region", Rect2()) as Rect2

		var holder := Node2D.new()
		holder.name = "Struct_%s" % sid
		holder.position = Vector2(wx, STRUCT_GROUND_Y)
		_structures_layer.add_child(holder)

		var marker := Node2D.new()
		marker.name = "Marker"
		marker.set_meta("sid", sid)
		marker.draw.connect(_on_draw_blueprint_marker.bind(marker))
		holder.add_child(marker)

		var found_tex: Texture2D = _load_tex(found_path)
		if found_tex != null:
			var f_sp := Sprite2D.new()
			f_sp.texture = found_tex
			f_sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var fh: float = float(found_tex.get_height())
			if found_reg.size.x > 0.0 and found_reg.size.y > 0.0:
				f_sp.region_enabled = true
				f_sp.region_rect = found_reg
				fh = found_reg.size.y
			f_sp.scale = Vector2(sc, sc)
			f_sp.position = Vector2(0.0, -fh * sc * 0.5 + 8.0)
			f_sp.modulate = Color(1.0, 0.92, 0.72, 0.72)
			f_sp.material = _make_structure_material(recolor, Vector2(0.0, 1.0))
			marker.add_child(f_sp)

		var built_root := Node2D.new()
		built_root.name = "BuiltRoot"
		built_root.visible = false
		holder.add_child(built_root)

		_add_ground_dressing(built_root, 108.0 * (sc / 1.5), seed_counter)

		var sp := Sprite2D.new()
		sp.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var tex: Texture2D = _load_tex(built_path)
		if tex != null:
			sp.texture = tex
			var h_px: float = float(tex.get_height())
			if built_reg.size.x > 0.0 and built_reg.size.y > 0.0:
				sp.region_enabled = true
				sp.region_rect = built_reg
				h_px = built_reg.size.y
			sp.scale = Vector2(sc, sc)
			sp.position = Vector2(0.0, -h_px * sc * 0.5 + 8.0)
			sp.material = _make_structure_material(recolor, Vector2(0.0, 1.0))
		built_root.add_child(sp)

		var upgrade_fx := Node2D.new()
		upgrade_fx.name = "UpgradeVisuals"
		upgrade_fx.set_meta("sid", sid)
		upgrade_fx.draw.connect(_on_draw_structure_upgrades.bind(upgrade_fx))
		built_root.add_child(upgrade_fx)

		if sid == "meteor_cannon":
			_cannon_barrel = Node2D.new()
			_cannon_barrel.name = "CannonBarrel"
			_cannon_barrel.position = Vector2(0.0, -158.0)
			var mount := Polygon2D.new()
			mount.polygon = _make_ellipse(18.0, 14.0, 14)
			mount.color = Color(0.28, 0.16, 0.14, 1.0)
			_cannon_barrel.add_child(mount)
			var barrel_poly := Polygon2D.new()
			barrel_poly.polygon = PackedVector2Array([
				Vector2(-14.0, -10.0), Vector2(78.0, -7.0), Vector2(78.0, 7.0), Vector2(-14.0, 10.0)
			])
			barrel_poly.color = Color(0.46, 0.28, 0.18, 1.0)
			_cannon_barrel.add_child(barrel_poly)
			var barrel_core := Polygon2D.new()
			barrel_core.polygon = PackedVector2Array([
				Vector2(10.0, -3.5), Vector2(74.0, -2.5), Vector2(74.0, 2.5), Vector2(10.0, 3.5)
			])
			barrel_core.color = Color(1.0, 0.80, 0.28, 1.0)
			_cannon_barrel.add_child(barrel_core)
			built_root.add_child(_cannon_barrel)

		_struct_nodes[sid] = {
			"holder": holder,
			"marker": marker,
			"built_root": built_root,
			"upgrade_fx": upgrade_fx,
			"bounce": 0.0,
			"world_x": wx,
		}


func _setup_meteor() -> void:
	_meteor_node = Node2D.new()
	_meteor_node.name = "MeteorSkyTarget"
	_meteor_node.position = Vector2(METEOR_WORLD_X, METEOR_START_Y)
	_meteor_node.z_index = 11
	_meteor_node.draw.connect(_on_draw_meteor)
	add_child(_meteor_node)
	_run_max_duration = maxf(GnorpGame.meteor_time_left, GnorpGame.BASE_RUN_DURATION)


func _setup_vfx_and_popups() -> void:
	_vfx_draw = Node2D.new()
	_vfx_draw.name = "VfxOverlay"
	_vfx_draw.z_index = 15
	_vfx_draw.draw.connect(_on_draw_vfx)
	add_child(_vfx_draw)

	_popup_layer = Node2D.new()
	_popup_layer.name = "FloatingPopups"
	_popup_layer.z_index = 20
	add_child(_popup_layer)

	for i: int in range(MAX_POPUPS):
		var lbl := Label.new()
		lbl.name = "Popup_%d" % i
		lbl.visible = false
		lbl.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 20)
		lbl.add_theme_color_override("font_outline_color", Color(0.12, 0.06, 0.06, 1.0))
		lbl.add_theme_constant_override("outline_size", 5)
		_popup_layer.add_child(lbl)
		_popup_pool.append(lbl)


func _connect_signals() -> void:
	if _connected:
		return
	_connected = true
	GnorpGame.rock_hit.connect(_on_rock_hit)
	GnorpGame.pile_changed.connect(_on_pile_changed)
	GnorpGame.pile_compressed.connect(_on_pile_compressed)
	GnorpGame.deposit_collected.connect(_on_deposit_collected)
	GnorpGame.structure_built.connect(_on_structure_built)
	GnorpGame.upgrade_purchased.connect(_on_upgrade_purchased)
	GnorpGame.roar_triggered.connect(_on_roar_triggered)
	GnorpGame.cannon_fired.connect(_on_cannon_fired)
	GnorpGame.run_ended.connect(_on_run_ended)
	GnorpGame.run_started.connect(_on_run_started)
	GnorpGame.resources_changed.connect(_refresh_structures_visuals)


func _disconnect_signals() -> void:
	if not _connected:
		return
	_connected = false
	if GnorpGame.rock_hit.is_connected(_on_rock_hit):
		GnorpGame.rock_hit.disconnect(_on_rock_hit)
	if GnorpGame.pile_changed.is_connected(_on_pile_changed):
		GnorpGame.pile_changed.disconnect(_on_pile_changed)
	if GnorpGame.pile_compressed.is_connected(_on_pile_compressed):
		GnorpGame.pile_compressed.disconnect(_on_pile_compressed)
	if GnorpGame.deposit_collected.is_connected(_on_deposit_collected):
		GnorpGame.deposit_collected.disconnect(_on_deposit_collected)
	if GnorpGame.structure_built.is_connected(_on_structure_built):
		GnorpGame.structure_built.disconnect(_on_structure_built)
	if GnorpGame.upgrade_purchased.is_connected(_on_upgrade_purchased):
		GnorpGame.upgrade_purchased.disconnect(_on_upgrade_purchased)
	if GnorpGame.roar_triggered.is_connected(_on_roar_triggered):
		GnorpGame.roar_triggered.disconnect(_on_roar_triggered)
	if GnorpGame.cannon_fired.is_connected(_on_cannon_fired):
		GnorpGame.cannon_fired.disconnect(_on_cannon_fired)
	if GnorpGame.run_ended.is_connected(_on_run_ended):
		GnorpGame.run_ended.disconnect(_on_run_ended)
	if GnorpGame.run_started.is_connected(_on_run_started):
		GnorpGame.run_started.disconnect(_on_run_started)
	if GnorpGame.resources_changed.is_connected(_refresh_structures_visuals):
		GnorpGame.resources_changed.disconnect(_refresh_structures_visuals)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_has_mouse_moved = true


func _unhandled_input(event: InputEvent) -> void:
	if ui_blocking_pan:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			var world_pos: Vector2 = get_global_mouse_position()
			var monolith_rect := Rect2(GnorpGame.ROCK_X - 135.0, STRUCT_GROUND_Y - 220.0, 270.0, 240.0)
			if monolith_rect.has_point(world_pos):
				GnorpGame.click_rock(world_pos.x)
				if _shockwaves.size() < MAX_SHOCKWAVES:
					_shockwaves.append({
						"pos": world_pos,
						"max_r": 46.0,
						"t": 0.0,
						"dur": 0.24,
						"color": Color(1.0, 0.88, 0.34, 0.85),
					})
				get_viewport().set_input_as_handled()
				return
			var pile_rect := Rect2(GnorpGame.PILE_X - 108.0, GnorpGame.GROUND_Y - 145.0, 216.0, 165.0)
			if pile_rect.has_point(world_pos):
				var moved: float = GnorpGame.scoop_pile()
				if moved > 0.0:
					for _i: int in range(2):
						_spawn_flying_shard_between(
							Vector2(GnorpGame.PILE_X + randf_range(-16.0, 16.0), GnorpGame.GROUND_Y - randf_range(16.0, 44.0)),
							Vector2(GnorpGame.DEPOSIT_X + randf_range(-20.0, 20.0), STRUCT_GROUND_Y - 40.0),
							Color(0.45, 0.96, 1.0, 1.0),
							5.5
						)
				get_viewport().set_input_as_handled()
				return
			# Clique direto em uma fundação desbloqueada no vale tenta construir a estrutura!
			for sid: Variant in _struct_nodes:
				var s_id: String = String(sid)
				if GnorpGame.is_structure_built(s_id) or not GnorpGame.is_structure_unlocked(s_id):
					continue
				var entry: Dictionary = _struct_nodes[sid] as Dictionary
				var wx: float = float(entry.get("world_x", 0.0))
				var found_rect := Rect2(wx - 90.0, STRUCT_GROUND_Y - 140.0, 180.0, 160.0)
				if found_rect.has_point(world_pos):
					GnorpGame.build_structure(s_id)
					get_viewport().set_input_as_handled()
					return


func _process(delta: float) -> void:
	_time += delta
	_process_camera_pan(delta)
	_process_hover_feedback()
	_process_landmarks(delta)
	_process_meteor(delta)
	_process_vfx(delta)
	_process_popups(delta)


func _process_camera_pan(delta: float) -> void:
	var half_w: float = _get_half_viewport_width()
	var min_cam_x: float = half_w
	var max_cam_x: float = maxf(GnorpGame.WORLD_WIDTH - half_w, half_w)

	_pan_left_strength = 0.0
	_pan_right_strength = 0.0
	_can_pan_left = _camera_base_x > min_cam_x + 4.0
	_can_pan_right = _camera_base_x < max_cam_x - 4.0

	if GnorpGame.auto_pan_enabled and not ui_blocking_pan and _has_mouse_moved:
		var vp_size: Vector2 = get_viewport_rect().size
		var mouse_pos: Vector2 = get_viewport().get_mouse_position()
		var in_y_band: bool = mouse_pos.y >= _hud_top_guard and mouse_pos.y <= (vp_size.y - _hud_bottom_guard)
		if vp_size.x > 10.0 and in_y_band:
			var margin_px: float = maxf(vp_size.x * EDGE_PAN_RATIO, 180.0)
			if mouse_pos.x >= 0.0 and mouse_pos.x < margin_px:
				var norm_l: float = clampf(1.0 - mouse_pos.x / margin_px, 0.0, 1.0)
				_pan_left_strength = pow(norm_l, 1.35)
				_camera_target_x -= _pan_left_strength * EDGE_PAN_SPEED * delta
			elif mouse_pos.x <= vp_size.x and mouse_pos.x > vp_size.x - margin_px:
				var norm_r: float = clampf(1.0 - (vp_size.x - mouse_pos.x) / margin_px, 0.0, 1.0)
				_pan_right_strength = pow(norm_r, 1.35)
				_camera_target_x += _pan_right_strength * EDGE_PAN_SPEED * delta

	_camera_target_x = clampf(_camera_target_x, min_cam_x, max_cam_x)
	_camera_base_x = lerpf(_camera_base_x, _camera_target_x, minf(delta * 10.0, 1.0))

	if _backdrop != null:
		_backdrop.set_camera_x(_camera_base_x)

	_shake_trauma = maxf(_shake_trauma - delta * 2.2, 0.0)
	var shake_mag: float = _shake_trauma * _shake_trauma * 20.0
	var shake_ofs := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake_mag

	if _camera != null:
		_camera.position = Vector2(_camera_base_x, 540.0) + shake_ofs


func _process_hover_feedback() -> void:
	var new_hover: String = ""
	if not ui_blocking_pan and is_inside_tree() and get_viewport() != null:
		var vp_size: Vector2 = get_viewport_rect().size
		var mp: Vector2 = get_viewport().get_mouse_position()
		if mp.y >= _hud_top_guard and mp.y <= (vp_size.y - _hud_bottom_guard):
			var world_pos: Vector2 = get_global_mouse_position()
			var monolith_rect := Rect2(GnorpGame.ROCK_X - 135.0, STRUCT_GROUND_Y - 220.0, 270.0, 240.0)
			var pile_rect := Rect2(GnorpGame.PILE_X - 108.0, GnorpGame.GROUND_Y - 145.0, 216.0, 165.0)
			if monolith_rect.has_point(world_pos):
				new_hover = "monolith"
			elif pile_rect.has_point(world_pos):
				new_hover = "pile"
			else:
				for sid: Variant in _struct_nodes:
					var s_id: String = String(sid)
					if GnorpGame.is_structure_built(s_id) or not GnorpGame.is_structure_unlocked(s_id):
						continue
					var entry: Dictionary = _struct_nodes[sid] as Dictionary
					var wx: float = float(entry.get("world_x", 0.0))
					var found_rect := Rect2(wx - 90.0, STRUCT_GROUND_Y - 140.0, 180.0, 160.0)
					if found_rect.has_point(world_pos):
						new_hover = "foundation"
						break
	_hover_target = new_hover
	var wanted_shape: int = Input.CURSOR_POINTING_HAND if _hover_target != "" else Input.CURSOR_ARROW
	if wanted_shape != _last_cursor_shape:
		_last_cursor_shape = wanted_shape
		if DisplayServer.get_name() != "headless":
			Input.set_default_cursor_shape(wanted_shape)


func _process_landmarks(delta: float) -> void:
	_monolith_squash = maxf(_monolith_squash - delta * 5.5, 0.0)
	if _monolith_root != null:
		var sx: float = 1.0 + _monolith_squash * 0.12
		var sy: float = 1.0 - _monolith_squash * 0.09
		_monolith_root.scale = Vector2(sx, sy)
	if _monolith_mat != null:
		_monolith_mat.set_shader_parameter("hit_flash", _monolith_squash)
	if _monolith_aura != null:
		_monolith_aura.queue_redraw()

	_pile_pulse = maxf(_pile_pulse - delta * 4.0, 0.0)
	if _pile_draw != null:
		var psx: float = 1.0 + _pile_pulse * 0.09
		var psy: float = 1.0 - _pile_pulse * 0.05
		_pile_draw.scale = Vector2(psx, psy)
		_pile_draw.queue_redraw()

	_deposit_pulse = maxf(_deposit_pulse - delta * 4.5, 0.0)
	if _deposit_root != null:
		_deposit_root.scale = Vector2(1.0 + _deposit_pulse * 0.10, 1.0 + _deposit_pulse * 0.12)

	for sid: Variant in _struct_nodes:
		var entry: Dictionary = _struct_nodes[sid] as Dictionary
		var bounce: float = float(entry["bounce"])
		if bounce > 0.0:
			bounce = maxf(bounce - delta * 3.5, 0.0)
			entry["bounce"] = bounce
			var built_root: Node2D = entry["built_root"] as Node2D
			built_root.scale = Vector2(1.0 + sin(bounce * PI) * 0.14, 1.0 - sin(bounce * PI) * 0.10)
			built_root.position.y = -absf(sin(bounce * PI)) * 28.0
		var marker: Node2D = entry["marker"] as Node2D
		if marker.visible:
			marker.queue_redraw()
		var upgrade_fx: Node2D = entry["upgrade_fx"] as Node2D
		if upgrade_fx.visible:
			upgrade_fx.queue_redraw()

	_cannon_recoil = maxf(_cannon_recoil - delta * 6.0, 0.0)
	if _cannon_barrel != null:
		var aim_vec: Vector2 = Vector2(METEOR_WORLD_X, _meteor_y) - _cannon_barrel.global_position
		_cannon_barrel.rotation = aim_vec.angle()
		_cannon_barrel.position = Vector2(0.0, -158.0) - Vector2.from_angle(_cannon_barrel.rotation) * (_cannon_recoil * 16.0)


func _process_meteor(delta: float) -> void:
	_meteor_flash = maxf(_meteor_flash - delta * 2.5, 0.0)
	if GnorpGame.run_state == "victory":
		_meteor_destroyed = true
	elif GnorpGame.run_state == "endless":
		_meteor_destroyed = false
		_meteor_y = 220.0 + sin(_time * 1.1) * 24.0
	elif GnorpGame.run_state == "impact":
		_meteor_destroyed = false
		_meteor_y = lerpf(_meteor_y, GnorpGame.GROUND_Y - 40.0, minf(delta * 8.0, 1.0))
	else:
		_meteor_destroyed = false
		var dur: float = maxf(_run_max_duration, 1.0)
		var prog: float = clampf(1.0 - (GnorpGame.meteor_time_left / dur), 0.0, 1.0)
		_meteor_y = lerpf(METEOR_START_Y, METEOR_IMPACT_Y, prog)

	if _meteor_node != null:
		_meteor_node.visible = not _meteor_destroyed
		_meteor_node.position = Vector2(METEOR_WORLD_X, _meteor_y)
		_meteor_node.queue_redraw()


func _process_vfx(delta: float) -> void:
	var si: int = _flying_shards.size() - 1
	while si >= 0:
		var sh: Dictionary = _flying_shards[si]
		var t: float = float(sh["t"]) + delta / maxf(float(sh["dur"]), 0.05)
		if t >= 1.0:
			_flying_shards.remove_at(si)
		else:
			sh["t"] = t
		si -= 1

	var bi: int = _beams.size() - 1
	while bi >= 0:
		var bm: Dictionary = _beams[bi]
		var bt: float = float(bm["t"]) + delta
		if bt >= float(bm["dur"]):
			_beams.remove_at(bi)
		else:
			bm["t"] = bt
		bi -= 1

	var wi: int = _shockwaves.size() - 1
	while wi >= 0:
		var sw: Dictionary = _shockwaves[wi]
		var wt: float = float(sw["t"]) + delta
		if wt >= float(sw["dur"]):
			_shockwaves.remove_at(wi)
		else:
			sw["t"] = wt
		wi -= 1

	var ei: int = _explosion_particles.size() - 1
	while ei >= 0:
		var ep: Dictionary = _explosion_particles[ei]
		var et: float = float(ep["t"]) + delta
		if et >= float(ep["dur"]):
			_explosion_particles.remove_at(ei)
		else:
			ep["t"] = et
			var vel: Vector2 = ep["vel"] as Vector2
			vel.y += 280.0 * delta
			ep["vel"] = vel
			ep["pos"] = (ep["pos"] as Vector2) + vel * delta
		ei -= 1

	if _vfx_draw != null:
		_vfx_draw.queue_redraw()


func _process_popups(delta: float) -> void:
	var pi: int = _popup_active.size() - 1
	while pi >= 0:
		var p: Dictionary = _popup_active[pi]
		var lbl: Label = p["label"] as Label
		var t: float = float(p["t"]) + delta
		var dur: float = float(p["dur"])
		if not is_instance_valid(lbl) or t >= dur:
			if is_instance_valid(lbl):
				lbl.visible = false
			_popup_active.remove_at(pi)
		else:
			p["t"] = t
			var prog: float = t / dur
			lbl.position = (p["start"] as Vector2) + Vector2(float(p["vx"]) * t, -58.0 * prog)
			lbl.modulate = Color(1.0, 1.0, 1.0, clampf(1.0 - smoothstep(0.55, 1.0, prog), 0.0, 1.0))
		pi -= 1


func _spawn_popup(world_pos: Vector2, text: String, col: Color, font_size: int = 20) -> void:
	if _popup_pool.is_empty():
		return
	var lbl: Label = _popup_pool[_popup_cursor]
	_popup_cursor = (_popup_cursor + 1) % _popup_pool.size()
	for idx: int in range(_popup_active.size() - 1, -1, -1):
		if _popup_active[idx]["label"] == lbl:
			_popup_active.remove_at(idx)

	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", col)
	var start := world_pos + Vector2(randf_range(-28.0, 28.0) - 40.0, randf_range(-16.0, 6.0))
	lbl.position = start
	lbl.modulate = Color.WHITE
	lbl.visible = true
	_popup_active.append({
		"label": lbl,
		"start": start,
		"vx": randf_range(-16.0, 16.0),
		"t": 0.0,
		"dur": 0.85,
	})


func _spawn_flying_shard_between(p0: Vector2, p2: Vector2, col: Color, size: float = 5.0) -> void:
	if _flying_shards.size() >= MAX_FLYING_SHARDS:
		_flying_shards.remove_at(0)
	_flying_shards.append({
		"p0": p0,
		"p2": p2,
		"peak": randf_range(80.0, 155.0),
		"t": 0.0,
		"dur": randf_range(0.32, 0.50),
		"size": size,
		"color": col,
	})


func _spawn_flying_shard(start_x: float, is_crit: bool) -> void:
	var p0 := Vector2(start_x + randf_range(-18.0, 18.0), STRUCT_GROUND_Y - randf_range(55.0, 125.0))
	var p2 := Vector2(GnorpGame.PILE_X + randf_range(-34.0, 34.0), GnorpGame.GROUND_Y - randf_range(10.0, 38.0))
	var col: Color = Color(1.0, 0.90, 0.34, 1.0) if is_crit else Color(0.98, 0.68, 0.22, 1.0)
	_spawn_flying_shard_between(p0, p2, col, 6.5 if is_crit else 4.5)


func _on_rock_hit(pos_x: float, _damage: float, shards_spawned: float, is_crit: bool, source: String) -> void:
	_monolith_squash = 1.0 if is_crit or source == "click" else 0.55
	if source == "click" or is_crit:
		add_trauma(0.16 if is_crit else 0.09)
	var shard_visuals: int = 3 if is_crit else (2 if source == "click" else 1)
	for _i: int in range(shard_visuals):
		_spawn_flying_shard(pos_x, is_crit)

	if source == "click" or is_crit or randf() < 0.28:
		var txt: String = "+%s" % GnorpGame.format_number(shards_spawned)
		if is_crit:
			txt = "CRIT! +%s" % GnorpGame.format_number(shards_spawned)
		var col: Color = Color(1.0, 0.88, 0.24, 1.0) if is_crit else Color(1.0, 0.94, 0.72, 1.0)
		_spawn_popup(Vector2(pos_x, STRUCT_GROUND_Y - 140.0), txt, col, 24 if is_crit else 19)


func _on_pile_changed(_pile_amount: float, _tier: int, _capacity: float) -> void:
	_pile_pulse = 0.65


func _on_pile_compressed(new_tier: int, multiplier: float) -> void:
	_pile_pulse = 1.0
	add_trauma(0.22)
	_spawn_popup(
		Vector2(GnorpGame.PILE_X, GnorpGame.GROUND_Y - 135.0),
		"COMPRIMIDO! Nv.%d (x%.1f)" % [new_tier, multiplier],
		Color(0.42, 0.96, 1.0, 1.0),
		23
	)
	if _shockwaves.size() < MAX_SHOCKWAVES:
		_shockwaves.append({
			"pos": Vector2(GnorpGame.PILE_X, GnorpGame.GROUND_Y - 24.0),
			"max_r": 160.0,
			"t": 0.0,
			"dur": 0.50,
			"color": Color(0.40, 0.94, 1.0, 0.9),
		})


func _on_deposit_collected(amount: float, source: String) -> void:
	_deposit_pulse = 0.85
	if source == "manual" or source == "scoop" or randf() < 0.28:
		var col: Color = Color(0.45, 0.96, 1.0, 1.0) if source == "manual" else Color(0.68, 1.0, 0.58, 1.0)
		_spawn_popup(
			Vector2(GnorpGame.DEPOSIT_X, STRUCT_GROUND_Y - 118.0),
			"+%s" % GnorpGame.format_number(amount),
			col,
			20 if source == "manual" else 18
		)


func _on_structure_built(struct_id: String, world_x: float) -> void:
	_refresh_structures_visuals()
	if _struct_nodes.has(struct_id):
		var entry: Dictionary = _struct_nodes[struct_id] as Dictionary
		entry["bounce"] = 1.0
	add_trauma(0.28)
	_spawn_popup(Vector2(world_x, STRUCT_GROUND_Y - 165.0), "CONSTRUÍDO!", Color(1.0, 0.86, 0.30, 1.0), 25)


func _on_upgrade_purchased(_upgrade_id: String) -> void:
	_refresh_structures_visuals()


func _on_roar_triggered(_duration: float, multiplier: float) -> void:
	add_trauma(0.36)
	var altar_x: float = 2460.0
	if _shockwaves.size() < MAX_SHOCKWAVES:
		_shockwaves.append({
			"pos": Vector2(altar_x, STRUCT_GROUND_Y - 75.0),
			"max_r": 520.0,
			"t": 0.0,
			"dur": 0.85,
			"color": Color(1.0, 0.78, 0.22, 0.95),
		})
	_spawn_popup(Vector2(altar_x, STRUCT_GROUND_Y - 170.0), "RUGIDO ALFA! x%.1f" % multiplier, Color(1.0, 0.78, 0.20, 1.0), 26)


func _on_cannon_fired(damage: float, _new_meteor_hp: float, source: String) -> void:
	if source == "ptero":
		return
	if source == "trex_apex":
		_meteor_flash = maxf(_meteor_flash, 0.75)
		if _beams.size() < MAX_BEAMS:
			_beams.append({
				"from": Vector2(GnorpGame.ROCK_X + 100.0, STRUCT_GROUND_Y - 90.0),
				"to": Vector2(METEOR_WORLD_X, _meteor_y),
				"t": 0.0,
				"dur": 0.24,
				"width": 7.5,
				"color": Color(1.0, 0.45, 0.20, 1.0),
			})
		_spawn_popup(Vector2(METEOR_WORLD_X, _meteor_y + 42.0), "-%s HP" % GnorpGame.format_number(damage), Color(1.0, 0.50, 0.22, 1.0), 20)
		return
	_cannon_recoil = 1.0
	_meteor_flash = 1.0
	add_trauma(0.30)
	if _beams.size() < MAX_BEAMS:
		var beam_w: float = 18.0 if GnorpGame.is_upgrade_owned("cannon_barrel") else 12.0
		_beams.append({
			"from": Vector2(2820.0, STRUCT_GROUND_Y - 158.0),
			"to": Vector2(METEOR_WORLD_X, _meteor_y),
			"t": 0.0,
			"dur": 0.28,
			"width": beam_w,
			"color": Color(1.0, 0.82, 0.28, 1.0),
		})
	_spawn_popup(Vector2(METEOR_WORLD_X, _meteor_y + 42.0), "-%s HP" % GnorpGame.format_number(damage), Color(1.0, 0.62, 0.24, 1.0), 22)


func _on_ptero_meteor_beam(from_pos: Vector2) -> void:
	_meteor_flash = maxf(_meteor_flash, 0.55)
	if _beams.size() < MAX_BEAMS:
		_beams.append({
			"from": from_pos,
			"to": Vector2(METEOR_WORLD_X, _meteor_y),
			"t": 0.0,
			"dur": 0.20,
			"width": 5.5,
			"color": Color(0.55, 0.95, 1.0, 1.0),
		})


func _on_run_ended(outcome: String, _amber_earned: float) -> void:
	if outcome == "victory":
		_meteor_destroyed = true
		add_trauma(0.85)
		_spawn_meteor_victory_explosion(Vector2(METEOR_WORLD_X, _meteor_y))
		if _shockwaves.size() < MAX_SHOCKWAVES:
			_shockwaves.append({
				"pos": Vector2(METEOR_WORLD_X, _meteor_y),
				"max_r": 620.0,
				"t": 0.0,
				"dur": 1.1,
				"color": Color(1.0, 0.90, 0.36, 1.0),
			})
	elif outcome == "impact":
		add_trauma(1.0)
		_meteor_flash = 1.0
		if _shockwaves.size() < MAX_SHOCKWAVES:
			_shockwaves.append({
				"pos": Vector2(METEOR_WORLD_X, GnorpGame.GROUND_Y - 30.0),
				"max_r": 900.0,
				"t": 0.0,
				"dur": 1.2,
				"color": Color(1.0, 0.42, 0.16, 1.0),
			})


func _on_run_started(_run_number: int) -> void:
	_meteor_destroyed = false
	_meteor_y = METEOR_START_Y
	_run_max_duration = maxf(GnorpGame.meteor_time_left, GnorpGame.BASE_RUN_DURATION)
	_explosion_particles.clear()
	_refresh_structures_visuals()


func _spawn_meteor_victory_explosion(center: Vector2) -> void:
	for i: int in range(60):
		var ang: float = randf_range(0.0, TAU)
		var spd: float = randf_range(120.0, 560.0)
		_explosion_particles.append({
			"pos": center,
			"vel": Vector2(cos(ang), sin(ang)) * spd,
			"t": 0.0,
			"dur": randf_range(0.8, 1.7),
			"size": randf_range(5.0, 13.0),
			"color": Color(1.0, randf_range(0.65, 0.95), randf_range(0.16, 0.48), 1.0),
		})


func _refresh_structures_visuals() -> void:
	for sid: Variant in _struct_nodes:
		var s_id: String = String(sid)
		var entry: Dictionary = _struct_nodes[sid] as Dictionary
		var built: bool = GnorpGame.is_structure_built(s_id)
		var unlocked: bool = GnorpGame.is_structure_unlocked(s_id)
		var marker: Node2D = entry["marker"] as Node2D
		var built_root: Node2D = entry["built_root"] as Node2D
		var upgrade_fx: Node2D = entry["upgrade_fx"] as Node2D
		built_root.visible = built
		marker.visible = (not built) and unlocked
		upgrade_fx.visible = built


func _on_draw_monolith_aura() -> void:
	if _monolith_aura == null:
		return
	var hover_boost: float = 0.08 if _hover_target == "monolith" else 0.0
	var pulse: float = sin(_time * 2.4) * 8.0 + _monolith_squash * 14.0
	var a: float = 0.14 + _monolith_squash * 0.22 + hover_boost
	_monolith_aura.draw_circle(Vector2.ZERO, 128.0 + pulse, Color(1.0, 0.66, 0.18, a * 0.55))
	_monolith_aura.draw_circle(Vector2.ZERO, 86.0 + pulse * 0.6, Color(1.0, 0.80, 0.30, a))


func _on_draw_pile() -> void:
	if _pile_draw == null:
		return
	var cap: float = maxf(GnorpGame.get_pile_capacity(), 1.0)
	var ratio: float = clampf(GnorpGame.pile_fragments / cap, 0.0, 1.0)
	var tier: int = GnorpGame.compression_tier

	var main_col: Color = Color(0.92, 0.56, 0.16, 1.0)
	var dark_col: Color = Color(0.60, 0.30, 0.10, 1.0)
	var hi_col: Color = Color(1.0, 0.82, 0.34, 1.0)
	if tier == 1:
		main_col = Color(0.22, 0.76, 0.90, 1.0)
		dark_col = Color(0.12, 0.44, 0.58, 1.0)
		hi_col = Color(0.66, 0.96, 1.0, 1.0)
	elif tier == 2:
		main_col = Color(0.96, 0.80, 0.18, 1.0)
		dark_col = Color(0.62, 0.46, 0.08, 1.0)
		hi_col = Color(1.0, 0.96, 0.60, 1.0)
	elif tier >= 3:
		main_col = Color(0.64, 0.34, 0.92, 1.0)
		dark_col = Color(0.38, 0.16, 0.60, 1.0)
		hi_col = Color(0.90, 0.72, 1.0, 1.0)

	if _hover_target == "pile":
		_pile_draw.draw_circle(Vector2(0.0, -34.0), 82.0, Color(hi_col.r, hi_col.g, hi_col.b, 0.16))

	# Base pedregosa da pilha integrada ao solo
	_pile_draw.draw_colored_polygon(_make_ellipse(84.0, 14.0, 18), Color(0.22, 0.11, 0.08, 0.56))
	var w: float = lerpf(44.0, 154.0, ratio)
	var h: float = lerpf(15.0, 120.0, ratio)
	if GnorpGame.pile_fragments <= 0.1 and tier == 0:
		w = 36.0
		h = 11.0

	var mound_shadow := PackedVector2Array([
		Vector2(-w * 0.52, 2.0),
		Vector2(-w * 0.28, -h * 0.62),
		Vector2(w * 0.08, -h * 0.92),
		Vector2(w * 0.42, -h * 0.50),
		Vector2(w * 0.54, 2.0),
	])
	_pile_draw.draw_colored_polygon(mound_shadow, dark_col)

	var mound := PackedVector2Array([
		Vector2(-w * 0.48, 0.0),
		Vector2(-w * 0.30, -h * 0.70),
		Vector2(-w * 0.04, -h),
		Vector2(w * 0.24, -h * 0.80),
		Vector2(w * 0.48, 0.0),
	])
	_pile_draw.draw_colored_polygon(mound, main_col)

	var crest := PackedVector2Array([
		Vector2(-w * 0.22, -h * 0.45),
		Vector2(-w * 0.04, -h * 0.96),
		Vector2(w * 0.18, -h * 0.64),
		Vector2(0.0, -h * 0.30),
	])
	_pile_draw.draw_colored_polygon(crest, hi_col)

	# Cristais facetados extras e pedras de contenção na base
	var shard_count: int = clampi(int(ratio * 10.0) + mini(tier * 2, 6), 2, 14)
	for i: int in range(shard_count):
		var frac: float = (float(i) / float(maxi(shard_count - 1, 1))) - 0.5
		var cx: float = frac * w * 0.68
		var cy: float = -h * (0.40 + 0.44 * (1.0 - absf(frac) * 1.6))
		var poly := PackedVector2Array([
			Vector2(cx - 5.5, cy + 4.0),
			Vector2(cx, cy - 12.0),
			Vector2(cx + 6.0, cy + 4.0),
		])
		_pile_draw.draw_colored_polygon(poly, hi_col if i % 2 == 0 else main_col)

	for r_idx: int in range(5):
		var rx: float = -60.0 + float(r_idx) * 30.0
		_pile_draw.draw_colored_polygon(_make_ellipse(10.0, 5.0, 8), Color(0.46, 0.26, 0.18, 0.90))
		_pile_draw.draw_circle(Vector2(rx, 2.0), 4.5, Color(0.58, 0.34, 0.22, 0.85))

	# Barra discreta de capacidade sob a pilha
	var bar_w: float = 114.0
	_pile_draw.draw_rect(Rect2(-bar_w * 0.5, 16.0, bar_w, 6.0), Color(0.14, 0.08, 0.08, 0.85))
	_pile_draw.draw_rect(Rect2(-bar_w * 0.5 + 1.0, 17.0, (bar_w - 2.0) * ratio, 4.0), hi_col)


func _on_draw_blueprint_marker(marker: Node2D) -> void:
	var pulse: float = 0.55 + 0.45 * sin(_time * 4.0)
	var sid: String = String(marker.get_meta("sid", ""))
	var can_afford: bool = GnorpGame.fragments >= GnorpGame.get_structure_cost(sid)
	var ring_col: Color = Color(1.0, 0.86, 0.28, 0.45 + pulse * 0.35) if can_afford else Color(0.92, 0.68, 0.32, 0.24 + pulse * 0.16)
	marker.draw_colored_polygon(_make_ellipse(78.0, 14.0, 18), Color(0.22, 0.11, 0.08, 0.36))
	marker.draw_arc(Vector2(0.0, 2.0), 74.0, 0.0, TAU, 32, ring_col, 2.5)


func _on_draw_structure_upgrades(node: Node2D) -> void:
	var sid: String = String(node.get_meta("sid", ""))
	var upgs: Array[Dictionary] = GnorpGame.get_upgrades_for_structure(sid)
	var owned_idx: int = 0
	for u: Dictionary in upgs:
		if GnorpGame.is_upgrade_owned(String(u["id"])):
			var ox: float = -34.0 + float(owned_idx) * 34.0
			var oy: float = -182.0 + sin(_time * 3.2 + float(owned_idx)) * 4.0
			node.draw_circle(Vector2(ox, oy), 9.0, Color(1.0, 0.76, 0.20, 0.32))
			var gem := PackedVector2Array([
				Vector2(ox, oy - 7.0), Vector2(ox + 6.0, oy), Vector2(ox, oy + 7.0), Vector2(ox - 6.0, oy)
			])
			node.draw_colored_polygon(gem, Color(1.0, 0.90, 0.34, 0.95))
			owned_idx += 1


func _on_draw_meteor() -> void:
	if _meteor_node == null or _meteor_destroyed:
		return
	var r: float = 54.0
	var pulse: float = sin(_time * 8.0) * 4.0
	var flash_mix: Color = Color(1.0, 0.96, 0.78, 1.0)
	var hp_ratio: float = clampf(GnorpGame.meteor_hp / maxf(GnorpGame.meteor_max_hp, 1.0), 0.0, 1.0)

	# Cauda flamejante superior direita
	for i: int in range(5):
		var off: float = float(i) * 26.0
		var tr: float = maxf(r * (0.95 - float(i) * 0.16) + pulse * 0.4, 8.0)
		var col := Color(1.0, 0.44 - float(i) * 0.06, 0.12, 0.42 - float(i) * 0.07)
		_meteor_node.draw_circle(Vector2(off * 0.85, -off * 0.95), tr, col)

	# Halo de fogo
	_meteor_node.draw_circle(Vector2.ZERO, r + 22.0 + pulse, Color(1.0, 0.42, 0.12, 0.28))
	_meteor_node.draw_circle(Vector2.ZERO, r + 10.0, Color(1.0, 0.68, 0.18, 0.52))

	# Rocha irregular girando
	var rock_pts := PackedVector2Array()
	var segs: int = 12
	for i: int in range(segs):
		var a: float = (float(i) / float(segs)) * TAU + _time * 0.55
		var rr: float = r * (0.86 + 0.18 * sin(float(i) * 2.7))
		rock_pts.append(Vector2(cos(a) * rr, sin(a) * rr))
	var rock_col: Color = Color(0.28, 0.14, 0.12, 1.0).lerp(flash_mix, _meteor_flash * 0.8)
	_meteor_node.draw_colored_polygon(rock_pts, rock_col)

	# Veios de magma incandescentes + rachaduras progressivas conforme o HP cai
	_meteor_node.draw_circle(Vector2(-10.0, 8.0), 14.0, Color(1.0, 0.56, 0.16, 0.75))
	_meteor_node.draw_circle(Vector2(14.0, -12.0), 9.0, Color(1.0, 0.84, 0.30, 0.85))
	if hp_ratio < 0.70:
		_meteor_node.draw_line(Vector2(-24.0, -14.0), Vector2(4.0, 6.0), Color(1.0, 0.78, 0.24, 0.92), 3.0)
		_meteor_node.draw_line(Vector2(4.0, 6.0), Vector2(28.0, 18.0), Color(1.0, 0.56, 0.16, 0.90), 2.5)
	if hp_ratio < 0.35:
		_meteor_node.draw_line(Vector2(18.0, -28.0), Vector2(-4.0, 4.0), Color(1.0, 0.92, 0.48, 0.98), 4.0)
		_meteor_node.draw_line(Vector2(-4.0, 4.0), Vector2(-26.0, 26.0), Color(1.0, 0.68, 0.22, 0.95), 3.5)

	# Anel discreto de HP sob o meteoro
	var bar_w: float = 120.0
	_meteor_node.draw_rect(Rect2(-bar_w * 0.5, r + 22.0, bar_w, 8.0), Color(0.12, 0.05, 0.05, 0.88))
	_meteor_node.draw_rect(Rect2(-bar_w * 0.5 + 1.0, r + 23.0, (bar_w - 2.0) * hp_ratio, 6.0), Color(1.0, 0.46, 0.18, 1.0))


func _on_draw_vfx() -> void:
	if _vfx_draw == null:
		return

	# Arcos parabólicos dos estilhaços
	for sh: Dictionary in _flying_shards:
		var t: float = float(sh["t"])
		var p0: Vector2 = sh["p0"] as Vector2
		var p2: Vector2 = sh["p2"] as Vector2
		var pos: Vector2 = p0.lerp(p2, t)
		pos.y -= sin(t * PI) * float(sh["peak"])
		var sz: float = float(sh["size"])
		var col: Color = sh["color"] as Color
		_vfx_draw.draw_rect(Rect2(pos - Vector2(sz * 0.5, sz * 0.5), Vector2(sz, sz)), col)

	# Raios de energia âmbar contra o Meteoro
	for bm: Dictionary in _beams:
		var ratio: float = 1.0 - clampf(float(bm["t"]) / maxf(float(bm["dur"]), 0.01), 0.0, 1.0)
		var from_pt: Vector2 = bm["from"] as Vector2
		var to_pt: Vector2 = bm["to"] as Vector2
		var col: Color = bm["color"] as Color
		var w: float = float(bm["width"]) * ratio
		_vfx_draw.draw_line(from_pt, to_pt, Color(col.r, col.g, col.b, ratio * 0.45), w * 2.2)
		_vfx_draw.draw_line(from_pt, to_pt, Color(1.0, 0.96, 0.78, ratio), maxf(w * 0.65, 2.0))
		_vfx_draw.draw_circle(to_pt, 18.0 * ratio, Color(col.r, col.g, col.b, ratio * 0.7))

	# Ondas expansivas
	for sw: Dictionary in _shockwaves:
		var prog: float = clampf(float(sw["t"]) / maxf(float(sw["dur"]), 0.01), 0.0, 1.0)
		var r: float = lerpf(18.0, float(sw["max_r"]), ease(prog, 0.45))
		var col: Color = sw["color"] as Color
		_vfx_draw.draw_arc(sw["pos"] as Vector2, r, 0.0, TAU, 48, Color(col.r, col.g, col.b, (1.0 - prog) * col.a), 4.0)

	# Explosão dourada na destruição do meteoro
	for ep: Dictionary in _explosion_particles:
		var prog: float = clampf(float(ep["t"]) / maxf(float(ep["dur"]), 0.01), 0.0, 1.0)
		var col: Color = ep["color"] as Color
		_vfx_draw.draw_circle(ep["pos"] as Vector2, float(ep["size"]) * (1.0 - prog * 0.6), Color(col.r, col.g, col.b, 1.0 - prog))


func _load_tex(path: String) -> Texture2D:
	if path == "":
		return null
	if _tex_cache.has(path):
		return _tex_cache[path] as Texture2D
	if not ResourceLoader.exists(path):
		return null
	var loaded: Texture2D = load(path) as Texture2D
	_tex_cache[path] = loaded
	return loaded


static func _make_ellipse(rx: float, ry: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in range(segments):
		var a: float = (float(i) / float(segments)) * TAU
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts
