class_name DinoSwarm
extends Node2D
## Enxame de dinossauros renderizado via MultiMeshInstance2D.
##
## • Simulação de combate O(espécies): mesmo com 10.000 unidades de uma espécie,
##   o cálculo de DPS e emissão de `Events.dig_hit` ocorre por espécie no intervalo `attack_interval`.
## • Simulação visual na GPU/MultiMesh: até MAX_VISUAL_INSTANCES agentes caminhando,
##   saltando (ou voando no caso de TRANSPORT) na superfície da escavação, usando `DinoData.sprite`
##   quando disponível ou quad colorido de fallback.

const MAX_VISUAL_INSTANCES: int = 500
const STAGE_MIN_X: float = 40.0
const STAGE_MAX_X: float = 980.0

class VisualAgent:
	var dino_id: StringName = &""
	var x: float = 100.0
	var base_y: float = 0.0
	var dir: float = 1.0
	var speed: float = 80.0
	var phase: float = 0.0
	var size: Vector2 = Vector2(22.0, 18.0)
	var color: Color = Color.WHITE
	var is_flying: bool = false
	var lunge_timer: float = 0.0
	var has_sprite: bool = false

@onready var _multimesh_instance: MultiMeshInstance2D = %MultiMeshInstance2D

var _agents: Array[VisualAgent] = []
var _attack_timers: Dictionary = {}
var _species_multimeshes: Dictionary = {}
var _quad_mesh_2d: ArrayMesh = null


func _ready() -> void:
	_quad_mesh_2d = _build_2d_quad_mesh()
	_setup_multimesh()
	Events.dino_count_changed.connect(_on_dino_count_changed)
	Events.run_started.connect(_on_run_started)
	Events.game_loaded.connect(_rebuild_all_agents)
	_rebuild_all_agents()


func _process(delta: float) -> void:
	if GameState.is_impacting:
		return
	_simulate_species_attacks(delta)
	_animate_visual_agents(delta)


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


func _setup_multimesh() -> void:
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
	var inst := MultiMeshInstance2D.new()
	inst.name = "MM_%s" % String(data.id)
	inst.texture = data.sprite
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_2D
	mm.use_colors = true
	mm.mesh = _quad_mesh_2d
	mm.instance_count = 60
	mm.visible_instance_count = 0
	inst.multimesh = mm
	add_child(inst)
	_species_multimeshes[data.id] = inst
	return inst


func _simulate_species_attacks(delta: float) -> void:
	for dino_id: Variant in GameState.dino_counts:
		var count: int = GameState.get_dino_count(dino_id)
		if count <= 0:
			continue
		var data: DinoData = GameState.get_dino(dino_id)
		if data == null or data.attack_interval <= 0.0:
			continue

		var elapsed: float = _attack_timers.get(dino_id, 0.0) + delta
		if elapsed >= data.attack_interval:
			var swings: int = floori(elapsed / data.attack_interval)
			elapsed = fmod(elapsed, data.attack_interval)
			var dmg: float = GameState.get_dino_damage(dino_id) * float(count) * float(swings)
			var is_crit: bool = randf() < data.crit_chance
			if is_crit:
				dmg *= data.crit_multiplier
			var hit_pos: Vector2 = global_position + Vector2(randf_range(STAGE_MIN_X, STAGE_MAX_X), 40.0)
			Events.dig_hit.emit(dmg, hit_pos, is_crit)
			_trigger_species_lunge(dino_id)
		_attack_timers[dino_id] = elapsed


func _trigger_species_lunge(dino_id: StringName) -> void:
	for agent: VisualAgent in _agents:
		if agent.dino_id == dino_id:
			agent.lunge_timer = 0.16


func _animate_visual_agents(delta: float) -> void:
	var fallback_mm: MultiMesh = _multimesh_instance.multimesh
	if fallback_mm == null:
		return

	var fallback_idx: int = 0
	var species_counts: Dictionary = {}
	var total: int = mini(_agents.size(), MAX_VISUAL_INSTANCES)

	for i: int in range(total):
		var a: VisualAgent = _agents[i]
		a.phase += delta * (a.speed * 0.08)
		a.x += a.dir * a.speed * delta
		if a.x < STAGE_MIN_X:
			a.x = STAGE_MIN_X
			a.dir = 1.0
		elif a.x > STAGE_MAX_X:
			a.x = STAGE_MAX_X
			a.dir = -1.0

		var hop: float = absf(sin(a.phase)) * (10.0 if a.is_flying else 6.0)
		var lunge_y: float = 0.0
		if a.lunge_timer > 0.0:
			a.lunge_timer = maxf(a.lunge_timer - delta, 0.0)
			lunge_y = 10.0

		var pos: Vector2 = Vector2(a.x, a.base_y - hop + lunge_y)
		# Sprites olham para a esquerda por padrão; quando dir > 0 (direita), inverte X (-size.x).
		var sx: float = -a.size.x * a.dir if a.has_sprite else a.size.x * a.dir
		var sy: float = a.size.y * (1.15 if a.lunge_timer > 0.0 else 1.0)
		var xform := Transform2D(Vector2(sx, 0.0), Vector2(0.0, sy), pos)

		if a.has_sprite and _species_multimeshes.has(a.dino_id):
			var sp_inst: MultiMeshInstance2D = _species_multimeshes[a.dino_id] as MultiMeshInstance2D
			var sp_mm: MultiMesh = sp_inst.multimesh
			var sp_idx: int = int(species_counts.get(a.dino_id, 0))
			if sp_idx < sp_mm.instance_count:
				sp_mm.set_instance_transform_2d(sp_idx, xform)
				sp_mm.set_instance_color(sp_idx, Color.WHITE)
				species_counts[a.dino_id] = sp_idx + 1
		else:
			fallback_mm.set_instance_transform_2d(fallback_idx, xform)
			fallback_mm.set_instance_color(fallback_idx, a.color)
			fallback_idx += 1

	fallback_mm.visible_instance_count = fallback_idx
	for sp_id: Variant in _species_multimeshes:
		var sp_inst: MultiMeshInstance2D = _species_multimeshes[sp_id] as MultiMeshInstance2D
		sp_inst.multimesh.visible_instance_count = int(species_counts.get(sp_id, 0))


func _on_dino_count_changed(dino_id: StringName, new_count: int) -> void:
	var current_visual: int = 0
	for a: VisualAgent in _agents:
		if a.dino_id == dino_id:
			current_visual += 1

	var target_visual: int = mini(new_count, 60)
	if target_visual > current_visual:
		var data: DinoData = GameState.get_dino(dino_id)
		if data != null:
			if data.sprite != null:
				_get_or_create_species_multimesh(data)
			for _i: int in range(target_visual - current_visual):
				if _agents.size() >= MAX_VISUAL_INSTANCES:
					break
				_agents.append(_create_agent(data))
	elif target_visual < current_visual:
		_rebuild_all_agents()


func _on_run_started(_run_number: int) -> void:
	_attack_timers.clear()
	_rebuild_all_agents()


func _rebuild_all_agents() -> void:
	_agents.clear()
	for data: DinoData in GameState.get_dinos_sorted():
		if data.sprite != null:
			_get_or_create_species_multimesh(data)
		var count: int = GameState.get_dino_count(data.id)
		var visual_count: int = mini(count, 60)
		for _i: int in range(visual_count):
			if _agents.size() >= MAX_VISUAL_INSTANCES:
				break
			_agents.append(_create_agent(data))
	if _multimesh_instance != null and _multimesh_instance.multimesh != null:
		_multimesh_instance.multimesh.visible_instance_count = 0
	for sp_id: Variant in _species_multimeshes:
		var sp_inst: MultiMeshInstance2D = _species_multimeshes[sp_id] as MultiMeshInstance2D
		sp_inst.multimesh.visible_instance_count = 0


func _create_agent(data: DinoData) -> VisualAgent:
	var a := VisualAgent.new()
	a.dino_id = data.id
	a.x = randf_range(STAGE_MIN_X, STAGE_MAX_X)
	a.dir = 1.0 if randf() < 0.5 else -1.0
	a.speed = data.move_speed * randf_range(0.85, 1.15)
	a.phase = randf() * TAU
	a.color = data.accent_color
	a.has_sprite = (data.sprite != null)
	a.is_flying = (data.role == DinoData.Role.TRANSPORT)
	a.base_y = randf_range(-90.0, -45.0) if a.is_flying else randf_range(-24.0, -10.0)
	if a.has_sprite:
		a.size = Vector2(36.0, 36.0)
	else:
		match data.role:
			DinoData.Role.COLLECTOR, DinoData.Role.FAST:
				a.size = Vector2(18.0, 14.0)
			DinoData.Role.BREAKER, DinoData.Role.SUPPORT:
				a.size = Vector2(34.0, 28.0)
			_:
				a.size = Vector2(26.0, 20.0)
	return a
