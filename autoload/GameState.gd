extends Node
## GameState — fonte única da verdade do Fóssil Rush.
##
## Guarda TODO o estado mutável do jogo (recursos, níveis, dinos, era, meteoro)
## e centraliza as regras de economia. Cenas leem daqui e emitem pedidos via Events.
##
## Responsabilidades:
##   • Bancos de dados (carrega todos os .tres de data/).
##   • Recursos: add / spend / can_afford.
##   • Upgrades: compra (1x / 10x / 100x / Máx) e estatísticas derivadas.
##   • Dinos: montagem, contagem, marcos.
##   • Escavação: aplica dano na camada, gera loot, avança eras.
##   • Meteoro: timer, impacto e prestígio.
##   • Serialização (to_save_dict / load_save_dict) usada pelo SaveManager.

#region Constantes
## IDs de recursos.
const RES_BONES: StringName = &"bones"
const RES_ROCKS: StringName = &"rocks"
const RES_MINERALS: StringName = &"minerals"
const RES_DNA: StringName = &"dna"
const RES_AMBER: StringName = &"amber"
## Recursos zerados a cada run (âmbar é permanente).
const RUN_RESOURCES: Array[StringName] = [RES_BONES, RES_ROCKS, RES_MINERALS, RES_DNA]
const ALL_RESOURCES: Array[StringName] = [RES_BONES, RES_ROCKS, RES_MINERALS, RES_DNA, RES_AMBER]

## Vida inicial da Rocha Laranja na Superfície.
const ORANGE_ROCK_MAX_HP: float = 10.0

## Escombros de pedra reconstruíveis na Superfície (custam RES_ROCKS).
const RUBBLE_ORDER: Array[StringName] = [
	&"rubble_forge",
	&"rubble_nest",
	&"rubble_silo",
	&"rubble_bunker",
]
const RUBBLE_DEFS: Dictionary = {
	&"rubble_forge": {
		"title": "Forja de Pedra",
		"desc": "+50% de Dano de Clique por nível",
		"base_cost": 15.0,
		"cost_growth": 2.1,
		"stat_id": &"click_damage",
		"mult_per_level": 0.50,
		"color": Color(0.92, 0.52, 0.24),
	},
	&"rubble_nest": {
		"title": "Ninho Aquecido",
		"desc": "+50% de Dano dos Dinos por nível",
		"base_cost": 30.0,
		"cost_growth": 2.2,
		"stat_id": &"dino_damage",
		"mult_per_level": 0.50,
		"color": Color(0.52, 0.85, 0.38),
	},
	&"rubble_silo": {
		"title": "Silo Geológico",
		"desc": "+45% de Ossos e Rochas por nível",
		"base_cost": 60.0,
		"cost_growth": 2.3,
		"stat_id": &"bones_mult",
		"mult_per_level": 0.45,
		"color": Color(0.42, 0.75, 0.92),
	},
	&"rubble_bunker": {
		"title": "Bastião de Rocha",
		"desc": "+8% de Escudo Anti-Meteoro por nível",
		"base_cost": 100.0,
		"cost_growth": 2.4,
		"stat_id": &"meteor_shield",
		"add_per_level": 0.08,
		"color": Color(0.75, 0.65, 0.88),
	},
}

## Pools de peças anatômicas para catalogação de fósseis no Museu.
const FOSSIL_PART_POOLS: Dictionary = {
	&"compsognathus": ["Falange Ligeira", "Crânio em Miniatura", "Vértebra Caudal"],
	&"velociraptor": ["Garra Falciforme", "Osso Nasal", "Dente Serrilhado"],
	&"triceratops": ["Chifre Supraorbital", "Placa do Escudo", "Bico Ossificado"],
	&"trex": ["Mandíbula Petrificada", "Presa de 22 cm", "Coroa Dorsal"],
	&"pterodactyl": ["Falange Alar", "Crista Pneumática", "Bico Fendido"],
	&"brachiosaurus": ["Vértebra Cervical", "Fêmur Colossal", "Arco Torácico"],
	&"ankylosaurus": ["Placa Osteoderma", "Clava da Cauda", "Espinho Lateral"],
	&"dilophosaurus": ["Crista Craniana Dupla", "Dente Canaliculado", "Escápula Ágil"],
}

## IDs de estatísticas afetadas por upgrades (UpgradeData.stat_id).
## Para dano de uma espécie use DinoData.get_damage_stat_id() → &"dino_damage:<id>".
const BalanceConfig = preload("res://data/BalanceConfig.gd")

const STAT_CLICK_DAMAGE: StringName = &"click_damage"
const STAT_CLICK_CRIT_CHANCE: StringName = &"click_crit_chance"
const STAT_DINO_DAMAGE: StringName = &"dino_damage"        ## Global (todos os dinos)
const STAT_DINO_EVO_MULT: StringName = &"dino_evo_mult"     ## Evolução genética em DNA (multiplica em separado)
const STAT_BONES_MULT: StringName = &"bones_mult"
const STAT_PRESTIGE_BONES_MULT: StringName = &"prestige_bones_mult"  ## Multiplicador permanente de prestígio
const STAT_MINERAL_CHANCE: StringName = &"mineral_chance"  ## Multiplicador da chance base da era
const STAT_FRAGMENT_CHANCE: StringName = &"fragment_chance"
const STAT_DNA_MULT: StringName = &"dna_mult"
const STAT_METEOR_TIME: StringName = &"meteor_time"        ## Segundos extras (ADD)
const STAT_METEOR_SHIELD: StringName = &"meteor_shield"    ## 0..1 de proteção
const STAT_AMBER_MULT: StringName = &"amber_mult"
const STAT_OFFLINE_MULT: StringName = &"offline_mult"
const STAT_AUTO_DPS: StringName = &"auto_dps"              ## DPS passivo de máquinas

## Valor de "Máx" no multiplicador de compra.
const BUY_MAX: int = -1
const BUY_MULTIPLIERS: Array[int] = [1, 10, 100, BUY_MAX]

## Timer base do meteoro (segundos) — fallback caso balance.tres ainda não tenha sido carregado.
const BASE_METEOR_TIME: float = 600.0
## A partir de qual run o meteoro aparece (1 = desde a primeira).
const METEOR_FIRST_RUN: int = 1
## Requisitos do Projeto Arca (condição de vitória do GDD §7).
const ARK_REQUIRED_LEVEL: int = 5
const ARK_REQUIRED_SHIELD: float = 0.75
const ARK_REQUIRED_ERA: int = 3

const BALANCE_PATH: String = "res://data/balance.tres"
const DINOS_DIR: String = "res://data/dinos"
const UPGRADES_DIR: String = "res://data/upgrades"
const ERAS_DIR: String = "res://data/eras"
#endregion


#region Bancos de dados (somente leitura após _ready)
var balance: BalanceConfig = BalanceConfig.new()
var dinos_db: Dictionary = {}
var upgrades_db: Dictionary = {}
## Ordenado por EraData.index.
var eras: Array[EraData] = []
#endregion


#region Estado da run (reseta no meteoro)
var resources: Dictionary = {}
var fragments: Dictionary = {}
var dino_counts: Dictionary = {}
var upgrade_levels: Dictionary = {}
var rubble_levels: Dictionary = {}

var orange_rock_hp: float = ORANGE_ROCK_MAX_HP
var orange_rock_broken: bool = false

var current_era_index: int = 0
## Camada dentro da era atual.
var current_layer_index: int = 0
var layer_hp: float = 0.0
var layer_max_hp: float = 0.0
## Total de camadas quebradas nesta run (profundidade).
var depth: int = 0
var run_total_bones: float = 0.0

var meteor_active: bool = false
var meteor_time_left: float = 0.0
var meteor_total_time: float = 0.0
var is_impacting: bool = false
var _dig_cycle_damage: float = 0.0
#endregion


#region Estado permanente (sobrevive ao prestígio)
var permanent_upgrade_levels: Dictionary = {}
var run_number: int = 1
var max_depth_ever: int = 0
var lifetime_bones: float = 0.0
var total_amber_earned: float = 0.0
## Espécies já revividas alguma vez (para bestiário e progressão de cor).
var discovered_dinos: Dictionary = {}
var ark_completed: bool = false
## Catálogo persistente do Museu Paleontológico (`dino_id -> {"count", "best_rarity", "parts"}`).
var fossil_catalog: Dictionary = {}
var total_fossils_evaluated: int = 0
var total_legendary_fossils: int = 0
var last_evaluated_fossil: Dictionary = {}
#endregion


#region Preferências / UI
var buy_multiplier: int = 1
var color_progress: float = 0.0
var danger_level: float = 0.0
var is_prestige_modal_open: bool = false
#endregion


#region Cache de estatísticas
var _stat_flat: Dictionary = {}
var _stat_mult: Dictionary = {}
#endregion


func _ready() -> void:
	_load_databases()
	_connect_events()
	start_new_game()


func _process(delta: float) -> void:
	if is_impacting:
		return
	_tick_passive_income(delta)
	_tick_meteor(delta)


func _connect_events() -> void:
	Events.dig_hit.connect(_on_dig_hit)
	Events.orange_rock_hit.connect(_on_orange_rock_hit)
	Events.rubble_rebuild_requested.connect(_on_rubble_rebuild_requested)
	Events.upgrade_purchase_requested.connect(_on_upgrade_purchase_requested)
	Events.dino_assembly_requested.connect(_on_dino_assembly_requested)
	Events.meteor_early_impact_requested.connect(_on_meteor_early_impact_requested)
	Events.prestige_modal_visibility_changed.connect(_on_prestige_modal_visibility_changed)


#region Ciclo de jogo
## Zera tudo (novo jogo do zero).
func start_new_game() -> void:
	permanent_upgrade_levels.clear()
	discovered_dinos.clear()
	fossil_catalog.clear()
	total_fossils_evaluated = 0
	total_legendary_fossils = 0
	last_evaluated_fossil.clear()
	ark_completed = false
	run_number = 1
	max_depth_ever = 0
	lifetime_bones = 0.0
	total_amber_earned = 0.0
	resources[RES_AMBER] = 0.0
	is_prestige_modal_open = false
	_reset_run_state()
	Events.run_started.emit(run_number)


## Reseta apenas o estado da run (chamado pelo prestígio).
func _reset_run_state() -> void:
	for res_id: StringName in RUN_RESOURCES:
		resources[res_id] = 0.0
	fragments.clear()
	dino_counts.clear()
	upgrade_levels.clear()
	rubble_levels.clear()
	orange_rock_hp = ORANGE_ROCK_MAX_HP
	orange_rock_broken = false
	current_era_index = 0
	current_layer_index = 0
	depth = 0
	run_total_bones = 0.0
	_dig_roll_accum = 0.0
	_auto_dig_accum = 0.0
	meteor_active = false
	is_impacting = false
	_dig_cycle_damage = 0.0
	recalculate_stats()
	_setup_layer()
	_setup_meteor()
	_update_color_progress()
	_emit_full_refresh()


## Emite todos os sinais de estado para que as cenas se redesenhem (após load/prestígio).
func _emit_full_refresh() -> void:
	for res_id: StringName in ALL_RESOURCES:
		Events.resource_changed.emit(res_id, get_resource(res_id), 0.0)
	for dino_id: Variant in dinos_db:
		Events.dino_count_changed.emit(dino_id, get_dino_count(dino_id))
		Events.fragments_changed.emit(dino_id, get_fragments(dino_id))
	Events.orange_rock_hp_changed.emit(orange_rock_hp, ORANGE_ROCK_MAX_HP)
	if orange_rock_broken:
		Events.orange_rock_broken.emit()
	for rubble_id: StringName in RUBBLE_ORDER:
		Events.rubble_rebuilt.emit(rubble_id, get_rubble_level(rubble_id))
	Events.era_changed.emit(current_era_index)
	Events.layer_hp_changed.emit(layer_hp, layer_max_hp)
	Events.meteor_timer_changed.emit(meteor_time_left, meteor_total_time)
	Events.buy_multiplier_changed.emit(buy_multiplier)
	Events.stats_recalculated.emit()
#endregion


#region Recursos
func get_resource(res_id: StringName) -> float:
	return resources.get(res_id, 0.0)


func add_resource(res_id: StringName, amount: float) -> void:
	if amount == 0.0:
		return
	var new_amount: float = maxf(get_resource(res_id) + amount, 0.0)
	resources[res_id] = new_amount
	if res_id == RES_BONES and amount > 0.0:
		run_total_bones += amount
		lifetime_bones += amount
	Events.resource_changed.emit(res_id, new_amount, amount)


func can_afford(res_id: StringName, amount: float) -> bool:
	return get_resource(res_id) >= amount


## Gasta se tiver saldo. Retorna true se conseguiu.
func spend(res_id: StringName, amount: float) -> bool:
	if not can_afford(res_id, amount):
		return false
	add_resource(res_id, -amount)
	return true


func get_fragments(dino_id: StringName) -> int:
	return fragments.get(dino_id, 0)


func add_fragments(dino_id: StringName, amount: int) -> void:
	var old_amount: int = get_fragments(dino_id)
	var new_amount: int = maxi(old_amount + amount, 0)
	fragments[dino_id] = new_amount
	Events.fragments_changed.emit(dino_id, new_amount)
	if amount > 0:
		var data: DinoData = get_dino(dino_id)
		var owned: int = get_dino_count(dino_id)
		if data != null and data.can_spawn_more(owned):
			var req: int = data.get_fragments_required(owned)
			if old_amount < req and new_amount >= req:
				Events.dino_fossil_completed.emit(dino_id, new_amount, req)
#endregion


#region Upgrades
func get_upgrade(upgrade_id: StringName) -> UpgradeData:
	return upgrades_db.get(upgrade_id, null)


func get_upgrade_level(upgrade_id: StringName) -> int:
	var data: UpgradeData = get_upgrade(upgrade_id)
	if data != null and data.is_permanent:
		return permanent_upgrade_levels.get(upgrade_id, 0)
	return upgrade_levels.get(upgrade_id, 0)


## Upgrades de uma aba, ordenados por sort_order (para a UI montar a lista).
func get_upgrades_by_category(category: UpgradeData.Category) -> Array[UpgradeData]:
	var result: Array[UpgradeData] = []
	for item: Variant in upgrades_db.values():
		var data: UpgradeData = item as UpgradeData
		if data.category == category:
			result.append(data)
	result.sort_custom(func(a: UpgradeData, b: UpgradeData) -> bool: return a.sort_order < b.sort_order)
	return result


func is_upgrade_unlocked(upgrade_id: StringName) -> bool:
	var data: UpgradeData = get_upgrade(upgrade_id)
	if data == null:
		return false
	if current_era_index < data.required_era_index and not data.is_permanent:
		return false
	if data.required_upgrade != &"":
		return get_upgrade_level(data.required_upgrade) >= data.required_level
	return true


## Resolve o multiplicador de compra atual (1/10/100/Máx) em níveis concretos.
## Retorna 0 se não puder comprar nem 1. Para 10x/100x, limita ao máximo de níveis restantes.
func resolve_purchase_amount(upgrade_id: StringName, multiplier: int = buy_multiplier) -> int:
	var data: UpgradeData = get_upgrade(upgrade_id)
	if data == null:
		return 0
	var level: int = get_upgrade_level(upgrade_id)
	if multiplier == BUY_MAX:
		return data.get_max_affordable(level, get_resource(data.cost_resource))
	var remaining: int = data.get_remaining_levels(level)
	return multiplier if remaining < 0 else mini(multiplier, remaining)


## Custo para a UI exibir, considerando o multiplicador atual.
func get_purchase_cost(upgrade_id: StringName, multiplier: int = buy_multiplier) -> float:
	var data: UpgradeData = get_upgrade(upgrade_id)
	if data == null:
		return 0.0
	var level: int = get_upgrade_level(upgrade_id)
	var amount: int = resolve_purchase_amount(upgrade_id, multiplier)
	if amount <= 0:
		return data.get_cost(level)  # mostra o custo de 1 nível (botão desabilitado)
	return data.get_bulk_cost(level, amount)


func can_purchase_upgrade(upgrade_id: StringName, multiplier: int = buy_multiplier) -> bool:
	var data: UpgradeData = get_upgrade(upgrade_id)
	if data == null or not is_upgrade_unlocked(upgrade_id):
		return false
	if data.is_maxed(get_upgrade_level(upgrade_id)):
		return false
	var amount: int = resolve_purchase_amount(upgrade_id, multiplier)
	if amount <= 0:
		return false
	return can_afford(data.cost_resource, get_purchase_cost(upgrade_id, multiplier))


## Compra `amount` níveis (ou BUY_MAX). Retorna true se comprou algo.
func purchase_upgrade(upgrade_id: StringName, amount: int = 1) -> bool:
	if not can_purchase_upgrade(upgrade_id, amount):
		return false
	var data: UpgradeData = get_upgrade(upgrade_id)
	var level: int = get_upgrade_level(upgrade_id)
	var levels_to_buy: int = resolve_purchase_amount(upgrade_id, amount)
	var cost: float = data.get_bulk_cost(level, levels_to_buy)
	if not spend(data.cost_resource, cost):
		return false
	var new_level: int = level + levels_to_buy
	if data.is_permanent:
		permanent_upgrade_levels[upgrade_id] = new_level
	else:
		upgrade_levels[upgrade_id] = new_level
	recalculate_stats()
	_update_color_progress()
	Events.upgrade_purchased.emit(upgrade_id, new_level)
	return true


func set_buy_multiplier(multiplier: int) -> void:
	if multiplier not in BUY_MULTIPLIERS or multiplier == buy_multiplier:
		return
	buy_multiplier = multiplier
	Events.buy_multiplier_changed.emit(buy_multiplier)


## Avança para o próximo multiplicador (1x → 10x → 100x → Máx → 1x).
func cycle_buy_multiplier() -> void:
	var idx: int = BUY_MULTIPLIERS.find(buy_multiplier)
	set_buy_multiplier(BUY_MULTIPLIERS[(idx + 1) % BUY_MULTIPLIERS.size()])


func _on_upgrade_purchase_requested(upgrade_id: StringName, amount: int) -> void:
	purchase_upgrade(upgrade_id, amount)
#endregion


#region Estatísticas
## Recalcula o cache de modificadores a partir de todos os upgrades comprados.
## Multiplicadores do mesmo stat_id somam (+(effect - 1)); tipos diferentes multiplicam entre si.
func recalculate_stats() -> void:
	_stat_flat.clear()
	_stat_mult.clear()
	for item: Variant in upgrades_db.values():
		var data: UpgradeData = item as UpgradeData
		var level: int = get_upgrade_level(data.id)
		if level <= 0 or data.stat_id == &"":
			continue
		var effect: float = data.get_effect_at_level(level)
		if data.effect_type == UpgradeData.EffectType.ADD:
			_stat_flat[data.stat_id] = _stat_flat.get(data.stat_id, 0.0) + effect
		else:
			_stat_mult[data.stat_id] = _stat_mult.get(data.stat_id, 1.0) + (effect - 1.0)

	# Bônus dos escombros/estações reconstruídas na Superfície (mesmo stat_id soma multiplicadores).
	for rubble_id: StringName in RUBBLE_ORDER:
		var r_lvl: int = get_rubble_level(rubble_id)
		if r_lvl <= 0:
			continue
		var def: Dictionary = RUBBLE_DEFS[rubble_id]
		var st_id: StringName = def.get("stat_id", &"")
		if def.has("add_per_level"):
			_stat_flat[st_id] = _stat_flat.get(st_id, 0.0) + float(def["add_per_level"]) * float(r_lvl)
		elif def.has("mult_per_level"):
			_stat_mult[st_id] = _stat_mult.get(st_id, 1.0) + float(def["mult_per_level"]) * float(r_lvl)

	var base_time: float = balance.base_meteor_time if balance != null else BASE_METEOR_TIME
	var expected_meteor_total: float = get_stat(STAT_METEOR_TIME, base_time)
	if meteor_active and not is_impacting and meteor_total_time > 0.0 and expected_meteor_total > meteor_total_time:
		var delta_time: float = expected_meteor_total - meteor_total_time
		meteor_total_time = expected_meteor_total
		meteor_time_left += delta_time
		Events.meteor_timer_changed.emit(meteor_time_left, meteor_total_time)

	Events.stats_recalculated.emit()


## Valor final de uma estatística: (base + somas) × multiplicadores.
func get_stat(stat_id: StringName, base_value: float = 0.0) -> float:
	return (base_value + _stat_flat.get(stat_id, 0.0)) * _stat_mult.get(stat_id, 1.0)


## Atalho para estatísticas que são multiplicadores puros (base 1.0).
func get_multiplier(stat_id: StringName) -> float:
	return get_stat(stat_id, 1.0)


func get_click_damage() -> float:
	var base_click: float = balance.base_click_damage if balance != null else 1.0
	return get_stat(STAT_CLICK_DAMAGE, base_click) \
		* get_area_tremor_multiplier() \
		* get_fortified_excavation_multiplier() \
		* get_prestige_excavation_multiplier()


## Soma bônus de papel por todas as espécies em `dino_counts` que correspondam a `role`.
func _sum_role_unit_bonus(role: DinoData.Role, default_per_unit: float, max_units: int, use_carry_capacity: bool = false, use_aura_bonus: bool = false) -> float:
	var bonus: float = 0.0
	for dino_id: Variant in dino_counts:
		var data: DinoData = get_dino(dino_id)
		if data == null or data.role != role:
			continue
		var count: int = mini(get_dino_count(dino_id), max_units)
		if count <= 0:
			continue
		var per_unit: float = default_per_unit
		if use_carry_capacity and data.carry_capacity > 0.0:
			per_unit = data.carry_capacity
		elif use_aura_bonus and data.aura_bonus > 0.0:
			per_unit = data.aura_bonus
		bonus += per_unit * float(count)
	return bonus


## Coleta em bando (COLLECTOR): +bônus de ossos ganhos por unidade (lê carry_capacity do .tres).
func get_collector_bones_multiplier() -> float:
	var def_bonus: float = balance.collector_default_bone_bonus if balance != null else 0.015
	var cap: int = balance.collector_max_units if balance != null else 30
	return 1.0 + _sum_role_unit_bonus(DinoData.Role.COLLECTOR, def_bonus, cap, true, false)


## Coleta em bando (COLLECTOR): amplia também a taxa de drops (minérios e fragmentos).
func get_collector_drop_multiplier() -> float:
	var ratio: float = balance.collector_drop_bonus_ratio if balance != null else 1.0
	return 1.0 + (get_collector_bones_multiplier() - 1.0) * ratio


## Tremor de impacto (AREA): +bônus de dano de clique e máquinas por unidade.
func get_area_tremor_multiplier() -> float:
	var per_unit: float = balance.area_tremor_bonus_per_unit if balance != null else 0.015
	var cap: int = balance.area_tremor_max_units if balance != null else 30
	return 1.0 + _sum_role_unit_bonus(DinoData.Role.AREA, per_unit, cap)


## Logística aérea (TRANSPORT): bônus na chance de extrair minérios por unidade (lê carry_capacity do .tres).
func get_transport_mineral_multiplier() -> float:
	var def_bonus: float = balance.transport_default_mineral_bonus if balance != null else 0.03
	var cap: int = balance.transport_max_units if balance != null else 25
	return 1.0 + _sum_role_unit_bonus(DinoData.Role.TRANSPORT, def_bonus, cap, true, false)


func get_mineral_rate_multiplier() -> float:
	return get_multiplier(STAT_MINERAL_CHANCE) * get_transport_mineral_multiplier()


## Multiplicador de aura de todos os dinos SUPPORT vivos (lê aura_bonus do .tres).
func get_support_aura_multiplier() -> float:
	var cap: int = balance.support_max_units if balance != null else 20
	return 1.0 + _sum_role_unit_bonus(DinoData.Role.SUPPORT, 0.04, cap, false, true)


## Suporte genético (SUPPORT): acelera também a síntese de DNA.
func get_support_dna_multiplier() -> float:
	var ratio: float = balance.support_dna_bonus_ratio if balance != null else 0.5
	return 1.0 + (get_support_aura_multiplier() - 1.0) * ratio


## Escudo fortificado (DEFENSE / Bunkers): estabiliza escavação de clique e máquinas.
func get_fortified_excavation_multiplier() -> float:
	var ratio: float = balance.shield_excavation_bonus if balance != null else 0.5
	return 1.0 + get_shield_ratio() * ratio


## Multiplicador combinado de ossos: bônus da run × prestígio permanente × coletores.
func get_total_bones_multiplier() -> float:
	return get_multiplier(STAT_BONES_MULT) * get_multiplier(STAT_PRESTIGE_BONES_MULT) * get_collector_bones_multiplier()


## Parcela da Mestria Paleontológica convertida em poder direto de escavação (evita estagnação pós-prestígio).
func get_prestige_excavation_multiplier() -> float:
	var exp_dig: float = balance.prestige_dig_exponent if balance != null else 0.28
	return pow(maxf(get_multiplier(STAT_PRESTIGE_BONES_MULT), 1.0), exp_dig)


func _get_role_damage_synergy(data: DinoData) -> float:
	match data.role:
		DinoData.Role.FAST:
			var per_u: float = balance.fast_pack_bonus_per_unit if balance != null else 0.02
			var cap: int = balance.fast_pack_max_units if balance != null else 30
			return 1.0 + per_u * float(mini(get_dino_count(data.id), cap))
		DinoData.Role.BREAKER:
			var per_era: float = balance.breaker_era_bonus if balance != null else 0.25
			return 1.0 + per_era * float(current_era_index)
		DinoData.Role.DEFENSE:
			var def_ratio: float = balance.defense_shield_to_dino_damage if balance != null else 0.50
			return 1.0 + get_shield_ratio() * def_ratio
	return 1.0


## Dano corrosivo passivo por segundo dos dinos ELEMENTAL (% do HP da camada com teto seguro).
func get_acid_dot_dps() -> float:
	var total_count: int = 0
	var total_elem_dps: float = 0.0
	for dino_id: StringName in dino_counts:
		var data: DinoData = get_dino(dino_id)
		var count: int = get_dino_count(dino_id)
		if data != null and count > 0 and data.role == DinoData.Role.ELEMENTAL:
			total_count += count
			total_elem_dps += get_dino_damage(dino_id) * float(count)
	if total_count <= 0:
		return 0.0
	var pct_u: float = balance.elemental_hp_pct_per_unit if balance != null else 0.002
	var pct_cap: float = balance.elemental_hp_pct_cap if balance != null else 0.04
	var cap_ratio: float = balance.elemental_dps_cap_ratio if balance != null else 0.45
	var pct_dps: float = minf(pct_u * float(total_count), pct_cap) * layer_max_hp
	var cap_dps: float = total_elem_dps * cap_ratio
	return minf(pct_dps, cap_dps)


## Descrição legível da sinergia única de cada espécie (para tooltips).
func get_dino_synergy_description(dino_id: StringName) -> String:
	var data: DinoData = get_dino(dino_id)
	if data == null:
		return ""
	var count: int = get_dino_count(dino_id)
	match data.role:
		DinoData.Role.COLLECTOR:
			var bone_pct: int = roundi((get_collector_bones_multiplier() - 1.0) * 100.0)
			var drop_pct: int = roundi((get_collector_drop_multiplier() - 1.0) * 100.0)
			return "Coleta em bando: +%d%% ossos e +%d%% drops" % [bone_pct, drop_pct]
		DinoData.Role.FAST:
			var per_u: float = balance.fast_pack_bonus_per_unit if balance != null else 0.02
			var cap: int = balance.fast_pack_max_units if balance != null else 30
			return "Matilha veloz: +%d%% dano próprio (+%.0f%%/unid, máx %d)" % [roundi(float(mini(count, cap)) * per_u * 100.0), per_u * 100.0, cap]
		DinoData.Role.AREA:
			return "Tremor em área: +%d%% clique e máquinas" % roundi((get_area_tremor_multiplier() - 1.0) * 100.0)
		DinoData.Role.BREAKER:
			var per_era: float = balance.breaker_era_bonus if balance != null else 0.25
			return "Mandíbula abissal: +%d%% dano na era atual (+%d%%/era)" % [roundi(float(current_era_index) * per_era * 100.0), roundi(per_era * 100.0)]
		DinoData.Role.TRANSPORT:
			return "Transporte aéreo: +%d%% chance de minério" % roundi((get_transport_mineral_multiplier() - 1.0) * 100.0)
		DinoData.Role.SUPPORT:
			return "Aura colossal: +%d%% dano dinos e +%d%% DNA" % [
				roundi((get_support_aura_multiplier() - 1.0) * 100.0),
				roundi((get_support_dna_multiplier() - 1.0) * 100.0),
			]
		DinoData.Role.DEFENSE:
			var def_ratio: float = balance.defense_shield_to_dino_damage if balance != null else 0.50
			return "Bastião: +%d%% escudo (+%.0f%%/unid) e +%d%% dano pelo escudo" % [
				roundi(data.meteor_damage_reduction * float(count) * 100.0),
				data.meteor_damage_reduction * 100.0,
				roundi(get_shield_ratio() * def_ratio * 100.0),
			]
		DinoData.Role.ELEMENTAL:
			return "Ácido corrosivo: +%s/s de corrosão na rocha" % format_number(get_acid_dot_dps())
	return ""


## Dano final por golpe de uma unidade de `dino_id` (com upgrades, evolução DNA, marcos, aura, prestígio e sinergia de papel).
func get_dino_damage(dino_id: StringName) -> float:
	var data: DinoData = get_dino(dino_id)
	if data == null:
		return 0.0
	return data.base_damage \
		* get_multiplier(STAT_DINO_DAMAGE) \
		* get_multiplier(STAT_DINO_EVO_MULT) \
		* get_multiplier(data.get_damage_stat_id()) \
		* data.get_milestone_multiplier(get_dino_count(dino_id)) \
		* get_support_aura_multiplier() \
		* get_prestige_excavation_multiplier() \
		* _get_role_damage_synergy(data)


## DPS total de todos os dinos (incluindo corrosão elemental).
func get_total_dino_dps() -> float:
	var total: float = 0.0
	for dino_id: Variant in dino_counts:
		var data: DinoData = get_dino(dino_id)
		var count: int = get_dino_count(dino_id)
		if data == null or count <= 0 or data.attack_interval <= 0.0:
			continue
		var crit_factor: float = 1.0 + data.crit_chance * (data.crit_multiplier - 1.0)
		total += get_dino_damage(dino_id) * crit_factor / data.attack_interval * float(count)
	return total + get_acid_dot_dps()


## DPS automático das máquinas (aba 🏭 Máquinas), amplificado por área, escavação fortificada e prestígio.
func get_auto_dps() -> float:
	return get_stat(STAT_AUTO_DPS, 0.0) \
		* get_area_tremor_multiplier() \
		* get_fortified_excavation_multiplier() \
		* get_prestige_excavation_multiplier()


## DPS combinado (dinos + máquinas).
func get_total_dps() -> float:
	return get_total_dino_dps() + get_auto_dps()


func get_bones_per_second() -> float:
	var era: EraData = get_current_era()
	if era == null:
		return 0.0
	return get_total_dps() * era.bones_per_damage * get_total_bones_multiplier()


func get_dna_per_second() -> float:
	var total: float = 0.0
	for dino_id: Variant in dino_counts:
		var data: DinoData = get_dino(dino_id)
		if data != null:
			total += data.dna_per_second * float(get_dino_count(dino_id))
	return total * get_multiplier(STAT_DNA_MULT) * get_support_dna_multiplier()
#endregion


#region Dinos
func get_dino(dino_id: StringName) -> DinoData:
	return dinos_db.get(dino_id, null)


## Lista todas as espécies ordenadas por era de desbloqueio e custo de montagem.
func get_dinos_sorted() -> Array[DinoData]:
	var list: Array[DinoData] = []
	for item: Variant in dinos_db.values():
		var data: DinoData = item as DinoData
		list.append(data)
	list.sort_custom(func(a: DinoData, b: DinoData) -> bool:
		if a.unlock_era_index != b.unlock_era_index:
			return a.unlock_era_index < b.unlock_era_index
		return a.assembly_cost < b.assembly_cost
	)
	return list


func get_dino_count(dino_id: StringName) -> int:
	return dino_counts.get(dino_id, 0)


func is_dino_unlocked(dino_id: StringName) -> bool:
	return get_dino_count(dino_id) > 0


func get_required_fragments_for_dino(dino_id: StringName) -> int:
	var data: DinoData = get_dino(dino_id)
	if data == null:
		return 0
	return data.get_fragments_required(get_dino_count(dino_id))


## Resolve quantas unidades de um dino serão compradas para `multiplier` (1, 10, 100 ou BUY_MAX).
## Para reviver a 1ª unidade (count == 0), sempre resolve para 1.
func resolve_dino_purchase_amount(dino_id: StringName, multiplier: int = buy_multiplier) -> int:
	var data: DinoData = get_dino(dino_id)
	if data == null:
		return 0
	var count: int = get_dino_count(dino_id)
	if count == 0:
		return 1
	if multiplier == BUY_MAX:
		return data.get_max_affordable_units(count, get_resource(RES_BONES))
	return maxi(multiplier, 1)


func get_dino_purchase_cost(dino_id: StringName, multiplier: int = buy_multiplier) -> float:
	var data: DinoData = get_dino(dino_id)
	if data == null:
		return 0.0
	var count: int = get_dino_count(dino_id)
	var amount: int = resolve_dino_purchase_amount(dino_id, multiplier)
	if amount <= 0:
		return data.get_unit_cost(count)
	return data.get_bulk_unit_cost(count, amount)


## Pode montar o 1º esqueleto ou clonar `multiplier` unidades?
func can_assemble_dino(dino_id: StringName, multiplier: int = buy_multiplier) -> bool:
	var data: DinoData = get_dino(dino_id)
	if data == null:
		return false
	var count: int = get_dino_count(dino_id)
	if not data.can_spawn_more(count):
		return false
	var required_fossils: int = data.get_fragments_required(0) if count == 0 else (data.get_fragments_required(count) if data.fragments_growth_per_unit > 0 else 0)
	if required_fossils > 0 and get_fragments(dino_id) < required_fossils:
		return false
	var amount: int = resolve_dino_purchase_amount(dino_id, multiplier)
	if amount <= 0:
		return false
	return can_afford(RES_BONES, data.get_bulk_unit_cost(count, amount))


func assemble_dino(dino_id: StringName, multiplier: int = 1) -> bool:
	if not can_assemble_dino(dino_id, multiplier):
		return false
	var data: DinoData = get_dino(dino_id)
	var old_count: int = get_dino_count(dino_id)
	var amount: int = resolve_dino_purchase_amount(dino_id, multiplier)
	if not spend(RES_BONES, data.get_bulk_unit_cost(old_count, amount)):
		return false
	var required_fossils: int = data.get_fragments_required(0) if old_count == 0 else (data.get_fragments_required(old_count) if data.fragments_growth_per_unit > 0 else 0)
	if required_fossils > 0:
		add_fragments(dino_id, -required_fossils)
	var new_count: int = old_count + amount
	dino_counts[dino_id] = new_count

	if old_count == 0:
		discovered_dinos[dino_id] = true
		Events.dino_unlocked.emit(dino_id)
		_update_color_progress()
	if data.get_milestones_reached(new_count) > data.get_milestones_reached(old_count):
		var crossed: int = new_count
		for m: int in data.milestones:
			if old_count < m and new_count >= m:
				crossed = m
		Events.dino_milestone_reached.emit(dino_id, crossed)
	Events.dino_count_changed.emit(dino_id, new_count)
	Events.stats_recalculated.emit()
	return true


func _on_dino_assembly_requested(dino_id: StringName) -> void:
	var mult: int = buy_multiplier if get_dino_count(dino_id) >= 1 else 1
	assemble_dino(dino_id, mult)
#endregion


#region Escavação
var _dig_roll_accum: float = 0.0


func get_current_era() -> EraData:
	if eras.is_empty():
		return null
	return eras[clampi(current_era_index, 0, eras.size() - 1)]


## Todas as camadas da Terra podem ser rompidas pelo dano acumulado (sem bloqueio artificial).
func can_break_current_layer() -> bool:
	return get_current_era() != null


func _setup_layer() -> void:
	var era: EraData = get_current_era()
	layer_max_hp = era.get_layer_hp(current_layer_index) if era != null else 120000.0
	layer_hp = layer_max_hp
	_dig_cycle_damage = 0.0
	Events.layer_hp_changed.emit(layer_hp, layer_max_hp)


## Amostragem determinística (usa randf()) da distribuição Binomial(n, p) em O(1) para n grande.
func _sample_binomial(n: int, p: float) -> int:
	if n <= 0 or p <= 0.0:
		return 0
	if p >= 1.0:
		return n
	if n <= 24:
		var hits: int = 0
		for _i: int in range(n):
			if randf() < p:
				hits += 1
		return hits
	if p > 0.5:
		return n - _sample_binomial(n, 1.0 - p)
	var lam: float = float(n) * p
	if lam < 12.0:
		var limit: float = exp(-lam)
		var k: int = 0
		var prod: float = 1.0
		while true:
			prod *= randf()
			if prod <= limit:
				break
			k += 1
			if k >= n:
				return n
		return k
	var sigma: float = sqrt(lam * (1.0 - p))
	var u1: float = maxf(randf(), 1e-7)
	var u2: float = randf()
	var z: float = sqrt(-2.0 * log(u1)) * cos(TAU * u2)
	return clampi(roundi(lam + sigma * z), 0, n)


## Distribui `total_hits` fragmentos aleatoriamente entre as espécies de `pool` em O(pool.size()).
func _distribute_fragment_drops(pool: Array[DinoData], total_hits: int, world_position: Vector2) -> void:
	var remaining_hits: int = total_hits
	var pool_size: int = pool.size()
	for i: int in range(pool_size):
		if remaining_hits <= 0:
			break
		var dino: DinoData = pool[i]
		var take: int = remaining_hits if i == pool_size - 1 else _sample_binomial(remaining_hits, 1.0 / float(pool_size - i))
		remaining_hits -= take
		if take > 0 and dino != null:
			add_fragments(dino.id, take)
			for _f: int in range(take):
				register_fossil_found(dino.id)
			Events.fragment_dropped.emit(dino.id, world_position)


## Aplica dano na camada atual (com carryover de overkill até trocar de era) e gera loot via binomial.
func apply_dig_damage(damage: float, world_position: Vector2 = Vector2.ZERO) -> void:
	if damage <= 0.0 or is_impacting:
		return
	var remaining: float = damage
	var loops: int = 0
	var max_loops: int = balance.max_overkill_layers_per_hit if balance != null else 8
	var rolls_per_base: float = balance.drop_rolls_per_base_layer if balance != null else 16.0
	var max_p: float = clampf(balance.drop_max_single_prob if balance != null else 0.95, 0.01, 0.999)
	var rocks_ratio: float = balance.rocks_per_bone_ratio if balance != null else 0.08
	var bones_mult: float = get_total_bones_multiplier()
	var drop_mult: float = get_collector_drop_multiplier()
	var mineral_rate_mult: float = get_mineral_rate_multiplier() * drop_mult
	var frag_rate_mult: float = get_multiplier(STAT_FRAGMENT_CHANCE) * drop_mult
	var total_bones_dropped: float = 0.0
	var total_rocks_dropped: float = 0.0
	var total_minerals_dropped: float = 0.0

	while remaining > 0.0 and loops < max_loops and not is_impacting:
		var era: EraData = get_current_era()
		if era == null:
			break
		var start_era: int = current_era_index
		var effective: float = minf(remaining, layer_hp)
		remaining -= effective
		loops += 1

		# Ossos e rochas proporcionais ao dano causado (run × prestígio × coletores).
		var bones: float = effective * era.bones_per_damage * bones_mult
		if bones > 0.0:
			add_resource(RES_BONES, bones)
			total_bones_dropped += bones
			var rocks: float = bones * rocks_ratio
			if rocks > 0.0:
				add_resource(RES_ROCKS, rocks)
				total_rocks_dropped += rocks

		# Rolagens proporcionais ao dano efetivo, amostradas via distribuição binomial sem teto de 5 rolagens.
		var roll_dmg: float = maxf(era.base_layer_hp / maxf(rolls_per_base, 1.0), 1.0)
		_dig_roll_accum += effective / roll_dmg
		var n_rolls: int = floori(_dig_roll_accum)
		if n_rolls > 0:
			_dig_roll_accum -= float(n_rolls)
			var min_p: float = clampf(era.mineral_chance * mineral_rate_mult, 0.0, max_p)
			var min_hits: int = _sample_binomial(n_rolls, min_p)
			if min_hits > 0:
				var min_gain: float = float(min_hits) * era.mineral_amount
				add_resource(RES_MINERALS, min_gain)
				total_minerals_dropped += min_gain

			var frag_p: float = clampf(era.fragment_chance * frag_rate_mult, 0.0, max_p)
			var frag_hits: int = _sample_binomial(n_rolls, frag_p)
			if frag_hits > 0 and not era.fragment_pool.is_empty():
				_distribute_fragment_drops(era.fragment_pool, frag_hits, world_position)

		layer_hp -= effective
		Events.layer_hp_changed.emit(layer_hp, layer_max_hp)
		if layer_hp <= 0.0:
			_break_layer(world_position)
			if current_era_index != start_era:
				break

	if total_bones_dropped > 0.0:
		Events.loot_dropped.emit(RES_BONES, total_bones_dropped, world_position)
	if total_rocks_dropped >= 0.1:
		Events.loot_dropped.emit(RES_ROCKS, total_rocks_dropped, world_position)
	if total_minerals_dropped > 0.0:
		Events.loot_dropped.emit(RES_MINERALS, total_minerals_dropped, world_position)


func _break_layer(world_position: Vector2 = Vector2.ZERO) -> void:
	var era: EraData = get_current_era()
	var bones_mult: float = get_total_bones_multiplier()
	if era != null:
		var bonus_bones: float = era.layer_break_bonus_bones * bones_mult
		var bonus_minerals: float = maxf(era.layer_break_bonus_minerals, era.mineral_amount if era.mineral_chance > 0.0 else 0.0)
		if bonus_bones > 0.0:
			add_resource(RES_BONES, bonus_bones)
		if bonus_minerals > 0.0:
			add_resource(RES_MINERALS, bonus_minerals)
			Events.loot_dropped.emit(RES_MINERALS, bonus_minerals, world_position)
		if bonus_bones > 0.0 or bonus_minerals > 0.0:
			Events.layer_resources_extracted.emit(current_era_index, bonus_bones, bonus_minerals)

		var break_frag_base: float = balance.layer_break_bonus_fragment_chance if balance != null else 0.35
		var break_frag_p: float = clampf(break_frag_base * get_multiplier(STAT_FRAGMENT_CHANCE) * get_collector_drop_multiplier(), 0.0, 0.95)
		if randf() < break_frag_p:
			var bonus_dino: DinoData = era.pick_random_fragment()
			if bonus_dino != null:
				add_fragments(bonus_dino.id, 1)
				register_fossil_found(bonus_dino.id)
				Events.fragment_dropped.emit(bonus_dino.id, world_position)

	depth += 1
	max_depth_ever = maxi(max_depth_ever, depth)
	# Bônus de rochas para reconstrução do acampamento ao quebrar uma camada inteira.
	var bonus_rocks: float = roundf((5.0 + float(depth) * 3.0) * maxf(1.0, get_multiplier(STAT_BONES_MULT)))
	add_resource(RES_ROCKS, bonus_rocks)
	Events.layer_broken.emit(current_era_index, current_layer_index, depth)

	current_layer_index += 1
	var is_last_era: bool = current_era_index >= eras.size() - 1
	if era != null and current_layer_index >= era.layers_count and not is_last_era:
		current_era_index += 1
		current_layer_index = 0
		_dig_roll_accum = 0.0
		Events.era_changed.emit(current_era_index)
		_update_color_progress()
	_setup_layer()


## Recompensa ao quebrar um veio especial na rocha (GDD §3).
func crack_rock_vein(world_position: Vector2 = Vector2.ZERO) -> void:
	var era: EraData = get_current_era()
	var bpd: float = era.bones_per_damage if era != null else 1.0
	var click_mult: float = balance.vein_click_multiplier if balance != null else 10.0
	var bps_sec: float = balance.vein_bps_seconds if balance != null else 3.5
	var min_mult: float = balance.vein_mineral_multiplier if balance != null else 2.0
	var frag_p: float = balance.vein_fragment_chance if balance != null else 0.50
	var bonus_bones: float = get_click_damage() * click_mult * bpd * get_total_bones_multiplier() + get_bones_per_second() * bps_sec
	var bonus_minerals: float = min_mult * (era.mineral_amount if era != null else 1.0)
	add_resource(RES_BONES, bonus_bones)
	add_resource(RES_MINERALS, bonus_minerals)
	var dropped_dino: StringName = &""
	if era != null and randf() < frag_p:
		var dino: DinoData = era.pick_random_fragment()
		if dino != null:
			add_fragments(dino.id, 1)
			dropped_dino = dino.id
			register_fossil_found(dino.id)
			Events.fragment_dropped.emit(dino.id, world_position)
	Events.loot_dropped.emit(RES_BONES, bonus_bones, world_position)
	Events.loot_dropped.emit(RES_MINERALS, bonus_minerals, world_position)
	Events.vein_cracked.emit(bonus_bones, bonus_minerals, dropped_dino)


func _on_dig_hit(damage: float, world_position: Vector2, _is_crit: bool) -> void:
	apply_dig_damage(damage, world_position)


#region Superfície: Rocha Laranja & Escombros
func _on_orange_rock_hit(damage: float, world_position: Vector2) -> void:
	if orange_rock_broken or damage <= 0.0:
		return
	var effective: float = minf(damage, orange_rock_hp)
	orange_rock_hp = maxf(orange_rock_hp - effective, 0.0)
	add_resource(RES_ROCKS, 1.0)
	Events.loot_dropped.emit(RES_ROCKS, 1.0, world_position)
	Events.orange_rock_hp_changed.emit(orange_rock_hp, ORANGE_ROCK_MAX_HP)

	if orange_rock_hp <= 0.0:
		orange_rock_broken = true
		# Ao quebrar a Rocha Laranja, nasce o 1º Dinossauro (protagonista)!
		if get_dino_count(&"compsognathus") == 0:
			dino_counts[&"compsognathus"] = 1
			discovered_dinos[&"compsognathus"] = true
			Events.dino_unlocked.emit(&"compsognathus")
			Events.dino_count_changed.emit(&"compsognathus", 1)
			_update_color_progress()
		Events.orange_rock_broken.emit()
		Events.notification_requested.emit("🦖 A Rocha Laranja se partiu! Seu Dinossauro despertou!", null)


func get_rubble_level(rubble_id: StringName) -> int:
	return rubble_levels.get(rubble_id, 0)


func get_rubble_cost(rubble_id: StringName) -> float:
	if not RUBBLE_DEFS.has(rubble_id):
		return 0.0
	var def: Dictionary = RUBBLE_DEFS[rubble_id]
	var lvl: int = get_rubble_level(rubble_id)
	return roundf(float(def["base_cost"]) * pow(float(def["cost_growth"]), float(lvl)))


func can_rebuild_rubble(rubble_id: StringName) -> bool:
	if not RUBBLE_DEFS.has(rubble_id):
		return false
	return can_afford(RES_ROCKS, get_rubble_cost(rubble_id))


func rebuild_rubble(rubble_id: StringName) -> bool:
	if not can_rebuild_rubble(rubble_id):
		return false
	var cost: float = get_rubble_cost(rubble_id)
	if not spend(RES_ROCKS, cost):
		return false
	var new_lvl: int = get_rubble_level(rubble_id) + 1
	rubble_levels[rubble_id] = new_lvl
	recalculate_stats()
	_update_color_progress()
	Events.rubble_rebuilt.emit(rubble_id, new_lvl)
	var def: Dictionary = RUBBLE_DEFS[rubble_id]
	Events.notification_requested.emit("🏗️ %s reconstruída (Nv. %d)!" % [String(def["title"]), new_lvl], null)
	return true


func _on_rubble_rebuild_requested(rubble_id: StringName) -> void:
	rebuild_rubble(rubble_id)
#endregion
#endregion


#region Meteoro & Prestígio
func _setup_meteor() -> void:
	var first_run: int = balance.meteor_first_run if balance != null else METEOR_FIRST_RUN
	var base_time: float = balance.base_meteor_time if balance != null else BASE_METEOR_TIME
	meteor_active = run_number >= first_run
	meteor_total_time = get_stat(STAT_METEOR_TIME, base_time)
	meteor_time_left = meteor_total_time
	_set_danger_level(0.0)
	Events.meteor_timer_changed.emit(meteor_time_left, meteor_total_time)


func _tick_meteor(delta: float) -> void:
	if not meteor_active or is_prestige_modal_open:
		return
	meteor_time_left = maxf(meteor_time_left - delta, 0.0)
	Events.meteor_timer_changed.emit(meteor_time_left, meteor_total_time)
	_set_danger_level(1.0 - meteor_time_left / maxf(meteor_total_time, 0.001))
	if meteor_time_left <= 0.0:
		trigger_meteor_impact()


func _on_prestige_modal_visibility_changed(is_open: bool) -> void:
	is_prestige_modal_open = is_open


func can_trigger_early_impact() -> bool:
	if is_impacting:
		return false
	var min_depth: int = balance.early_impact_min_depth if balance != null else 3
	var min_amber: float = balance.early_impact_min_amber if balance != null else 1.0
	return depth >= min_depth and calculate_amber_reward() >= min_amber


func _on_meteor_early_impact_requested() -> void:
	if not can_trigger_early_impact():
		var min_depth: int = balance.early_impact_min_depth if balance != null else 3
		Events.notification_requested.emit(
			"Escave pelo menos %dm e acumule +1 Âmbar para antecipar o impacto." % min_depth,
			null
		)
		return
	trigger_meteor_impact()


## Inicia o impacto (timer zerado ou antecipado pelo jogador).
## A cena do meteoro toca a cinemática e depois chama perform_prestige().
func trigger_meteor_impact() -> void:
	if is_impacting:
		return
	is_impacting = true
	meteor_active = false
	Events.meteor_impact_started.emit()


## Prévia do âmbar que o jogador receberia agora (para a UI "Antecipar impacto").
## shield_ratio: 0..1 — quanto do impacto foi absorvido pelas defesas.
func calculate_amber_reward(shield_ratio: float = -1.0) -> float:
	if run_total_bones <= 0.0 and depth <= 0:
		return 0.0
	if shield_ratio < 0.0:
		shield_ratio = get_shield_ratio()
	var divisor: float = balance.amber_bones_divisor if balance != null else 2700.0
	var exponent: float = balance.amber_bones_exponent if balance != null else 0.088
	var depth_weight: float = balance.amber_depth_per_layer if balance != null else 0.042
	var layer_weight: float = balance.amber_layer_progress_weight if balance != null else 0.05
	var shield_weight: float = balance.amber_shield_bonus if balance != null else 0.75
	var from_bones: float = pow(maxf(run_total_bones / maxf(divisor, 1.0), 0.0), exponent)
	var layer_progress: float = clampf(1.0 - (layer_hp / maxf(layer_max_hp, 1.0)), 0.0, 1.0)
	var depth_factor: float = 1.0 + float(depth) * depth_weight + layer_progress * layer_weight
	var survival_factor: float = 1.0 + clampf(shield_ratio, 0.0, 1.0) * shield_weight
	return floorf(from_bones * depth_factor * survival_factor * get_multiplier(STAT_AMBER_MULT))


## Proteção atual contra o meteoro (upgrades de defesa + dinos DEFENSE).
func get_shield_ratio() -> float:
	var shield: float = get_stat(STAT_METEOR_SHIELD, 0.0)
	for dino_id: Variant in dino_counts:
		var data: DinoData = get_dino(dino_id)
		if data != null and data.meteor_damage_reduction > 0.0:
			shield += data.meteor_damage_reduction * float(get_dino_count(dino_id))
	return clampf(shield, 0.0, 1.0)


## Conclui o prestígio: concede âmbar e começa uma nova run.
func perform_prestige(shield_ratio: float = -1.0) -> float:
	var amber: float = calculate_amber_reward(shield_ratio)
	add_resource(RES_AMBER, amber)
	total_amber_earned += amber
	var finished_run: int = run_number
	run_number += 1
	_reset_run_state()
	Events.prestige_completed.emit(amber, finished_run)
	Events.run_started.emit(run_number)
	return amber


func _set_danger_level(level: float) -> void:
	level = clampf(level, 0.0, 1.0)
	if is_equal_approx(level, danger_level):
		return
	danger_level = level
	Events.danger_level_changed.emit(danger_level)


## Progresso rumo à condição de vitória do Projeto Arca (GDD §7).
func get_ark_progress() -> Dictionary:
	var req_lvl: int = balance.ark_required_level if balance != null else ARK_REQUIRED_LEVEL
	var req_shield: float = balance.ark_required_shield if balance != null else ARK_REQUIRED_SHIELD
	var req_era: int = balance.ark_required_era if balance != null else ARK_REQUIRED_ERA
	var ark_lvl: int = get_upgrade_level(&"amber_ark_project")
	var shield: float = get_shield_ratio()
	var ready: bool = ark_lvl >= req_lvl and shield >= req_shield and current_era_index >= req_era
	return {
		"ark_level": ark_lvl,
		"ark_required": req_lvl,
		"shield_ratio": shield,
		"shield_required": req_shield,
		"era_index": current_era_index,
		"era_required": req_era,
		"ready": ready,
		"completed": ark_completed,
	}


func can_activate_ark_victory() -> bool:
	var prog: Dictionary = get_ark_progress()
	return bool(prog["ready"])


func activate_ark_victory() -> bool:
	if not can_activate_ark_victory():
		return false
	var first_time: bool = not ark_completed
	ark_completed = true
	meteor_time_left = meteor_total_time
	_set_danger_level(0.0)
	Events.meteor_timer_changed.emit(meteor_time_left, meteor_total_time)
	if first_time:
		var bonus_amber: float = balance.ark_first_completion_amber if balance != null else 25.0
		add_resource(RES_AMBER, bonus_amber)
		total_amber_earned += bonus_amber
	Events.ark_victory_achieved.emit(run_number, total_amber_earned)
	return true
#endregion


#region Progressão cromática
## 0 = cinza/terroso, 1 = colorido. Baseado em espécies descobertas e eras alcançadas.
func _update_color_progress() -> void:
	var total_steps: int = maxi(dinos_db.size() + eras.size(), 1)
	var steps: int = discovered_dinos.size() + current_era_index
	var progress: float = clampf(float(steps) / float(total_steps), 0.0, 1.0)
	if is_equal_approx(progress, color_progress):
		return
	color_progress = progress
	Events.color_progress_changed.emit(color_progress)
#endregion


#region Renda passiva / offline
var _auto_dig_accum: float = 0.0


func _tick_passive_income(delta: float) -> void:
	var dna_rate: float = get_dna_per_second()
	if dna_rate > 0.0:
		add_resource(RES_DNA, dna_rate * delta)
	var passive_dps: float = get_auto_dps() + get_acid_dot_dps()
	if passive_dps > 0.0:
		_auto_dig_accum += delta
		if _auto_dig_accum >= 0.5:
			var step: float = _auto_dig_accum
			_auto_dig_accum = 0.0
			apply_dig_damage(passive_dps * step, Vector2.ZERO)


## Eficiência do ganho offline em relação ao ritmo passivo ativo (base ~20%, teto 50%).
func get_offline_efficiency() -> float:
	var base_eff: float = balance.offline_base_efficiency if balance != null else 0.20
	var max_eff: float = balance.offline_max_efficiency if balance != null else 0.50
	return clampf(base_eff * get_multiplier(STAT_OFFLINE_MULT), 0.0, max_eff)


## Aplica ganhos offline de forma simplificada (sem simular camadas). Retorna os ganhos.
## O timer do meteoro NÃO corre offline.
func apply_offline_progress(seconds: float) -> Dictionary:
	var gains: Dictionary = {}
	if seconds <= 0.0:
		return gains
	var max_hours: float = balance.offline_max_hours if balance != null else 8.0
	var capped_seconds: float = minf(seconds, max_hours * 3600.0)
	var eff: float = get_offline_efficiency()
	var bones: float = get_bones_per_second() * capped_seconds * eff
	var dna: float = get_dna_per_second() * capped_seconds * eff
	if bones > 0.0:
		add_resource(RES_BONES, bones)
		gains[RES_BONES] = bones
	if dna > 0.0:
		add_resource(RES_DNA, dna)
		gains[RES_DNA] = dna
	return gains
#endregion


#region Museu de Fósseis & Golpe Preciso
## Sorteia a raridade do fóssil (0=Comum .. 3=Lendário) segundo os pesos em `balance.tres`.
func roll_fossil_rarity() -> int:
	var weights: Array[float] = [55.0, 27.0, 13.0, 5.0]
	if balance != null and not balance.fossil_rarity_weights.is_empty():
		weights = balance.fossil_rarity_weights
	var total: float = 0.0
	for w: float in weights:
		total += w
	var pick: float = randf() * maxf(total, 1.0)
	var accum: float = 0.0
	for i: int in range(weights.size()):
		accum += weights[i]
		if pick <= accum:
			return i
	return 0


## Registra um fóssil no catálogo permanente do Museu e emite `Events.fossil_found`.
func register_fossil_found(dino_id: StringName, forced_rarity: int = -1) -> Dictionary:
	var rarity: int = clampi(forced_rarity, 0, 3) if forced_rarity >= 0 else roll_fossil_rarity()
	total_fossils_evaluated += 1
	if rarity >= 3:
		total_legendary_fossils += 1

	var data: DinoData = get_dino(dino_id)
	var dname: String = data.display_name if data != null else String(dino_id)
	var fallback_part: String = data.get_fossil_display_name() if data != null else "Fragmento Fóssil"
	var parts_raw: Variant = FOSSIL_PART_POOLS.get(dino_id, [fallback_part])
	var parts: Array = parts_raw as Array if parts_raw is Array and not (parts_raw as Array).is_empty() else [fallback_part]
	var part_name: String = String(parts[randi() % parts.size()])

	var rec: Dictionary = fossil_catalog.get(dino_id, {}) as Dictionary
	if rec.is_empty():
		var empty_parts: Array[String] = []
		rec = {
			"count": 0,
			"best_rarity": 0,
			"parts": empty_parts,
		}
	rec["count"] = int(rec.get("count", 0)) + 1
	rec["best_rarity"] = maxi(int(rec.get("best_rarity", 0)), rarity)
	var found_parts: Array[String] = []
	var existing_parts: Variant = rec.get("parts", [])
	if existing_parts is Array:
		for p: Variant in (existing_parts as Array):
			found_parts.append(String(p))
	if not found_parts.has(part_name):
		found_parts.append(part_name)
	rec["parts"] = found_parts
	fossil_catalog[dino_id] = rec

	var era: EraData = get_current_era()
	var era_name: String = era.display_name if era != null else "Crosta"
	last_evaluated_fossil = {
		"dino_id": dino_id,
		"display_name": dname,
		"rarity": rarity,
		"part_name": part_name,
		"record_number": total_fossils_evaluated,
		"depth": depth,
		"era_name": era_name,
	}
	Events.fossil_found.emit(dino_id, rarity)
	return last_evaluated_fossil


## Retorna o multiplicador de clique para um resultado do sismógrafo Golpe Preciso.
func get_precise_strike_multiplier(result: StringName) -> float:
	if result == &"perfect":
		return balance.precise_strike_perfect_mult if balance != null else 8.0
	if result == &"good":
		return balance.precise_strike_good_mult if balance != null else 3.5
	return 0.0


## Resolve o Golpe Preciso aplicando o dano bônus no GameState e emitindo `Events.precise_strike_resolved`.
func resolve_precise_strike(result: StringName, world_position: Vector2 = Vector2.ZERO) -> float:
	var mult: float = get_precise_strike_multiplier(result)
	var bonus: float = maxf(get_click_damage(), 1.0) * mult if mult > 0.0 else 0.0
	if bonus > 0.0:
		apply_dig_damage(bonus, world_position)
	Events.precise_strike_resolved.emit(result, bonus)
	return bonus
#endregion


#region Serialização (usada pelo SaveManager)
func to_save_dict() -> Dictionary:
	return {
		"resources": _sn_dict_to_json(resources),
		"fragments": _sn_dict_to_json(fragments),
		"dino_counts": _sn_dict_to_json(dino_counts),
		"upgrade_levels": _sn_dict_to_json(upgrade_levels),
		"rubble_levels": _sn_dict_to_json(rubble_levels),
		"orange_rock_hp": orange_rock_hp,
		"orange_rock_broken": orange_rock_broken,
		"permanent_upgrade_levels": _sn_dict_to_json(permanent_upgrade_levels),
		"discovered_dinos": discovered_dinos.keys().map(func(k: StringName) -> String: return String(k)),
		"current_era_index": current_era_index,
		"current_layer_index": current_layer_index,
		"layer_hp": layer_hp,
		"depth": depth,
		"run_total_bones": run_total_bones,
		"meteor_time_left": meteor_time_left,
		"run_number": run_number,
		"max_depth_ever": max_depth_ever,
		"lifetime_bones": lifetime_bones,
		"total_amber_earned": total_amber_earned,
		"buy_multiplier": buy_multiplier,
		"ark_completed": ark_completed,
		"fossil_catalog": _fossil_catalog_to_json(fossil_catalog),
		"total_fossils_evaluated": total_fossils_evaluated,
		"total_legendary_fossils": total_legendary_fossils,
	}


func load_save_dict(data: Dictionary) -> void:
	last_evaluated_fossil.clear()
	resources.clear()
	for res_id: StringName in ALL_RESOURCES:
		resources[res_id] = 0.0
	for key: Variant in data.get("resources", {}):
		resources[StringName(key)] = float(data["resources"][key])

	fragments.clear()
	_json_to_int_dict(data.get("fragments", {}), fragments)
	dino_counts.clear()
	_json_to_int_dict(data.get("dino_counts", {}), dino_counts)
	upgrade_levels.clear()
	_json_to_int_dict(data.get("upgrade_levels", {}), upgrade_levels)
	rubble_levels.clear()
	_json_to_int_dict(data.get("rubble_levels", {}), rubble_levels)
	orange_rock_broken = bool(data.get("orange_rock_broken", false))
	orange_rock_hp = 0.0 if orange_rock_broken else clampf(float(data.get("orange_rock_hp", ORANGE_ROCK_MAX_HP)), 0.01, ORANGE_ROCK_MAX_HP)
	permanent_upgrade_levels.clear()
	_json_to_int_dict(data.get("permanent_upgrade_levels", {}), permanent_upgrade_levels)

	discovered_dinos.clear()
	for dino_id: Variant in data.get("discovered_dinos", []):
		discovered_dinos[StringName(str(dino_id))] = true

	_json_to_fossil_catalog(data.get("fossil_catalog", {}))
	total_fossils_evaluated = maxi(int(data.get("total_fossils_evaluated", 0)), 0)
	total_legendary_fossils = maxi(int(data.get("total_legendary_fossils", 0)), 0)

	run_number = int(data.get("run_number", 1))
	max_depth_ever = int(data.get("max_depth_ever", 0))
	lifetime_bones = float(data.get("lifetime_bones", 0.0))
	total_amber_earned = float(data.get("total_amber_earned", 0.0))
	run_total_bones = float(data.get("run_total_bones", 0.0))
	depth = int(data.get("depth", 0))
	current_era_index = clampi(int(data.get("current_era_index", 0)), 0, maxi(eras.size() - 1, 0))
	current_layer_index = int(data.get("current_layer_index", 0))
	var saved_buy: int = int(data.get("buy_multiplier", 1))
	buy_multiplier = saved_buy if saved_buy in BUY_MULTIPLIERS else 1
	ark_completed = bool(data.get("ark_completed", false))
	is_impacting = false

	recalculate_stats()
	_setup_layer()
	layer_hp = clampf(float(data.get("layer_hp", layer_max_hp)), 0.01, layer_max_hp)
	_setup_meteor()
	meteor_time_left = clampf(float(data.get("meteor_time_left", meteor_total_time)), 0.0, meteor_total_time)
	if meteor_active and meteor_time_left <= 0.0:
		push_warning("[GameState] Save inconsistente detectado (meteor_active com meteor_time_left <= 0); resetando run sem reaplicar prestígio.")
		_reset_run_state()
		return
	_update_color_progress()
	_emit_full_refresh()


static func _sn_dict_to_json(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in source:
		out[String(key)] = source[key]
	return out


static func _json_to_int_dict(source: Dictionary, target: Dictionary) -> void:
	for key: Variant in source:
		target[StringName(str(key))] = int(source[key])


static func _fossil_catalog_to_json(source: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for key: Variant in source:
		var rec_val: Variant = source[key]
		if not rec_val is Dictionary:
			continue
		var rec: Dictionary = rec_val as Dictionary
		var parts_out: Array[String] = []
		var raw_parts: Variant = rec.get("parts", [])
		if raw_parts is Array:
			for p: Variant in (raw_parts as Array):
				parts_out.append(String(p))
		out[String(key)] = {
			"count": int(rec.get("count", 0)),
			"best_rarity": clampi(int(rec.get("best_rarity", 0)), 0, 3),
			"parts": parts_out,
		}
	return out


func _json_to_fossil_catalog(raw: Variant) -> void:
	fossil_catalog.clear()
	if not raw is Dictionary:
		return
	var dict_raw: Dictionary = raw as Dictionary
	for key: Variant in dict_raw:
		var rec_val: Variant = dict_raw[key]
		if not rec_val is Dictionary:
			continue
		var rec: Dictionary = rec_val as Dictionary
		var parts_in: Array[String] = []
		var raw_parts: Variant = rec.get("parts", [])
		if raw_parts is Array:
			for p: Variant in (raw_parts as Array):
				parts_in.append(String(p))
		fossil_catalog[StringName(str(key))] = {
			"count": maxi(int(rec.get("count", 0)), 0),
			"best_rarity": clampi(int(rec.get("best_rarity", 0)), 0, 3),
			"parts": parts_in,
		}
#endregion


#region Carregamento dos bancos de dados
func _load_databases() -> void:
	var loaded_balance: BalanceConfig = load(BALANCE_PATH) as BalanceConfig
	if loaded_balance != null:
		balance = loaded_balance
	else:
		balance = BalanceConfig.new()

	dinos_db.clear()
	upgrades_db.clear()
	eras.clear()

	for res: Resource in _load_resources_recursive(DINOS_DIR):
		var dino: DinoData = res as DinoData
		if dino != null:
			_register_unique(dinos_db, dino.id, dino, res.resource_path)

	for res: Resource in _load_resources_recursive(UPGRADES_DIR):
		var upgrade: UpgradeData = res as UpgradeData
		if upgrade != null:
			_register_unique(upgrades_db, upgrade.id, upgrade, res.resource_path)

	for res: Resource in _load_resources_recursive(ERAS_DIR):
		var era: EraData = res as EraData
		if era != null:
			eras.append(era)
	eras.sort_custom(func(a: EraData, b: EraData) -> bool: return a.index < b.index)

	print("[GameState] Carregados: %d dinos, %d upgrades, %d eras" % [dinos_db.size(), upgrades_db.size(), eras.size()])


static func _register_unique(db: Dictionary, id: StringName, res: Resource, path: String) -> void:
	if id == &"":
		push_error("[GameState] Resource sem id: %s" % path)
		return
	if db.has(id):
		push_error("[GameState] ID duplicado '%s' em %s" % [id, path])
		return
	db[id] = res


## Carrega todos os .tres/.res de uma pasta (e subpastas). Compatível com builds exportados (.remap).
static func _load_resources_recursive(dir_path: String) -> Array[Resource]:
	var result: Array[Resource] = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return result
	for sub: String in dir.get_directories():
		result.append_array(_load_resources_recursive(dir_path.path_join(sub)))
	for file: String in dir.get_files():
		var clean: String = file.trim_suffix(".remap")
		if not (clean.ends_with(".tres") or clean.ends_with(".res")):
			continue
		var res: Resource = load(dir_path.path_join(clean))
		if res != null:
			result.append(res)
	return result
#endregion


#region Formatação (helpers estáticos para a UI)
const NUMBER_SUFFIXES: PackedStringArray = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]


## 999 → "999" | 1234 → "1.23K" | 45_600_000 → "45.6M" | 1e40 → "1.00e40"
static func format_number(value: float) -> String:
	if is_nan(value):
		return "NaN"
	if is_inf(value):
		return "∞"
	var sign_str: String = "-" if value < 0.0 else ""
	var v: float = absf(value)
	if v < 1000.0:
		if v < 10.0 and not is_equal_approx(v, roundf(v)):
			return sign_str + "%.1f" % v
		return sign_str + str(floori(v))
	var tier: int = floori(log(v) / log(1000.0))
	if tier >= NUMBER_SUFFIXES.size():
		var exponent: int = floori(log(v) / log(10.0))
		return sign_str + "%.2fe%d" % [v / pow(10.0, float(exponent)), exponent]
	var scaled: float = v / pow(1000.0, float(tier))
	# Corrige casos como 999.999K → "1000.00K"
	if scaled >= 999.995 and tier + 1 < NUMBER_SUFFIXES.size():
		tier += 1
		scaled /= 1000.0
	var fmt: String = "%.2f" if scaled < 10.0 else ("%.1f" if scaled < 100.0 else "%.0f")
	return sign_str + (fmt % scaled) + NUMBER_SUFFIXES[tier]


## 125.4 → "02:05" | 3725 → "1:02:05"
static func format_time(seconds: float) -> String:
	var total: int = maxi(ceili(seconds), 0)
	var h: int = total / 3600
	var m: int = (total % 3600) / 60
	var s: int = total % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%02d:%02d" % [m, s]
#endregion
