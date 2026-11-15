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
## Camadas até passar para a próxima era. Na última era, as camadas continuam infinitamente.
@export var layers_count: int = 10
@export var base_layer_hp: float = 10.0
@export_range(1.0, 10.0, 0.001) var layer_hp_growth: float = 1.25

@export_group("Recompensas")
## Ossos gerados por ponto de dano causado.
@export var bones_per_damage: float = 1.0
## Chance (0–1) de cada golpe soltar minério.
@export_range(0.0, 1.0, 0.001) var mineral_chance: float = 0.0
@export var mineral_amount: float = 1.0
## Chance (0–1) de cada golpe soltar um fragmento de fóssil.
@export_range(0.0, 1.0, 0.0001) var fragment_chance: float = 0.0
## Espécies cujos fragmentos podem cair nesta era.
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
