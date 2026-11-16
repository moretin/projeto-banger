class_name EraData
extends Resource
## Definição de uma era geológica (uma "faixa" de camadas no corte lateral do solo).
##
## Cada era é um arquivo .tres em res://data/eras/. A ordem é definida por `index`.
## Vida da camada:  hp(n) = base_layer_hp * layer_hp_growth ^ n   (n = camada dentro da era)

@export_group("Identidade")
## ID único e estável (usado no save).
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
## Ordem da era (0 = superfície). Deve ser único e sequencial.
@export var index: int = 0

@export_group("Camadas")
## Camadas até passar para a próxima faixa da Terra. No Núcleo, as camadas continuam infinitamente.
@export var layers_count: int = 10
@export var base_layer_hp: float = 120000.0
@export_range(1.0, 10.0, 0.001) var layer_hp_growth: float = 1.85
## Run mínima necessária para conseguir quebrar a primeira camada desta faixa (ex.: Crosta exige run >= 3).
@export var min_run_to_break: int = 1

@export_group("Recompensas")
## Nome do recurso/material proveniente desta camada da Terra (Terra, Pedra, Rocha Incandescente, Magma, Núcleo).
@export var layer_resource_name: String = "Terra"
## Recursos gerados por ponto de dano causado na escavação (mantido baixo para evitar inflação).
@export var bones_per_damage: float = 0.06
## Bônus de recursos proveniente da camada ao conseguir quebrá-la por completo.
@export var layer_break_bonus_bones: float = 800.0
## Bônus de minérios raros liberado ao quebrar uma camada desta faixa.
@export var layer_break_bonus_minerals: float = 5.0
## Dano acumulado necessário na camada para cada rolagem de extração de fóssil/minério.
@export var fossil_damage_threshold: float = 180.0
## Chance (0–1) de cada ciclo de escavação soltar minério.
@export_range(0.0, 1.0, 0.001) var mineral_chance: float = 0.01
@export var mineral_amount: float = 1.0
## Chance (0–1) de cada ciclo de escavação desenterrar um fóssil específico.
@export_range(0.0, 1.0, 0.0001) var fragment_chance: float = 0.015
## Espécies cujos fósseis específicos podem ser encontrados nesta camada da Terra.
@export var fragment_pool: Array[DinoData] = []

@export_group("Visual")
@export var layer_texture: Texture2D
## Cor "dessaturada" (início do jogo).
@export var rock_color_muted: Color = Color(0.45, 0.42, 0.38)
## Cor vibrante (quando color_progress = 1.0).
@export var rock_color_vivid: Color = Color(0.75, 0.5, 0.3)
@export var background_color: Color = Color(0.2, 0.18, 0.16)


func get_layer_hp(layer_index: int) -> float:
	return base_layer_hp * pow(layer_hp_growth, float(layer_index))


## Cor da rocha interpolada pela progressão cromática (0..1).
func get_rock_color(color_progress: float) -> Color:
	return rock_color_muted.lerp(rock_color_vivid, clampf(color_progress, 0.0, 1.0))


## Sorteia um fragmento do pool (ou null se vazio).
func pick_random_fragment() -> DinoData:
	if fragment_pool.is_empty():
		return null
	return fragment_pool.pick_random() as DinoData
