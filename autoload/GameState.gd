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
const RES_FISH: StringName = &"fish"
const RES_FEATHERS: StringName = &"feathers"
const RES_SCIENCE: StringName = &"science"
const RES_RAW_FOSSILS: StringName = &"raw_fossils"
const RES_METAL: StringName = &"metal"
const RES_SCALES: StringName = &"scales"
const RES_BEAKS: StringName = &"beaks"
const RES_WOOD: StringName = &"wood"
const RES_BERRIES: StringName = &"berries"
const RES_RESIN: StringName = &"resin"
const RES_ICE: StringName = &"ice"
const RES_CRYSTALS: StringName = &"crystals"
const RESOURCE_NAMES: Dictionary = {
	RES_BONES: "ossos", RES_ROCKS: "rochas", RES_MINERALS: "minérios", RES_DNA: "DNA",
	RES_AMBER: "âmbar", RES_FISH: "peixes", RES_FEATHERS: "penas", RES_SCIENCE: "ciência",
	RES_RAW_FOSSILS: "fósseis brutos", RES_METAL: "metal", RES_SCALES: "escamas", RES_BEAKS: "bicos de ave",
	RES_WOOD: "madeira", RES_BERRIES: "frutas", RES_RESIN: "resina", RES_ICE: "gelo", RES_CRYSTALS: "cristais",
}
## Recursos zerados a cada run (âmbar é permanente).
const RUN_RESOURCES: Array[StringName] = [
	RES_BONES, RES_ROCKS, RES_MINERALS, RES_DNA, RES_FISH, RES_FEATHERS, RES_SCIENCE,
	RES_RAW_FOSSILS, RES_METAL, RES_SCALES, RES_BEAKS,
	RES_WOOD, RES_BERRIES, RES_RESIN, RES_ICE, RES_CRYSTALS,
]
const ALL_RESOURCES: Array[StringName] = [
	RES_BONES, RES_ROCKS, RES_MINERALS, RES_DNA, RES_AMBER, RES_FISH, RES_FEATHERS, RES_SCIENCE,
	RES_RAW_FOSSILS, RES_METAL, RES_SCALES, RES_BEAKS,
	RES_WOOD, RES_BERRIES, RES_RESIN, RES_ICE, RES_CRYSTALS,
]

## Biomas da Superfície (esquerda -> centro -> direita).
const BIOME_FOREST: StringName = &"forest"
const BIOME_AMBER: StringName = &"amber_basin"
const BIOME_SNOW: StringName = &"snow"
const BIOME_ORDER: Array[StringName] = [BIOME_FOREST, BIOME_AMBER, BIOME_SNOW]
const BIOME_NAMES: Dictionary = {
	BIOME_FOREST: "Floresta Ancestral",
	BIOME_AMBER: "Bacia do Âmbar",
	BIOME_SNOW: "Cordilheira Nevada",
}

## Vida inicial da Rocha Laranja na Superfície.
const ORANGE_ROCK_MAX_HP: float = 10.0
const FIELD_GEAR_YIELD_BONUS: float = 0.25
const HERO_BASE_FARM_RATE: float = 0.20
const HERO_ASSIST_BONUS_MULT: float = 0.35
## Probabilidade base de encontrar um fóssil bruto por coleta (1 em 1000).
const BASE_RAW_FOSSIL_CHANCE: float = 0.001
## Tempo base (em segundos) para limpar um fóssil bruto na Universidade.
const BASE_FOSSIL_CLEAN_SECONDS: float = 40.0
## Quantidade de fósseis limpos necessários para reviver o dinossauro especialista de cada estrutura.
const STATION_REVIVE_FOSSILS_REQUIRED: int = 10
const STATION_FOSSIL_FLASH_DURATION: float = 2.8

## Estruturas reconstruíveis nos 3 biomas da Superfície.
const RUBBLE_ORDER: Array[StringName] = [
	&"rubble_forge",
	&"rubble_nest",
	&"rubble_silo",
	&"rubble_bunker",
	&"forest_grove",
	&"forest_sanctuary",
	&"snow_glacier",
	&"snow_observatory",
]
const RUBBLE_DEFS: Dictionary = {
	&"rubble_forge": {
		"title": "Pedreira do Casco",
		"biome": BIOME_AMBER,
		"worker": "Paquicefalossauro",
		"worker_desc": "Paquicefalossauro coleta Rochas automaticamente (+0.7/s base).",
		"build_resource": RES_ROCKS,
		"build_cost": 40.0,
		"expand_resource": RES_ROCKS,
		"base_cost": 90.0,
		"cost_growth": 2.35,
		"product": RES_ROCKS,
		"rate": 0.7,
		"worker_cost": 65.0,
		"gear": &"field_helmet",
		"category": UpgradeData.Category.TOOLS,
		"desc": "+15% de coleta manual por ampliação",
		"stat_id": &"manual_yield",
		"mult_per_level": 0.15,
		"color": Color(0.92, 0.52, 0.24),
		"fossils": [&"ankylosaurus", &"triceratops", &"trex"],
		"revive_dino": &"ankylosaurus",
		"revive_name": "Anquilossauro Minerador",
		"revive_cost": 450.0,
		"revive_mult": 2.5,
		"tier2_product": RES_METAL,
		"tier2_rate": 0.30,
	},
	&"rubble_nest": {
		"title": "Pesqueiro do Junco",
		"biome": BIOME_AMBER,
		"worker": "Bariônix",
		"worker_desc": "Bariônix pesca Peixes automaticamente (+0.65/s base).",
		"build_resource": RES_ROCKS,
		"build_cost": 120.0,
		"expand_resource": RES_ROCKS,
		"base_cost": 180.0,
		"cost_growth": 2.4,
		"product": RES_FISH,
		"rate": 0.65,
		"worker_cost": 90.0,
		"gear": &"field_fins",
		"category": UpgradeData.Category.DINOS,
		"desc": "+8% de produção global das estruturas por nível",
		"stat_id": &"station_yield",
		"mult_per_level": 0.08,
		"color": Color(0.52, 0.85, 0.38),
		"fossils": [&"dilophosaurus", &"brachiosaurus"],
		"revive_dino": &"dilophosaurus",
		"revive_name": "Dilofossauro Escamoso",
		"revive_cost": 550.0,
		"revive_mult": 2.5,
		"tier2_product": RES_SCALES,
		"tier2_rate": 0.28,
	},
	&"rubble_silo": {
		"title": "Torre dos Ventos",
		"biome": BIOME_AMBER,
		"worker": "Pterodáctilo",
		"worker_desc": "Pterodáctilo coleta Penas automaticamente (+0.55/s base).",
		"build_resource": RES_ROCKS,
		"build_cost": 420.0,
		"expand_resource": RES_ROCKS,
		"base_cost": 480.0,
		"cost_growth": 2.45,
		"product": RES_FEATHERS,
		"rate": 0.55,
		"worker_cost": 130.0,
		"gear": &"field_goggles",
		"category": UpgradeData.Category.MACHINES,
		"desc": "+18% de sorte de fósseis brutos por nível",
		"stat_id": &"fossil_luck",
		"mult_per_level": 0.18,
		"color": Color(0.42, 0.75, 0.92),
		"fossils": [&"velociraptor", &"pterodactyl", &"compsognathus"],
		"revive_dino": &"velociraptor",
		"revive_name": "Velociraptor Caçador",
		"revive_cost": 750.0,
		"revive_mult": 2.5,
		"tier2_product": RES_BEAKS,
		"tier2_rate": 0.25,
	},
	&"rubble_bunker": {
		"title": "Universidade da Arca",
		"biome": BIOME_AMBER,
		"worker": "Troodonte",
		"worker_desc": "Troodonte produz Ciência automaticamente (+0.45/s base) e acelera a limpeza de fósseis.",
		"build_resource": RES_ROCKS,
		"build_cost": 1100.0,
		"expand_resource": RES_ROCKS,
		"base_cost": 1200.0,
		"cost_growth": 2.5,
		"product": RES_SCIENCE,
		"rate": 0.45,
		"worker_cost": 170.0,
		"gear": &"field_lens",
		"category": UpgradeData.Category.DEFENSE,
		"desc": "+6% de Escudo Anti-Meteoro por nível",
		"stat_id": &"meteor_shield",
		"add_per_level": 0.06,
		"color": Color(0.75, 0.65, 0.88),
		"fossils": [&"brachiosaurus", &"compsognathus", &"velociraptor", &"triceratops", &"trex", &"pterodactyl", &"ankylosaurus", &"dilophosaurus"],
		"revive_dino": &"brachiosaurus",
		"revive_name": "Braquiossauro Decano",
		"revive_cost": 950.0,
		"revive_mult": 2.5,
		"tier2_product": RES_SCIENCE,
		"tier2_rate": 1.2,
	},
	&"forest_grove": {
		"title": "Bosque das Sequoias",
		"biome": BIOME_FOREST,
		"worker": "Tricerátopo",
		"worker_desc": "Tricerátopo colhe Madeira ancestral automaticamente (+0.85/s base).",
		"build_resource": RES_METAL,
		"build_cost": 15.0,
		"expand_resource": RES_WOOD,
		"base_cost": 220.0,
		"cost_growth": 2.4,
		"product": RES_WOOD,
		"rate": 0.85,
		"worker_cost": 120.0,
		"gear": &"field_timber_harness",
		"category": UpgradeData.Category.FOREST_GROVE,
		"desc": "+12% de produção global das estruturas por nível",
		"stat_id": &"station_yield",
		"mult_per_level": 0.12,
		"color": Color(0.32, 0.72, 0.36),
		"fossils": [&"triceratops", &"ankylosaurus"],
		"revive_dino": &"triceratops",
		"revive_name": "Tricerátopo Alfa",
		"revive_cost": 900.0,
		"revive_mult": 2.5,
		"tier2_product": RES_RESIN,
		"tier2_rate": 0.30,
	},
	&"forest_sanctuary": {
		"title": "Clareira das Samambaias",
		"biome": BIOME_FOREST,
		"worker": "Estegossauro",
		"worker_desc": "Estegossauro colhe Frutas silvestres automaticamente (+0.80/s base).",
		"build_resource": RES_SCALES,
		"build_cost": 18.0,
		"expand_resource": RES_BERRIES,
		"base_cost": 280.0,
		"cost_growth": 2.45,
		"product": RES_BERRIES,
		"rate": 0.80,
		"worker_cost": 150.0,
		"gear": &"field_botanic_basket",
		"category": UpgradeData.Category.FOREST_SANCTUARY,
		"desc": "+15% de recursos raros Tier-2 por nível",
		"stat_id": &"tier2_yield",
		"mult_per_level": 0.15,
		"color": Color(0.86, 0.42, 0.48),
		"fossils": [&"trex", &"dilophosaurus"],
		"revive_dino": &"trex",
		"revive_name": "T-Rex Guardião",
		"revive_cost": 1200.0,
		"revive_mult": 2.5,
		"tier2_product": RES_BERRIES,
		"tier2_rate": 1.5,
	},
	&"snow_glacier": {
		"title": "Geleira Cristalina",
		"biome": BIOME_SNOW,
		"worker": "Criolofossauro",
		"worker_desc": "Criolofossauro extrai Gelo glacial automaticamente (+0.75/s base).",
		"build_resource": RES_BEAKS,
		"build_cost": 18.0,
		"expand_resource": RES_ICE,
		"base_cost": 340.0,
		"cost_growth": 2.45,
		"product": RES_ICE,
		"rate": 0.75,
		"worker_cost": 180.0,
		"gear": &"field_ice_crampons",
		"category": UpgradeData.Category.SNOW_GLACIER,
		"desc": "+22% de sorte de fósseis brutos por nível",
		"stat_id": &"fossil_luck",
		"mult_per_level": 0.22,
		"color": Color(0.55, 0.88, 0.98),
		"fossils": [&"pterodactyl", &"velociraptor"],
		"revive_dino": &"pterodactyl",
		"revive_name": "Pterodáctilo Polar",
		"revive_cost": 1400.0,
		"revive_mult": 2.5,
		"tier2_product": RES_CRYSTALS,
		"tier2_rate": 0.28,
	},
	&"snow_observatory": {
		"title": "Santuário Ártico",
		"biome": BIOME_SNOW,
		"worker": "Paquirrinossauro",
		"worker_desc": "Paquirrinossauro lapida Cristais árticos automaticamente (+0.65/s base).",
		"build_resource": RES_RESIN,
		"build_cost": 25.0,
		"expand_resource": RES_CRYSTALS,
		"base_cost": 420.0,
		"cost_growth": 2.5,
		"product": RES_CRYSTALS,
		"rate": 0.65,
		"worker_cost": 220.0,
		"gear": &"field_aurora_prism",
		"category": UpgradeData.Category.SNOW_OBSERVATORY,
		"desc": "+12% de recompensa de Âmbar por nível",
		"stat_id": &"amber_mult",
		"mult_per_level": 0.12,
		"color": Color(0.68, 0.76, 1.0),
		"fossils": [&"compsognathus", &"brachiosaurus"],
		"revive_dino": &"compsognathus",
		"revive_name": "Compsognato Ártico",
		"revive_cost": 1800.0,
		"revive_mult": 3.0,
		"tier2_product": RES_CRYSTALS,
		"tier2_rate": 1.8,
	},
}

## IDs de estatísticas afetadas por upgrades (UpgradeData.stat_id).
const BalanceConfig = preload("res://data/BalanceConfig.gd")

const STAT_MANUAL_YIELD: StringName = &"manual_yield"        ## Multiplicador da coleta manual [E]
const STAT_STATION_YIELD: StringName = &"station_yield"      ## Multiplicador global da produção automática das estruturas
const STAT_CLICK_DAMAGE: StringName = &"click_damage"
const STAT_CLICK_CRIT_CHANCE: StringName = &"click_crit_chance"
const STAT_DINO_DAMAGE: StringName = &"dino_damage"          ## Legado (escavação subterrânea)
const STAT_DINO_EVO_MULT: StringName = &"dino_evo_mult"      ## Legado (escavação subterrânea)
const STAT_BONES_MULT: StringName = &"bones_mult"
const STAT_PRESTIGE_BONES_MULT: StringName = &"prestige_bones_mult"
const STAT_MINERAL_CHANCE: StringName = &"mineral_chance"
const STAT_FRAGMENT_CHANCE: StringName = &"fragment_chance"
const STAT_DNA_MULT: StringName = &"dna_mult"
const STAT_METEOR_TIME: StringName = &"meteor_time"          ## Segundos extras (ADD)
const STAT_METEOR_SHIELD: StringName = &"meteor_shield"      ## 0..1 de proteção
const STAT_AMBER_MULT: StringName = &"amber_mult"
const STAT_OFFLINE_MULT: StringName = &"offline_mult"
const STAT_AUTO_DPS: StringName = &"auto_dps"                ## DPS passivo legado
const STAT_FOSSIL_LUCK: StringName = &"fossil_luck"
const STAT_CLEANING_SPEED: StringName = &"cleaning_speed"
const STAT_CLEAN_DOUBLE_CHANCE: StringName = &"clean_double_chance"
const STAT_TIER2_YIELD: StringName = &"tier2_yield"

## Valor de "Máx" no multiplicador de compra.
const BUY_MAX: int = -1
const BUY_MULTIPLIERS: Array[int] = [1, 10, 100, BUY_MAX]

## Timer base do meteoro (segundos) — fallback caso balance.tres ainda não tenha sido carregado.
const BASE_METEOR_TIME: float = 1200.0
## A partir de qual run o meteoro aparece (1 = desde a primeira).
const METEOR_FIRST_RUN: int = 1
## Requisitos do Projeto Arca (condição de vitória do GDD §7).
const ARK_REQUIRED_LEVEL: int = 5
const ARK_REQUIRED_SHIELD: float = 0.75
const ARK_REQUIRED_ERA: int = 3
const ARK_SITE_ID: StringName = &"ark"
const ARK_MODULE_HULL: StringName = &"hull_reinforcement"
const ARK_MODULES: Dictionary = {
	&"hull_reinforcement": {
		"title": "Reforço de Casco",
		"desc": "+40% Âmbar no impacto e +10% escudo permanente da Arca.",
		"costs": { &"rocks": 80.0, &"metal": 6.0 },
		"amber_bonus_mult": 0.40,
		"shield_bonus": 0.10,
	},
}
const QUARRY_STARTER_METAL_BURST: float = 3.0

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
var station_worker_unlocked: Dictionary = {}

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
var run_surface_progress: float = 0.0

var meteor_active: bool = false
var meteor_time_left: float = 0.0
var meteor_total_time: float = 0.0
var is_impacting: bool = false
var _dig_cycle_damage: float = 0.0
var current_biome: StringName = BIOME_AMBER
var hero_station: StringName = &""
var raw_fossil_queue: Array[StringName] = []
var fossil_cleaning_progress: float = 0.0
var station_revived_dinos: Dictionary = {}
var station_last_fossil_time: Dictionary = {}
#endregion


#region Estado permanente (sobrevive ao prestígio)
var permanent_upgrade_levels: Dictionary = {}
var run_number: int = 1
var max_depth_ever: int = 0
var lifetime_bones: float = 0.0
var total_amber_earned: float = 0.0
## Espécies já revividas alguma vez (para progressão visual).
var discovered_dinos: Dictionary = {}
var ark_completed: bool = false
var total_fossils_evaluated: int = 0
var total_legendary_fossils: int = 0
var rescued_station_dinos: Dictionary = {}
var quarry_clue_active: bool = false
var quarry_special_plate_found: bool = false
var quarry_ankylo_rescued: bool = false
var ark_modules_built: Dictionary = {}
var last_impact_summary: Dictionary = {}
#endregion


#region Preferências / UI
var buy_multiplier: int = 1
var color_progress: float = 0.0
var danger_level: float = 0.0
var is_prestige_modal_open: bool = false
var sfx_volume: float = 1.0
var music_volume: float = 1.0
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
	rescued_station_dinos.clear()
	quarry_clue_active = false
	quarry_special_plate_found = false
	quarry_ankylo_rescued = false
	ark_modules_built.clear()
	last_impact_summary.clear()
	fragments.clear()
	raw_fossil_queue.clear()
	fossil_cleaning_progress = 0.0
	total_fossils_evaluated = 0
	total_legendary_fossils = 0
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
	_field_elapsed = 0.0
	for res_id: StringName in RUN_RESOURCES:
		resources[res_id] = 0.0
	resources[RES_RAW_FOSSILS] = float(raw_fossil_queue.size())
	dino_counts.clear()
	upgrade_levels.clear()
	rubble_levels.clear()
	rubble_levels[&"rubble_forge"] = 1
	station_worker_unlocked.clear()
	orange_rock_hp = ORANGE_ROCK_MAX_HP
	orange_rock_broken = false
	quarry_clue_active = false
	current_era_index = 0
	current_layer_index = 0
	depth = 0
	run_total_bones = 0.0
	run_surface_progress = 0.0
	_dig_roll_accum = 0.0
	_auto_dig_accum = 0.0
	meteor_active = false
	is_impacting = false
	_dig_cycle_damage = 0.0
	current_biome = BIOME_AMBER
	hero_station = &""
	station_revived_dinos.clear()
	for st: StringName in RUBBLE_ORDER:
		if is_station_dino_rescued(st):
			station_revived_dinos[st] = 1
			var revive_dino: StringName = get_station_revive_dino_id(st)
			if revive_dino != &"":
				dino_counts[revive_dino] = maxi(get_dino_count(revive_dino), 1)
				discovered_dinos[revive_dino] = true
	station_last_fossil_time.clear()
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
	Events.biome_changed.emit(current_biome)
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
	if data.required_station != &"":
		if not is_station_built(data.required_station) or not has_station_worker(data.required_station):
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

	# Bônus das estações reconstruídas/ampliadas na Superfície (mesmo stat_id soma multiplicadores).
	for rubble_id: StringName in RUBBLE_ORDER:
		var r_lvl: int = get_rubble_level(rubble_id)
		var bonus_lvl: int = maxi(r_lvl - 1, 0) if rubble_id == &"rubble_forge" else r_lvl
		if bonus_lvl <= 0:
			continue
		var def: Dictionary = RUBBLE_DEFS[rubble_id] as Dictionary
		var st_id: StringName = StringName(def.get("stat_id", &""))
		if st_id == &"":
			continue
		if def.has("add_per_level"):
			_stat_flat[st_id] = float(_stat_flat.get(st_id, 0.0)) + float(def["add_per_level"]) * float(bonus_lvl)
		elif def.has("mult_per_level"):
			_stat_mult[st_id] = float(_stat_mult.get(st_id, 1.0)) + float(def["mult_per_level"]) * float(bonus_lvl)

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


## Museu removido: mantido em 1.0 sem bônus adicional.
func get_museum_collection_multiplier() -> float:
	return 1.0


## Multiplicador combinado de ossos (legado subterrâneo).
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
			if frag_hits > 0:
				var active_pool: Array[DinoData] = era.fragment_pool
				if hero_station != &"":
					var biome_pool: Array[DinoData] = get_biome_fossil_pool(hero_station, false)
					if not biome_pool.is_empty():
						active_pool = biome_pool
				if not active_pool.is_empty():
					_distribute_fragment_drops(active_pool, frag_hits, world_position)

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
			var bonus_dino: DinoData = null
			if hero_station != &"":
				var biome_pool: Array[DinoData] = get_biome_fossil_pool(hero_station, false)
				if not biome_pool.is_empty():
					bonus_dino = biome_pool[randi() % biome_pool.size()]
			if bonus_dino == null:
				bonus_dino = era.pick_random_fragment()
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


#region Superfície: Rocha Laranja, Biomas & Estruturas
func _on_orange_rock_hit(damage: float, world_position: Vector2) -> void:
	if orange_rock_broken or damage <= 0.0:
		return
	var effective: float = minf(damage, orange_rock_hp)
	orange_rock_hp = maxf(orange_rock_hp - effective, 0.0)
	Events.orange_rock_hp_changed.emit(orange_rock_hp, ORANGE_ROCK_MAX_HP)

	if orange_rock_hp <= 0.0:
		orange_rock_broken = true
		# Chocar o Ovo concede apenas 5 Rochas: o jogador caminha até a Pedreira e farma manualmente primeiro.
		var shell_bonus: float = 5.0
		add_resource(RES_ROCKS, shell_bonus)
		Events.loot_dropped.emit(RES_ROCKS, shell_bonus, world_position)
		# Ao quebrar a Rocha Laranja, nasce o 1º Dinossauro (protagonista)!
		if get_dino_count(&"compsognathus") == 0:
			dino_counts[&"compsognathus"] = 1
			discovered_dinos[&"compsognathus"] = true
			Events.dino_unlocked.emit(&"compsognathus")
			Events.dino_count_changed.emit(&"compsognathus", 1)
			_update_color_progress()
		if not quarry_ankylo_rescued and not quarry_special_plate_found:
			quarry_clue_active = true
		Events.orange_rock_broken.emit()
		if not quarry_ankylo_rescued and not quarry_special_plate_found:
			Events.notification_requested.emit("🦖 O Ovo se partiu! Uma batida ecoa na Pedreira do Casco — vá investigar!", null)
		elif quarry_ankylo_rescued:
			Events.notification_requested.emit("🦖 O Ovo se partiu! O Anquilossauro já está firme no veio da Pedreira!", null)
		else:
			Events.notification_requested.emit("🦖 O Ovo se partiu! Leve a Placa Especial à Pedreira do Casco para despertar o Anquilossauro!", null)


func get_station_biome(station: StringName) -> StringName:
	if not RUBBLE_DEFS.has(station):
		return BIOME_AMBER
	return StringName((RUBBLE_DEFS[station] as Dictionary).get("biome", BIOME_AMBER))


func get_stations_for_biome(biome: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	for station: StringName in RUBBLE_ORDER:
		if get_station_biome(station) == biome:
			result.append(station)
	return result


func set_current_biome(biome: StringName) -> void:
	if not (biome in BIOME_ORDER):
		return
	current_biome = biome
	if hero_station != &"" and get_station_biome(hero_station) != current_biome:
		hero_station = &""
	Events.biome_changed.emit(current_biome)


func set_hero_station(station: StringName) -> void:
	var normalized: StringName = station if RUBBLE_DEFS.has(station) else &""
	if hero_station == normalized:
		return
	hero_station = normalized
	Events.stats_recalculated.emit()


func is_station_built(station: StringName) -> bool:
	return get_rubble_level(station) > 0


func has_station_worker(station: StringName) -> bool:
	return bool(station_worker_unlocked.get(station, false))


func get_station_worker_cost(station: StringName) -> float:
	if not RUBBLE_DEFS.has(station):
		return 0.0
	return float((RUBBLE_DEFS[station] as Dictionary).get("worker_cost", 65.0))


func can_hire_station_worker(station: StringName) -> bool:
	if not RUBBLE_DEFS.has(station):
		return false
	if not is_station_built(station) or has_station_worker(station):
		return false
	var product: StringName = StringName((RUBBLE_DEFS[station] as Dictionary)["product"])
	return can_afford(product, get_station_worker_cost(station))


func hire_station_worker(station: StringName) -> bool:
	if not can_hire_station_worker(station):
		return false
	var def: Dictionary = RUBBLE_DEFS[station] as Dictionary
	var product: StringName = StringName(def["product"])
	var cost: float = get_station_worker_cost(station)
	if not spend(product, cost):
		return false
	station_worker_unlocked[station] = true
	recalculate_stats()
	_update_color_progress()
	Events.rubble_rebuilt.emit(station, get_rubble_level(station))
	Events.notification_requested.emit(
		"🦖 %s recrutado em %s!" % [String(def["worker"]), String(def["title"])],
		null
	)
	return true


func get_station_for_dino(dino_id: StringName) -> StringName:
	for station: StringName in RUBBLE_ORDER:
		if get_station_revive_dino_id(station) == dino_id:
			return station
	return &""


func get_total_revived_station_dinos() -> int:
	var total: int = 0
	for station: StringName in RUBBLE_ORDER:
		total += get_station_revived_count(station)
	return total


func get_global_revive_station_multiplier() -> float:
	return 1.0 \
		+ 0.35 * float(get_station_revived_count(&"rubble_bunker")) \
		+ 0.50 * float(get_station_revived_count(&"forest_sanctuary"))


func get_active_surface_resources() -> Array[StringName]:
	var active: Array[StringName] = [RES_ROCKS]
	if is_station_built(&"rubble_nest") or get_resource(RES_FISH) > 0.0:
		active.append(RES_FISH)
	if is_station_built(&"rubble_silo") or get_resource(RES_FEATHERS) > 0.0:
		active.append(RES_FEATHERS)
	if is_station_built(&"rubble_bunker") or get_resource(RES_SCIENCE) > 0.0:
		active.append(RES_SCIENCE)
	if not raw_fossil_queue.is_empty() or get_resource(RES_RAW_FOSSILS) > 0.0:
		active.append(RES_RAW_FOSSILS)
	if get_station_revived_count(&"rubble_forge") > 0 or get_resource(RES_METAL) > 0.0:
		active.append(RES_METAL)
	if get_station_revived_count(&"rubble_nest") > 0 or get_resource(RES_SCALES) > 0.0:
		active.append(RES_SCALES)
	if get_station_revived_count(&"rubble_silo") > 0 or get_resource(RES_BEAKS) > 0.0:
		active.append(RES_BEAKS)
	if is_station_built(&"forest_grove") or get_resource(RES_WOOD) > 0.0:
		active.append(RES_WOOD)
	if is_station_built(&"forest_sanctuary") or get_resource(RES_BERRIES) > 0.0:
		active.append(RES_BERRIES)
	if get_station_revived_count(&"forest_grove") > 0 or get_resource(RES_RESIN) > 0.0:
		active.append(RES_RESIN)
	if is_station_built(&"snow_glacier") or get_resource(RES_ICE) > 0.0:
		active.append(RES_ICE)
	if is_station_built(&"snow_observatory") or get_station_revived_count(&"snow_glacier") > 0 or get_resource(RES_CRYSTALS) > 0.0:
		active.append(RES_CRYSTALS)
	if get_resource(RES_AMBER) > 0.0 or total_amber_earned > 0.0:
		active.append(RES_AMBER)
	return active


func get_resource_rate(res_id: StringName) -> float:
	var total: float = 0.0
	for station: StringName in RUBBLE_ORDER:
		var def: Dictionary = RUBBLE_DEFS[station] as Dictionary
		if StringName(def["product"]) == res_id:
			total += get_station_effective_rate(station)
		if StringName(def["tier2_product"]) == res_id:
			total += get_station_tier2_rate(station)
	return total


func get_hero_station_bonus_rate(station: StringName) -> float:
	if not orange_rock_broken or hero_station != station or not is_station_built(station):
		return 0.0
	return HERO_BASE_FARM_RATE + get_station_rate(station) * HERO_ASSIST_BONUS_MULT


func get_station_effective_rate(station: StringName) -> float:
	return get_station_rate(station) + get_hero_station_bonus_rate(station)


func get_biome_fossil_pool(station: StringName, include_future_fallback: bool = false) -> Array[DinoData]:
	var pool: Array[DinoData] = []
	if not RUBBLE_DEFS.has(station):
		return pool
	var ids: Variant = (RUBBLE_DEFS[station] as Dictionary).get("fossils", [])
	var all_station: Array[DinoData] = []
	if ids is Array:
		for raw_id: Variant in (ids as Array):
			var dino: DinoData = get_dino(StringName(raw_id))
			if dino != null:
				all_station.append(dino)
				if dino.unlock_era_index <= current_era_index:
					pool.append(dino)
	if pool.is_empty() and include_future_fallback and not all_station.is_empty():
		all_station.sort_custom(func(a: DinoData, b: DinoData) -> bool: return a.unlock_era_index < b.unlock_era_index)
		var min_era: int = all_station[0].unlock_era_index
		for d: DinoData in all_station:
			if d.unlock_era_index == min_era:
				pool.append(d)
	return pool


func get_biome_fossil_names(station: StringName) -> String:
	if not RUBBLE_DEFS.has(station):
		return ""
	var names: PackedStringArray = []
	var ids: Variant = (RUBBLE_DEFS[station] as Dictionary).get("fossils", [])
	if ids is Array:
		for raw_id: Variant in (ids as Array):
			var dino: DinoData = get_dino(StringName(raw_id))
			if dino != null:
				names.append(dino.display_name)
	if names.size() > 4:
		return "Todas as espécies"
	return ", ".join(names)


func extract_biome_fossil(station: StringName, world_position: Vector2 = Vector2.ZERO, guarantee: bool = false) -> StringName:
	var pool: Array[DinoData] = get_biome_fossil_pool(station, true)
	if pool.is_empty():
		return &""
	var chance: float = clampf(0.28 * get_multiplier(STAT_FOSSIL_LUCK) * get_multiplier(STAT_FRAGMENT_CHANCE) * get_collector_drop_multiplier(), 0.05, 0.90)
	if not guarantee and randf() >= chance:
		return &""
	var candidates: Array[DinoData] = []
	for d: DinoData in pool:
		var count: int = get_dino_count(d.id)
		var req: int = d.get_fragments_required(count)
		if d.can_spawn_more(count) and (count == 0 or d.fragments_growth_per_unit > 0) and get_fragments(d.id) < req:
			candidates.append(d)
	if candidates.is_empty():
		candidates = pool
	var picked: DinoData = candidates[randi() % candidates.size()]
	add_fragments(picked.id, 1)
	register_fossil_found(picked.id)
	Events.fragment_dropped.emit(picked.id, world_position)
	return picked.id


func get_raw_fossil_find_chance(station: StringName) -> float:
	if not RUBBLE_DEFS.has(station):
		return BASE_RAW_FOSSIL_CHANCE
	var luck_mult: float = get_multiplier(STAT_FOSSIL_LUCK) * get_multiplier(STAT_FRAGMENT_CHANCE)
	var level_mult: float = 1.0 + 0.35 * float(maxi(get_rubble_level(station) - 1, 0))
	var hero_mult: float = 2.5 if (orange_rock_broken and hero_station == station) else 1.0
	return clampf(BASE_RAW_FOSSIL_CHANCE * luck_mult * level_mult * hero_mult, 0.0, 0.50)


func get_station_fossil_flash(station: StringName) -> float:
	return maxf(float(station_last_fossil_time.get(station, 0.0)), 0.0)


func get_station_revived_count(station: StringName) -> int:
	return int(station_revived_dinos.get(station, 0))


func get_station_revive_dino_id(station: StringName) -> StringName:
	if not RUBBLE_DEFS.has(station):
		return &""
	return StringName((RUBBLE_DEFS[station] as Dictionary).get("revive_dino", &""))


func get_station_revive_cost(station: StringName) -> float:
	if not RUBBLE_DEFS.has(station):
		return 0.0
	var def: Dictionary = RUBBLE_DEFS[station] as Dictionary
	var lvl: int = get_station_revived_count(station)
	return roundf(float(def.get("revive_cost", 450.0)) * pow(2.5, float(lvl)))


func can_revive_station_dino(station: StringName) -> bool:
	if not RUBBLE_DEFS.has(station) or not is_station_built(station):
		return false
	var dino_id: StringName = get_station_revive_dino_id(station)
	if dino_id == &"" or get_fragments(dino_id) < STATION_REVIVE_FOSSILS_REQUIRED:
		return false
	var product: StringName = StringName((RUBBLE_DEFS[station] as Dictionary)["product"])
	return can_afford(product, get_station_revive_cost(station))


func is_quarry_extraction_available() -> bool:
	return orange_rock_broken and not quarry_special_plate_found and not quarry_ankylo_rescued


func claim_quarry_special_plate() -> bool:
	if quarry_special_plate_found or quarry_ankylo_rescued:
		return false
	quarry_special_plate_found = true
	quarry_clue_active = false
	register_fossil_found(&"ankylosaurus")
	Events.notification_requested.emit("🦴 Placa Especial do Anquilossauro extraída! Desperte-o na Pedreira do Casco!", null)
	return true


func can_awaken_quarry_ankylosaurus() -> bool:
	return orange_rock_broken and quarry_special_plate_found and not quarry_ankylo_rescued


func awaken_quarry_ankylosaurus() -> bool:
	if not can_awaken_quarry_ankylosaurus():
		return false
	quarry_ankylo_rescued = true
	quarry_clue_active = false
	rescued_station_dinos[&"rubble_forge"] = true
	station_revived_dinos[&"rubble_forge"] = maxi(get_station_revived_count(&"rubble_forge"), 1)
	dino_counts[&"ankylosaurus"] = maxi(get_dino_count(&"ankylosaurus"), 1)
	discovered_dinos[&"ankylosaurus"] = true
	add_resource(RES_METAL, QUARRY_STARTER_METAL_BURST)
	recalculate_stats()
	_update_color_progress()
	Events.dino_unlocked.emit(&"ankylosaurus")
	Events.dino_count_changed.emit(&"ankylosaurus", get_dino_count(&"ankylosaurus"))
	Events.rubble_rebuilt.emit(&"rubble_forge", get_rubble_level(&"rubble_forge"))
	Events.quarry_vein_opened.emit()
	Events.notification_requested.emit("🦕 Anquilossauro despertou e derrubou a laje! Veio de Metal aberto na Pedreira!", null)
	return true


func is_quarry_slab_broken() -> bool:
	return quarry_ankylo_rescued or bool(rescued_station_dinos.get(&"rubble_forge", false)) or get_station_revived_count(&"rubble_forge") > 0


func is_station_dino_rescued(station: StringName) -> bool:
	if bool(rescued_station_dinos.get(station, false)):
		return true
	if station == &"rubble_forge" and quarry_ankylo_rescued:
		return true
	return false


func get_rescued_companion_count() -> int:
	var count: int = 0
	for st: StringName in RUBBLE_ORDER:
		if is_station_dino_rescued(st):
			count += 1
	return count


func get_rescued_companion_names() -> Array[String]:
	var names: Array[String] = []
	for st: StringName in RUBBLE_ORDER:
		if is_station_dino_rescued(st) and RUBBLE_DEFS.has(st):
			var def: Dictionary = RUBBLE_DEFS[st] as Dictionary
			names.append(String(def.get("revive_name", st)))
	return names


func revive_station_dino(station: StringName) -> bool:
	if not can_revive_station_dino(station):
		return false
	var def: Dictionary = RUBBLE_DEFS[station] as Dictionary
	var product: StringName = StringName(def["product"])
	var cost: float = get_station_revive_cost(station)
	if not spend(product, cost):
		return false
	var dino_id: StringName = get_station_revive_dino_id(station)
	add_fragments(dino_id, -STATION_REVIVE_FOSSILS_REQUIRED)
	var new_revived: int = get_station_revived_count(station) + 1
	station_revived_dinos[station] = new_revived
	rescued_station_dinos[station] = true
	var opened_quarry_vein: bool = false
	if station == &"rubble_forge" and not quarry_ankylo_rescued:
		quarry_ankylo_rescued = true
		quarry_special_plate_found = true
		quarry_clue_active = false
		opened_quarry_vein = true
	var prev_count: int = get_dino_count(dino_id)
	dino_counts[dino_id] = prev_count + 1
	if prev_count == 0:
		discovered_dinos[dino_id] = true
		Events.dino_unlocked.emit(dino_id)
		_update_color_progress()
	Events.dino_count_changed.emit(dino_id, prev_count + 1)
	Events.rubble_rebuilt.emit(station, get_rubble_level(station))
	if opened_quarry_vein:
		Events.quarry_vein_opened.emit()
	recalculate_stats()
	var rname: String = String(def.get("revive_name", dino_id))
	var mult_val: float = float(def.get("revive_mult", 2.5))
	Events.notification_requested.emit("🦖 %s revivido em %s! (×%.1f produção)" % [rname, String(def["title"]), mult_val], null)
	return true


func roll_station_raw_fossil(station: StringName, rolls: int = 1, force_find: bool = false, world_position: Vector2 = Vector2.ZERO) -> bool:
	if not RUBBLE_DEFS.has(station) or rolls <= 0:
		return false
	var hits: int = 1 if force_find else _sample_binomial(rolls, get_raw_fossil_find_chance(station))
	if hits <= 0:
		return false
	var target_dino: StringName = get_station_revive_dino_id(station)
	if target_dino == &"":
		target_dino = &"compsognathus"
	for _i: int in range(hits):
		raw_fossil_queue.append(target_dino)
	add_resource(RES_RAW_FOSSILS, float(hits))
	station_last_fossil_time[station] = STATION_FOSSIL_FLASH_DURATION
	Events.loot_dropped.emit(RES_RAW_FOSSILS, float(hits), world_position)
	return true


func get_university_cleaning_speed() -> float:
	if not is_station_built(&"rubble_bunker"):
		return 0.0
	var base_speed: float = 1.0
	if has_station_worker(&"rubble_bunker"):
		base_speed += 0.25
	if orange_rock_broken and hero_station == &"rubble_bunker":
		base_speed += 0.35
	base_speed += 0.60 * float(get_station_revived_count(&"rubble_bunker"))
	return base_speed * get_multiplier(STAT_CLEANING_SPEED)


func get_university_clean_duration() -> float:
	return BASE_FOSSIL_CLEAN_SECONDS / maxf(get_university_cleaning_speed(), 0.001)


func get_university_clean_remaining_seconds() -> float:
	if raw_fossil_queue.is_empty() or get_university_cleaning_speed() <= 0.0:
		return 0.0
	return maxf(1.0 - fossil_cleaning_progress, 0.0) * get_university_clean_duration()


func _complete_one_cleaned_fossil(world_position: Vector2 = Vector2.ZERO) -> StringName:
	if raw_fossil_queue.is_empty():
		return &""
	var dino_id: StringName = raw_fossil_queue[0]
	raw_fossil_queue.remove_at(0)
	if get_resource(RES_RAW_FOSSILS) > 0.0:
		add_resource(RES_RAW_FOSSILS, -1.0)
	var double_p: float = clampf(get_stat(STAT_CLEAN_DOUBLE_CHANCE, 0.0), 0.0, 0.90)
	var out_count: int = 2 if randf() < double_p else 1
	add_fragments(dino_id, out_count)
	for _c: int in range(out_count):
		register_fossil_found(dino_id)
	Events.fragment_dropped.emit(dino_id, world_position)
	return dino_id


func _tick_university_cleaning(delta: float) -> void:
	if raw_fossil_queue.is_empty():
		fossil_cleaning_progress = 0.0
		return
	var speed: float = get_university_cleaning_speed()
	if speed <= 0.0:
		return
	fossil_cleaning_progress += (delta * speed) / BASE_FOSSIL_CLEAN_SECONDS
	while fossil_cleaning_progress >= 1.0 - 1e-6 and not raw_fossil_queue.is_empty():
		fossil_cleaning_progress = maxf(fossil_cleaning_progress - 1.0, 0.0)
		_complete_one_cleaned_fossil(Vector2.ZERO)
	if raw_fossil_queue.is_empty():
		fossil_cleaning_progress = 0.0


func get_university_prep_cost() -> float:
	return 25.0 + float(current_era_index) * 15.0


func can_prepare_fossil_at_university() -> bool:
	return can_afford(RES_SCIENCE, get_university_prep_cost())


func prepare_fossil_at_university(world_position: Vector2 = Vector2.ZERO) -> StringName:
	if not raw_fossil_queue.is_empty() and can_prepare_fossil_at_university():
		if spend(RES_SCIENCE, get_university_prep_cost()):
			fossil_cleaning_progress = 0.0
			return _complete_one_cleaned_fossil(world_position)
	if not can_prepare_fossil_at_university():
		return &""
	if not spend(RES_SCIENCE, get_university_prep_cost()):
		return &""
	var picked: DinoData = null
	var fallback: Array[DinoData] = []
	for d: DinoData in get_dinos_sorted():
		if d.unlock_era_index <= current_era_index:
			fallback.append(d)
			var count: int = get_dino_count(d.id)
			var req: int = d.get_fragments_required(count)
			if d.can_spawn_more(count) and (count == 0 or d.fragments_growth_per_unit > 0) and get_fragments(d.id) < req:
				picked = d
				break
	if picked == null:
		if not fallback.is_empty():
			picked = fallback[randi() % fallback.size()]
		else:
			var sorted: Array[DinoData] = get_dinos_sorted()
			if not sorted.is_empty():
				picked = sorted[0]
	if picked == null:
		return &""
	add_fragments(picked.id, 1)
	var rarity: int = maxi(roll_fossil_rarity(), 1)
	register_fossil_found(picked.id, rarity)
	Events.fragment_dropped.emit(picked.id, world_position)
	return picked.id


func hero_farm_action(station: StringName = hero_station, world_position: Vector2 = Vector2.ZERO) -> Dictionary:
	if not orange_rock_broken:
		_on_orange_rock_hit(get_click_damage(), world_position)
		return {"kind": &"egg"}
	var target_station: StringName = station if RUBBLE_DEFS.has(station) else &"rubble_forge"
	if not is_station_built(target_station):
		var title: String = String((RUBBLE_DEFS[target_station] as Dictionary)["title"])
		Events.notification_requested.emit("Construa %s primeiro para farmar!" % title, null)
		return {"kind": &"locked", "station": target_station}
	var def: Dictionary = RUBBLE_DEFS[target_station] as Dictionary
	var product: StringName = StringName(def["product"])
	var base_manual: float = (1.0 + get_station_rate(target_station) * 0.25) * get_multiplier(STAT_MANUAL_YIELD)
	var gain: float = maxf(1.0, base_manual)
	add_resource(product, gain)
	Events.loot_dropped.emit(product, gain, world_position)
	if get_station_revived_count(target_station) > 0:
		var t2_product: StringName = StringName(def["tier2_product"])
		var t2_gain: float = maxf(0.25, get_station_tier2_rate(target_station) * 0.35 * get_multiplier(STAT_MANUAL_YIELD))
		add_resource(t2_product, t2_gain)
		Events.loot_dropped.emit(t2_product, t2_gain, world_position)
	var progress_gain: float = maxf(10.0, gain * 18.0 * get_multiplier(STAT_STATION_YIELD))
	run_surface_progress += progress_gain
	var found_raw: bool = roll_station_raw_fossil(target_station, 5, false, world_position)
	var cleaned_dino: StringName = &""
	if target_station == &"rubble_bunker" and not raw_fossil_queue.is_empty():
		fossil_cleaning_progress += (4.0 * get_multiplier(STAT_CLEANING_SPEED)) / BASE_FOSSIL_CLEAN_SECONDS
		if fossil_cleaning_progress >= 1.0 - 1e-6:
			fossil_cleaning_progress = maxf(fossil_cleaning_progress - 1.0, 0.0)
			cleaned_dino = _complete_one_cleaned_fossil(world_position)
			if raw_fossil_queue.is_empty():
				fossil_cleaning_progress = 0.0
	return {
		"kind": &"farm",
		"station": target_station,
		"product": product,
		"amount": gain,
		"raw_fossil_found": found_raw,
		"fossil": cleaned_dino,
	}


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)


func get_rubble_level(rubble_id: StringName) -> int:
	return rubble_levels.get(rubble_id, 0)


func get_rubble_cost_resource(rubble_id: StringName) -> StringName:
	if not RUBBLE_DEFS.has(rubble_id):
		return RES_ROCKS
	var def: Dictionary = RUBBLE_DEFS[rubble_id] as Dictionary
	if get_rubble_level(rubble_id) <= 0:
		return StringName(def.get("build_resource", RES_ROCKS))
	return StringName(def.get("expand_resource", RES_ROCKS))


func get_rubble_cost(rubble_id: StringName) -> float:
	if not RUBBLE_DEFS.has(rubble_id):
		return 0.0
	var def: Dictionary = RUBBLE_DEFS[rubble_id] as Dictionary
	var lvl: int = get_rubble_level(rubble_id)
	if lvl <= 0:
		return float(def.get("build_cost", def["base_cost"]))
	return roundf(float(def["base_cost"]) * pow(float(def["cost_growth"]), float(lvl - 1)))


func can_rebuild_rubble(rubble_id: StringName) -> bool:
	if not RUBBLE_DEFS.has(rubble_id):
		return false
	var lvl: int = get_rubble_level(rubble_id)
	if lvl >= 1 and not has_station_worker(rubble_id):
		return false
	return can_afford(get_rubble_cost_resource(rubble_id), get_rubble_cost(rubble_id))


func rebuild_rubble(rubble_id: StringName) -> bool:
	if not can_rebuild_rubble(rubble_id):
		return false
	var res_id: StringName = get_rubble_cost_resource(rubble_id)
	var cost: float = get_rubble_cost(rubble_id)
	if not spend(res_id, cost):
		return false
	var new_lvl: int = get_rubble_level(rubble_id) + 1
	rubble_levels[rubble_id] = new_lvl
	recalculate_stats()
	_update_color_progress()
	Events.rubble_rebuilt.emit(rubble_id, new_lvl)
	var def: Dictionary = RUBBLE_DEFS[rubble_id] as Dictionary
	var msg: String = "🏗️ %s construída!" % String(def["title"]) if new_lvl == 1 else "🏗️ %s ampliada (Nv. %d)!" % [String(def["title"]), new_lvl]
	Events.notification_requested.emit(msg, null)
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
	var has_progress: bool = depth >= min_depth or run_surface_progress >= 2700.0 or quarry_ankylo_rescued or get_ark_built_module_count() > 0
	return has_progress and calculate_amber_reward() >= min_amber


func _on_meteor_early_impact_requested() -> void:
	if not can_trigger_early_impact():
		var min_depth: int = balance.early_impact_min_depth if balance != null else 3
		Events.notification_requested.emit(
			"Acumule progresso nas estações (ou %dm) e +1 Âmbar para antecipar o impacto." % min_depth,
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


func is_ark_module_built(module_id: StringName) -> bool:
	return bool(ark_modules_built.get(module_id, false))


func get_ark_built_module_count() -> int:
	var count: int = 0
	for mod_id: Variant in ARK_MODULES:
		if is_ark_module_built(StringName(mod_id)):
			count += 1
	return count


func get_ark_module_costs(module_id: StringName) -> Dictionary:
	if not ARK_MODULES.has(module_id):
		return {}
	var def: Dictionary = ARK_MODULES[module_id] as Dictionary
	var raw_costs: Variant = def.get("costs", {})
	if raw_costs is Dictionary:
		return (raw_costs as Dictionary).duplicate()
	return {}


func can_build_ark_module(module_id: StringName) -> bool:
	if not ARK_MODULES.has(module_id) or is_ark_module_built(module_id):
		return false
	var costs: Dictionary = get_ark_module_costs(module_id)
	if costs.is_empty():
		return false
	for res_key: Variant in costs:
		var res_id: StringName = StringName(res_key)
		var amt: float = float(costs[res_key])
		if not can_afford(res_id, amt):
			return false
	return true


func build_ark_module(module_id: StringName) -> bool:
	if not can_build_ark_module(module_id):
		return false
	var def: Dictionary = ARK_MODULES[module_id] as Dictionary
	var costs: Dictionary = get_ark_module_costs(module_id)
	for res_key: Variant in costs:
		var res_id: StringName = StringName(res_key)
		var amt: float = float(costs[res_key])
		if not spend(res_id, amt):
			return false
	ark_modules_built[module_id] = true
	recalculate_stats()
	_update_color_progress()
	Events.ark_module_built.emit(module_id, get_ark_built_module_count())
	var title: String = String(def.get("title", module_id))
	Events.notification_requested.emit("🛡️ Módulo '%s' concluído na Arca dos Vivos!" % title, null)
	return true


func get_ark_impact_amber_multiplier() -> float:
	return 1.0 + (0.40 if is_ark_module_built(ARK_MODULE_HULL) else 0.0)


func get_campaign_next_goal_text() -> String:
	if not orange_rock_broken:
		if quarry_ankylo_rescued:
			return "Objetivo: Quebre o Ovo de Âmbar — o Anquilossauro já aguarda no veio da Pedreira!"
		return "Objetivo: Quebre o Ovo de Âmbar para iniciar a expedição."
	if is_quarry_extraction_available():
		return "Objetivo: Vá à Pedreira do Casco e investigue a trinca na jazida."
	if can_awaken_quarry_ankylosaurus():
		return "Objetivo: Desperte o Anquilossauro na Pedreira do Casco para abrir o veio de Metal."
	if not is_ark_module_built(ARK_MODULE_HULL):
		return "Objetivo: Junte 80 Rochas e 6 Metal para construir o Reforço de Casco na Arca dos Vivos."
	if not is_station_built(&"forest_grove"):
		return "Objetivo: Use Metal para abrir o Bosque das Sequoias à esquerda ou prepare a Arca para o impacto."
	if not can_activate_ark_victory():
		return "Objetivo: Resgate dinos (%d/8) e fortaleça a Arca dos Vivos (%d%% escudo)." % [
			get_rescued_companion_count(),
			roundi(get_shield_ratio() * 100.0),
		]
	return "Objetivo: Arca dos Vivos pronta! Ative a proteção contra o meteoro."


func fast_forward_meteor_to(seconds_left: float = 5.0) -> void:
	if is_impacting:
		return
	if meteor_total_time <= 0.0:
		var base_time: float = balance.base_meteor_time if balance != null else BASE_METEOR_TIME
		meteor_total_time = get_stat(STAT_METEOR_TIME, base_time)
	meteor_active = true
	meteor_time_left = clampf(seconds_left, 0.0, meteor_total_time)
	_set_danger_level(1.0 - meteor_time_left / maxf(meteor_total_time, 0.001))
	Events.meteor_timer_changed.emit(meteor_time_left, meteor_total_time)


## Prévia do âmbar que o jogador receberia agora (para a UI "Antecipar impacto").
## shield_ratio: 0..1 — quanto do impacto foi absorvido pelas defesas.
func calculate_amber_reward(shield_ratio: float = -1.0) -> float:
	var effective_progress: float = run_total_bones + run_surface_progress
	if effective_progress <= 0.0 and depth <= 0:
		return 0.0
	if shield_ratio < 0.0:
		shield_ratio = get_shield_ratio()
	var divisor: float = balance.amber_bones_divisor if balance != null else 2700.0
	var exponent: float = balance.amber_bones_exponent if balance != null else 0.088
	var depth_weight: float = balance.amber_depth_per_layer if balance != null else 0.042
	var layer_weight: float = balance.amber_layer_progress_weight if balance != null else 0.05
	var shield_weight: float = balance.amber_shield_bonus if balance != null else 0.75
	var from_bones: float = pow(maxf(effective_progress / maxf(divisor, 1.0), 0.0), exponent)
	var layer_progress: float = clampf(1.0 - (layer_hp / maxf(layer_max_hp, 1.0)), 0.0, 1.0)
	var depth_factor: float = 1.0 + float(depth) * depth_weight + layer_progress * layer_weight
	var survival_factor: float = 1.0 + clampf(shield_ratio, 0.0, 1.0) * shield_weight
	var snow_revive_mult: float = 1.0 + 0.50 * float(get_station_revived_count(&"snow_observatory"))
	var surface_milestones: float = 1.0 + 0.12 * float(get_total_revived_station_dinos())
	var ark_mult: float = get_ark_impact_amber_multiplier()
	var amber_mult: float = get_multiplier(STAT_AMBER_MULT)
	var computed: float = floorf(from_bones * depth_factor * survival_factor * snow_revive_mult * surface_milestones * ark_mult * amber_mult)
	if (quarry_ankylo_rescued or get_ark_built_module_count() > 0) and effective_progress > 0.0:
		var floor_amber: float = floorf((2.0 + float(get_ark_built_module_count()) * 2.0) * ark_mult * amber_mult)
		return maxf(computed, floor_amber)
	return computed


## Proteção atual contra o meteoro (upgrades de defesa + Santuário Ártico + Arca + dinos DEFENSE).
func get_shield_ratio() -> float:
	var shield: float = get_stat(STAT_METEOR_SHIELD, 0.0)
	shield += 0.15 * float(get_station_revived_count(&"snow_observatory"))
	if is_ark_module_built(ARK_MODULE_HULL):
		shield += 0.10
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
	var effective_shield: float = get_shield_ratio() if shield_ratio < 0.0 else clampf(shield_ratio, 0.0, 1.0)
	last_impact_summary = {
		"amber_gained": amber,
		"run_number": finished_run,
		"rescued_names": get_rescued_companion_names(),
		"rescued_count": get_rescued_companion_count(),
		"ankylo_rescued": quarry_ankylo_rescued,
		"slab_broken": is_quarry_slab_broken(),
		"hull_built": is_ark_module_built(ARK_MODULE_HULL),
		"ark_modules_count": get_ark_built_module_count(),
		"shield_pct": roundi(effective_shield * 100.0),
		"next_goal": get_campaign_next_goal_text(),
	}
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
	var ready: bool = ark_lvl >= req_lvl and shield >= req_shield and (current_era_index >= req_era or get_total_revived_station_dinos() >= 4)
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
## 0 = cinza/terroso, 1 = colorido. Baseado em espécies descobertas e estruturas construídas nos 3 biomas.
func _update_color_progress() -> void:
	var built_count: int = 0
	for station: StringName in RUBBLE_ORDER:
		if is_station_built(station):
			built_count += 1
	var total_steps: int = maxi(dinos_db.size() + RUBBLE_ORDER.size(), 1)
	var steps: int = discovered_dinos.size() + built_count
	var progress: float = clampf(float(steps) / float(total_steps), 0.0, 1.0)
	if is_equal_approx(progress, color_progress):
		return
	color_progress = progress
	Events.color_progress_changed.emit(color_progress)
#endregion


#region Renda passiva / offline
var _auto_dig_accum: float = 0.0
var _field_elapsed: float = 0.0


func get_station_rate(station: StringName) -> float:
	if not RUBBLE_DEFS.has(station) or not is_station_built(station) or not has_station_worker(station):
		return 0.0
	var site: Dictionary = RUBBLE_DEFS[station] as Dictionary
	var gear_level: int = get_upgrade_level(StringName(site["gear"]))
	var revived: int = get_station_revived_count(station)
	var base_revive_mult: float = float(site.get("revive_mult", 2.5))
	var revive_mult: float = pow(base_revive_mult, float(revived)) if revived > 0 else 1.0
	return float(site["rate"]) \
		* float(get_rubble_level(station)) \
		* (1.0 + FIELD_GEAR_YIELD_BONUS * float(gear_level)) \
		* revive_mult \
		* get_multiplier(STAT_STATION_YIELD) \
		* get_global_revive_station_multiplier()


func get_station_tier2_rate(station: StringName) -> float:
	var revived: int = get_station_revived_count(station)
	if revived <= 0 or not RUBBLE_DEFS.has(station) or not is_station_built(station):
		return 0.0
	var site: Dictionary = RUBBLE_DEFS[station] as Dictionary
	var base_t2: float = float(site.get("tier2_rate", 0.0))
	return base_t2 * float(revived) * get_multiplier(STAT_TIER2_YIELD)


func _harvest_stations(seconds: float, gains: Dictionary) -> void:
	var yield_mult: float = get_multiplier(STAT_STATION_YIELD)
	var t2_mult: float = get_multiplier(STAT_TIER2_YIELD)
	for station: StringName in RUBBLE_ORDER:
		var def: Dictionary = RUBBLE_DEFS[station] as Dictionary
		var amount: float = seconds * get_station_effective_rate(station)
		if amount > 0.0:
			var product: StringName = StringName(def["product"])
			add_resource(product, amount)
			gains[product] = float(gains.get(product, 0.0)) + amount
			run_surface_progress += amount * 12.0 * yield_mult
		var t2_amount: float = seconds * get_station_tier2_rate(station)
		if t2_amount > 0.0:
			var t2_product: StringName = StringName(def["tier2_product"])
			add_resource(t2_product, t2_amount)
			gains[t2_product] = float(gains.get(t2_product, 0.0)) + t2_amount
			run_surface_progress += t2_amount * 45.0 * t2_mult


func _tick_passive_income(delta: float) -> void:
	for station: StringName in RUBBLE_ORDER:
		var t: float = float(station_last_fossil_time.get(station, 0.0))
		if t > 0.0:
			station_last_fossil_time[station] = maxf(t - delta, 0.0)
	_field_elapsed += delta
	if _field_elapsed >= 1.0:
		var step_secs: float = _field_elapsed
		_harvest_stations(step_secs, {})
		_field_elapsed = 0.0
		var roll_count: int = maxi(floori(step_secs), 1)
		for station: StringName in RUBBLE_ORDER:
			if is_station_built(station) and (has_station_worker(station) or (orange_rock_broken and hero_station == station)):
				roll_station_raw_fossil(station, roll_count, false, Vector2.ZERO)
	_tick_university_cleaning(delta)
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
	_harvest_stations(capped_seconds * eff, gains)
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


#region Fósseis & Golpe Preciso
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


## Registra estatísticas simples do fóssil encontrado e emite `Events.fossil_found` para áudio/VFX.
func register_fossil_found(dino_id: StringName, forced_rarity: int = -1) -> Dictionary:
	var rarity: int = clampi(forced_rarity, 0, 3) if forced_rarity >= 0 else roll_fossil_rarity()
	total_fossils_evaluated += 1
	if rarity >= 3:
		total_legendary_fossils += 1
	Events.fossil_found.emit(dino_id, rarity)
	return {
		"dino_id": dino_id,
		"rarity": rarity,
		"record_number": total_fossils_evaluated,
	}


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
		"station_worker_unlocked": _sn_dict_to_json(station_worker_unlocked),
		"current_biome": String(current_biome),
		"orange_rock_hp": orange_rock_hp,
		"orange_rock_broken": orange_rock_broken,
		"permanent_upgrade_levels": _sn_dict_to_json(permanent_upgrade_levels),
		"discovered_dinos": discovered_dinos.keys().map(func(k: StringName) -> String: return String(k)),
		"current_era_index": current_era_index,
		"current_layer_index": current_layer_index,
		"layer_hp": layer_hp,
		"depth": depth,
		"run_total_bones": run_total_bones,
		"run_surface_progress": run_surface_progress,
		"meteor_time_left": meteor_time_left,
		"run_number": run_number,
		"max_depth_ever": max_depth_ever,
		"lifetime_bones": lifetime_bones,
		"total_amber_earned": total_amber_earned,
		"buy_multiplier": buy_multiplier,
		"ark_completed": ark_completed,
		"total_fossils_evaluated": total_fossils_evaluated,
		"total_legendary_fossils": total_legendary_fossils,
		"raw_fossil_queue": raw_fossil_queue.map(func(k: StringName) -> String: return String(k)),
		"fossil_cleaning_progress": fossil_cleaning_progress,
		"station_revived_dinos": _sn_dict_to_json(station_revived_dinos),
		"rescued_station_dinos": _sn_dict_to_json(rescued_station_dinos),
		"quarry_clue_active": quarry_clue_active,
		"quarry_special_plate_found": quarry_special_plate_found,
		"quarry_ankylo_rescued": quarry_ankylo_rescued,
		"ark_modules_built": _sn_dict_to_json(ark_modules_built),
		"last_impact_summary": last_impact_summary.duplicate(true),
		"sfx_volume": sfx_volume,
		"music_volume": music_volume,
	}


func load_save_dict(data: Dictionary) -> void:
	_field_elapsed = 0.0
	hero_station = &""
	station_last_fossil_time.clear()
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
	if get_rubble_level(&"rubble_forge") < 1:
		rubble_levels[&"rubble_forge"] = 1
	station_worker_unlocked.clear()
	var raw_workers: Variant = data.get("station_worker_unlocked", {})
	if raw_workers is Dictionary:
		_json_to_bool_dict(raw_workers as Dictionary, station_worker_unlocked)
	var saved_biome: StringName = StringName(str(data.get("current_biome", String(BIOME_AMBER))))
	current_biome = saved_biome if saved_biome in BIOME_ORDER else BIOME_AMBER
	station_revived_dinos.clear()
	_json_to_int_dict(data.get("station_revived_dinos", {}), station_revived_dinos)
	rescued_station_dinos.clear()
	var raw_rescued: Variant = data.get("rescued_station_dinos", {})
	if raw_rescued is Dictionary:
		_json_to_bool_dict(raw_rescued as Dictionary, rescued_station_dinos)
	ark_modules_built.clear()
	var raw_ark: Variant = data.get("ark_modules_built", {})
	if raw_ark is Dictionary:
		_json_to_bool_dict(raw_ark as Dictionary, ark_modules_built)
	last_impact_summary.clear()
	var raw_summary: Variant = data.get("last_impact_summary", {})
	if raw_summary is Dictionary:
		last_impact_summary = (raw_summary as Dictionary).duplicate(true)
	raw_fossil_queue.clear()
	for raw_d: Variant in data.get("raw_fossil_queue", []):
		raw_fossil_queue.append(StringName(str(raw_d)))
	resources[RES_RAW_FOSSILS] = float(raw_fossil_queue.size())
	fossil_cleaning_progress = clampf(float(data.get("fossil_cleaning_progress", 0.0)), 0.0, 1.0)
	sfx_volume = clampf(float(data.get("sfx_volume", 1.0)), 0.0, 1.0)
	music_volume = clampf(float(data.get("music_volume", 1.0)), 0.0, 1.0)
	orange_rock_broken = bool(data.get("orange_rock_broken", false))
	orange_rock_hp = 0.0 if orange_rock_broken else clampf(float(data.get("orange_rock_hp", ORANGE_ROCK_MAX_HP)), 0.01, ORANGE_ROCK_MAX_HP)
	quarry_clue_active = bool(data.get("quarry_clue_active", false))
	quarry_special_plate_found = bool(data.get("quarry_special_plate_found", false))
	quarry_ankylo_rescued = bool(data.get("quarry_ankylo_rescued", false))
	permanent_upgrade_levels.clear()
	_json_to_int_dict(data.get("permanent_upgrade_levels", {}), permanent_upgrade_levels)

	discovered_dinos.clear()
	for dino_id: Variant in data.get("discovered_dinos", []):
		discovered_dinos[StringName(str(dino_id))] = true

	for st_key: Variant in station_revived_dinos:
		if int(station_revived_dinos[st_key]) > 0:
			rescued_station_dinos[StringName(st_key)] = true
	if bool(rescued_station_dinos.get(&"rubble_forge", false)) or int(station_revived_dinos.get(&"rubble_forge", 0)) > 0:
		quarry_ankylo_rescued = true
	if quarry_ankylo_rescued:
		quarry_special_plate_found = true
		quarry_clue_active = false
		rescued_station_dinos[&"rubble_forge"] = true
	elif quarry_special_plate_found:
		quarry_clue_active = false
	elif not orange_rock_broken:
		quarry_clue_active = false
	for st: StringName in RUBBLE_ORDER:
		if is_station_dino_rescued(st):
			rescued_station_dinos[st] = true
			station_revived_dinos[st] = maxi(get_station_revived_count(st), 1)
			var revive_dino: StringName = get_station_revive_dino_id(st)
			if revive_dino != &"":
				dino_counts[revive_dino] = maxi(get_dino_count(revive_dino), 1)
				discovered_dinos[revive_dino] = true

	total_fossils_evaluated = maxi(int(data.get("total_fossils_evaluated", 0)), 0)
	total_legendary_fossils = maxi(int(data.get("total_legendary_fossils", 0)), 0)

	run_number = int(data.get("run_number", 1))
	max_depth_ever = int(data.get("max_depth_ever", 0))
	lifetime_bones = float(data.get("lifetime_bones", 0.0))
	total_amber_earned = float(data.get("total_amber_earned", 0.0))
	run_total_bones = float(data.get("run_total_bones", 0.0))
	run_surface_progress = maxf(float(data.get("run_surface_progress", 0.0)), 0.0)
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


static func _json_to_bool_dict(source: Dictionary, target: Dictionary) -> void:
	for key: Variant in source:
		target[StringName(str(key))] = bool(source[key])
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
