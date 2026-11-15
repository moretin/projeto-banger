extends Control
## Main — cena raiz (placeholder do M0).
##
## Na integração, esta cena vai instanciar:
##   • scenes/dig_site/  → Corte lateral do solo (esquerda/centro)
##   • scenes/ui/        → HUD + Painel lateral de upgrades (direita)
##   • scenes/meteor/    → Céu, meteoro e cinemática de impacto
## Nenhuma delas se referencia: tudo passa por Events / GameState.

@onready var _status_label: Label = %StatusLabel


func _ready() -> void:
	Events.resource_changed.connect(_on_resource_changed)
	Events.meteor_timer_changed.connect(_on_meteor_timer_changed)
	_refresh()


## Debug do M0: clique em qualquer lugar = golpe na rocha.
func _gui_input(event: InputEvent) -> void:
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	if mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		Events.dig_hit.emit(GameState.get_click_damage(), mouse_event.position, false)


func _on_resource_changed(_res_id: StringName, _amount: float, _delta: float) -> void:
	_refresh()


func _on_meteor_timer_changed(_time_left: float, _total: float) -> void:
	_refresh()


func _refresh() -> void:
	var era: EraData = GameState.get_current_era()
	_status_label.text = "Fóssil Rush · M0\n\n🦴 %s   💎 %s   🧬 %s   🟠 %s\nEra: %s · Profundidade: %d · Camada: %s / %s\n☄️ %s\n\n(clique para cavar)" % [
		GameState.format_number(GameState.get_resource(GameState.RES_BONES)),
		GameState.format_number(GameState.get_resource(GameState.RES_MINERALS)),
		GameState.format_number(GameState.get_resource(GameState.RES_DNA)),
		GameState.format_number(GameState.get_resource(GameState.RES_AMBER)),
		era.display_name if era != null else "—",
		GameState.depth,
		GameState.format_number(GameState.layer_hp),
		GameState.format_number(GameState.layer_max_hp),
		GameState.format_time(GameState.meteor_time_left),
	]
