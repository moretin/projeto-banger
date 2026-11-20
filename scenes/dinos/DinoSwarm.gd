class_name DinoSwarm
extends Node2D
## Equipe de Dinossauros Trabalhadores no Corte Geológico (MultiMesh GPU-instanced).
##
## • Combate O(espécies): mesmo com centenas de unidades, golpes e dano rodam por espécie.
## • Renderização 60 FPS na Web via `MultiMeshInstance2D` por espécie (`MAX_VISUAL_INSTANCES = 160`)
##   com filtro pixel-art NEAREST e um único canvas em lote (`WorkOverlay`) para itens e ações:
##     - COLLECTOR (Compsognato): leva feixes de ossos até o cesto/guincho lateral.
##     - TRANSPORT (Pterodáctilo): voa na cota superior levando cristais de minério.
##     - AREA (Tricerátopo): empurra blocos fendidos ao longo da bancada.
##     - DEFENSE (Anquilossauro): sustenta/rebate escombros do teto na couraça + clava.
##     - BREAKER (T-Rex): pisada pesada + mordida esmagadora na jazida.
##     - FAST (Velociraptor): investidas com rasgos triplos de garra.
##     - SUPPORT (Braquiossauro): balanço de pescoço + ondas douradas de ressonância.
##     - ELEMENTAL (Dilofossauro): cospe globos parabólicos de ácido bio-âmbar.

const MAX_VISUAL_INSTANCES: int = 160
const MAX_SPECIES_VISUAL: int = 24
const MAX_ACTIVE_FX: int = 48
const STAGE_MIN_X: float = 82.0
const DEFAULT_STAGE_MAX_X: float = 960.0
const HOIST_BASKET_X: float = 96.0
const RIGHT_FACING_DINOS: Dictionary = {
	&"compsognathus": true,
	&"pterodactyl": true,
	&"pachycephalosaurus": true,
}


class VisualAgent:
	var dino_id: StringName = &""
	var role: DinoData.Role = DinoData.Role.COLLECTOR
	var x: float = 160.0
	var base_y: float = -16.0
	var dir: float = 1.0
	var speed: float = 80.0
	var phase: float = 0.0
	var size: Vector2 = Vector2(36.0, 36.0)
	var accent: Color = Color.WHITE
	var lunge_timer: float = 0.0
	var carrying: bool = false
	var block_offset_x: float = 34.0
	var spit_cooldown: float = 1.0


@onready var _multimesh_instance: MultiMeshInstance2D = %MultiMeshInstance2D

var _agents: Array[VisualAgent] = []
var _attack_timers: Dictionary = {}
var _species_multimeshes: Dictionary = {}
var _quad_mesh_2d: ArrayMesh = null
var _work_overlay: Node2D = null
var _active_fx: Array[Dictionary] = []
var _basket_bones_level: float = 0.4
var _hoist_pulse: float = 0.0
var _falling_pebbles: Array[Dictionary] = []


func _ready() -> void:
	_quad_mesh_2d = _build_2d_quad_mesh()
	_setup_fallback_bone_mesh()
	_work_overlay = Node2D.new()
	_work_overlay.name = "WorkOverlay"
	_work_overlay.z_index = 2
	add_child(_work_overlay)
	_work_overlay.draw.connect(_on_work_overlay_draw)

	Events.dino_count_changed.connect(_on_dino_count_changed)
	Events.run_started.connect(_on_run_started)
	Events.game_loaded.connect(_rebuild_all_agents)
	_rebuild_all_agents()


func _process(delta: float) -> void:
	if GameState.is_impacting:
		return
	_hoist_pulse = maxf(_hoist_pulse - delta * 2.5, 0.0)
	_basket_bones_level = clampf(lerpf(_basket_bones_level, 0.35 + minf(float(_agents.size()) * 0.03, 0.65), delta * 2.0), 0.25, 1.0)
	_simulate_species_attacks(delta)
	_animate_visual_agents(delta)
	_tick_fx(delta)
	if _work_overlay != null:
		_work_overlay.queue_redraw()


func _get_stage_max_x() -> float:
	var parent_node: Node = get_parent()
	if parent_node != null and parent_node.get_parent() != null:
		var grand: Node = parent_node.get_parent()
		if grand is Control:
			var w: float = (grand as Control).size.x
			if w > 300.0:
				return clampf(w - 92.0, 620.0, 1280.0)
	return DEFAULT_STAGE_MAX_X


static func _build_2d_quad_mesh() -> ArrayMesh:
	var arr_mesh := ArrayMesh.new()
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([
		Vector2(-0.5, -0.5),
		Vector2(0.5, -0.5),
		Vector2(0.5, 0.5),
		Vector2(-0.5, 0.5),
	])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0),
	])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return arr_mesh


func _setup_fallback_bone_mesh() -> void:
	_multimesh_instance.texture = AmberTheme.get_icon(&"bones")
	_multimesh_instance.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = _quad_mesh_2d
	mm.instance_count = MAX_VISUAL_INSTANCES
	mm.visible_instance_count = 0
	_multimesh_instance.multimesh = mm


func _get_or_create_species_multimesh(data: DinoData) -> MultiMeshInstance2D:
	if _species_multimeshes.has(data.id):
		return _species_multimeshes[data.id] as MultiMeshInstance2D
	var sprite_tex: Texture2D = AmberTheme.get_dino_sprite(data.id, data.sprite)
	if sprite_tex == null:
		sprite_tex = AmberTheme.get_icon(&"bones")
	var inst := MultiMeshInstance2D.new()
	inst.name = "MM_%s" % String(data.id)
	inst.texture = sprite_tex
	inst.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = _quad_mesh_2d
	mm.instance_count = MAX_SPECIES_VISUAL + 8
	mm.visible_instance_count = 0
	inst.multimesh = mm
	add_child(inst)
	_species_multimeshes[data.id] = inst
	return inst


func _simulate_species_attacks(delta: float) -> void:
	var max_x: float = _get_stage_max_x()
	for dino_id: Variant in GameState.dino_counts:
		var count: int = GameState.get_dino_count(dino_id)
		if count <= 0:
			continue
		var data: DinoData = GameState.get_dino(dino_id)
		if data == null or data.attack_interval <= 0.0:
			continue

		var elapsed: float = float(_attack_timers.get(dino_id, 0.0)) + delta
		if elapsed >= data.attack_interval:
			var swings: int = floori(elapsed / data.attack_interval)
			elapsed = fmod(elapsed, data.attack_interval)
			var dmg: float = GameState.get_dino_damage(dino_id) * float(count) * float(swings)
			var is_crit: bool = randf() < data.crit_chance
			if is_crit:
				dmg *= data.crit_multiplier
			var hit_pos: Vector2 = global_position + Vector2(randf_range(STAGE_MIN_X + 60.0, max_x - 40.0), 42.0)
			Events.dig_hit.emit(dmg, hit_pos, is_crit)
			_trigger_species_action(dino_id, data.role)
		_attack_timers[dino_id] = elapsed


func _trigger_species_action(dino_id: StringName, role: DinoData.Role) -> void:
	var triggered_one: bool = false
	for agent: VisualAgent in _agents:
		if agent.dino_id != dino_id:
			continue
		agent.lunge_timer = 0.24
		if not triggered_one:
			triggered_one = true
			match role:
				DinoData.Role.BREAKER:
					_spawn_fx("bite", Vector2(agent.x + agent.dir * 18.0, 22.0), 0.36, agent.accent)
				DinoData.Role.FAST:
					_spawn_fx("slash", Vector2(agent.x + agent.dir * 14.0, 14.0), 0.28, Color(1.0, 0.85, 0.42))
				DinoData.Role.SUPPORT:
					_spawn_fx("aura", Vector2(agent.x, agent.base_y), 0.72, Color(0.98, 0.82, 0.35))
				DinoData.Role.ELEMENTAL:
					_spawn_fx("acid", Vector2(agent.x + agent.dir * 18.0, agent.base_y - 4.0), 0.55, Color(0.65, 0.96, 0.35), agent.dir)
				DinoData.Role.DEFENSE:
					_spawn_fx("shield", Vector2(agent.x, agent.base_y - 22.0), 0.38, Color(0.95, 0.84, 0.55))


func _spawn_fx(kind: String, pos: Vector2, dur: float, col: Color, dir: float = 1.0) -> void:
	if _active_fx.size() >= MAX_ACTIVE_FX:
		_active_fx.pop_front()
	_active_fx.append({
		"kind": kind,
		"pos": pos,
		"start_pos": pos,
		"dir": dir,
		"t": 0.0,
		"dur": dur,
		"color": col,
	})


func _tick_fx(delta: float) -> void:
	var i: int = _active_fx.size() - 1
	while i >= 0:
		var fx: Dictionary = _active_fx[i]
		var t: float = float(fx["t"]) + delta
		if t >= float(fx["dur"]):
			_active_fx.remove_at(i)
		else:
			fx["t"] = t
		i -= 1


func _animate_visual_agents(delta: float) -> void:
	var max_x: float = _get_stage_max_x()
	var fallback_mm: MultiMesh = _multimesh_instance.multimesh
	if fallback_mm == null:
		return

	var fallback_idx: int = 0
	var species_counts: Dictionary = {}
	var total: int = mini(_agents.size(), MAX_VISUAL_INSTANCES)

	for i: int in range(total):
		var a: VisualAgent = _agents[i]
		a.phase += delta * maxf(a.speed * 0.065, 1.5)
		if a.lunge_timer > 0.0:
			a.lunge_timer = maxf(a.lunge_timer - delta, 0.0)

		var pos := Vector2(a.x, a.base_y)
		var rot: float = 0.0
		var sy_mult: float = 1.0

		match a.role:
			DinoData.Role.COLLECTOR:
				# Compsognato corre com carga de ossos de volta até o cesto/guincho lateral
				a.x += a.dir * a.speed * delta
				if a.dir < 0.0 and a.x <= HOIST_BASKET_X + 18.0:
					a.x = HOIST_BASKET_X + 18.0
					a.dir = 1.0
					if a.carrying:
						a.carrying = false
						_hoist_pulse = 1.0
				elif a.dir > 0.0 and a.x >= max_x - 70.0:
					a.dir = -1.0
					a.carrying = true
				elif not a.carrying and a.dir < 0.0 and a.x < max_x * 0.65:
					a.carrying = true
				var scurry: float = absf(sin(a.phase * 1.4)) * 4.5
				pos = Vector2(a.x, a.base_y - scurry)

			DinoData.Role.TRANSPORT:
				# Pterodáctilo voa em curvas na cota superior da trincheira levando cristais de minério
				a.x += a.dir * a.speed * delta
				if a.x < STAGE_MIN_X + 35.0:
					a.x = STAGE_MIN_X + 35.0
					a.dir = 1.0
					a.carrying = true
				elif a.x > max_x - 35.0:
					a.x = max_x - 35.0
					a.dir = -1.0
					a.carrying = false
				var swoop: float = sin(a.phase * 0.9) * 16.0
				pos = Vector2(a.x, a.base_y + swoop)
				rot = a.dir * cos(a.phase * 0.9) * 0.14
				sy_mult = 1.0 + sin(a.phase * 3.8) * 0.16

			DinoData.Role.AREA:
				# Tricerátopo inclina os chifres empurrando bloco fendido de pedra
				a.x += a.dir * (a.speed * 0.58) * delta
				if a.x < STAGE_MIN_X + 90.0:
					a.x = STAGE_MIN_X + 90.0
					a.dir = 1.0
				elif a.x > max_x - 90.0:
					a.x = max_x - 90.0
					a.dir = -1.0
				pos = Vector2(a.x, a.base_y - absf(sin(a.phase * 0.7)) * 2.0)
				rot = -0.10 * a.dir

			DinoData.Role.DEFENSE:
				# Anquilossauro vigia as bordas/escoras rebatendo escombros do teto
				a.x += a.dir * (a.speed * 0.28) * delta
				var guard_min: float = STAGE_MIN_X + 36.0
				var guard_max: float = max_x - 36.0
				if a.x > 260.0 and a.x < max_x - 260.0:
					a.x = guard_min if a.dir < 0.0 else guard_max
				if a.x <= guard_min:
					a.x = guard_min
					a.dir = 1.0
				elif a.x >= guard_max:
					a.x = guard_max
					a.dir = -1.0
				var brace_shake: float = sin(a.phase * 2.2) * 1.5
				pos = Vector2(a.x, a.base_y + brace_shake)
				if a.lunge_timer > 0.0:
					rot = -0.18 * a.dir

			DinoData.Role.BREAKER:
				# T-Rex anda lento e pesado; dá mordida vertical firme na jazida
				a.x += a.dir * (a.speed * 0.45) * delta
				if a.x < STAGE_MIN_X + 60.0:
					a.x = STAGE_MIN_X + 60.0
					a.dir = 1.0
				elif a.x > max_x - 60.0:
					a.x = max_x - 60.0
					a.dir = -1.0
				var stomp: float = absf(sin(a.phase * 0.65)) * 3.5
				var chomp_y: float = 9.0 if a.lunge_timer > 0.0 else 0.0
				pos = Vector2(a.x, a.base_y - stomp + chomp_y)
				if a.lunge_timer > 0.0:
					rot = 0.22 * a.dir
					sy_mult = 1.12

			DinoData.Role.FAST:
				# Velociraptor avança rasante rápido
				a.x += a.dir * (a.speed * 1.25) * delta
				if a.x < STAGE_MIN_X + 40.0:
					a.x = STAGE_MIN_X + 40.0
					a.dir = 1.0
				elif a.x > max_x - 40.0:
					a.x = max_x - 40.0
					a.dir = -1.0
				var dash: float = absf(sin(a.phase * 1.6)) * 4.0
				pos = Vector2(a.x, a.base_y - dash)
				rot = 0.10 * a.dir if a.lunge_timer > 0.0 else 0.0

			DinoData.Role.SUPPORT:
				# Braquiossauro fica imponente balançando o pescoço e irradiando aura
				a.x += a.dir * (a.speed * 0.14) * delta
				if a.x < STAGE_MIN_X + 120.0:
					a.x = STAGE_MIN_X + 120.0
					a.dir = 1.0
				elif a.x > max_x - 120.0:
					a.x = max_x - 120.0
					a.dir = -1.0
				pos = Vector2(a.x, a.base_y + sin(a.phase * 0.4) * 1.5)
				rot = sin(a.phase * 0.5) * 0.05

			DinoData.Role.ELEMENTAL:
				# Dilofossauro desloca entre disparos de ácido bio-âmbar
				a.x += a.dir * (a.speed * 0.65) * delta
				if a.x < STAGE_MIN_X + 50.0:
					a.x = STAGE_MIN_X + 50.0
					a.dir = 1.0
				elif a.x > max_x - 50.0:
					a.x = max_x - 50.0
					a.dir = -1.0
				pos = Vector2(a.x, a.base_y - absf(sin(a.phase)) * 3.0)
				if a.lunge_timer > 0.0:
					rot = -0.15 * a.dir

		# Ajusta orientação horizontal de acordo com a direção padrão da arte.
		var face_sign: float = 1.0 if RIGHT_FACING_DINOS.has(a.dino_id) else -1.0
		var sx: float = a.size.x * a.dir * face_sign
		var sy: float = a.size.y * sy_mult
		var xform := Transform2D(rot, Vector2(sx, sy), 0.0, pos)

		if _species_multimeshes.has(a.dino_id):
			var sp_inst: MultiMeshInstance2D = _species_multimeshes[a.dino_id] as MultiMeshInstance2D
			var sp_mm: MultiMesh = sp_inst.multimesh
			var sp_idx: int = int(species_counts.get(a.dino_id, 0))
			if sp_idx < sp_mm.instance_count:
				sp_mm.set_instance_transform_2d(sp_idx, xform)
				sp_mm.set_instance_color(sp_idx, Color.WHITE)
				species_counts[a.dino_id] = sp_idx + 1
		else:
			fallback_mm.set_instance_transform_2d(fallback_idx, xform)
			fallback_mm.set_instance_color(fallback_idx, Color.WHITE)
			fallback_idx += 1

	fallback_mm.visible_instance_count = fallback_idx
	for sp_id: Variant in _species_multimeshes:
		var sp_inst: MultiMeshInstance2D = _species_multimeshes[sp_id] as MultiMeshInstance2D
		sp_inst.multimesh.visible_instance_count = int(species_counts.get(sp_id, 0))


func _on_work_overlay_draw() -> void:
	if _agents.is_empty():
		return

	# Cesto / guincho de ossos à esquerda da bancada
	var basket_y: float = -18.0 - _hoist_pulse * 4.0
	_work_overlay.draw_rect(Rect2(HOIST_BASKET_X - 18.0, basket_y, 36.0, 22.0), Color(0.38, 0.23, 0.11, 0.95))
	_work_overlay.draw_rect(Rect2(HOIST_BASKET_X - 15.0, basket_y + 3.0, 30.0, 5.0), Color(0.68, 0.45, 0.20, 0.95))
	# Ossos empilhados dentro do cesto
	var pile_h: float = 6.0 * _basket_bones_level
	_work_overlay.draw_rect(Rect2(HOIST_BASKET_X - 10.0, basket_y - pile_h, 20.0, pile_h + 2.0), Color(0.97, 0.92, 0.78, 0.95))

	var drawn_loads: int = 0
	var total: int = mini(_agents.size(), MAX_VISUAL_INSTANCES)
	for i: int in range(total):
		if drawn_loads >= 64:
			break
		var a: VisualAgent = _agents[i]
		match a.role:
			DinoData.Role.COLLECTOR:
				if a.carrying:
					# Feixe visível de ossos nas costas do Compsognato
					var bpos := Vector2(a.x, a.base_y - 16.0)
					_work_overlay.draw_line(bpos + Vector2(-7.0, 2.0), bpos + Vector2(7.0, -2.0), Color(0.98, 0.93, 0.80), 4.0)
					_work_overlay.draw_circle(bpos + Vector2(-7.0, 2.0), 2.5, Color(0.98, 0.93, 0.80))
					_work_overlay.draw_circle(bpos + Vector2(7.0, -2.0), 2.5, Color(0.98, 0.93, 0.80))
					drawn_loads += 1
			DinoData.Role.TRANSPORT:
				if a.carrying:
					# Cristal de minério brilhante carregado pelo Pterodáctilo
					var mpos := Vector2(a.x + a.dir * 2.0, a.base_y + sin(a.phase * 0.9) * 16.0 + 18.0)
					var poly := PackedVector2Array([
						mpos + Vector2(0.0, -7.0), mpos + Vector2(6.0, 0.0),
						mpos + Vector2(0.0, 8.0), mpos + Vector2(-6.0, 0.0),
					])
					_work_overlay.draw_colored_polygon(poly, Color(0.45, 0.92, 0.95, 0.95))
					drawn_loads += 1
			DinoData.Role.AREA:
				# Bloco fendido de pedra empurrado pelo Tricerátopo
				var bx: float = a.x + a.dir * 28.0
				var by: float = a.base_y - 6.0
				_work_overlay.draw_rect(Rect2(bx - 10.0, by - 4.0, 20.0, 18.0), Color(0.54, 0.40, 0.24, 0.96))
				_work_overlay.draw_rect(Rect2(bx - 8.0, by - 2.0, 16.0, 4.0), Color(0.84, 0.67, 0.42, 0.85))
				drawn_loads += 1
			DinoData.Role.DEFENSE:
				# Pedregulhos do teto aparados sobre a couraça do Anquilossauro
				var offset_t: float = fmod(a.phase * 0.8, 1.0)
				var sy: float = lerpf(-58.0, -18.0, offset_t)
				_work_overlay.draw_circle(Vector2(a.x + sin(a.phase) * 8.0, sy), 4.0, Color(0.58, 0.42, 0.28, 0.85))
				drawn_loads += 1

	# Efeitos de ataque ativos (mordida, garra, onda sonora, ácido, escudo)
	for fx: Dictionary in _active_fx:
		var prog: float = clampf(float(fx["t"]) / maxf(float(fx["dur"]), 0.01), 0.0, 1.0)
		var alpha: float = 1.0 - prog
		var col: Color = fx["color"] as Color
		col.a = alpha
		var pos: Vector2 = fx["pos"] as Vector2
		match String(fx["kind"]):
			"bite":
				# Arco dentado de mordida do T-Rex sobre o topo da jazida
				var jaw_gap: float = lerpf(16.0, 2.0, prog)
				_work_overlay.draw_line(pos + Vector2(-12.0, -jaw_gap), pos + Vector2(12.0, -jaw_gap), Color(1.0, 0.96, 0.84, alpha), 3.0)
				_work_overlay.draw_line(pos + Vector2(-10.0, jaw_gap), pos + Vector2(10.0, jaw_gap), Color(1.0, 0.96, 0.84, alpha), 3.0)
			"slash":
				# Rasgo triplo diagonal do Velociraptor
				for k: int in range(-1, 2):
					var p0: Vector2 = pos + Vector2(-12.0 + float(k) * 5.0, -10.0)
					var p1: Vector2 = pos + Vector2(12.0 + float(k) * 5.0, 14.0)
					_work_overlay.draw_line(p0, p1, col, 2.5)
			"aura":
				# Ondas douradas concêntricas do Braquiossauro
				var r: float = lerpf(18.0, 74.0, prog)
				_work_overlay.draw_arc(pos + Vector2(0.0, -12.0), r, 0.0, TAU, 24, col, 2.2)
			"acid":
				# Trajetória parabólica de ácido do Dilofossauro
				var d: float = float(fx["dir"])
				var start_p: Vector2 = fx["start_pos"] as Vector2
				var cur_p: Vector2 = start_p + Vector2(d * prog * 46.0, -sin(prog * PI) * 26.0 + prog * 28.0)
				_work_overlay.draw_circle(cur_p, 5.0, col)
			"shield":
				# Arco de deflexão sobre o Anquilossauro
				_work_overlay.draw_arc(pos, 22.0, PI * 1.1, PI * 1.9, 12, col, 3.0)


func _on_dino_count_changed(dino_id: StringName, new_count: int) -> void:
	var current_visual: int = 0
	for a: VisualAgent in _agents:
		if a.dino_id == dino_id:
			current_visual += 1

	var target_visual: int = mini(new_count, MAX_SPECIES_VISUAL)
	if target_visual > current_visual:
		var data: DinoData = GameState.get_dino(dino_id)
		if data != null:
			_get_or_create_species_multimesh(data)
			for _i: int in range(target_visual - current_visual):
				if _agents.size() >= MAX_VISUAL_INSTANCES:
					break
				_agents.append(_create_agent(data))
	elif target_visual < current_visual:
		_rebuild_all_agents()


func _on_run_started(_run_number: int) -> void:
	_attack_timers.clear()
	_active_fx.clear()
	_rebuild_all_agents()


func _rebuild_all_agents() -> void:
	_agents.clear()
	var max_x: float = _get_stage_max_x()
	for data: DinoData in GameState.get_dinos_sorted():
		_get_or_create_species_multimesh(data)
		var count: int = GameState.get_dino_count(data.id)
		var visual_count: int = mini(count, MAX_SPECIES_VISUAL)
		for _i: int in range(visual_count):
			if _agents.size() >= MAX_VISUAL_INSTANCES:
				break
			_agents.append(_create_agent(data, max_x))
	if _multimesh_instance != null and _multimesh_instance.multimesh != null:
		_multimesh_instance.multimesh.visible_instance_count = 0
	for sp_id: Variant in _species_multimeshes:
		var sp_inst: MultiMeshInstance2D = _species_multimeshes[sp_id] as MultiMeshInstance2D
		sp_inst.multimesh.visible_instance_count = 0


func _create_agent(data: DinoData, max_x: float = DEFAULT_STAGE_MAX_X) -> VisualAgent:
	var a := VisualAgent.new()
	a.dino_id = data.id
	a.role = data.role
	a.x = randf_range(STAGE_MIN_X + 30.0, max_x - 30.0)
	a.dir = 1.0 if randf() < 0.5 else -1.0
	a.speed = data.move_speed * randf_range(0.85, 1.15)
	a.phase = randf() * TAU
	a.accent = data.accent_color
	a.carrying = (randf() < 0.5)

	match data.role:
		DinoData.Role.COLLECTOR:
			a.size = Vector2(54.0, 22.0)
			a.base_y = randf_range(-16.0, -8.0)
		DinoData.Role.TRANSPORT:
			a.size = Vector2(44.0, 41.0)
			a.base_y = randf_range(-88.0, -50.0)
		DinoData.Role.BREAKER:
			a.size = Vector2(48.0, 44.0)
			a.base_y = -20.0
		DinoData.Role.SUPPORT:
			a.size = Vector2(54.0, 50.0)
			a.base_y = -24.0
		DinoData.Role.AREA, DinoData.Role.DEFENSE:
			a.size = Vector2(42.0, 32.0)
			a.base_y = -14.0
		_:
			a.size = Vector2(40.0, 34.0)
			a.base_y = randf_range(-18.0, -10.0)
	return a
