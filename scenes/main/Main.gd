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
# Tremores isolados, em vez de ruido aleatorio aplicado a cada frame.
const TREMOR_START_DANGER: float = 0.72
const TREMOR_PERIOD: float = 4.5
const TREMOR_DURATION: float = 0.42
const TREMOR_MAX_PIXELS: float = 2.4

@onready var _scenario_viewport: Control = %ScenarioViewport
@onready var _surface_scene: SurfaceScene = %SurfaceScene
@onready var _dig_site: DigSite = %DigSite
@onready var _top_gear_button: Button = %TopGearButton

var _current_scenario: StringName = &"surface"
var _transition_tween: Tween
var _tremor_clock: float = 0.0


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


func _process(delta: float) -> void:
	if _transition_tween != null and _transition_tween.is_running():
		return
	var danger: float = GameState.danger_level
	if GameState.is_impacting or danger < TREMOR_START_DANGER:
		_tremor_clock = 0.0
	else:
		_tremor_clock += delta
	var offset: float = _meteor_tremor_offset(danger, _tremor_clock)
	if GameState.is_impacting:
		offset = 0.0
	_surface_scene.position.x = offset
	_dig_site.position.x = offset


## Tremor com envelope suave e pausa longa entre pulsos.
## Efeito puramente visual: nao altera o estado do jogo nem a economia.
static func _meteor_tremor_offset(danger: float, elapsed: float) -> float:
	if danger < TREMOR_START_DANGER:
		return 0.0
	var phase: float = fposmod(maxf(elapsed, 0.0), TREMOR_PERIOD)
	if phase >= TREMOR_DURATION:
		return 0.0
	var intensity: float = clampf((danger - TREMOR_START_DANGER) / (1.0 - TREMOR_START_DANGER), 0.0, 1.0)
	var envelope: float = pow(sin(PI * phase / TREMOR_DURATION), 2.0)
	return sin(phase * 37.0) * envelope * intensity * TREMOR_MAX_PIXELS


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
