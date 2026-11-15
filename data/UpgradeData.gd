class_name UpgradeData
extends Resource
## Definição de um upgrade (dados puros, sem estado).
##
## Cada upgrade é um arquivo .tres em res://data/upgrades/ (ou subpastas).
## O NÍVEL atual fica em GameState; este Resource só descreve custo e efeito.
##
## Custo:   custo(n) = base_cost * cost_growth ^ n
## Efeito:  aplicado sobre a estatística `stat_id` (ver constantes STAT_* em GameState).

## Abas do painel lateral (AMBER = árvore permanente de prestígio).
enum Category { TOOLS, DINOS, MACHINES, DEFENSE, AMBER }

## Como o efeito se acumula por nível.
enum EffectType {
	ADD,              ## +value por nível (soma no valor base). Ex.: +1 de dano de clique.
	MULTIPLY_PERCENT, ## ×(1 + value × nível). Ex.: value 0.1 → +10% por nível (aditivo entre níveis).
	MULTIPLY,         ## ×(value ^ nível). Ex.: value 2.0 → dobra a cada nível (exponencial).
}

@export_group("Identidade")
## ID único e estável (usado no save). NUNCA mude depois de publicado.
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var category: Category = Category.TOOLS
## Ordem de exibição dentro da aba (menor = mais acima).
@export var sort_order: int = 0

@export_group("Custo")
## Recurso gasto (GameState.RES_BONES, RES_MINERALS, RES_DNA, RES_AMBER).
@export var cost_resource: StringName = &"bones"
@export var base_cost: float = 10.0
## Crescimento por nível. Típico: 1.07 a 1.15.
@export_range(1.0, 10.0, 0.001) var cost_growth: float = 1.15
## 0 = infinito.
@export var max_level: int = 0

@export_group("Efeito")
## Estatística afetada (ex.: &"click_damage", &"bones_mult", &"dino_damage:trex").
@export var stat_id: StringName = &""
@export var effect_type: EffectType = EffectType.ADD
@export var effect_value: float = 1.0

@export_group("Requisitos")
## Upgrade que precisa estar no nível `required_level` para este aparecer.
@export var required_upgrade: StringName = &""
@export var required_level: int = 1
## Era mínima (índice) para desbloquear.
@export var required_era_index: int = 0
## true = upgrade de prestígio (não reseta no meteoro).
@export var is_permanent: bool = false


## Custo de UM nível, partindo de `level` (nível atual).
func get_cost(level: int) -> float:
	return base_cost * pow(cost_growth, float(level))


## Custo de comprar `amount` níveis a partir de `level` (soma de PG).
func get_bulk_cost(level: int, amount: int) -> float:
	if amount <= 0:
		return 0.0
	var first: float = get_cost(level)
	if is_equal_approx(cost_growth, 1.0):
		return first * float(amount)
	return first * (pow(cost_growth, float(amount)) - 1.0) / (cost_growth - 1.0)


## Quantos níveis cabem no orçamento `budget` a partir de `level`.
func get_max_affordable(level: int, budget: float) -> int:
	var remaining: int = get_remaining_levels(level)
	if remaining == 0 or budget < get_cost(level):
		return 0
	var n: int
	if is_equal_approx(cost_growth, 1.0):
		n = floori(budget / get_cost(level))
	else:
		var ratio: float = budget * (cost_growth - 1.0) / get_cost(level) + 1.0
		n = floori(log(ratio) / log(cost_growth))
	if remaining > 0:
		n = mini(n, remaining)
	# Corrige erros de arredondamento de float.
	while n > 0 and get_bulk_cost(level, n) > budget:
		n -= 1
	return n


## Níveis restantes até o máximo. -1 = infinito.
func get_remaining_levels(level: int) -> int:
	if max_level <= 0:
		return -1
	return maxi(max_level - level, 0)


func is_maxed(level: int) -> bool:
	return max_level > 0 and level >= max_level


## Valor do efeito acumulado em `level`.
## ADD → valor somado; MULTIPLY_* → fator multiplicativo.
func get_effect_at_level(level: int) -> float:
	match effect_type:
		EffectType.ADD:
			return effect_value * float(level)
		EffectType.MULTIPLY_PERCENT:
			return 1.0 + effect_value * float(level)
		EffectType.MULTIPLY:
			return pow(effect_value, float(level))
	return 0.0
