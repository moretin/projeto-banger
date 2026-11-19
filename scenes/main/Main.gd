extends Control
## Main — cena raiz do Fóssil Rush.
##
## Gerencia os 2 cenários verticais na área esquerda/centro (`ScenarioViewport`):
##   • Cenário 1 (Topo): `SurfaceScene` — Acampamento de Campo (Ovo de Âmbar, Compsognato Principal
##     em Pixel Art e estações reconstruíveis com Rochas).
##   • Cenário 2 (Abaixo): `DigSite` — Corte Geológico Vertical com escovação, silhuetas e câmera móvel.
## A transição entre `surface` e `dig_site` é feita suavemente via Tween vertical ao receber
## `Events.scenario_transition_requested`.

const DINO_SWARM_SCENE: PackedScene = preload("res://scenes/dinos/DinoSwarm.tscn")

@onready var _scenario_viewport: Control = %ScenarioViewport
@onready var _surface_scene: SurfaceScene = %SurfaceScene
@onready var _dig_site: DigSite = %DigSite
@onready var _top_gear_button: Button = %TopGearButton

var _current_scenario: StringName = &"surface"
var _transition_tween: Tween


func _ready() -> void:
	var swarm: DinoSwarm = DINO_SWARM_SCENE.instantiate() as DinoSwarm
	_dig_site.get_dino_stage().add_child(swarm)

	_top_gear_button.icon = AmberTheme.get_icon(&"settings")
	_top_gear_button.pressed.connect(func() -> void: Events.settings_modal_requested.emit())
	_scenario_viewport.resized.connect(_sync_scenario_layout)
	Events.scenario_transition_requested.connect(transition_to_scenario)
	Events.run_started.connect(_on_run_started)

	# Aguarda 1 frame para o container calcular o tamanho final e posiciona na Superfície.
	_sync_scenario_layout.call_deferred()


func _process(_delta: float) -> void:
	if _transition_tween != null and _transition_tween.is_running():
		return
	var d: float = GameState.danger_level
	if d >= 0.45 and not GameState.is_impacting:
		var amp: float = pow((d - 0.45) / 0.55, 1.4) * 2.8
		var jitter_x: float = randf_range(-amp, amp)
		_surface_scene.position.x = jitter_x
		_dig_site.position.x = jitter_x
	else:
		_surface_scene.position.x = 0.0
		_dig_site.position.x = 0.0


func transition_to_scenario(target: StringName) -> void:
	if target != &"surface" and target != &"dig_site":
		return
	if target == _current_scenario:
		return
	_current_scenario = target
	var h: float = _scenario_viewport.size.y
	_surface_scene.show()
	_dig_site.show()
	_surface_scene.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED if target == &"surface" else Control.FOCUS_BEHAVIOR_DISABLED
	_dig_site.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED if target == &"dig_site" else Control.FOCUS_BEHAVIOR_DISABLED

	var surface_target_y: float = 0.0 if target == &"surface" else -h
	var dig_target_y: float = h if target == &"surface" else 0.0

	if _transition_tween != null and _transition_tween.is_valid():
		_transition_tween.kill()
	_transition_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_transition_tween.tween_property(_surface_scene, "position:y", surface_target_y, 0.55)
	_transition_tween.tween_property(_dig_site, "position:y", dig_target_y, 0.55)
	_transition_tween.finished.connect(_sync_scenario_layout)
	Events.scenario_changed.emit(_current_scenario)


func _sync_scenario_layout() -> void:
	if _transition_tween != null and _transition_tween.is_running():
		return
	var sz: Vector2 = _scenario_viewport.size
	if sz.x <= 10.0 or sz.y <= 10.0:
		return
	_surface_scene.size = sz
	_dig_site.size = sz
	_surface_scene.visible = _current_scenario == &"surface"
	_dig_site.visible = _current_scenario == &"dig_site"
	if _current_scenario == &"surface":
		_surface_scene.position = Vector2.ZERO
		_dig_site.position = Vector2(0.0, sz.y)
	else:
		_surface_scene.position = Vector2(0.0, -sz.y)
		_dig_site.position = Vector2.ZERO


func _on_run_started(_run: int) -> void:
	transition_to_scenario(&"surface")
