class_name DinoSwarmStage
extends Node2D
## Palco vivo dos dinossauros do vale panorâmico (até ~65 atores simultâneos).
## Sincroniza com GnorpGame.dino_counts e executa os comportamentos físicos reais:
## pachy, compy, ptero, ankylo, trex e timer automático do Canhão Anti-Meteoro.

signal request_camera_shake(trauma: float)
signal ptero_meteor_shot_visual(from_pos: Vector2)

const MAX_VISIBLE_DINOS: int = 65
const SPECIES_ORDER: Array[String] = ["pachy", "compy", "ptero", "ankylo", "trex", "cannon"]

const HOME_X: Dictionary = {
	"pachy": 1180.0,
	"compy": 1440.0,
	"ptero": 1760.0,
	"ankylo": 2100.0,
	"trex": 2460.0,
	"cannon": 2820.0,
}

const SINGLE_TEXTURES: Dictionary = {
	"pachy": "res://assets/sprites/pachycephalosaurus.png",
	"compy": "res://assets/sprites/compsognathus.png",
	"ptero": "res://assets/sprites/pterodactyl.png",
	"ankylo": "res://assets/sprites/ankylosaurus.png",
	"trex": "res://assets/sprites/trex.png",
	"cannon": "res://assets/sprites/compsognathus.png",
}

const WORKER_SHEETS: Dictionary = {
	"pachy": "res://assets/sprites/surface/workers/pachycephalosaurus.png",
	"ptero": "res://assets/sprites/surface/workers/pterodactyl.png",
	"ankylo": "res://assets/sprites/surface/workers/ankylosaurus.png",
}

const COMPY_WALK_PATH: String = "res://assets/sprites/compsognathus_walk.png"

const RIGHT_FACING: Dictionary = {
	"pachy": true,
	"compy": true,
	"ptero": true,
	"cannon": true,
}

const TARGET_HEIGHT_PX: Dictionary = {
	"pachy": 54.0,
	"compy": 34.0,
	"ptero": 52.0,
	"ankylo": 58.0,
	"trex": 86.0,
	"cannon": 34.0,
}


class DinoActor:
	extends Node2D
	var species: String = ""
	var index: int = 0
	var sprite: Sprite2D = null
	var shadow: Polygon2D = null
	var crystal: Polygon2D = null
	var badge: Polygon2D = null
	var state: String = "to_target"
	var timer: float = 0.0
	var action_cd: float = 0.0
	var secondary_cd: float = 0.0
	var phase: float = 0.0
	var carrying: bool = false
	var home_x: float = 1180.0
	var target_x: float = 340.0
	var base_scale: float = 1.0
	var is_sheet_3x2: bool = false
	var is_compy_walk: bool = false
	var cell_size: Vector2 = Vector2.ZERO
	var single_tex: Texture2D = null
	var walk_tex: Texture2D = null
	var hit_squash: float = 0.0
	var facing_right: bool = false
	var carried_value: float = 0.0


var _actors: Array[DinoActor] = []
var _tex_cache: Dictionary = {}
var _sync_poll_timer: float = 0.0
var _last_counts: Dictionary = {}
var _cannon_timer: float = 0.8
var _roar_global_cooldown: float = 0.0
var _connected: bool = false


func _ready() -> void:
	_connect_signals()
	sync_with_game_state()


func _exit_tree() -> void:
	_disconnect_signals()
	for actor: DinoActor in _actors:
		if is_instance_valid(actor):
			actor.queue_free()
	_actors.clear()
	_tex_cache.clear()
	_last_counts.clear()


func _connect_signals() -> void:
	if _connected:
		return
	_connected = true
	GnorpGame.dino_recruited.connect(_on_dino_recruited)
	GnorpGame.structure_built.connect(_on_structure_built)
	GnorpGame.run_started.connect(_on_run_started)


func _disconnect_signals() -> void:
	if not _connected:
		return
	_connected = false
	if GnorpGame.dino_recruited.is_connected(_on_dino_recruited):
		GnorpGame.dino_recruited.disconnect(_on_dino_recruited)
	if GnorpGame.structure_built.is_connected(_on_structure_built):
		GnorpGame.structure_built.disconnect(_on_structure_built)
	if GnorpGame.run_started.is_connected(_on_run_started):
		GnorpGame.run_started.disconnect(_on_run_started)


func _on_dino_recruited(_species_id: String, _new_count: int, _struct_x: float) -> void:
	sync_with_game_state()


func _on_structure_built(_struct_id: String, _world_x: float) -> void:
	sync_with_game_state()


func _on_run_started(_run_number: int) -> void:
	_cannon_timer = 0.5
	_roar_global_cooldown = 0.0
	sync_with_game_state()


func sync_with_game_state() -> void:
	var desired: Dictionary = _compute_visible_allocation()
	var current_by_species: Dictionary = {}
	for sp: String in SPECIES_ORDER:
		current_by_species[sp] = []

	for actor: DinoActor in _actors:
		if not is_instance_valid(actor):
			continue
		var list_ref: Array = current_by_species[actor.species] as Array
		list_ref.append(actor)

	for sp: String in SPECIES_ORDER:
		var want: int = int(desired.get(sp, 0))
		var have_list: Array = current_by_species[sp] as Array
		while have_list.size() > want:
			var removed: DinoActor = have_list.pop_back() as DinoActor
			_actors.erase(removed)
			if is_instance_valid(removed):
				removed.queue_free()
		while have_list.size() < want:
			var idx: int = have_list.size()
			var created: DinoActor = _spawn_actor(sp, idx)
			have_list.append(created)
			_actors.append(created)

	_last_counts = GnorpGame.dino_counts.duplicate()


func _compute_visible_allocation() -> Dictionary:
	var alloc: Dictionary = {}
	var total_raw: int = 0
	for sp: String in SPECIES_ORDER:
		var cnt: int = maxi(GnorpGame.get_dino_count(sp), 0)
		alloc[sp] = cnt
		total_raw += cnt

	if total_raw <= MAX_VISIBLE_DINOS:
		return alloc

	var scaled: Dictionary = {}
	var assigned: int = 0
	for sp: String in SPECIES_ORDER:
		var cnt: int = int(alloc[sp])
		if cnt <= 0:
			scaled[sp] = 0
		else:
			var share: int = maxi(1, floori(float(cnt) * float(MAX_VISIBLE_DINOS) / float(total_raw)))
			scaled[sp] = share
			assigned += share

	while assigned > MAX_VISIBLE_DINOS:
		var max_sp: String = ""
		var max_val: int = 1
		for sp: String in SPECIES_ORDER:
			var val: int = int(scaled[sp])
			if val > max_val:
				max_val = val
				max_sp = sp
		if max_sp == "":
			break
		scaled[max_sp] = max_val - 1
		assigned -= 1

	return scaled


func _load_tex(path: String) -> Texture2D:
	if _tex_cache.has(path):
		return _tex_cache[path] as Texture2D
	if not ResourceLoader.exists(path):
		return null
	var loaded: Texture2D = load(path) as Texture2D
	_tex_cache[path] = loaded
	return loaded


func _spawn_actor(species: String, idx: int) -> DinoActor:
	var actor := DinoActor.new()
	actor.name = "Dino_%s_%d" % [species, idx]
	actor.species = species
	actor.index = idx
	actor.phase = randf_range(0.0, TAU)
	actor.home_x = float(HOME_X.get(species, 1180.0)) + randf_range(-26.0, 26.0)
	actor.z_index = 5 if species != "ptero" else 8

	var shadow := Polygon2D.new()
	var shadow_rx: float = 24.0 if species == "trex" or species == "ankylo" else 16.0
	shadow.polygon = _make_ellipse(shadow_rx, 5.5, 12)
	shadow.color = Color(0.12, 0.06, 0.06, 0.36)
	shadow.z_index = -1
	actor.add_child(shadow)
	actor.shadow = shadow

	var sprite := Sprite2D.new()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	actor.add_child(sprite)
	actor.sprite = sprite

	# Verifica se há worker sheet 3x2 válida (>= 256px) ou walk sheet do compy ou sprite único.
	var single_path: String = String(SINGLE_TEXTURES.get(species, ""))
	var single_tex: Texture2D = _load_tex(single_path)
	actor.single_tex = single_tex

	var sheet_path: String = String(WORKER_SHEETS.get(species, ""))
	var sheet_tex: Texture2D = _load_tex(sheet_path) if sheet_path != "" else null
	if sheet_tex != null and sheet_tex.get_width() >= 256:
		actor.is_sheet_3x2 = true
		actor.cell_size = Vector2(float(sheet_tex.get_width()) / 3.0, float(sheet_tex.get_height()) / 2.0)
		sprite.texture = sheet_tex
		sprite.region_enabled = true
		sprite.region_rect = Rect2(Vector2.ZERO, actor.cell_size)
	elif species == "compy" or species == "cannon":
		var walk_tex: Texture2D = _load_tex(COMPY_WALK_PATH)
		if walk_tex != null and walk_tex.get_width() >= 180:
			actor.is_compy_walk = true
			actor.walk_tex = walk_tex
			actor.cell_size = Vector2(float(walk_tex.get_width()) / 4.0, float(walk_tex.get_height()))
			sprite.texture = walk_tex
			sprite.region_enabled = true
			sprite.region_rect = Rect2(Vector2.ZERO, actor.cell_size)
		else:
			sprite.texture = single_tex
	else:
		sprite.texture = single_tex

	var tex_h: float = 48.0
	if actor.is_sheet_3x2 or actor.is_compy_walk:
		tex_h = maxf(actor.cell_size.y, 1.0)
	elif single_tex != null:
		tex_h = maxf(float(single_tex.get_height()), 1.0)

	var wanted_h: float = float(TARGET_HEIGHT_PX.get(species, 44.0))
	var sc: float = wanted_h / tex_h
	actor.base_scale = sc
	sprite.scale = Vector2(sc, sc)
	sprite.position = Vector2(0.0, -wanted_h * 0.48)

	if species == "compy":
		var crystal := Polygon2D.new()
		crystal.polygon = PackedVector2Array([
			Vector2(-7.0, -4.0), Vector2(0.0, -11.0), Vector2(7.0, -4.0), Vector2(0.0, 2.0)
		])
		crystal.color = Color(1.0, 0.80, 0.22, 1.0)
		crystal.position = Vector2(0.0, -wanted_h - 6.0)
		crystal.visible = false
		actor.add_child(crystal)
		actor.crystal = crystal

	var badge := Polygon2D.new()
	badge.polygon = PackedVector2Array([
		Vector2(-5.0, 0.0), Vector2(0.0, -6.0), Vector2(5.0, 0.0), Vector2(0.0, 4.0)
	])
	badge.color = Color(1.0, 0.88, 0.30, 0.9)
	badge.position = Vector2(0.0, -wanted_h - 12.0)
	badge.visible = false
	actor.add_child(badge)
	actor.badge = badge

	match species:
		"pachy":
			actor.position = Vector2(actor.home_x, GnorpGame.GROUND_Y + randf_range(2.0, 9.0))
			actor.state = "run_to_rock"
			actor.target_x = GnorpGame.ROCK_X + 74.0 + randf_range(-10.0, 18.0)
			actor.facing_right = false
		"compy":
			actor.position = Vector2(actor.home_x, GnorpGame.GROUND_Y + randf_range(3.0, 10.0))
			actor.state = "to_pile"
			actor.target_x = GnorpGame.PILE_X + randf_range(-28.0, 28.0)
			actor.facing_right = false
		"ptero":
			actor.position = Vector2(actor.home_x, randf_range(270.0, 430.0))
			actor.state = "cruise"
			actor.target_x = GnorpGame.ROCK_X + 60.0
			actor.action_cd = randf_range(0.6, 2.2)
			actor.secondary_cd = randf_range(1.4, 2.6)
			actor.facing_right = false
		"ankylo":
			actor.position = Vector2(actor.home_x, GnorpGame.GROUND_Y + randf_range(2.0, 8.0))
			actor.state = "march_to_rock"
			actor.target_x = GnorpGame.ROCK_X + 86.0 + randf_range(-8.0, 14.0)
			actor.facing_right = false
		"trex":
			actor.position = Vector2(actor.home_x, GnorpGame.GROUND_Y + randf_range(3.0, 9.0))
			actor.state = "patrol_or_hunt"
			actor.target_x = GnorpGame.ROCK_X + 102.0 + randf_range(-10.0, 14.0)
			actor.action_cd = randf_range(2.5, 5.0)
			actor.facing_right = false
		"cannon":
			actor.position = Vector2(actor.home_x + randf_range(-42.0, 42.0), GnorpGame.GROUND_Y + randf_range(2.0, 9.0))
			actor.state = "crew"
			actor.facing_right = false
			sprite.modulate = Color(1.0, 0.90, 0.72, 1.0)

	add_child(actor)
	return actor


func _process(delta: float) -> void:
	_sync_poll_timer += delta
	if _sync_poll_timer >= 0.35:
		_sync_poll_timer = 0.0
		if _counts_differ():
			sync_with_game_state()

	_roar_global_cooldown = maxf(_roar_global_cooldown - delta, 0.0)

	var is_active: bool = (GnorpGame.run_state == "playing" or GnorpGame.run_state == "endless")
	if not is_active:
		return

	_tick_cannon_auto(delta)

	for actor: DinoActor in _actors:
		if not is_instance_valid(actor):
			continue
		actor.phase += delta
		actor.hit_squash = maxf(actor.hit_squash - delta * 5.0, 0.0)
		var spd_mult: float = GnorpGame.get_dino_speed_multiplier(actor.species)
		match actor.species:
			"pachy":
				_update_pachy(actor, delta, spd_mult)
			"compy":
				_update_compy(actor, delta, spd_mult)
			"ptero":
				_update_ptero(actor, delta, spd_mult)
			"ankylo":
				_update_ankylo(actor, delta, spd_mult)
			"trex":
				_update_trex(actor, delta, spd_mult)
			"cannon":
				_update_cannon_crew(actor, delta, spd_mult)
		_animate_actor_visuals(actor)


func _counts_differ() -> bool:
	for sp: String in SPECIES_ORDER:
		if int(_last_counts.get(sp, -1)) != GnorpGame.get_dino_count(sp):
			return true
	return false


func _tick_cannon_auto(delta: float) -> void:
	if not GnorpGame.is_structure_built("meteor_cannon"):
		return
	var crew_count: int = GnorpGame.get_dino_count("cannon")
	if crew_count <= 0:
		return
	_cannon_timer -= delta
	if _cannon_timer <= 0.0:
		_cannon_timer = maxf(GnorpGame.get_cannon_interval(), 0.25)
		GnorpGame.fire_cannon_volley("cannon")


func _update_pachy(actor: DinoActor, delta: float, spd_mult: float) -> void:
	var move_spd: float = 215.0 * spd_mult
	if actor.state == "run_to_rock":
		actor.facing_right = false
		actor.position.x = move_toward(actor.position.x, actor.target_x, move_spd * delta)
		if absf(actor.position.x - actor.target_x) <= 2.0:
			actor.state = "windup"
			actor.timer = 0.22 / maxf(spd_mult, 0.5)
	elif actor.state == "windup":
		actor.facing_right = false
		actor.timer -= delta
		if actor.timer <= 0.0:
			actor.state = "headbutt"
			actor.timer = 0.14
	elif actor.state == "headbutt":
		actor.facing_right = false
		actor.position.x = move_toward(actor.position.x, GnorpGame.ROCK_X + 42.0, 420.0 * spd_mult * delta)
		actor.timer -= delta
		if actor.timer <= 0.0:
			GnorpGame.apply_dino_hit("pachy")
			actor.hit_squash = 1.0
			actor.state = "recoil"
			actor.target_x = 505.0 + float(actor.index % 5) * 26.0
	elif actor.state == "recoil":
		actor.facing_right = true
		actor.position.x = move_toward(actor.position.x, actor.target_x, 165.0 * spd_mult * delta)
		if absf(actor.position.x - actor.target_x) <= 3.0:
			actor.state = "run_to_rock"
			actor.target_x = GnorpGame.ROCK_X + 74.0 + randf_range(-8.0, 14.0)

	if actor.badge != null:
		actor.badge.visible = GnorpGame.is_upgrade_owned("pachy_helmet")


func _update_compy(actor: DinoActor, delta: float, spd_mult: float) -> void:
	var move_spd: float = 195.0 * spd_mult
	if actor.state == "to_pile":
		actor.carrying = false
		actor.carried_value = 0.0
		var pile_x: float = GnorpGame.PILE_X + float((actor.index % 4) - 2) * 12.0
		actor.facing_right = pile_x > actor.position.x
		actor.position.x = move_toward(actor.position.x, pile_x, move_spd * delta)
		if absf(actor.position.x - pile_x) <= 3.0:
			var picked_val: float = GnorpGame.take_from_pile(GnorpGame.get_compy_carry_capacity(), "compy")
			if picked_val > 0.0:
				actor.carried_value = picked_val
				actor.carrying = true
				actor.hit_squash = 0.6
				actor.state = "to_deposit"
			else:
				actor.state = "wait_pile"
				actor.timer = 0.35
	elif actor.state == "wait_pile":
		actor.facing_right = false
		actor.timer -= delta
		if actor.timer <= 0.0:
			actor.state = "to_pile"
	elif actor.state == "to_deposit":
		actor.facing_right = true
		var dep_x: float = GnorpGame.DEPOSIT_X - 18.0 + float(actor.index % 3) * 10.0
		actor.position.x = move_toward(actor.position.x, dep_x, move_spd * 0.92 * delta)
		if absf(actor.position.x - dep_x) <= 3.0:
			GnorpGame.deliver_to_deposit(actor.carried_value, "compy")
			actor.carried_value = 0.0
			actor.carrying = false
			actor.hit_squash = 0.7
			actor.state = "to_pile"

	if actor.crystal != null:
		actor.crystal.visible = actor.carrying
		if actor.carrying:
			var tier_col: Color = Color(1.0, 0.80, 0.24, 1.0)
			if GnorpGame.compression_tier >= 3:
				tier_col = Color(0.78, 0.48, 1.0, 1.0)
			elif GnorpGame.compression_tier == 2:
				tier_col = Color(1.0, 0.92, 0.36, 1.0)
			elif GnorpGame.compression_tier == 1:
				tier_col = Color(0.35, 0.90, 1.0, 1.0)
			actor.crystal.color = tier_col

	if actor.badge != null:
		actor.badge.visible = GnorpGame.is_upgrade_owned("compy_pouch")


func _update_ptero(actor: DinoActor, delta: float, spd_mult: float) -> void:
	var has_sky_beam: bool = GnorpGame.is_upgrade_owned("ptero_sky_beam")
	var base_alt: float = 285.0 + float(actor.index % 4) * 42.0
	if actor.state == "cruise":
		var patrol_x: float = 980.0 + sin(actor.phase * 0.75 * spd_mult + float(actor.index)) * 680.0
		var dx: float = patrol_x - actor.position.x
		actor.facing_right = dx >= 0.0
		actor.position.x = lerpf(actor.position.x, patrol_x, minf(delta * 2.4 * spd_mult, 1.0))
		actor.position.y = lerpf(actor.position.y, base_alt + sin(actor.phase * 3.1) * 18.0, minf(delta * 4.0, 1.0))
		actor.action_cd -= delta * spd_mult
		if actor.action_cd <= 0.0:
			actor.state = "dive_rock"
			actor.action_cd = randf_range(2.2, 3.3)
		if has_sky_beam:
			actor.secondary_cd -= delta * spd_mult
			if actor.secondary_cd <= 0.0:
				actor.secondary_cd = randf_range(2.1, 3.0)
				var beam_dmg: float = maxf(GnorpGame.get_dino_hit_power("ptero") * 0.9, 3.0)
				GnorpGame.apply_ptero_meteor_shot(beam_dmg)
				ptero_meteor_shot_visual.emit(actor.position + Vector2(0.0, -18.0))
	elif actor.state == "dive_rock":
		var dive_target := Vector2(GnorpGame.ROCK_X + 26.0, GnorpGame.GROUND_Y - 110.0)
		actor.facing_right = dive_target.x > actor.position.x
		actor.position = actor.position.move_toward(dive_target, 420.0 * spd_mult * delta)
		if actor.position.distance_to(dive_target) <= 8.0:
			GnorpGame.apply_dino_hit("ptero")
			actor.hit_squash = 0.8
			actor.state = "climb"
	elif actor.state == "climb":
		var climb_target := Vector2(880.0 + float(actor.index % 5) * 90.0, base_alt)
		actor.facing_right = climb_target.x > actor.position.x
		actor.position = actor.position.move_toward(climb_target, 320.0 * spd_mult * delta)
		if actor.position.distance_to(climb_target) <= 12.0:
			actor.state = "cruise"

	if actor.shadow != null:
		var height_above_ground: float = maxf(GnorpGame.GROUND_Y - actor.position.y, 20.0)
		actor.shadow.position = Vector2(0.0, height_above_ground)
		var sh_scale: float = clampf(1.0 - height_above_ground / 750.0, 0.35, 0.9)
		actor.shadow.scale = Vector2(sh_scale, sh_scale)
	if actor.badge != null:
		actor.badge.visible = has_sky_beam


func _update_ankylo(actor: DinoActor, delta: float, spd_mult: float) -> void:
	var move_spd: float = 135.0 * spd_mult
	if actor.state == "march_to_rock":
		actor.facing_right = false
		actor.position.x = move_toward(actor.position.x, actor.target_x, move_spd * delta)
		if absf(actor.position.x - actor.target_x) <= 3.0:
			actor.state = "tail_slam"
			actor.timer = 0.34 / maxf(spd_mult, 0.5)
	elif actor.state == "tail_slam":
		actor.facing_right = true
		actor.timer -= delta
		if actor.timer <= 0.0:
			GnorpGame.apply_dino_hit("ankylo")
			actor.hit_squash = 1.0
			request_camera_shake.emit(0.14)
			actor.state = "step_back"
			actor.target_x = 460.0 + float(actor.index % 4) * 32.0
	elif actor.state == "step_back":
		actor.facing_right = true
		actor.position.x = move_toward(actor.position.x, actor.target_x, move_spd * 0.85 * delta)
		if absf(actor.position.x - actor.target_x) <= 3.0:
			actor.state = "march_to_rock"
			actor.target_x = GnorpGame.ROCK_X + 86.0 + randf_range(-8.0, 14.0)

	if actor.badge != null:
		actor.badge.visible = GnorpGame.is_upgrade_owned("ankylo_club")


func _update_trex(actor: DinoActor, delta: float, spd_mult: float) -> void:
	var move_spd: float = 165.0 * spd_mult
	actor.action_cd -= delta * spd_mult
	if actor.action_cd <= 0.0 and _roar_global_cooldown <= 0.0 and GnorpGame.roar_time_left <= 0.1:
		actor.action_cd = 17.0
		_roar_global_cooldown = 16.0
		actor.hit_squash = 1.1
		GnorpGame.trigger_trex_roar()

	if actor.state == "patrol_or_hunt":
		actor.facing_right = false
		actor.position.x = move_toward(actor.position.x, actor.target_x, move_spd * delta)
		if absf(actor.position.x - actor.target_x) <= 4.0:
			actor.state = "bite"
			actor.timer = 0.28 / maxf(spd_mult, 0.5)
	elif actor.state == "bite":
		actor.facing_right = false
		actor.timer -= delta
		if actor.timer <= 0.0:
			GnorpGame.apply_dino_hit("trex")
			actor.hit_squash = 1.1
			request_camera_shake.emit(0.22)
			actor.state = "retreat"
			actor.target_x = 580.0 + float(actor.index % 3) * 55.0
	elif actor.state == "retreat":
		actor.facing_right = true
		actor.position.x = move_toward(actor.position.x, actor.target_x, move_spd * 0.9 * delta)
		if absf(actor.position.x - actor.target_x) <= 4.0:
			actor.state = "patrol_or_hunt"
			actor.target_x = GnorpGame.ROCK_X + 104.0 + randf_range(-10.0, 12.0)

	if actor.badge != null:
		actor.badge.visible = GnorpGame.roar_time_left > 0.0 or GnorpGame.is_upgrade_owned("trex_alpha")


func _update_cannon_crew(actor: DinoActor, _delta: float, _spd_mult: float) -> void:
	var spot_x: float = 2820.0 + float(actor.index - 2) * 26.0
	actor.facing_right = spot_x < 2820.0
	actor.position.x = lerpf(actor.position.x, spot_x, 0.08)
	if actor.badge != null:
		actor.badge.visible = GnorpGame.is_upgrade_owned("cannon_overclock")


func _animate_actor_visuals(actor: DinoActor) -> void:
	if actor.sprite == null:
		return
	var default_right: bool = bool(RIGHT_FACING.get(actor.species, false))
	actor.sprite.flip_h = (actor.facing_right != default_right)

	var stride: float = sin(actor.phase * 11.0)
	var bob: float = absf(stride) * (4.0 if actor.species != "ptero" else 2.5)
	var sx: float = 1.0 + actor.hit_squash * 0.24 - absf(stride) * 0.04
	var sy: float = 1.0 - actor.hit_squash * 0.18 + absf(stride) * 0.04
	actor.sprite.scale = Vector2(actor.base_scale * sx, actor.base_scale * sy)

	var wanted_h: float = float(TARGET_HEIGHT_PX.get(actor.species, 44.0))
	actor.sprite.position.y = -wanted_h * 0.48 * sy - bob
	if actor.species == "pachy" and actor.state == "windup":
		actor.sprite.rotation = -0.22
	elif actor.species == "ptero":
		actor.sprite.rotation = stride * 0.09
	else:
		actor.sprite.rotation = stride * 0.045 * (1.0 if actor.facing_right else -1.0)

	if actor.is_sheet_3x2:
		var frame: int = posmod(floori(actor.phase * 7.5), 6)
		var col: int = frame % 3
		var row: int = floori(float(frame) / 3.0)
		actor.sprite.region_rect = Rect2(Vector2(float(col), float(row)) * actor.cell_size, actor.cell_size)
	elif actor.is_compy_walk:
		var walk_frame: int = posmod(floori(actor.phase * 10.0), 4)
		actor.sprite.region_rect = Rect2(float(walk_frame) * actor.cell_size.x, 0.0, actor.cell_size.x, actor.cell_size.y)


static func _make_ellipse(rx: float, ry: float, segments: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i: int in range(segments):
		var a: float = (float(i) / float(segments)) * TAU
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts
