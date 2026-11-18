class_name AmberPalette
extends Resource
## Paleta centralizada "Âmbar Fossilizado" do Fóssil Rush.
##
## Fluxo cromático contínuo (NUNCA preto e branco ou cinza):
##   1. Início em sépia quente e âmbar translúcido
##   2. Evolução para selva pré-histórica viva com a profundidade / eras
##   3. Aquecimento para brasa e laranja-vermelho conforme o meteoro se aproxima

@export_group("Fase 1 — Sépia e Âmbar Translúcido")
@export var sepia_sky_top: Color = Color("3b2414")
@export var sepia_sky_horizon: Color = Color("6e441e")
@export var sepia_ground: Color = Color("52341a")
@export var sepia_canopy: Color = Color("805524")

@export_group("Fase 2 — Selva Pré-Histórica Viva")
@export var jungle_sky_top: Color = Color("163e34")
@export var jungle_sky_horizon: Color = Color("2a7050")
@export var jungle_ground: Color = Color("285a34")
@export var jungle_canopy: Color = Color("4a9944")

@export_group("Fase 3 — Brasa & Meteoro")
@export var ember_sky_top: Color = Color("4f1209")
@export var ember_sky_horizon: Color = Color("c94216")
@export var ember_ground: Color = Color("662211")
@export var ember_canopy: Color = Color("e25f1f")

@export_group("UI e Destaque")
@export var amber_highlight: Color = Color("f6b23d")
@export var parchment_text: Color = Color("faecd0")
@export var frame_border: Color = Color("a8702b")


func get_jungle_factor(depth: int, era_index: int) -> float:
	var by_depth: float = float(maxi(depth, 0)) / 14.0
	var by_era: float = float(maxi(era_index, 0)) * 0.25
	var by_prog: float = GameState.color_progress * 0.45
	return clampf(maxf(by_depth + by_era, by_prog), 0.0, 1.0)


func sample_sky_color(depth: int, era_index: int, danger: float) -> Color:
	var j: float = get_jungle_factor(depth, era_index)
	var base_sky: Color = sepia_sky_top.lerp(jungle_sky_top, j)
	return base_sky.lerp(ember_sky_top, clampf(danger, 0.0, 1.0))


func sample_horizon_color(depth: int, era_index: int, danger: float) -> Color:
	var j: float = get_jungle_factor(depth, era_index)
	var base_hor: Color = sepia_sky_horizon.lerp(jungle_sky_horizon, j)
	return base_hor.lerp(ember_sky_horizon, clampf(danger, 0.0, 1.0))


func sample_ground_color(depth: int, era_index: int, danger: float) -> Color:
	var j: float = get_jungle_factor(depth, era_index)
	var base_gnd: Color = sepia_ground.lerp(jungle_ground, j)
	return base_gnd.lerp(ember_ground, clampf(danger, 0.0, 1.0) * 0.55)


func sample_canopy_color(depth: int, era_index: int, danger: float) -> Color:
	var j: float = get_jungle_factor(depth, era_index)
	var base_can: Color = sepia_canopy.lerp(jungle_canopy, j)
	return base_can.lerp(ember_canopy, clampf(danger, 0.0, 1.0) * 0.65)


func sample_stratum_color(era_base: Color, depth_offset: int, danger: float) -> Color:
	var warm_tint: Color = era_base.lerp(Color("6e4522"), 0.24)
	var shifted: Color = warm_tint.darkened(clampf(float(depth_offset) * 0.14, 0.0, 0.55))
	return shifted.lerp(Color("8a2b12"), clampf(danger, 0.0, 1.0) * 0.28)
