extends Node
## GnorpGame — Núcleo de simulação, economia, enxame e persistência do reboot estilo Gnorp Apologue.

const WORLD_WIDTH: float = 3200.0
const ROCK_X: float = 340.0
const PILE_X: float = 610.0
const DEPOSIT_X: float = 960.0
const GROUND_Y: float = 780.0
const BASE_RUN_DURATION: float = 240.0
const METEOR_MAX_HP: float = 45000.0
const BASE_PILE_CAPACITY: float = 150.0
const BASE_MANUAL_SCOOP: float = 4.0
const SAVE_PATH: String = "user://gnorp_save.json"
const TEMP_SAVE_PATH: String = "user://gnorp_save.tmp"
const AUTOSAVE_INTERVAL: float = 15.0
const SAVE_VERSION: int = 1

const STRUCTURES: Array[Dictionary] = [
	{
		"id": "pachy_nest",
		"name": "Ninho Pachy",
		"species": "pachy",
		"dino_name": "Pachycephalossauro",
		"role": "Investidor de Cabeçada",
		"world_x": 1180.0,
		"build_cost": 30.0,
		"dino_base_cost": 22.0,
		"dino_cost_scale": 1.38,
		"unlock_fragments": 12.0,
		"max_dinos": 18,
		"icon": "res://assets/sprites/pachycephalosaurus.png",
	},
	{
		"id": "compy_den",
		"name": "Toca Compy",
		"species": "compy",
		"dino_name": "Compsognato",
		"role": "Carregador da Pilha",
		"world_x": 1440.0,
		"build_cost": 90.0,
		"dino_base_cost": 50.0,
		"dino_cost_scale": 1.36,
		"unlock_fragments": 45.0,
		"max_dinos": 20,
		"icon": "res://assets/sprites/compsognathus.png",
	},
	{
		"id": "ptero_perch",
		"name": "Poleiro Ptero",
		"species": "ptero",
		"dino_name": "Pterodáctilo",
		"role": "Ataque Aéreo",
		"world_x": 1760.0,
		"build_cost": 420.0,
		"dino_base_cost": 190.0,
		"dino_cost_scale": 1.40,
		"unlock_fragments": 220.0,
		"max_dinos": 15,
		"icon": "res://assets/sprites/pterodactyl.png",
	},
	{
		"id": "ankylo_lair",
		"name": "Fenda Anquilo",
		"species": "ankylo",
		"dino_name": "Anquilossauro",
		"role": "Esmagador Sísmico (Mid-game)",
		"world_x": 2100.0,
		"build_cost": 1650.0,
		"dino_base_cost": 680.0,
		"dino_cost_scale": 1.44,
		"unlock_fragments": 950.0,
		"max_dinos": 12,
		"icon": "res://assets/sprites/ankylosaurus.png",
	},
	{
		"id": "trex_altar",
		"name": "Altar T-Rex",
		"species": "trex",
		"dino_name": "Tiranossauro Rex",
		"role": "Rugido Alfa de Enxame",
		"world_x": 2460.0,
		"build_cost": 7500.0,
		"dino_base_cost": 2800.0,
		"dino_cost_scale": 1.48,
		"unlock_fragments": 4200.0,
		"max_dinos": 8,
		"icon": "res://assets/sprites/trex.png",
	},
	{
		"id": "meteor_cannon",
		"name": "Canhão Anti-Meteoro",
		"species": "cannon",
		"dino_name": "Artificieiro Âmbar",
		"role": "Artilharia Celestial",
		"world_x": 2820.0,
		"build_cost": 24000.0,
		"dino_base_cost": 8500.0,
		"dino_cost_scale": 1.55,
		"unlock_fragments": 14000.0,
		"max_dinos": 6,
		"icon": "res://assets/sprites/icons/icon_meteor.png",
	},
]

const UPGRADES: Array[Dictionary] = [
	# pachy_nest
	{
		"id": "pachy_helmet",
		"struct_id": "pachy_nest",
		"name": "Elmo de Âmbar",
		"short": "Elmo",
		"desc": "+55% de dano por cabeçada dos Pachys e visual reforçado no vale.",
		"cost": 75.0,
		"icon_index": 0,
		"icon": "res://assets/sprites/icons/icon_shield.png",
	},
	{
		"id": "pachy_frenzy",
		"struct_id": "pachy_nest",
		"name": "Frenesi de Cabeçada",
		"short": "Frenesi",
		"desc": "+35% de velocidade de corrida e ataque dos Pachys.",
		"cost": 190.0,
		"icon_index": 1,
		"icon": "res://assets/sprites/icons/icon_power.png",
	},
	{
		"id": "pachy_ricochet",
		"struct_id": "pachy_nest",
		"name": "Estilhaço Ricochete",
		"short": "Ricochete",
		"desc": "Cada cabeçada Pachy solta +1.5 fragmentos extras diretamente na Pilha.",
		"cost": 420.0,
		"icon_index": 2,
		"icon": "res://assets/sprites/icons/icon_fragment.png",
	},
	# compy_den
	{
		"id": "compy_pouch",
		"struct_id": "compy_den",
		"name": "Bolsa de Cristais",
		"short": "Bolsa 2x",
		"desc": "Dobra (2x) a capacidade de carga de cada Compsognato.",
		"cost": 160.0,
		"icon_index": 3,
		"icon": "res://assets/sprites/icons/icon_rocks.png",
	},
	{
		"id": "compy_sprint",
		"struct_id": "compy_den",
		"name": "Corrida Ligeira",
		"short": "Sprint",
		"desc": "+40% de velocidade dos Compys entre a Pilha e o Depósito.",
		"cost": 380.0,
		"icon_index": 4,
		"icon": "res://assets/sprites/icons/icon_power.png",
	},
	{
		"id": "compy_magnet",
		"struct_id": "compy_den",
		"name": "Ímã de Depósito",
		"short": "Ímã +25%",
		"desc": "Bônus de +25% nos fragmentos entregues da Pilha ao Depósito.",
		"cost": 860.0,
		"icon_index": 5,
		"icon": "res://assets/sprites/icons/icon_amber.png",
	},
	# ptero_perch
	{
		"id": "ptero_dive",
		"struct_id": "ptero_perch",
		"name": "Mergulho Sônico",
		"short": "Mergulho",
		"desc": "+55% de dano aéreo dos Pteros no Monólito.",
		"cost": 750.0,
		"icon_index": 6,
		"icon": "res://assets/sprites/icons/icon_power.png",
	},
	{
		"id": "ptero_sky_beam",
		"struct_id": "ptero_perch",
		"name": "Raios de Âmbar",
		"short": "Raio Céu",
		"desc": "Pteros disparam raios de âmbar diretamente contra o Meteoro!",
		"cost": 1800.0,
		"icon_index": 7,
		"icon": "res://assets/sprites/icons/icon_meteor.png",
	},
	{
		"id": "ptero_flock",
		"struct_id": "ptero_perch",
		"name": "Revoada Veloz",
		"short": "Revoada",
		"desc": "+30% de velocidade aérea e cadência de ataque dos Pteros.",
		"cost": 3600.0,
		"icon_index": 8,
		"icon": "res://assets/sprites/icons/icon_egg.png",
	},
	# ankylo_lair
	{
		"id": "ankylo_club",
		"struct_id": "ankylo_lair",
		"name": "Clava Tectônica",
		"short": "Clava",
		"desc": "+65% de dano nos golpes de cauda dos Anquilossauros.",
		"cost": 2900.0,
		"icon_index": 9,
		"icon": "res://assets/sprites/icons/icon_tools.png",
	},
	{
		"id": "ankylo_compress",
		"struct_id": "ankylo_lair",
		"name": "Prensa Cristalina",
		"short": "Prensa",
		"desc": "Golpes de Anquilo dão +20% de bônus de compressão na Pilha.",
		"cost": 6200.0,
		"icon_index": 10,
		"icon": "res://assets/sprites/icons/icon_minerals.png",
	},
	{
		"id": "ankylo_quake",
		"struct_id": "ankylo_lair",
		"name": "Onda Sísmica",
		"short": "Sísmica",
		"desc": "Onda sísmica gera +35% estilhaços adicionais por golpe.",
		"cost": 11500.0,
		"icon_index": 11,
		"icon": "res://assets/sprites/icons/icon_power.png",
	},
	# trex_altar
	{
		"id": "trex_alpha",
		"struct_id": "trex_altar",
		"name": "Rugido Alfa Supremo",
		"short": "Alfa 2.2x",
		"desc": "Rugido Alfa dura +3s e escala o multiplicador do enxame para 2.2x.",
		"cost": 12500.0,
		"icon_index": 12,
		"icon": "res://assets/sprites/icons/icon_audio.png",
	},
	{
		"id": "trex_terrify",
		"struct_id": "trex_altar",
		"name": "Aura Predadora",
		"short": "Terror",
		"desc": "+50% de dano base do T-Rex e aura global +18% para todos os dinos.",
		"cost": 24000.0,
		"icon_index": 13,
		"icon": "res://assets/sprites/icons/icon_power.png",
	},
	{
		"id": "trex_apex",
		"struct_id": "trex_altar",
		"name": "Lança Apex",
		"short": "Apex",
		"desc": "Cada mordida do T-Rex dispara uma lança de âmbar contra o Meteoro.",
		"cost": 42000.0,
		"icon_index": 14,
		"icon": "res://assets/sprites/icons/icon_meteor.png",
	},
	# meteor_cannon
	{
		"id": "cannon_barrel",
		"struct_id": "meteor_cannon",
		"name": "Cano Pesado",
		"short": "Cano +75%",
		"desc": "+75% de dano por disparo do Canhão no Meteoro.",
		"cost": 35000.0,
		"icon_index": 15,
		"icon": "res://assets/sprites/icons/icon_machines.png",
	},
	{
		"id": "cannon_overclock",
		"struct_id": "meteor_cannon",
		"name": "Sobrecarga Térmica",
		"short": "Cadência",
		"desc": "Cadência de disparo do Canhão +35% mais rápida.",
		"cost": 62000.0,
		"icon_index": 16,
		"icon": "res://assets/sprites/icons/icon_power.png",
	},
	{
		"id": "cannon_amber_core",
		"struct_id": "meteor_cannon",
		"name": "Núcleo de Âmbar",
		"short": "Núcleo",
		"desc": "+80% de dano bônus e fragmentos acumulados aceleram a recarga.",
		"cost": 110000.0,
		"icon_index": 17,
		"icon": "res://assets/sprites/icons/icon_amber.png",
	},
]

const TALENTS: Array[Dictionary] = [
	{
		"id": "talent_claw_click",
		"name": "Garra Primordial",
		"desc": "+75% de dano de clique no Monólito e +2 lascas coletadas por clique na Pilha.",
		"max_rank": 5,
		"base_cost": 2,
		"icon": "res://assets/sprites/icons/icon_tools.png",
	},
	{
		"id": "talent_amber_magnet",
		"name": "Imã de Âmbar",
		"desc": "+30% de Âmbar Puro ganho ao fim das runs por nível.",
		"max_rank": 4,
		"base_cost": 3,
		"icon": "res://assets/sprites/icons/icon_amber.png",
	},
	{
		"id": "talent_headstart",
		"name": "Despertar Rápido",
		"desc": "Começa todas as runs com +40 Fragmentos por nível.",
		"max_rank": 4,
		"base_cost": 3,
		"icon": "res://assets/sprites/icons/icon_fragment.png",
	},
	{
		"id": "talent_pile_dense",
		"name": "Compressão Cristalina",
		"desc": "+25% no valor da compressão da Pilha por nível.",
		"max_rank": 4,
		"base_cost": 3,
		"icon": "res://assets/sprites/icons/icon_rocks.png",
	},
	{
		"id": "talent_cheap_nests",
		"name": "Arquitetura Fóssil",
		"desc": "-8% no custo de estruturas e dinos por nível.",
		"max_rank": 4,
		"base_cost": 4,
		"icon": "res://assets/sprites/icons/icon_camp.png",
	},
	{
		"id": "talent_time_warp",
		"name": "Céu Estendido",
		"desc": "+25s extras antes do impacto do Meteoro por nível.",
		"max_rank": 4,
		"base_cost": 3,
		"icon": "res://assets/sprites/icons/icon_meteor.png",
	},
	{
		"id": "talent_swarm_spirit",
		"name": "Fúria do Enxame",
		"desc": "+25% de força e +12% de velocidade de todos os dinos por nível.",
		"max_rank": 5,
		"base_cost": 3,
		"icon": "res://assets/sprites/icons/icon_egg.png",
	},
	{
		"id": "talent_meteor_cracker",
		"name": "Núcleo Perfurante",
		"desc": "+35% de dano contra o Meteoro por nível.",
		"max_rank": 5,
		"base_cost": 4,
		"icon": "res://assets/sprites/icons/icon_power.png",
	},
]

#region Estado Público
var fragments: float = 0.0
var pile_fragments: float = 0.0
var total_run_fragments: float = 0.0
var amber_pure: float = 0.0
var compression_tier: int = 0
var meteor_hp: float = 45000.0
var meteor_max_hp: float = 45000.0
var meteor_time_left: float = 240.0
var run_number: int = 1
var run_state: String = "playing"
var total_victories: int = 0
var audio_muted: bool = false
var master_volume: float = 0.8
var auto_pan_enabled: bool = true
var roar_time_left: float = 0.0
var roar_multiplier: float = 1.0
var structures_built: Dictionary = {}
var dino_counts: Dictionary = {}
var upgrades_owned: Dictionary = {}
var talent_ranks: Dictionary = {}
var rock_clicks_total: int = 0
#endregion

#region Sinais Públicos
@warning_ignore_start("unused_signal")
signal resources_changed()
signal rock_hit(pos_x: float, damage: float, shards_spawned: float, is_crit: bool, source: String)
signal pile_changed(pile_amount: float, tier: int, capacity: float)
signal pile_compressed(new_tier: int, multiplier: float)
signal deposit_collected(amount: float, source: String)
signal structure_built(struct_id: String, world_x: float)
signal dino_recruited(species_id: String, new_count: int, struct_x: float)
signal upgrade_purchased(upgrade_id: String)
signal talent_purchased(talent_id: String, new_rank: int)
signal roar_triggered(duration: float, multiplier: float)
signal cannon_fired(damage: float, new_meteor_hp: float, source: String)
signal meteor_tick(time_left: float, hp: float, max_hp: float)
signal run_ended(outcome: String, amber_earned: float)
signal run_started(run_number: int)
signal audio_settings_changed()
@warning_ignore_restore("unused_signal")
#endregion

var _autosave_elapsed: float = 0.0
var _meteor_emit_elapsed: float = 0.0
var _is_loading: bool = false
var _sim_clock: float = 0.0
var _frag_rate_samples: Array[Dictionary] = []
var _meteor_dps_samples: Array[Dictionary] = []


func _ready() -> void:
	if not load_game():
		_reset_run_state()


func _exit_tree() -> void:
	_frag_rate_samples.clear()
	_meteor_dps_samples.clear()


func _process(delta: float) -> void:
	_sim_clock += delta
	_prune_rate_samples()

	if roar_time_left > 0.0:
		roar_time_left = maxf(0.0, roar_time_left - delta)
		if roar_time_left <= 0.0:
			roar_multiplier = 1.0

	if run_state == "playing":
		meteor_time_left = maxf(0.0, meteor_time_left - delta)
		_meteor_emit_elapsed += delta
		if _meteor_emit_elapsed >= 0.25 or meteor_time_left <= 0.0:
			_meteor_emit_elapsed = 0.0
			meteor_tick.emit(meteor_time_left, meteor_hp, meteor_max_hp)
		if meteor_time_left <= 0.0:
			end_run_by_impact()

	_autosave_elapsed += delta
	if _autosave_elapsed >= AUTOSAVE_INTERVAL:
		_autosave_elapsed = 0.0
		save_game()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_CLOSE_REQUEST, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT:
			save_game()


#region Núcleo de Gameplay
func click_rock(world_pos_x: float = ROCK_X) -> float:
	if run_state != "playing" and run_state != "endless":
		return 0.0
	rock_clicks_total += 1
	var dmg: float = get_click_damage()
	var is_crit: bool = randf() < 0.15
	var shards: float = dmg * (2.0 if is_crit else 1.0)
	_add_to_pile(shards)
	rock_hit.emit(world_pos_x, dmg, shards, is_crit, "click")
	return shards


func scoop_pile(max_amount: float = -1.0) -> float:
	var effective_max: float = get_manual_scoop_amount() if max_amount < 0.0 else max_amount
	return collect_from_pile(effective_max, "manual")


func apply_dino_hit(species_id: String) -> float:
	if run_state != "playing" and run_state != "endless":
		return 0.0
	var power: float = get_dino_hit_power(species_id)
	if power <= 0.0:
		return 0.0
	var is_crit: bool = randf() < 0.10
	var shards: float = power * (1.8 if is_crit else 1.0)
	if species_id == "pachy" and is_upgrade_owned("pachy_ricochet"):
		shards += 1.5
	elif species_id == "ankylo" and is_upgrade_owned("ankylo_quake"):
		shards *= 1.35
	_add_to_pile(shards)
	rock_hit.emit(ROCK_X, power, shards, is_crit, species_id)
	if species_id == "trex" and is_upgrade_owned("trex_apex"):
		var spear_dmg: float = power * 0.9 * _get_meteor_talent_multiplier()
		_damage_meteor(spear_dmg, "trex_apex")
	return shards


func take_from_pile(max_carry: float, source: String = "compy") -> float:
	if pile_fragments <= 0.0 or max_carry <= 0.0:
		return 0.0
	var taken: float = minf(max_carry, pile_fragments)
	var mult: float = get_compression_multiplier()
	if source == "compy" and is_upgrade_owned("compy_magnet"):
		mult *= 1.25
	var delivered: float = taken * mult
	pile_fragments = maxf(0.0, pile_fragments - taken)
	if pile_fragments <= 0.01:
		pile_fragments = 0.0
		compression_tier = 0
	pile_changed.emit(pile_fragments, compression_tier, get_pile_capacity())
	return delivered


func deliver_to_deposit(delivered: float, source: String = "compy") -> float:
	if delivered <= 0.0:
		return 0.0
	fragments += delivered
	total_run_fragments += delivered
	_frag_rate_samples.append({"time": _sim_clock, "val": delivered})
	deposit_collected.emit(delivered, source)
	resources_changed.emit()
	return delivered


func collect_from_pile(max_carry: float, source: String = "compy") -> float:
	var delivered: float = take_from_pile(max_carry, source)
	return deliver_to_deposit(delivered, source)


func trigger_trex_roar() -> void:
	if run_state != "playing" and run_state != "endless":
		return
	var duration: float = 4.5 + (3.0 if is_upgrade_owned("trex_alpha") else 0.0)
	var mult: float = 2.2 if is_upgrade_owned("trex_alpha") else 1.6
	roar_time_left = duration
	roar_multiplier = mult
	roar_triggered.emit(duration, mult)


func fire_cannon_volley(source: String = "cannon") -> float:
	if run_state != "playing" and run_state != "endless":
		return 0.0
	var crew_count: int = maxi(1, get_dino_count("cannon"))
	var damage: float = 220.0 * float(crew_count)
	if is_upgrade_owned("cannon_barrel"):
		damage *= 1.75
	if is_upgrade_owned("cannon_amber_core"):
		damage *= 1.80
	damage *= _get_meteor_talent_multiplier()
	if roar_time_left > 0.0:
		damage *= minf(roar_multiplier, 1.4)
	_damage_meteor(damage, source)
	return damage


func apply_ptero_meteor_shot(damage: float) -> void:
	if run_state != "playing" and run_state != "endless":
		return
	if damage <= 0.0:
		return
	var scaled_dmg: float = damage * _get_meteor_talent_multiplier()
	if roar_time_left > 0.0:
		scaled_dmg *= roar_multiplier
	_damage_meteor(scaled_dmg, "ptero")


func _add_to_pile(amount: float) -> void:
	if amount <= 0.0:
		return
	pile_fragments += amount
	var compressed: bool = false
	var guard: int = 0
	while pile_fragments >= get_pile_capacity() and guard < 20:
		guard += 1
		compression_tier += 1
		# Condensa o volume físico da pilha em 35% enquanto o tier de compressão multiplica o valor na coleta.
		pile_fragments *= 0.65
		compressed = true
	if compressed:
		pile_compressed.emit(compression_tier, get_compression_multiplier())
	pile_changed.emit(pile_fragments, compression_tier, get_pile_capacity())


func _damage_meteor(damage: float, source: String) -> void:
	if damage <= 0.0:
		return
	_meteor_dps_samples.append({"time": _sim_clock, "val": damage})
	meteor_hp = maxf(0.0, meteor_hp - damage)
	cannon_fired.emit(damage, meteor_hp, source)
	meteor_tick.emit(meteor_time_left, meteor_hp, meteor_max_hp)
	if meteor_hp <= 0.0:
		if run_state == "playing":
			run_state = "victory"
			total_victories += 1
			var amber_earned: float = get_amber_reward_preview("victory")
			amber_pure += amber_earned
			resources_changed.emit()
			run_ended.emit("victory", amber_earned)
			save_game()
		elif run_state == "endless":
			meteor_max_hp = roundf(meteor_max_hp * 1.5)
			meteor_hp = meteor_max_hp
			amber_pure += 5.0
			resources_changed.emit()
			meteor_tick.emit(meteor_time_left, meteor_hp, meteor_max_hp)
#endregion


#region Compras & Progressão
func build_structure(struct_id: String) -> bool:
	var def: Dictionary = get_structure_def(struct_id)
	if def.is_empty():
		return false
	if is_structure_built(struct_id):
		return false
	var cost: float = get_structure_cost(struct_id)
	if fragments < cost:
		return false
	fragments -= cost
	structures_built[struct_id] = true
	var species: String = String(def.get("species", ""))
	var world_x: float = float(def.get("world_x", DEPOSIT_X))
	var new_count: int = get_dino_count(species) + 1
	dino_counts[species] = new_count
	structure_built.emit(struct_id, world_x)
	dino_recruited.emit(species, new_count, world_x)
	resources_changed.emit()
	return true


func recruit_dino(struct_id: String) -> bool:
	var def: Dictionary = get_structure_def(struct_id)
	if def.is_empty():
		return false
	if not is_structure_built(struct_id):
		return false
	var species: String = String(def.get("species", ""))
	var current: int = get_dino_count(species)
	var max_dinos: int = int(def.get("max_dinos", 1))
	if current >= max_dinos:
		return false
	var cost: float = get_dino_cost(struct_id)
	if fragments < cost:
		return false
	fragments -= cost
	var new_count: int = current + 1
	dino_counts[species] = new_count
	var world_x: float = float(def.get("world_x", DEPOSIT_X))
	dino_recruited.emit(species, new_count, world_x)
	resources_changed.emit()
	return true


func buy_upgrade(upgrade_id: String) -> bool:
	var def: Dictionary = _get_upgrade_def(upgrade_id)
	if def.is_empty():
		return false
	if is_upgrade_owned(upgrade_id):
		return false
	var struct_id: String = String(def.get("struct_id", ""))
	if not is_structure_built(struct_id):
		return false
	var cost: float = get_upgrade_cost(upgrade_id)
	if fragments < cost:
		return false
	fragments -= cost
	upgrades_owned[upgrade_id] = true
	upgrade_purchased.emit(upgrade_id)
	resources_changed.emit()
	return true


func buy_talent(talent_id: String) -> bool:
	var def: Dictionary = _get_talent_def(talent_id)
	if def.is_empty():
		return false
	var rank: int = get_talent_rank(talent_id)
	var max_rank: int = int(def.get("max_rank", 1))
	if rank >= max_rank:
		return false
	var cost: int = get_talent_cost(talent_id)
	if amber_pure < float(cost):
		return false
	amber_pure -= float(cost)
	var new_rank: int = rank + 1
	talent_ranks[talent_id] = new_rank
	if talent_id == "talent_time_warp" and run_state == "playing":
		meteor_time_left += 25.0
		meteor_tick.emit(meteor_time_left, meteor_hp, meteor_max_hp)
	talent_purchased.emit(talent_id, new_rank)
	resources_changed.emit()
	save_game()
	return true
#endregion


#region Ciclo de Run
func end_run_by_impact() -> float:
	if run_state != "playing":
		return 0.0
	run_state = "impact"
	meteor_time_left = 0.0
	var amber_earned: float = get_amber_reward_preview("impact")
	amber_pure += amber_earned
	meteor_tick.emit(meteor_time_left, meteor_hp, meteor_max_hp)
	resources_changed.emit()
	run_ended.emit("impact", amber_earned)
	save_game()
	return amber_earned


func start_next_run(keep_playing: bool = false) -> void:
	if keep_playing:
		continue_endless_mode()
		return
	run_number += 1
	_reset_run_state()
	run_started.emit(run_number)
	pile_changed.emit(pile_fragments, compression_tier, get_pile_capacity())
	meteor_tick.emit(meteor_time_left, meteor_hp, meteor_max_hp)
	resources_changed.emit()
	save_game()


func continue_endless_mode() -> void:
	run_state = "endless"
	if meteor_hp <= 0.0:
		meteor_max_hp = roundf(meteor_max_hp * 1.5)
		meteor_hp = meteor_max_hp
	meteor_tick.emit(meteor_time_left, meteor_hp, meteor_max_hp)
	resources_changed.emit()
	save_game()


func reset_campaign() -> void:
	amber_pure = 0.0
	talent_ranks.clear()
	run_number = 1
	total_victories = 0
	_reset_run_state()
	delete_save()
	run_started.emit(run_number)
	pile_changed.emit(pile_fragments, compression_tier, get_pile_capacity())
	meteor_tick.emit(meteor_time_left, meteor_hp, meteor_max_hp)
	resources_changed.emit()


func fast_forward_meteor(seconds_left: float = 3.0) -> void:
	if run_state != "playing":
		return
	meteor_time_left = maxf(0.1, seconds_left)
	meteor_tick.emit(meteor_time_left, meteor_hp, meteor_max_hp)


func _reset_run_state() -> void:
	var headstart: float = float(get_talent_rank("talent_headstart")) * 40.0
	fragments = headstart
	pile_fragments = 0.0
	total_run_fragments = 0.0
	compression_tier = 0
	meteor_max_hp = METEOR_MAX_HP * (1.0 + float(total_victories) * 0.5)
	meteor_hp = meteor_max_hp
	meteor_time_left = BASE_RUN_DURATION + float(get_talent_rank("talent_time_warp")) * 25.0
	roar_time_left = 0.0
	roar_multiplier = 1.0
	structures_built.clear()
	dino_counts.clear()
	upgrades_owned.clear()
	rock_clicks_total = 0
	run_state = "playing"
	_meteor_emit_elapsed = 0.0
	_frag_rate_samples.clear()
	_meteor_dps_samples.clear()
#endregion


#region Persistência
func save_game() -> bool:
	if _is_loading:
		return false
	var payload: Dictionary = {
		"version": SAVE_VERSION,
		"fragments": fragments,
		"pile_fragments": pile_fragments,
		"total_run_fragments": total_run_fragments,
		"amber_pure": amber_pure,
		"compression_tier": compression_tier,
		"meteor_hp": meteor_hp,
		"meteor_max_hp": meteor_max_hp,
		"meteor_time_left": meteor_time_left,
		"run_number": run_number,
		"run_state": run_state,
		"total_victories": total_victories,
		"audio_muted": audio_muted,
		"master_volume": master_volume,
		"auto_pan_enabled": auto_pan_enabled,
		"structures_built": structures_built.duplicate(true),
		"dino_counts": dino_counts.duplicate(true),
		"upgrades_owned": upgrades_owned.duplicate(true),
		"talent_ranks": talent_ranks.duplicate(true),
		"rock_clicks_total": rock_clicks_total,
	}
	var json_text: String = JSON.stringify(payload, "\t")
	var file: FileAccess = FileAccess.open(TEMP_SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(json_text)
	file.close()

	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return false
	if dir.file_exists(SAVE_PATH.get_file()):
		dir.remove(SAVE_PATH.get_file())
	var err: Error = dir.rename(TEMP_SAVE_PATH.get_file(), SAVE_PATH.get_file())
	return err == OK


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return false
	var content: String = file.get_as_text()
	file.close()
	if content.is_empty():
		return false
	var parsed: Variant = JSON.parse_string(content)
	if not (parsed is Dictionary):
		return false
	var data: Dictionary = parsed as Dictionary
	_is_loading = true
	fragments = float(data.get("fragments", 0.0))
	pile_fragments = float(data.get("pile_fragments", 0.0))
	total_run_fragments = float(data.get("total_run_fragments", 0.0))
	amber_pure = float(data.get("amber_pure", 0.0))
	compression_tier = int(data.get("compression_tier", 0))
	meteor_max_hp = maxf(1.0, float(data.get("meteor_max_hp", METEOR_MAX_HP)))
	meteor_hp = clampf(float(data.get("meteor_hp", meteor_max_hp)), 0.0, meteor_max_hp)
	meteor_time_left = maxf(0.0, float(data.get("meteor_time_left", BASE_RUN_DURATION)))
	run_number = maxi(1, int(data.get("run_number", 1)))
	run_state = String(data.get("run_state", "playing"))
	total_victories = maxi(0, int(data.get("total_victories", 0)))
	audio_muted = bool(data.get("audio_muted", false))
	master_volume = clampf(float(data.get("master_volume", 0.8)), 0.0, 1.0)
	auto_pan_enabled = bool(data.get("auto_pan_enabled", true))
	rock_clicks_total = maxi(0, int(data.get("rock_clicks_total", 0)))
	roar_time_left = 0.0
	roar_multiplier = 1.0

	structures_built.clear()
	var sb_raw: Variant = data.get("structures_built", {})
	if sb_raw is Dictionary:
		var sb_dict: Dictionary = sb_raw as Dictionary
		for k: Variant in sb_dict:
			structures_built[String(k)] = bool(sb_dict[k])

	dino_counts.clear()
	var dc_raw: Variant = data.get("dino_counts", {})
	if dc_raw is Dictionary:
		var dc_dict: Dictionary = dc_raw as Dictionary
		for k: Variant in dc_dict:
			dino_counts[String(k)] = maxi(0, int(dc_dict[k]))

	upgrades_owned.clear()
	var uo_raw: Variant = data.get("upgrades_owned", {})
	if uo_raw is Dictionary:
		var uo_dict: Dictionary = uo_raw as Dictionary
		for k: Variant in uo_dict:
			upgrades_owned[String(k)] = bool(uo_dict[k])

	talent_ranks.clear()
	var tr_raw: Variant = data.get("talent_ranks", {})
	if tr_raw is Dictionary:
		var tr_dict: Dictionary = tr_raw as Dictionary
		for k: Variant in tr_dict:
			talent_ranks[String(k)] = maxi(0, int(tr_dict[k]))

	_is_loading = false
	pile_changed.emit(pile_fragments, compression_tier, get_pile_capacity())
	meteor_tick.emit(meteor_time_left, meteor_hp, meteor_max_hp)
	resources_changed.emit()
	audio_settings_changed.emit()
	return true


func delete_save() -> void:
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		return
	if dir.file_exists(SAVE_PATH.get_file()):
		dir.remove(SAVE_PATH.get_file())
	if dir.file_exists(TEMP_SAVE_PATH.get_file()):
		dir.remove(TEMP_SAVE_PATH.get_file())
#endregion


#region Getters & Configurações Tipados
func get_structure_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in STRUCTURES:
		result.append(item)
	return result


func get_structure_def(struct_id: String) -> Dictionary:
	for item: Dictionary in STRUCTURES:
		if String(item.get("id", "")) == struct_id:
			return item
	return {}


func get_upgrades_for_structure(struct_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in UPGRADES:
		if String(item.get("struct_id", "")) == struct_id:
			result.append(item)
	return result


func get_talent_list() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item: Dictionary in TALENTS:
		result.append(item)
	return result


func get_dino_count(species_id: String) -> int:
	return int(dino_counts.get(species_id, 0))


func get_total_dino_count() -> int:
	var total: int = 0
	for k: Variant in dino_counts:
		total += int(dino_counts[k])
	return total


func get_structure_cost(struct_id: String) -> float:
	var def: Dictionary = get_structure_def(struct_id)
	if def.is_empty():
		return 0.0
	var base: float = float(def.get("build_cost", 0.0))
	return maxf(1.0, roundf(base * _get_cost_discount_multiplier()))


func get_dino_cost(struct_id: String) -> float:
	var def: Dictionary = get_structure_def(struct_id)
	if def.is_empty():
		return 0.0
	var base: float = float(def.get("dino_base_cost", 0.0))
	var scale: float = float(def.get("dino_cost_scale", 1.35))
	var species: String = String(def.get("species", ""))
	var count: int = get_dino_count(species)
	var exponent: int = maxi(0, count - 1) if is_structure_built(struct_id) else count
	var raw_cost: float = base * pow(scale, float(exponent))
	return maxf(1.0, roundf(raw_cost * _get_cost_discount_multiplier()))


func get_upgrade_cost(upgrade_id: String) -> float:
	var def: Dictionary = _get_upgrade_def(upgrade_id)
	if def.is_empty():
		return 0.0
	return float(def.get("cost", 0.0))


func get_talent_cost(talent_id: String) -> int:
	var def: Dictionary = _get_talent_def(talent_id)
	if def.is_empty():
		return 0
	var base_cost: int = int(def.get("base_cost", 1))
	var rank: int = get_talent_rank(talent_id)
	return maxi(1, roundi(float(base_cost) * pow(1.5, float(rank))))


func is_structure_built(struct_id: String) -> bool:
	return bool(structures_built.get(struct_id, false))


func is_structure_unlocked(struct_id: String) -> bool:
	if is_structure_built(struct_id):
		return true
	var def: Dictionary = get_structure_def(struct_id)
	if def.is_empty():
		return false
	var req: float = float(def.get("unlock_fragments", 0.0))
	return maxf(total_run_fragments, fragments) >= req


func is_upgrade_owned(upgrade_id: String) -> bool:
	return bool(upgrades_owned.get(upgrade_id, false))


func get_talent_rank(talent_id: String) -> int:
	return int(talent_ranks.get(talent_id, 0))


func get_click_damage() -> float:
	var rank: int = get_talent_rank("talent_claw_click")
	var mult: float = 1.0 + float(rank) * 0.75
	if roar_time_left > 0.0:
		mult *= 1.20
	return 2.0 * mult


func get_manual_scoop_amount() -> float:
	return BASE_MANUAL_SCOOP + float(get_talent_rank("talent_claw_click")) * 2.0


func get_pile_capacity() -> float:
	return BASE_PILE_CAPACITY * pow(1.65, float(compression_tier))


func get_compression_multiplier() -> float:
	if compression_tier <= 0:
		return 1.0
	var talent_bonus: float = 1.0 + float(get_talent_rank("talent_pile_dense")) * 0.25
	var ankylo_bonus: float = 1.20 if is_upgrade_owned("ankylo_compress") else 1.0
	return (1.0 + float(compression_tier) * 0.45) * talent_bonus * ankylo_bonus


func get_dino_speed_multiplier(species_id: String) -> float:
	var mult: float = 1.0 + float(get_talent_rank("talent_swarm_spirit")) * 0.12
	match species_id:
		"pachy":
			if is_upgrade_owned("pachy_frenzy"):
				mult *= 1.35
		"compy":
			if is_upgrade_owned("compy_sprint"):
				mult *= 1.40
		"ptero":
			if is_upgrade_owned("ptero_flock"):
				mult *= 1.30
	if roar_time_left > 0.0:
		mult *= 1.20
	return mult


func get_dino_hit_power(species_id: String) -> float:
	var base: float = 0.0
	match species_id:
		"pachy":
			base = 2.5
			if is_upgrade_owned("pachy_helmet"):
				base *= 1.55
		"compy":
			base = 1.0
		"ptero":
			base = 8.0
			if is_upgrade_owned("ptero_dive"):
				base *= 1.55
		"ankylo":
			base = 24.0
			if is_upgrade_owned("ankylo_club"):
				base *= 1.65
		"trex":
			base = 65.0
			if is_upgrade_owned("trex_terrify"):
				base *= 1.50
		"cannon":
			base = 220.0
		_:
			return 0.0
	var global_mult: float = 1.0 + float(get_talent_rank("talent_swarm_spirit")) * 0.25
	if is_upgrade_owned("trex_terrify"):
		global_mult *= 1.18
	if roar_time_left > 0.0:
		global_mult *= roar_multiplier
	return base * global_mult


func get_compy_carry_capacity() -> float:
	var cap: float = 6.0
	if is_upgrade_owned("compy_pouch"):
		cap *= 2.0
	return cap


func get_cannon_interval() -> float:
	var crew_count: int = maxi(1, get_dino_count("cannon"))
	var interval: float = 3.8 / (1.0 + 0.14 * float(crew_count - 1))
	if is_upgrade_owned("cannon_overclock"):
		interval /= 1.35
	if is_upgrade_owned("cannon_amber_core"):
		var frag_accel: float = 1.0 + minf(0.45, log(maxf(1.0, fragments)) * 0.04)
		interval /= frag_accel
	return maxf(0.55, interval)


func get_amber_reward_preview(outcome: String) -> float:
	var effective_frags: float = maxf(total_run_fragments, fragments)
	var base: float = maxf(2.0, floorf(pow(maxf(effective_frags, 15.0) / 45.0, 0.42)))
	var damage_ratio: float = clampf(1.0 - (meteor_hp / maxf(meteor_max_hp, 1.0)), 0.0, 1.0)
	base += floorf(damage_ratio * 8.0)
	if outcome == "victory":
		base = (base + 10.0 + float(total_victories) * 3.0) * 1.5
	var magnet_mult: float = 1.0 + float(get_talent_rank("talent_amber_magnet")) * 0.30
	return maxf(1.0, roundf(base * magnet_mult))


func get_fragments_per_second() -> float:
	_prune_rate_samples()
	if _frag_rate_samples.is_empty():
		return 0.0
	var total: float = 0.0
	for entry: Dictionary in _frag_rate_samples:
		total += float(entry.get("val", 0.0))
	return total / 3.0


func get_meteor_dps() -> float:
	_prune_rate_samples()
	if _meteor_dps_samples.is_empty():
		return 0.0
	var total: float = 0.0
	for entry: Dictionary in _meteor_dps_samples:
		total += float(entry.get("val", 0.0))
	return total / 3.0


func get_next_locked_structure() -> Dictionary:
	for item: Dictionary in STRUCTURES:
		var sid: String = String(item.get("id", ""))
		if not is_structure_built(sid) and not is_structure_unlocked(sid):
			return item
	return {}


func can_afford_any_talent() -> bool:
	for item: Dictionary in TALENTS:
		var tid: String = String(item.get("id", ""))
		var rank: int = get_talent_rank(tid)
		var max_rank: int = int(item.get("max_rank", 1))
		if rank < max_rank and amber_pure >= float(get_talent_cost(tid)):
			return true
	return false


func set_audio_muted(muted: bool) -> void:
	if audio_muted == muted:
		return
	audio_muted = muted
	audio_settings_changed.emit()


func set_master_volume(vol: float) -> void:
	var clamped: float = clampf(vol, 0.0, 1.0)
	if is_equal_approx(master_volume, clamped):
		return
	master_volume = clamped
	audio_settings_changed.emit()


func set_auto_pan(enabled: bool) -> void:
	if auto_pan_enabled == enabled:
		return
	auto_pan_enabled = enabled
	audio_settings_changed.emit()


func format_number(value: float) -> String:
	var sign_prefix: String = "-" if value < 0.0 else ""
	var abs_val: float = absf(value)
	if abs_val < 10.0:
		if is_equal_approx(abs_val, roundf(abs_val)):
			return "%s%d" % [sign_prefix, roundi(abs_val)]
		return "%s%.1f" % [sign_prefix, abs_val]
	if abs_val < 1000.0:
		return "%s%d" % [sign_prefix, roundi(abs_val)]
	if abs_val < 1000000.0:
		return "%s%.1fK" % [sign_prefix, abs_val / 1000.0]
	if abs_val < 1000000000.0:
		return "%s%.1fM" % [sign_prefix, abs_val / 1000000.0]
	if abs_val < 1000000000000.0:
		return "%s%.1fB" % [sign_prefix, abs_val / 1000000000.0]
	return "%s%.1fT" % [sign_prefix, abs_val / 1000000000000.0]


func _prune_rate_samples() -> void:
	var cutoff: float = _sim_clock - 3.0
	while not _frag_rate_samples.is_empty() and float(_frag_rate_samples[0].get("time", 0.0)) < cutoff:
		_frag_rate_samples.remove_at(0)
	while not _meteor_dps_samples.is_empty() and float(_meteor_dps_samples[0].get("time", 0.0)) < cutoff:
		_meteor_dps_samples.remove_at(0)


func _get_upgrade_def(upgrade_id: String) -> Dictionary:
	for item: Dictionary in UPGRADES:
		if String(item.get("id", "")) == upgrade_id:
			return item
	return {}


func _get_talent_def(talent_id: String) -> Dictionary:
	for item: Dictionary in TALENTS:
		if String(item.get("id", "")) == talent_id:
			return item
	return {}


func _get_cost_discount_multiplier() -> float:
	var rank: int = get_talent_rank("talent_cheap_nests")
	return maxf(0.60, 1.0 - 0.08 * float(rank))


func _get_meteor_talent_multiplier() -> float:
	var rank: int = get_talent_rank("talent_meteor_cracker")
	return 1.0 + 0.35 * float(rank)
#endregion
