extends Control
## Main — cena raiz do Fóssil Rush.
##
## Compõe o layout responsivo dividindo a tela entre:
##   • Topo: HUD (`res://scenes/ui/HUD.tscn`)
##   • Esquerda/Centro: DigSite (`res://scenes/dig_site/DigSite.tscn`) + DinoSwarm (`res://scenes/dinos/DinoSwarm.tscn`)
##   • Direita: UpgradePanel (`res://scenes/ui/UpgradePanel.tscn`)
##   • Camada de Overlay: MeteorOverlay (`res://scenes/meteor/MeteorOverlay.tscn`),
##     SaveModals (`res://scenes/ui/SaveModals.tscn`) e VfxAudioManager (`res://scenes/dig_site/VfxAudioManager.tscn`).

const DINO_SWARM_SCENE: PackedScene = preload("res://scenes/dinos/DinoSwarm.tscn")

@onready var _dig_site: DigSite = %DigSite


func _ready() -> void:
	var swarm: DinoSwarm = DINO_SWARM_SCENE.instantiate() as DinoSwarm
	_dig_site.get_dino_stage().add_child(swarm)
