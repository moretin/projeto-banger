extends Control
## Main — cena raiz do Fóssil Rush no estilo Gnorp Apologue.
##
## Compõe:
##   • Mundo em visão lateral: DigSite (construções clicáveis + rocha) + DinoSwarm
##   • HUD minimalista: barra superior de recursos, telemetria à esquerda, controles à direita
##   • Tela Inicial: TitleScreen (exibida ao iniciar e ao clicar no botão Home do HUD)
##   • Overlays modais: MeteorOverlay, SaveModals e VfxAudioManager

const DINO_SWARM_SCENE: PackedScene = preload("res://scenes/dinos/DinoSwarm.tscn")

@onready var _dig_site: DigSite = %DigSite
@onready var _hud: HUD = %HUD
@onready var _title_screen: TitleScreen = %TitleScreen


func _ready() -> void:
	theme = UITheme.build_gnorp_theme()

	var swarm: DinoSwarm = DINO_SWARM_SCENE.instantiate() as DinoSwarm
	_dig_site.get_dino_stage().add_child(swarm)
	swarm.setup_world(_dig_site)

	if _hud != null:
		_hud.menu_requested.connect(func() -> void:
			if _title_screen != null:
				_title_screen.visible = true
		)


func get_dig_site() -> DigSite:
	return _dig_site


func get_title_screen() -> TitleScreen:
	return _title_screen
