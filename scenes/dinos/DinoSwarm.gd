class_name DinoSwarm
extends Node2D
## Enxame de dinossauros em Pixel-Art caminhando pelo solo e céu no estilo Gnorp Apologue.
##
## • Simulação de combate O(espécies): mesmo com milhares de unidades de uma espécie,
##   o cálculo de DPS e emissão de `Events.dig_hit` ocorre por espécie no intervalo `attack_interval`.
## • Comportamentos por papel (GDD §4):
##   - Atacantes (T-Rex, Raptor, Tricerátopo, Anquilo, Dilofo): posicionam-se na frente da rocha,
##     olhando para a direita, e dão botes sincronizados contra o paredão.
##   - Coletores (Compsognato): correm entre a rocha e o acampamento carregando pacotes de ossos.
##   - Transporte (Pterodáctilo): sobrevoam o céu entre a base e o topo da rocha.
##   - Suporte (Braquiossauro): permanece atrás da linha de frente emitindo pulsos de aura.

const MAX_VISUAL_INSTANCES: int = 80

class VisualAgent:
	var dino_id: StringName = &""
	var role: DinoData.Role = DinoData.Role.BREAKER
	var x: float = 200.0
	var home_x: float = 200.0
	var front_offset: float = 40.0
	var dir: float = 1.0
	var carrying_bone: bool = false
	var speed: float = 80.0
	var phase: float = 0.0
	var fly_y_offset: float = 160.0
	var size: Vector2 = Vector2(56.0, 44.0)
	var is_flying: bool = false
	var lunge_timer: float = 0.0
	var buff_timer: float = 0.0
	var tex: Texture2D = null

@onready var _multimesh_instance: MultiMeshInstance2D = %MultiMeshInstance2D

var _dig_site: DigSite = null
var _agents: Array[VisualAgent] = []
var _attack_timers: Dictionary[StringName, float] = {}


func setup_world(dig_site: DigSite) -> void:
	_dig_site = dig_site


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _multimesh_instance != null:
		_multimesh_instance.visible = false
	Events.dino_count_changed.connect(_on_dino_count_changed)
	Events.run_started.connect(_on_run_started)
	Events.game_loaded.connect(_rebuild_all_agents)
	_rebuild_all_agents()


func _process(delta: float) -> void:
	if GameState.is_impacting:
		return
	_simulate_species_attacks(delta)
	_animate_visual_agents(delta)
	queue_redraw()


func _get_world_metrics() -> Dictionary:
	if _dig_site != null and is_instance_valid(_dig_site):
		return {
			"ground_y": _dig_site.get_ground_y(),
			"rock_x": _dig_site.get_rock_face_x(),
			"home_range": _dig_site.get_home_x_range(),
		}
	var vp: Vector2 = get_viewport_rect().size
	if vp.x <= 10.0 or vp.y <= 10.0:
		vp = Vector2(1600.0, 900.0)
	return {
		"ground_y": vp.y - 64.0,
		"rock_x": vp.x * 0.72,
		"home_range": Vector2(60.0, vp.x * 0.65),
	}


func _simulate_species_attacks(delta: float) -> void:
	var metrics: Dictionary = _get_world_metrics()
	var ground_y: float = float(metrics["ground_y"])
	var rock_x: float = float(metrics["rock_x"])
	for dino_id: StringName in GameState.dino_counts:
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
			var local_hit := Vector2(rock_x + randf_range(12.0, 42.0), ground_y - randf_range(24.0, 110.0))
			var hit_global: Vector2 = _dig_site.get_global_transform_with_canvas() * local_hit if _dig_site != null else (global_position + local_hit)
			Events.dig_hit.emit(dmg, hit_global, is_crit)
			_trigger_species_lunge(dino_id)
		_attack_timers[dino_id] = elapsed


func _trigger_species_lunge(dino_id: StringName) -> void:
	for agent: VisualAgent in _agents:
		if agent.dino_id == dino_id:
			agent.lunge_timer = 0.20
			if agent.role == DinoData.Role.SUPPORT:
				agent.buff_timer = 0.45


func _animate_visual_agents(delta: float) -> void:
	var metrics: Dictionary = _get_world_metrics()
	var rock_x: float = float(metrics["rock_x"])
	var home_range: Vector2 = metrics["home_range"]

	for a: VisualAgent in _agents:
		a.phase += delta * 6.0
		if a.lunge_timer > 0.0:
			a.lunge_timer = maxf(a.lunge_timer - delta, 0.0)
		if a.buff_timer > 0.0:
			a.buff_timer = maxf(a.buff_timer - delta, 0.0)

		if a.is_flying:
			a.x += a.dir * a.speed * delta
			if a.x < home_range.x:
				a.x = home_range.x
				a.dir = 1.0
			elif a.x > rock_x + 30.0:
				a.x = rock_x + 30.0
				a.dir = -1.0
		elif a.role == DinoData.Role.COLLECTOR:
			a.x += a.dir * a.speed * delta
			if a.x >= rock_x - 24.0:
				a.x = rock_x - 24.0
				a.dir = -1.0
				a.carrying_bone = true
			elif a.x <= a.home_x:
				a.x = a.home_x
				a.dir = 1.0
				a.carrying_bone = false
		elif a.role == DinoData.Role.SUPPORT:
			var target_x: float = clampf(rock_x - 165.0 - a.front_offset * 0.5, home_range.x, rock_x - 60.0)
			a.x = lerpf(a.x, target_x, minf(delta * 2.5, 1.0))
			a.dir = 1.0
		else:
			var target_x: float = clampf(rock_x - a.front_offset, home_range.x, rock_x - 18.0)
			a.x = lerpf(a.x, target_x, minf(delta * 4.0, 1.0))
			a.dir = 1.0


func _draw() -> void:
	if _agents.is_empty():
		return
	var metrics: Dictionary = _get_world_metrics()
	var ground_y: float = float(metrics["ground_y"])

	for a: VisualAgent in _agents:
		if a.tex == null:
			continue
		var hop: float = absf(sin(a.phase)) * (10.0 if a.is_flying else 4.0)
		var lunge_x: float = (16.0 * (a.lunge_timer / 0.20)) if (a.lunge_timer > 0.0 and a.dir > 0.0 and a.role != DinoData.Role.SUPPORT) else 0.0
		var pos_x: float = a.x + lunge_x
		var base_y: float = (ground_y - a.fly_y_offset + sin(a.phase * 0.5) * 14.0) if a.is_flying else (ground_y - a.size.y * 0.5)
		var pos := Vector2(round(pos_x), round(base_y - hop))

		# Sombra sutil no solo para voadores e terrestres
		if not a.is_flying:
			draw_rect(Rect2(round(pos.x - a.size.x * 0.30), ground_y - 2.0, round(a.size.x * 0.60), 3.0), Color(0, 0, 0, 0.35), true)

		# O sprite base olha para a esquerda; para olhar para a direita (dir > 0), espelha em X mantendo o centro.
		var face_right: bool = a.dir > 0.0
		var draw_x: float = (pos.x + a.size.x * 0.5) if face_right else (pos.x - a.size.x * 0.5)
		var draw_w: float = -a.size.x if face_right else a.size.x
		draw_texture_rect(a.tex, Rect2(Vector2(draw_x, pos.y - a.size.y * 0.5), Vector2(draw_w, a.size.y)), false)

		# Coletores carregam um ossinho branco de volta; voadores carregam minério ciano.
		if a.carrying_bone:
			var bx: float = pos.x + (a.size.x * 0.38 if face_right else -a.size.x * 0.45)
			draw_rect(Rect2(bx, pos.y - 6.0, 8.0, 5.0), UITheme.G_FG, true)
		elif a.is_flying and a.dir < 0.0:
			draw_rect(Rect2(pos.x - 4.0, pos.y + a.size.y * 0.35, 7.0, 7.0), Color("#5FE3E8"), true)

		# Braquiossauro emite pulso quadrado estilo Gnorp quando ativa aura
		if a.buff_timer > 0.0:
			var k: float = 1.0 - (a.buff_timer / 0.45)
			var r: float = round(a.size.x * 0.5 + k * 28.0)
			draw_rect(Rect2(pos - Vector2(r, r * 0.6), Vector2(r * 2.0, r * 1.2)), Color(UITheme.G_GOOD, 1.0 - k), false, 2.0)


func _on_dino_count_changed(dino_id: StringName, new_count: int) -> void:
	var current_visual: int = 0
	for a: VisualAgent in _agents:
		if a.dino_id == dino_id:
			current_visual += 1

	var target_visual: int = mini(new_count, 10)
	if target_visual > current_visual:
		var data: DinoData = GameState.get_dino(dino_id)
		if data != null:
			for _i: int in range(target_visual - current_visual):
				if _agents.size() >= MAX_VISUAL_INSTANCES:
					break
				_agents.append(_create_agent(data, _agents.size()))
	elif target_visual < current_visual:
		_rebuild_all_agents()


func _on_run_started(_run_number: int) -> void:
	_attack_timers.clear()
	_rebuild_all_agents()


func _rebuild_all_agents() -> void:
	_agents.clear()
	var idx: int = 0
	for data: DinoData in GameState.get_dinos_sorted():
		var count: int = GameState.get_dino_count(data.id)
		var visual_count: int = mini(count, 10)
		for _i: int in range(visual_count):
			if _agents.size() >= MAX_VISUAL_INSTANCES:
				break
			_agents.append(_create_agent(data, idx))
			idx += 1
	queue_redraw()


func _create_agent(data: DinoData, index: int) -> VisualAgent:
	var metrics: Dictionary = _get_world_metrics()
	var home_range: Vector2 = metrics["home_range"]
	var rock_x: float = float(metrics["rock_x"])

	var a := VisualAgent.new()
	a.dino_id = data.id
	a.role = data.role
	a.tex = UITheme.get_dino_sprite(data.id)
	a.home_x = randf_range(home_range.x + 20.0, minf(home_range.x + 280.0, home_range.y))
	a.front_offset = 24.0 + float(index % 6) * 16.0 + randf_range(-4.0, 4.0)
	a.x = randf_range(a.home_x, maxf(a.home_x + 40.0, rock_x - 40.0))
	a.dir = 1.0
	a.speed = data.move_speed * randf_range(0.9, 1.15)
	a.phase = randf() * TAU
	a.is_flying = (data.role == DinoData.Role.TRANSPORT)
	a.fly_y_offset = randf_range(140.0, 230.0)
	match data.role:
		DinoData.Role.COLLECTOR:
			a.size = Vector2(46.0, 36.0)
		DinoData.Role.FAST, DinoData.Role.ELEMENTAL:
			a.size = Vector2(56.0, 44.0)
		DinoData.Role.BREAKER, DinoData.Role.SUPPORT:
			a.size = Vector2(74.0, 58.0)
		_:
			a.size = Vector2(62.0, 48.0)
	return a
