class_name DinoData
extends Resource
## Definição de uma espécie de dinossauro (dados puros, sem estado).
##
## Cada espécie é um arquivo .tres em res://data/dinos/.
## Quantidade e nível ficam em GameState; este Resource só descreve a espécie.
##
## Revivendo:
##   • 1ª unidade: exige `fragments_required` fragmentos + `assembly_cost` em ossos.
##   • Unidades extras: custam ossos, com custo exponencial (`unit_cost_growth`).

## Papel na escavação (define o comportamento da cena do dino em scenes/dinos/).
enum Role {
	COLLECTOR, ## Pega ossos do chão (Compsognato)
	BREAKER,   ## Golpes lentos e fortes (T-Rex)
	AREA,      ## Dano em área / atordoa (Tricerátopo)
	FAST,      ## Muitos golpes rápidos (Velociraptor)
	TRANSPORT, ## Carrega minérios voando (Pterodáctilo)
	SUPPORT,   ## Aura de buff (Braquiossauro)
	DEFENSE,   ## Reduz dano do meteoro (Anquilossauro)
	ELEMENTAL, ## Dano ao longo do tempo (Dilofossauro)
}

@export_group("Identidade")
## ID único e estável (usado no save e em stat_ids como &"dino_damage:trex").
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var role: Role = Role.BREAKER
@export var icon: Texture2D
## Sprite (ou spritesheet) usado pelo MultiMesh/cena do dino.
@export var sprite: Texture2D
## Cor de destaque, usada na progressão cromática do mundo.
@export var accent_color: Color = Color.WHITE
## Cena opcional com comportamento especial (se vazio, usa o comportamento padrão do Role).
@export var behavior_scene: PackedScene

@export_group("Desbloqueio")
## Era (índice) em que os fragmentos começam a aparecer.
@export var unlock_era_index: int = 0
@export var fragments_required: int = 10
## Custo em ossos para montar o 1º esqueleto.
@export var assembly_cost: float = 50.0

@export_group("Custo de unidades extras")
@export var unit_base_cost: float = 25.0
@export_range(1.0, 10.0, 0.001) var unit_cost_growth: float = 1.12

@export_group("Combate / Escavação")
## Dano por golpe (antes de multiplicadores).
@export var base_damage: float = 1.0
## Segundos entre golpes.
@export var attack_interval: float = 1.0
@export_range(0.0, 1.0, 0.01) var crit_chance: float = 0.0
@export var crit_multiplier: float = 2.0
@export var move_speed: float = 60.0

@export_group("Utilidade")
## Ossos carregados por viagem (COLLECTOR / TRANSPORT).
@export var carry_capacity: float = 0.0
## Bônus de aura em % (SUPPORT). 0.05 = +5% de produção para dinos próximos.
@export var aura_bonus: float = 0.0
## Redução do dano do meteoro por unidade (DEFENSE). 0.01 = 1%.
@export var meteor_damage_reduction: float = 0.0
## DNA gerado por segundo por unidade.
@export var dna_per_second: float = 0.0

@export_group("Marcos")
## Quantidades que disparam bônus.
@export var milestones: Array[int] = [25, 50, 100, 200, 400]
## Multiplicador aplicado a CADA marco atingido (2.0 = dobra).
@export var milestone_multiplier: float = 2.0


## Custo em ossos da próxima unidade, tendo `owned` unidades.
## Retorna `assembly_cost` para a primeira unidade.
func get_unit_cost(owned: int) -> float:
	if owned <= 0:
		return assembly_cost
	return unit_base_cost * pow(unit_cost_growth, float(owned - 1))


## Dano por segundo de UMA unidade, sem multiplicadores externos.
func get_base_dps() -> float:
	if attack_interval <= 0.0:
		return 0.0
	var crit_factor: float = 1.0 + crit_chance * (crit_multiplier - 1.0)
	return base_damage * crit_factor / attack_interval


## Multiplicador acumulado pelos marcos já atingidos com `count` unidades.
func get_milestone_multiplier(count: int) -> float:
	return pow(milestone_multiplier, float(get_milestones_reached(count)))


func get_milestones_reached(count: int) -> int:
	var reached: int = 0
	for m: int in milestones:
		if count >= m:
			reached += 1
	return reached


## Próximo marco a partir de `count` (-1 se todos foram atingidos). Útil para barras de progresso na UI.
func get_next_milestone(count: int) -> int:
	for m: int in milestones:
		if count < m:
			return m
	return -1


## ID da estatística de dano desta espécie (para upgrades específicos).
func get_damage_stat_id() -> StringName:
	return StringName("dino_damage:%s" % id)
