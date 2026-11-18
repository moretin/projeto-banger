class_name SeismographDial
extends Control
## Dial Sismógrafo "Golpe Preciso" — mini-desafio de timing ao quebrar uma camada geológica.
##
## Acertar na faixa âmbar ou no epicentro envia o resultado ao `GameState.resolve_precise_strike`.
## Errar ou deixar o tempo zerar perde APENAS o bônus — nunca progresso, recursos ou dano já feito.

const SWEET_HALF_PERFECT: float = 0.065
const SWEET_HALF_GOOD: float = 0.19

var _active: bool = false
var _resolved: bool = false
var _in_dig_site: bool = false
var _elapsed: float = 0.0
var _result_hold: float = 0.0
var _cooldown_left: float = 0.0
var _needle_pos: float = 0.5
var _sweet_center: float = 0.5
var _status_text: String = "SISMÓGRAFO — GOLPE PRECISO (CLIQUE OU [ESPAÇO])"
var _status_color: Color = Color(0.99, 0.90, 0.68, 1.0)


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(390.0, 92.0)

	gui_input.connect(_on_gui_input)
	draw.connect(_on_draw)

	Events.scenario_changed.connect(_on_scenario_changed)
	Events.layer_broken.connect(_on_layer_broken)
	Events.run_started.connect(_on_run_started)


func _process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)

	if not _active:
		return

	if _resolved:
		_result_hold -= delta
		if _result_hold <= 0.0:
			_close_dial()
		else:
			queue_redraw()
		return

	_elapsed += delta
	_needle_pos = 0.5 + sin(_elapsed * 4.6) * 0.46
	if _elapsed >= _get_dial_duration():
		_resolve_strike(false)
	else:
		queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not _active or _resolved:
		return
	var ek: InputEventKey = event as InputEventKey
	if ek != null and ek.pressed and not ek.echo:
		if ek.keycode == KEY_SPACE or ek.keycode == KEY_ENTER:
			_resolve_strike(true)
			get_viewport().set_input_as_handled()


func _on_gui_input(event: InputEvent) -> void:
	if not _active or _resolved:
		return
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_resolve_strike(true)
		accept_event()


func _on_scenario_changed(current_scenario: StringName) -> void:
	_in_dig_site = (current_scenario == &"dig_site")
	if not _in_dig_site and _active:
		_close_dial()


func _on_layer_broken(_era_idx: int, _layer_idx: int, _depth: int) -> void:
	if not _in_dig_site:
		return
	if _cooldown_left > 0.0:
		return
	trigger_dial(false)


func _on_run_started(_run: int) -> void:
	_cooldown_left = 0.0
	_close_dial()


func _get_dial_duration() -> float:
	return GameState.balance.precise_strike_dial_duration if GameState.balance != null else 2.6


func _get_dial_cooldown() -> float:
	return GameState.balance.precise_strike_dial_cooldown if GameState.balance != null else 5.5


## Ativa o dial do sismógrafo manualmente (útil em eventos especiais e validação visual).
func trigger_dial(force: bool = true) -> void:
	if not force and _active:
		return
	_active = true
	_resolved = false
	_elapsed = 0.0
	_result_hold = 0.0
	_cooldown_left = _get_dial_cooldown()
	_sweet_center = randf_range(0.38, 0.62)
	_needle_pos = 0.08
	_status_text = "SISMÓGRAFO — GOLPE PRECISO (CLIQUE OU [ESPAÇO])"
	_status_color = Color(0.99, 0.90, 0.68, 1.0)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	queue_redraw()


func _resolve_strike(by_player: bool) -> void:
	if _resolved:
		return
	_resolved = true
	_result_hold = 0.72

	var dist: float = absf(_needle_pos - _sweet_center)
	var result: StringName = &"miss"
	if by_player and dist <= SWEET_HALF_PERFECT:
		result = &"perfect"
	elif by_player and dist <= SWEET_HALF_GOOD:
		result = &"good"

	var bonus: float = GameState.resolve_precise_strike(result, global_position + size * 0.5)
	if result == &"perfect":
		_status_text = "EPICENTRO PERFEITO! (+%s)" % GameState.format_number(bonus)
		_status_color = Color(1.0, 0.86, 0.30, 1.0)
	elif result == &"good":
		_status_text = "GOLPE FIRME! (+%s)" % GameState.format_number(bonus)
		_status_color = Color(0.55, 0.94, 0.52, 1.0)
	else:
		_status_text = "Sem ressonância extra — escavação segue firme"
		_status_color = Color(0.84, 0.72, 0.54, 0.92)

	queue_redraw()


func _close_dial() -> void:
	_active = false
	_resolved = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w <= 20.0 or h <= 20.0:
		return

	# Moldura mogno/latão do sismógrafo
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(0.14, 0.085, 0.045, 0.96))
	draw_rect(Rect2(2.0, 2.0, w - 4.0, h - 4.0), Color(0.76, 0.52, 0.20, 0.95), false, 2.0)

	var font: Font = ThemeDB.fallback_font
	if font != null:
		draw_string(font, Vector2(12.0, 20.0), _status_text, HORIZONTAL_ALIGNMENT_CENTER, w - 24.0, 12, _status_color)

	# Faixa de papel milimetrado
	var bar_x: float = 18.0
	var bar_y: float = 30.0
	var bar_w: float = w - 36.0
	var bar_h: float = 34.0
	draw_rect(Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.95, 0.88, 0.72, 0.95))

	# Linhas milimetradas sutis e onda sísmica viva
	var grid_col := Color(0.76, 0.62, 0.42, 0.35)
	for gx: int in range(1, 16):
		var lx: float = bar_x + bar_w * (float(gx) / 16.0)
		draw_line(Vector2(lx, bar_y), Vector2(lx, bar_y + bar_h), grid_col, 1.0)

	# Zona Âmbar (GOOD) e Zona Central Ouro-Rubi (PERFECT)
	var good_x0: float = bar_x + (_sweet_center - SWEET_HALF_GOOD) * bar_w
	var good_w: float = SWEET_HALF_GOOD * 2.0 * bar_w
	draw_rect(Rect2(good_x0, bar_y + 2.0, good_w, bar_h - 4.0), Color(0.92, 0.64, 0.18, 0.55))

	var perf_x0: float = bar_x + (_sweet_center - SWEET_HALF_PERFECT) * bar_w
	var perf_w: float = SWEET_HALF_PERFECT * 2.0 * bar_w
	draw_rect(Rect2(perf_x0, bar_y + 2.0, perf_w, bar_h - 4.0), Color(0.98, 0.84, 0.24, 0.92))
	draw_rect(Rect2(perf_x0, bar_y + 2.0, perf_w, bar_h - 4.0), Color(0.68, 0.18, 0.08, 0.85), false, 2.0)

	# Traço de sismógrafo oscilando atrás da agulha
	var wave_pts := PackedVector2Array()
	for s_i: int in range(28):
		var r: float = float(s_i) / 27.0
		var wx: float = bar_x + r * bar_w
		var amp: float = 4.0 + maxf(0.0, 1.0 - absf(r - _sweet_center) * 4.0) * 9.0
		var wy: float = bar_y + bar_h * 0.5 + sin(r * 24.0 + _elapsed * 18.0) * amp
		wave_pts.append(Vector2(wx, wy))
	draw_polyline(wave_pts, Color(0.28, 0.14, 0.06, 0.72), 1.6)

	# Agulha oscilante
	var nx: float = bar_x + _needle_pos * bar_w
	draw_rect(Rect2(nx - 2.5, bar_y - 3.0, 5.0, bar_h + 6.0), Color(0.16, 0.08, 0.04, 1.0))
	draw_rect(Rect2(nx - 1.0, bar_y - 1.0, 2.0, bar_h + 2.0), Color(1.0, 0.94, 0.72, 1.0))

	# Barra regressiva discreta na base
	var time_ratio: float = 1.0 - clampf(_elapsed / maxf(_get_dial_duration(), 0.01), 0.0, 1.0)
	draw_rect(Rect2(bar_x, bar_y + bar_h + 8.0, bar_w, 5.0), Color(0.09, 0.05, 0.03, 0.9))
	draw_rect(Rect2(bar_x, bar_y + bar_h + 8.0, bar_w * time_ratio, 5.0), Color(0.95, 0.68, 0.22, 0.95))
