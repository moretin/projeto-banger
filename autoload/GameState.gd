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
const RES_MINERALS: StringName = &"minerals"
const RES_DNA: StringName = &"dna"
const RES_AMBER: StringName = &"amber"
## Recursos zerados a cada run (âmbar é permanente).
const RUN_RESOURCES: Array[StringName] = [RES_BONES, RES_MINERALS, RES_DNA]
const ALL_RESOURCES: Array[StringName] = [RES_BONES, RES_MINERALS, RES_DNA, RES_AMBER]

## IDs de estatísticas afetadas por upgrades (UpgradeData.stat_id).
## Para dano de uma espécie use DinoData.get_damage_stat_id() → &"dino_damage:<id>".
const STAT_CLICK_DAMAGE: StringName = &"click_damage"
const STAT_CLICK_CRIT_CHANCE: StringName = &"click_crit_chance"
const STAT_DINO_DAMAGE: StringName = &"dino_damage"        ## Global (todos os dinos)
const STAT_BONES_MULT: StringName = &"bones_mult"
const STAT_MINERAL_CHANCE: StringName = &"mineral_chance"  ## Multiplicador da chance base da era
const STAT_FRAGMENT_CHANCE: StringName = &"fragment_chance"
const STAT_DNA_MULT: StringName = &"dna_mult"
const STAT_METEOR_TIME: StringName = &"meteor_time"        ## Segundos extras (ADD)
const STAT_METEOR_SHIELD: StringName = &"meteor_shield"    ## 0..1 de proteção
const STAT_AMBER_MULT: StringName = &"amber_mult"
const STAT_OFFLINE_MULT: StringName = &"offline_mult"

## Valor de "Máx" no multiplicador de compra.
const BUY_MAX: int = -1
const BUY_MULTIPLIERS: Array[int] = [1, 10, 100, BUY_MAX]

## Timer base do meteoro (segundos).
const BASE_METEOR_TIME: float = 900.0
## A partir de qual run o meteoro aparece (1 = desde a primeira).
const METEOR_FIRST_RUN: int = 1

const DINOS_DIR: String = "res://data/dinos"
const UPGRADES_DIR: String = "res://data/upgrades"
const ERAS_DIR: String = "res://data/eras"
#endregion


#region Bancos de dados (somente leitura após _ready)
var dinos_db: Dictionary[StringName, DinoData] = {}
var upgrades_db: Dictionary[StringName, UpgradeData] = {}
## Ordenado por EraData.index.
var eras: Array[EraData] = []
#endregion


#region Estado da run (reseta no meteoro)
var resources: Dictionary[StringName, float] = {}
var fragments: Dictionary[StringName, int] = {}
var dino_counts: Dictionary[StringName, int] = {}
var upgrade_levels: Dictionary[StringName, int] = {}

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
#endregion


#region Estado permanente (sobrevive ao prestígio)
var permanent_upgrade_levels: Dictionary[StringName, int] = {}
var run_number: int = 1
var max_depth_ever: int = 0
var lifetime_bones: float = 0.0
var total_amber_earned: float = 0.0
## Espécies já revividas alguma vez (para bestiário e progressão de cor).
var discovered_dinos: Dictionary[StringName, bool] = {}
#endregion


#region Preferências / UI
var buy_multiplier: int = 1
var color_progress: float = 0.0
var danger_level: float = 0.0
#endregion


#region Cache de estatísticas
var _stat_flat: Dictionary[StringName, float] = {}
var _stat_mult: Dictionary[StringName, float] = {}
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
	Events.upgrade_purchase_requested.connect(_on_upgrade_purchase_requested)
	Events.dino_assembly_requested.connect(_on_dino_assembly_requested)
	Events.meteor_early_impact_requested.connect(trigger_meteor_impact)


#region Ciclo de jogo
## Zera tudo (novo jogo do zero).
func start_new_game() -> void:
	permanent_upgrade_levels.clear()
	discovered_dinos.clear()
	run_number = 1
	max_depth_ever = 0
	lifetime_bones = 0.0
	total_amber_earned = 0.0
	resources[RES_AMBER] = 0.0
	_reset_run_state()
	Events.run_started.emit(run_number)


## Reseta apenas o estado da run (chamado pelo prestígio).
func _reset_run_state() -> void:
	for res_id: StringName in RUN_RESOURCES:
		resources[res_id] = 0.0
	fragments.clear()
	dino_counts.clear()
	upgrade_levels.clear()
	current_era_index = 0
	current_layer_index = 0
	depth = 0
	run_total_bones = 0.0
	is_impacting = false
	recalculate_stats()
	_setup_layer()
	_setup_meteor()
	_update_color_progress()
	_emit_full_refresh()


## Emite todos os sinais de estado para que as cenas se redesenhem (após load/prestígio).
func _emit_full_refresh() -> void:
	for res_id: StringName in ALL_RESOURCES:
		Events.resource_changed.emit(res_id, get_resource(res_id), 0.0)
	for dino_id: StringName in dinos_db:
		Events.dino_count_changed.emit(dino_id, get_dino_count(dino_id))
		Events.fragments_changed.emit(dino_id, get_fragments(dino_id))
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
	var new_amount: int = maxi(get_fragments(dino_id) + amount, 0)
	fragments[dino_id] = new_amount
	Events.fragments_changed.emit(dino_id, new_amount)
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
	for data: UpgradeData in upgrades_db.values():
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
func recalculate_stats() -> void:
	_stat_flat.clear()
	_stat_mult.clear()
	for data: UpgradeData in upgrades_db.values():
		var level: int = get_upgrade_level(data.id)
		if level <= 0 or data.stat_id == &"":
			continue
		var effect: float = data.get_effect_at_level(level)
		if data.effect_type == UpgradeData.EffectType.ADD:
			_stat_flat[data.stat_id] = _stat_flat.get(data.stat_id, 0.0) + effect
		else:
			_stat_mult[data.stat_id] = _stat_mult.get(data.stat_id, 1.0) * effect
	Events.stats_recalculated.emit()


## Valor final de uma estatística: (base + somas) × multiplicadores.
func get_stat(stat_id: StringName, base_value: float = 0.0) -> float:
	return (base_value + _stat_flat.get(stat_id, 0.0)) * _stat_mult.get(stat_id, 1.0)


## Atalho para estatísticas que são multiplicadores puros (base 1.0).
func get_multiplier(stat_id: StringName) -> float:
	return get_stat(stat_id, 1.0)


func get_click_damage() -> float:
	return get_stat(STAT_CLICK_DAMAGE, 1.0)


## Dano final por golpe de uma unidade de `dino_id` (com upgrades e marcos).
func get_dino_damage(dino_id: StringName) -> float:
	var data: DinoData = get_dino(dino_id)
	if data == null:
		return 0.0
	return data.base_damage \
		* get_multiplier(STAT_DINO_DAMAGE) \
		* get_multiplier(data.get_damage_stat_id()) \
		* data.get_milestone_multiplier(get_dino_count(dino_id))


## DPS total de todos os dinos (usado no progresso offline e na UI de estatísticas).
func get_total_dino_dps() -> float:
	var total: float = 0.0
	for dino_id: StringName in dino_counts:
		var data: DinoData = get_dino(dino_id)
		var count: int = get_dino_count(dino_id)
		if data == null or count <= 0 or data.attack_interval <= 0.0:
			continue
		var crit_factor: float = 1.0 + data.crit_chance * (data.crit_multiplier - 1.0)
		total += get_dino_damage(dino_id) * crit_factor / data.attack_interval * float(count)
	return total


func get_bones_per_second() -> float:
	var era: EraData = get_current_era()
	if era == null:
		return 0.0
	return get_total_dino_dps() * era.bones_per_damage * get_multiplier(STAT_BONES_MULT)


func get_dna_per_second() -> float:
	var total: float = 0.0
	for dino_id: StringName in dino_counts:
		var data: DinoData = get_dino(dino_id)
		if data != null:
			total += data.dna_per_second * float(get_dino_count(dino_id))
	return total * get_multiplier(STAT_DNA_MULT)
#endregion


#region Dinos
func get_dino(dino_id: StringName) -> DinoData:
	return dinos_db.get(dino_id, null)


func get_dino_count(dino_id: StringName) -> int:
	return dino_counts.get(dino_id, 0)


func is_dino_unlocked(dino_id: StringName) -> bool:
	return get_dino_count(dino_id) > 0


## Pode montar o 1º esqueleto ou comprar mais uma unidade?
func can_assemble_dino(dino_id: StringName) -> bool:
	var data: DinoData = get_dino(dino_id)
	if data == null:
		return false
	var count: int = get_dino_count(dino_id)
	if count == 0 and get_fragments(dino_id) < data.fragments_required:
		return false
	return can_afford(RES_BONES, data.get_unit_cost(count))


func assemble_dino(dino_id: StringName) -> bool:
	if not can_assemble_dino(dino_id):
		return false
	var data: DinoData = get_dino(dino_id)
	var old_count: int = get_dino_count(dino_id)
	spend(RES_BONES, data.get_unit_cost(old_count))
	if old_count == 0:
		add_fragments(dino_id, -data.fragments_required)
	var new_count: int = old_count + 1
	dino_counts[dino_id] = new_count

	if old_count == 0:
		discovered_dinos[dino_id] = true
		Events.dino_unlocked.emit(dino_id)
		_update_color_progress()
	if data.get_milestones_reached(new_count) > data.get_milestones_reached(old_count):
		Events.dino_milestone_reached.emit(dino_id, new_count)
		Events.stats_recalculated.emit()
	Events.dino_count_changed.emit(dino_id, new_count)
	return true


func _on_dino_assembly_requested(dino_id: StringName) -> void:
	assemble_dino(dino_id)
#endregion


#region Escavação
func get_current_era() -> EraData:
	if eras.is_empty():
		return null
	return eras[clampi(current_era_index, 0, eras.size() - 1)]


func _setup_layer() -> void:
	var era: EraData = get_current_era()
	layer_max_hp = era.get_layer_hp(current_layer_index) if era != null else 10.0
	layer_hp = layer_max_hp
	Events.layer_hp_changed.emit(layer_hp, layer_max_hp)


## Aplica dano na camada atual e gera loot. Chamado via Events.dig_hit.
func apply_dig_damage(damage: float, world_position: Vector2 = Vector2.ZERO) -> void:
	var era: EraData = get_current_era()
	if era == null or damage <= 0.0 or is_impacting:
		return
	var effective: float = minf(damage, layer_hp)

	# Ossos proporcionais ao dano causado.
	var bones: float = effective * era.bones_per_damage * get_multiplier(STAT_BONES_MULT)
	add_resource(RES_BONES, bones)
	Events.loot_dropped.emit(RES_BONES, bones, world_position)

	# Minério (chance por golpe).
	if randf() < era.mineral_chance * get_multiplier(STAT_MINERAL_CHANCE):
		add_resource(RES_MINERALS, era.mineral_amount)
		Events.loot_dropped.emit(RES_MINERALS, era.mineral_amount, world_position)

	# Fragmento de fóssil (chance por golpe).
	if randf() < era.fragment_chance * get_multiplier(STAT_FRAGMENT_CHANCE):
		var dino: DinoData = era.pick_random_fragment()
		if dino != null:
			add_fragments(dino.id, 1)
			Events.fragment_dropped.emit(dino.id, world_position)

	layer_hp -= effective
	Events.layer_hp_changed.emit(layer_hp, layer_max_hp)
	if layer_hp <= 0.0:
		_break_layer()


func _break_layer() -> void:
	depth += 1
	max_depth_ever = maxi(max_depth_ever, depth)
	Events.layer_broken.emit(current_era_index, current_layer_index, depth)

	var era: EraData = get_current_era()
	current_layer_index += 1
	var is_last_era: bool = current_era_index >= eras.size() - 1
	if era != null and current_layer_index >= era.layers_count and not is_last_era:
		current_era_index += 1
		current_layer_index = 0
		Events.era_changed.emit(current_era_index)
		_update_color_progress()
	_setup_layer()


func _on_dig_hit(damage: float, world_position: Vector2, _is_crit: bool) -> void:
	apply_dig_damage(damage, world_position)
#endregion


#region Meteoro & Prestígio
func _setup_meteor() -> void:
	meteor_active = run_number >= METEOR_FIRST_RUN
	meteor_total_time = get_stat(STAT_METEOR_TIME, BASE_METEOR_TIME)
	meteor_time_left = meteor_total_time
	_set_danger_level(0.0)
	Events.meteor_timer_changed.emit(meteor_time_left, meteor_total_time)


func _tick_meteor(delta: float) -> void:
	if not meteor_active:
		return
	meteor_time_left = maxf(meteor_time_left - delta, 0.0)
	Events.meteor_timer_changed.emit(meteor_time_left, meteor_total_time)
	_set_danger_level(1.0 - meteor_time_left / maxf(meteor_total_time, 0.001))
	if meteor_time_left <= 0.0:
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
	if shield_ratio < 0.0:
		shield_ratio = get_shield_ratio()
	var from_bones: float = sqrt(run_total_bones / 1000.0)
	var depth_factor: float = 1.0 + float(depth) * 0.1
	var survival_factor: float = 1.0 + clampf(shield_ratio, 0.0, 1.0)
	return floorf(from_bones * depth_factor * survival_factor * get_multiplier(STAT_AMBER_MULT))


## Proteção atual contra o meteoro (upgrades de defesa + dinos DEFENSE).
func get_shield_ratio() -> float:
	var shield: float = get_stat(STAT_METEOR_SHIELD, 0.0)
	for dino_id: StringName in dino_counts:
		var data: DinoData = get_dino(dino_id)
		if data != null:
			shield += data.meteor_damage_reduction * float(get_dino_count(dino_id))
	return clampf(shield, 0.0, 1.0)


## Conclui o prestígio: concede âmbar e começa uma nova run.
func perform_prestige(shield_ratio: float = -1.0) -> float:
	var amber: float = calculate_amber_reward(shield_ratio)
	add_resource(RES_AMBER, amber)
	total_amber_earned += amber
	var finished_run: int = run_number
	run_number += 1
	Events.prestige_completed.emit(amber, finished_run)
	_reset_run_state()
	Events.run_started.emit(run_number)
	return amber


func _set_danger_level(level: float) -> void:
	level = clampf(level, 0.0, 1.0)
	if is_equal_approx(level, danger_level):
		return
	danger_level = level
	Events.danger_level_changed.emit(danger_level)
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
func _tick_passive_income(delta: float) -> void:
	var dna_rate: float = get_dna_per_second()
	if dna_rate > 0.0:
		add_resource(RES_DNA, dna_rate * delta)


## Aplica ganhos offline de forma simplificada (sem simular camadas). Retorna os ganhos.
## O timer do meteoro NÃO corre offline.
func apply_offline_progress(seconds: float) -> Dictionary[StringName, float]:
	var gains: Dictionary[StringName, float] = {}
	if seconds <= 0.0:
		return gains
	var mult: float = get_multiplier(STAT_OFFLINE_MULT)
	var bones: float = get_bones_per_second() * seconds * mult
	var dna: float = get_dna_per_second() * seconds * mult
	if bones > 0.0:
		add_resource(RES_BONES, bones)
		gains[RES_BONES] = bones
	if dna > 0.0:
		add_resource(RES_DNA, dna)
		gains[RES_DNA] = dna
	return gains
#endregion


#region Serialização (usada pelo SaveManager)
func to_save_dict() -> Dictionary:
	return {
		"resources": _sn_dict_to_json(resources),
		"fragments": _sn_dict_to_json(fragments),
		"dino_counts": _sn_dict_to_json(dino_counts),
		"upgrade_levels": _sn_dict_to_json(upgrade_levels),
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
	}


func load_save_dict(data: Dictionary) -> void:
	resources.clear()
	for res_id: StringName in ALL_RESOURCES:
		resources[res_id] = 0.0
	for key: String in data.get("resources", {}):
		resources[StringName(key)] = float(data["resources"][key])

	fragments.clear()
	_json_to_int_dict(data.get("fragments", {}), fragments)
	dino_counts.clear()
	_json_to_int_dict(data.get("dino_counts", {}), dino_counts)
	upgrade_levels.clear()
	_json_to_int_dict(data.get("upgrade_levels", {}), upgrade_levels)
	permanent_upgrade_levels.clear()
	_json_to_int_dict(data.get("permanent_upgrade_levels", {}), permanent_upgrade_levels)

	discovered_dinos.clear()
	for dino_id: Variant in data.get("discovered_dinos", []):
		discovered_dinos[StringName(str(dino_id))] = true

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
	is_impacting = false

	recalculate_stats()
	_setup_layer()
	layer_hp = clampf(float(data.get("layer_hp", layer_max_hp)), 0.01, layer_max_hp)
	_setup_meteor()
	meteor_time_left = clampf(float(data.get("meteor_time_left", meteor_total_time)), 0.0, meteor_total_time)
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
#endregion


#region Carregamento dos bancos de dados
func _load_databases() -> void:
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
