class_name FieldLandmark
extends Button
## O alvo de interação cobre a estrutura e exibe seu nome na dica de contexto.

const INK: Color = Color("#302d38")
const DARK_INK: Color = Color("#261820")
const WOOD: Color = Color("#815446")
const TIMBER: Color = Color("#c38459")
const CREAM: Color = Color("#ffdf9f")
const AMBER: Color = Color("#edaa48")
const ART_FPS: float = 24.0
const AMBER_NEST: Texture2D = preload("res://assets/sprites/surface/structures/amber_nest.png")
const STATION_ART: Dictionary = {
	&"rubble_forge": [
		preload("res://assets/sprites/surface/structures/quarry_foundation.png"),
		preload("res://assets/sprites/surface/structures/quarry_built.png"),
	],
	&"rubble_nest": [
		preload("res://assets/sprites/surface/structures/lake_foundation.png"),
		preload("res://assets/sprites/surface/structures/lake_built.png"),
	],
	&"rubble_silo": [
		preload("res://assets/sprites/surface/structures/tower_foundation.png"),
		preload("res://assets/sprites/surface/structures/tower_built.png"),
	],
	&"rubble_bunker": [
		preload("res://assets/sprites/surface/structures/university_foundation.png"),
		preload("res://assets/sprites/surface/structures/university_built.png"),
	],
	&"forest_grove": [
		preload("res://assets/sprites/surface/structures/grove_foundation.png"),
		preload("res://assets/sprites/surface/structures/grove_built.png"),
	],
	&"forest_sanctuary": [
		preload("res://assets/sprites/surface/structures/fern_foundation.png"),
		preload("res://assets/sprites/surface/structures/fern_built.png"),
	],
	&"snow_glacier": [
		preload("res://assets/sprites/surface/structures/glacier_foundation.png"),
		preload("res://assets/sprites/surface/structures/glacier_built.png"),
	],
	&"snow_observatory": [
		preload("res://assets/sprites/surface/structures/arctic_foundation.png"),
		preload("res://assets/sprites/surface/structures/arctic_built.png"),
	],
}
const ARK_STAGES: Texture2D = preload("res://assets/sprites/surface/structures/ark_stages.png")
const QUARRY_VEIN_STAGES: Texture2D = preload("res://assets/sprites/surface/structures/quarry_vein_stages.png")
const METAL_MID: Color = Color("#7d92a6")
const METAL_GLINT: Color = Color("#d7e8f5")

var station: StringName
var selected: bool = false
var phase: float = 0.0
var _frame: int = -1
var pulse: float = 0.0
var _egg_health: Label
var _built_cached: bool = false
var _clue_cached: bool = false
var _slab_broken_cached: bool = false
var _ark_active_cached: bool = false
var _slab_shatter_timer: float = 0.0
var _last_origin: Vector2 = Vector2.ZERO
var _last_factor: float = 1.0
var _text_overlay: Control = null
var _pending_fossil_label: Dictionary = {}


func _ready() -> void:
	flat = true
	texture_filter = Control.TEXTURE_FILTER_NEAREST
	for style: StringName in [&"normal", &"hover", &"pressed", &"focus", &"disabled"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_text_overlay = Control.new()
	_text_overlay.name = "CrispTextOverlay"
	_text_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text_overlay.texture_filter = Control.TEXTURE_FILTER_LINEAR
	_text_overlay.draw.connect(_on_text_overlay_draw)
	add_child(_text_overlay)
	if station == &"egg":
		_egg_health = Label.new()
		add_child(_egg_health)
		_egg_health.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		_egg_health.offset_top = -35
		_egg_health.offset_bottom = 0
		_egg_health.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_egg_health.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_egg_health.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_egg_health.texture_filter = Control.TEXTURE_FILTER_LINEAR
		_egg_health.add_theme_font_size_override("font_size", 18)
		_egg_health.add_theme_color_override("font_color", Color("#fff1ce"))
		_egg_health.add_theme_color_override("font_outline_color", INK)
		_egg_health.add_theme_constant_override("outline_size", 6)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	Events.rubble_rebuilt.connect(_on_rubble_rebuilt)
	Events.orange_rock_broken.connect(_on_orange_rock_broken)
	Events.quarry_vein_opened.connect(_on_quarry_vein_opened)
	Events.ark_module_built.connect(_on_ark_module_built)
	Events.dino_unlocked.connect(_on_dino_unlocked)
	Events.fossil_found.connect(_on_fossil_found)
	Events.run_started.connect(_on_run_or_load_changed.unbind(1))
	Events.game_loaded.connect(_on_run_or_load_changed)
	refresh()


func refresh() -> void:
	var description: String = ""
	if station == &"egg":
		var intact: bool = not GameState.orange_rock_broken
		var health: String = "%d/%d" % [ceili(GameState.orange_rock_hp), int(GameState.ORANGE_ROCK_MAX_HP)]
		description = "Ovo de âmbar · %s" % health if intact else "Ninho de âmbar"
		if _egg_health != null:
			_egg_health.text = health
			_egg_health.visible = intact
	elif station == &"ark":
		var ark_upgraded: bool = GameState.is_ark_module_built(GameState.ARK_MODULE_HULL) or GameState.get_rescued_companion_count() > 0
		_ark_active_cached = ark_upgraded
		description = "Arca dos Vivos" if ark_upgraded else "Base da Arca"
	elif GameState.RUBBLE_DEFS.has(station):
		var def: Dictionary = GameState.RUBBLE_DEFS[station] as Dictionary
		var title: String = String(def["title"])
		var built: bool = GameState.is_station_built(station)
		_built_cached = built
		if station == &"rubble_forge":
			_clue_cached = GameState.quarry_clue_active
			_slab_broken_cached = GameState.is_quarry_slab_broken()
		description = title if built else "%s (Construir)" % title
	tooltip_text = description
	accessibility_name = description
	queue_redraw()


func _on_rubble_rebuilt(rubble_id: StringName, _new_level: int) -> void:
	if rubble_id == station:
		refresh()


func _on_orange_rock_broken() -> void:
	if station == &"egg" or station == &"rubble_forge":
		refresh()


func _on_quarry_vein_opened() -> void:
	if station == &"rubble_forge":
		_slab_shatter_timer = 1.2
		pulse = 1.0
		refresh()
	elif station == &"ark":
		pulse = 0.7
		refresh()


func _on_ark_module_built(_module_id: StringName, _total_modules: int) -> void:
	if station == &"ark":
		pulse = 1.0
		refresh()


func _on_dino_unlocked(_dino_id: StringName) -> void:
	if station == &"ark":
		refresh()


func _on_fossil_found(_dino_id: StringName, _rarity: int) -> void:
	if station == &"rubble_forge":
		refresh()


func _on_run_or_load_changed() -> void:
	_slab_shatter_timer = 0.0
	pulse = 0.0
	refresh()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if station != &"egg" and GameState.RUBBLE_DEFS.has(station):
		var built_now: bool = GameState.is_station_built(station)
		if built_now != _built_cached:
			refresh()
	if station == &"rubble_forge":
		if GameState.quarry_clue_active != _clue_cached or GameState.is_quarry_slab_broken() != _slab_broken_cached:
			refresh()
	elif station == &"ark":
		var ark_now: bool = GameState.is_ark_module_built(GameState.ARK_MODULE_HULL) or GameState.get_rescued_companion_count() > 0
		if ark_now != _ark_active_cached:
			refresh()
	phase += delta
	var was_pulsing: bool = pulse > 0.0
	pulse = maxf(0.0, pulse - delta * 3.0)
	var was_shattering: bool = _slab_shatter_timer > 0.0
	_slab_shatter_timer = maxf(0.0, _slab_shatter_timer - delta)
	var flash_active: bool = (station != &"egg" and station != &"ark" and GameState.get_station_fossil_flash(station) > 0.0)
	var quarry_active: bool = (station == &"rubble_forge" and (GameState.quarry_clue_active or was_shattering or _slab_shatter_timer > 0.0))
	var egg_companion_active: bool = (station == &"egg" and GameState.quarry_ankylo_rescued)
	var keep_animating: bool = _built_cached or was_pulsing or flash_active or station == &"ark" or quarry_active or egg_companion_active
	if not keep_animating:
		return
	var frame: int = floori(phase * ART_FPS)
	var finished_burst: bool = (was_pulsing and pulse <= 0.0) or (was_shattering and _slab_shatter_timer <= 0.0)
	if frame != _frame or finished_burst:
		_frame = frame
		queue_redraw()


func _draw() -> void:
	_pending_fossil_label.clear()
	var art_size: Vector2 = Vector2(size.x, size.y - 35.0)
	var factor: float = minf(art_size.x / 84.0, art_size.y / 64.0)
	if factor <= 0.0:
		return
	var origin: Vector2 = Vector2((size.x - 84.0 * factor) / 2.0, art_size.y - factor * 64.0)
	if pulse > 0.0:
		origin.y -= roundf(sin(pulse * PI) * 2.0) * factor
	_last_origin = origin
	_last_factor = factor
	draw_set_transform(origin, 0.0, Vector2.ONE * factor)
	if station == &"egg":
		_nest()
		if GameState.quarry_ankylo_rescued and not GameState.orange_rock_broken:
			StationWorkerArt.draw_ankylo_companion_by_egg(self, phase, origin, factor)
	elif station == &"ark":
		_draw_ark_site()
	elif STATION_ART.has(station):
		var level: int = GameState.get_rubble_level(station)
		_draw_station(level)
		if level > 0 and GameState.has_station_worker(station):
			var has_gear: bool = false
			if GameState.RUBBLE_DEFS.has(station):
				var def: Dictionary = GameState.RUBBLE_DEFS[station] as Dictionary
				var gear_id: StringName = StringName(def.get("gear", &""))
				has_gear = gear_id != &"" and GameState.get_upgrade_level(gear_id) > 0
			StationWorkerArt.draw(self, station, phase, has_gear, false, origin, factor)
		var revived: int = GameState.get_station_revived_count(station)
		if revived > 0:
			StationWorkerArt.draw(self, station, phase, false, true, origin, factor)
		if station == &"rubble_forge" and _slab_shatter_timer > 0.0:
			_draw_quarry_slab_shatter()
		var flash_left: float = GameState.get_station_fossil_flash(station)
		if flash_left > 0.0:
			_draw_fossil_badge(flash_left)
	if selected or has_focus() or is_hovered():
		_box(15.0, 60.0, 54.0, 2.0, AMBER if selected else INK)
		_box(36.0, 61.0, 12.0, 2.0, CREAM)
	if _text_overlay != null:
		_text_overlay.queue_redraw()


func _box(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)


func _nest() -> void:
	var frame_x: int = 168 if GameState.orange_rock_broken else 0
	draw_texture_rect_region(AMBER_NEST, Rect2(0.0, 0.0, 84.0, 64.0), Rect2(float(frame_x), 0.0, 168.0, 128.0))
	if GameState.orange_rock_broken:
		return
	var crack: Color = Color("#743720")
	if GameState.orange_rock_hp < 7.0:
		draw_polyline(PackedVector2Array([Vector2(47.0, 17.0), Vector2(45.0, 23.0), Vector2(48.0, 29.0), Vector2(44.0, 32.0)]), crack, 1.0)
	if GameState.orange_rock_hp < 4.0:
		draw_polyline(PackedVector2Array([Vector2(44.0, 32.0), Vector2(45.0, 38.0), Vector2(38.0, 42.0), Vector2(40.0, 49.0)]), crack, 1.0)
		draw_line(Vector2(44.0, 36.0), Vector2(50.0, 39.0), crack, 1.0)


func _draw_station(level: int) -> void:
	if STATION_ART.has(station):
		var variants: Array = STATION_ART[station] as Array
		var texture: Texture2D = variants[1 if level > 0 else 0] as Texture2D
		draw_texture_rect(texture, Rect2(0.0, 0.0, 84.0, 64.0), false)
		if level <= 0:
			return
		match station:
			&"rubble_forge":
				_draw_quarry_vein_and_slab()
				if GameState.get_upgrade_level(&"tools_metal_pick") > 0:
					_draw_glint(Vector2(19.0, 32.0), 0.0)
			&"rubble_nest":
				for i: int in range(3):
					var ripple: float = fmod(phase * 0.55 + float(i) / 3.0, 1.0)
					var length: float = roundf(2.0 + ripple * 7.0)
					var x: float = 22.0 + float(i) * 12.0 - length * 0.5
					_box(x, 47.0 + float(i) * 2.0, length, 1.0, Color(0.68, 0.91, 0.81, sin(ripple * PI) * 0.32))
			&"rubble_silo":
				var gust: float = fmod(phase * 0.75, 1.0)
				_box(61.0 + roundf(gust * 13.0), 8.0, 3.0, 1.0, Color(1.0, 0.85, 0.59, sin(gust * PI) * 0.65))
			&"rubble_bunker":
				if not GameState.raw_fossil_queue.is_empty():
					_draw_glint(Vector2(44.0, 13.0), 0.5)
			&"forest_grove":
				_draw_glint(Vector2(37.0, 42.0), 0.3)
			&"forest_sanctuary":
				_draw_glint(Vector2(50.0, 41.0), 1.0)
			&"snow_glacier":
				_draw_glint(Vector2(33.0, 18.0), 0.8)
			&"snow_observatory":
				_draw_glint(Vector2(43.0, 22.0), 0.4)
		if level >= 2:
			_draw_supply_crate(Vector2(71.0 if station != &"rubble_silo" else 57.0, 53.0))


func _draw_supply_crate(pos: Vector2) -> void:
	_box(pos.x, pos.y, 8.0, 5.0, INK)
	_box(pos.x + 1.0, pos.y, 6.0, 1.0, CREAM)
	_box(pos.x + 1.0, pos.y + 1.0, 6.0, 3.0, TIMBER)
	_box(pos.x + 3.0, pos.y + 2.0, 2.0, 2.0, WOOD)


func _draw_glint(at: Vector2, offset: float) -> void:
	var strength: float = pow(maxf(sin(phase * 3.0 + offset), 0.0), 4.0)
	var sparkle: Color = Color(1.0, 0.91, 0.64, strength)
	_box(at.x - 1.5, at.y, 4.0, 1.0, sparkle)
	_box(at.x, at.y - 1.5, 1.0, 4.0, sparkle)


func _draw_metal_glint(at: Vector2, offset: float) -> void:
	var strength: float = pow(maxf(sin(phase * 3.8 + offset), 0.0), 3.0)
	var sparkle: Color = Color(METAL_GLINT.r, METAL_GLINT.g, METAL_GLINT.b, strength)
	_box(at.x - 1.5, at.y, 4.0, 1.0, sparkle)
	_box(at.x, at.y - 1.5, 1.0, 4.0, sparkle)


## Desenha os dois estágios da Arca sobre a mesma fundação.
func _draw_ark_site() -> void:
	var hull_built: bool = GameState.is_ark_module_built(GameState.ARK_MODULE_HULL)
	var frame_x: float = 168.0 if hull_built else 0.0
	draw_texture_rect_region(ARK_STAGES, Rect2(0.0, 0.0, 84.0, 64.0), Rect2(frame_x, 0.0, 168.0, 128.0))

	var companions: int = mini(GameState.get_rescued_companion_count(), 8)
	for i: int in range(companions):
		_box(12.0 + float(i) * 2.0, 54.0, 1.0, 1.0, CREAM)

	if GameState.can_activate_ark_victory():
		_draw_glint(Vector2(51.0, 15.0), 0.2)
		for i: int in range(4):
			var t: float = fposmod(phase * 0.62 + float(i) * 0.25, 1.0)
			var x: float = 37.0 + float(i) * 7.0 + sin(t * TAU + float(i)) * 2.0
			_box(roundf(x), roundf(24.0 - t * 19.0), 1.0, 1.0, Color(1.0, 0.94, 0.64, sin(t * PI)))


func _draw_quarry_vein_and_slab() -> void:
	var slab_open: bool = GameState.is_quarry_slab_broken()
	var frame_x: float = 52.0 if slab_open else 0.0
	draw_texture_rect_region(QUARRY_VEIN_STAGES, Rect2(1.0, 34.0, 26.0, 24.0), Rect2(frame_x, 0.0, 52.0, 48.0))
	if slab_open:
		_draw_metal_glint(Vector2(14.0, 47.0), 0.0)
		return
	if not GameState.quarry_clue_active:
		return

	var pulse_strength: float = 0.5 + 0.5 * sin(phase * 4.2)
	var crack: PackedVector2Array = PackedVector2Array([
		Vector2(17.0, 40.0), Vector2(12.0, 43.0), Vector2(16.0, 47.0),
		Vector2(13.0, 49.0), Vector2(16.0, 52.0), Vector2(13.0, 55.0),
	])
	draw_polyline(crack, Color(1.0, 0.70, 0.32, 0.20 + pulse_strength * 0.50), 1.0)
	for i: int in range(4):
		var t: float = fposmod(phase * 0.66 + float(i) * 0.25, 1.0)
		var dust_x: float = 8.0 + float(i) * 3.5 + sin(t * TAU + float(i)) * 1.5
		_box(roundf(dust_x), roundf(46.0 - t * 16.0), 1.0, 1.0, Color(0.98, 0.80, 0.46, sin(t * PI) * 0.65))


func _draw_quarry_slab_shatter() -> void:
	var t: float = clampf(1.0 - _slab_shatter_timer / 1.2, 0.0, 1.0)
	var center := Vector2(14.5, 46.0)
	var ring_r: float = lerpf(4.0, 28.0, ease(t, 0.45))
	var ring_a: float = (1.0 - t) * 0.90
	draw_arc(center, ring_r, 0.0, TAU, 24, Color(1.0, 0.88, 0.56, ring_a), 2.0)
	draw_arc(center, ring_r * 0.72, 0.0, TAU, 20, Color(METAL_GLINT.r, METAL_GLINT.g, METAL_GLINT.b, ring_a * 0.75), 1.2)

	var velocities: Array[Vector2] = [
		Vector2(-18.0, -24.0), Vector2(-10.0, -30.0), Vector2(4.0, -32.0), Vector2(16.0, -26.0),
		Vector2(-22.0, -12.0), Vector2(20.0, -14.0), Vector2(-12.0, -18.0), Vector2(11.0, -20.0),
	]
	var fade: float = 1.0 - smoothstep(0.65, 1.0, t)
	for ci: int in range(velocities.size()):
		var vel: Vector2 = velocities[ci]
		var pos: Vector2 = center + Vector2(vel.x * t, vel.y * t + 46.0 * t * t)
		var sz: float = (3.5 if ci % 2 == 0 else 2.6) * (1.0 - t * 0.35)
		var col: Color = Color(METAL_MID.r, METAL_MID.g, METAL_MID.b, fade) if ci % 3 == 0 else Color(0.56, 0.47, 0.44, fade)
		_box(roundf(pos.x - sz * 0.5 - 0.5), roundf(pos.y - sz * 0.5 - 0.5), sz + 1.0, sz + 1.0, Color(DARK_INK.r, DARK_INK.g, DARK_INK.b, fade))
		_box(roundf(pos.x - sz * 0.5), roundf(pos.y - sz * 0.5), sz, sz, col)


func _draw_fossil_badge(flash_left: float) -> void:
	var duration: float = maxf(GameState.STATION_FOSSIL_FLASH_DURATION, 0.1)
	var elapsed: float = clampf(duration - flash_left, 0.0, duration)
	var progress: float = clampf(elapsed / duration, 0.0, 1.0)
	var fade_in: float = clampf(elapsed / 0.08, 0.0, 1.0)
	var fade_out: float = clampf(flash_left / 0.70, 0.0, 1.0)
	var alpha: float = minf(fade_in, fade_out)

	# Escala de entrada com quique suave (0.5 -> 1.08 -> 1.0) + respiração leve.
	var pop_scale: float = 1.0
	if elapsed < 0.18:
		pop_scale = lerpf(0.50, 1.08, ease(elapsed / 0.18, 0.35))
	elif elapsed < 0.34:
		pop_scale = lerpf(1.08, 1.00, (elapsed - 0.18) / 0.16)
	else:
		pop_scale = 1.00 + sin(elapsed * 5.2) * 0.025

	var float_y: float = -progress * 7.5 - absf(sin(elapsed * 4.2)) * 1.4
	var center: Vector2 = Vector2(42.0, 14.0 + float_y)

	# 1. Halo radial dourado-âmbar suave + raios cintilantes sutis atrás do fóssil.
	var pulse_w: float = sin(phase * 8.0)
	draw_circle(center, (17.5 + pulse_w * 1.2) * pop_scale, Color(1.0, 0.72, 0.20, alpha * 0.18))
	draw_circle(center, (13.0 + pulse_w * 0.8) * pop_scale, Color(1.0, 0.86, 0.36, alpha * 0.34))
	draw_circle(center, 9.5 * pop_scale, Color(1.0, 0.95, 0.70, alpha * 0.30))
	for ray_i: int in range(4):
		var ang: float = phase * 1.2 + float(ray_i) * PI * 0.25
		var dir_v := Vector2(cos(ang), sin(ang))
		draw_line(
			center - dir_v * (14.5 * pop_scale),
			center + dir_v * (14.5 * pop_scale),
			Color(1.0, 0.92, 0.56, alpha * 0.28),
			1.0,
		)

	# 2. Partículas pixeladas douradas subindo ao redor do bloco de fóssil.
	for mi: int in range(7):
		var seed_f: float = float(mi) * 1.37
		var mote_t: float = fposmod(elapsed * 0.75 + seed_f * 0.41, 1.0)
		var mx: float = center.x + sin(seed_f * 4.2 + mote_t * 3.0) * 13.5
		var my: float = center.y + 8.0 - mote_t * 22.0
		var m_alpha: float = alpha * sin(mote_t * PI) * 0.92
		var m_sz: float = 1.5 if mi % 2 == 0 else 1.0
		var m_col: Color = Color(1.0, 0.96, 0.78, m_alpha) if mi % 2 == 0 else Color(1.0, 0.80, 0.28, m_alpha)
		_box(roundf(mx), roundf(my), m_sz, m_sz, m_col)

	# 3. Bloco de fóssil pixel art (usa textura oficial do AmberTheme com fallback artesanal).
	var block_sz: float = 24.0 * pop_scale
	var block_rect := Rect2(center - Vector2(block_sz * 0.5, block_sz * 0.5), Vector2(block_sz, block_sz))
	var fossil_tex: Texture2D = AmberTheme.get_fossil_found_texture()
	if fossil_tex != null:
		draw_texture_rect(fossil_tex, block_rect, false, Color(1.0, 1.0, 1.0, alpha))
	else:
		_draw_fossil_block_fallback(block_rect, alpha)

	# 4. Texto "Fóssil Encontrado!" agendado para o overlay nítido (LINEAR filtering).
	var font: Font = ThemeDB.fallback_font
	if font != null:
		var label_text: String = "Fóssil Encontrado!"
		var font_sz: int = clampi(roundi(13.0 + _last_factor * 0.85), 14, 18)
		var measured_w: float = font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_sz).x
		var text_w: float = maxf(measured_w + 18.0, 160.0)
		var mid_x: float = _last_origin.x + center.x * _last_factor
		var top_y: float = _last_origin.y + (center.y - block_sz * 0.52) * _last_factor - 6.0
		var text_pos := Vector2(roundf(mid_x - text_w * 0.5), roundf(top_y))
		var outline_col := Color(DARK_INK.r, DARK_INK.g, DARK_INK.b, alpha)
		var text_col := Color(1.0, 0.957, 0.769, alpha)  # #fff4c4
		_pending_fossil_label = {
			"text": label_text,
			"font_sz": font_sz,
			"text_w": text_w,
			"text_pos": text_pos,
			"alpha": alpha,
			"outline_col": outline_col,
			"text_col": text_col,
		}


func _on_text_overlay_draw() -> void:
	if _text_overlay == null or _pending_fossil_label.is_empty():
		return
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	var label_text: String = String(_pending_fossil_label["text"])
	var font_sz: int = int(_pending_fossil_label["font_sz"])
	var text_w: float = float(_pending_fossil_label["text_w"])
	var text_pos: Vector2 = _pending_fossil_label["text_pos"] as Vector2
	var alpha: float = float(_pending_fossil_label["alpha"])
	var outline_col: Color = _pending_fossil_label["outline_col"] as Color
	var text_col: Color = _pending_fossil_label["text_col"] as Color
	_text_overlay.draw_string(font, text_pos + Vector2(0.0, 1.5), label_text, HORIZONTAL_ALIGNMENT_CENTER, text_w, font_sz, Color(0.10, 0.05, 0.07, alpha * 0.75))
	_text_overlay.draw_string_outline(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, text_w, font_sz, 5, outline_col)
	_text_overlay.draw_string(font, text_pos, label_text, HORIZONTAL_ALIGNMENT_CENTER, text_w, font_sz, text_col)


func _draw_fossil_block_fallback(rect: Rect2, alpha: float) -> void:
	var s: float = rect.size.x / 24.0
	var p: Vector2 = rect.position
	_box(p.x, p.y, 24.0 * s, 24.0 * s, Color(DARK_INK.r, DARK_INK.g, DARK_INK.b, alpha))
	_box(p.x + 1.0 * s, p.y + 1.0 * s, 22.0 * s, 22.0 * s, Color(0.47, 0.29, 0.23, alpha))
	_box(p.x + 2.0 * s, p.y + 2.0 * s, 20.0 * s, 6.0 * s, Color(0.85, 0.61, 0.43, alpha))
	_box(p.x + 2.0 * s, p.y + 8.0 * s, 20.0 * s, 14.0 * s, Color(0.68, 0.42, 0.32, alpha))
	_box(p.x + 2.0 * s, p.y + 2.0 * s, 20.0 * s, 1.5 * s, Color(0.93, 0.67, 0.28, alpha))
	var bone_col := Color(0.99, 0.94, 0.80, alpha)
	var bone_sh := Color(0.84, 0.75, 0.58, alpha)
	_box(p.x + 6.0 * s, p.y + 11.0 * s, 12.0 * s, 3.0 * s, bone_col)
	_box(p.x + 5.0 * s, p.y + 9.5 * s, 3.0 * s, 2.5 * s, bone_col)
	_box(p.x + 5.0 * s, p.y + 13.0 * s, 3.0 * s, 2.5 * s, bone_sh)
	_box(p.x + 16.0 * s, p.y + 9.5 * s, 3.0 * s, 2.5 * s, bone_col)
	_box(p.x + 16.0 * s, p.y + 13.0 * s, 3.0 * s, 2.5 * s, bone_sh)
	_box(p.x + 9.0 * s, p.y + 6.0 * s, 6.0 * s, 3.0 * s, Color(1.0, 0.88, 0.54, alpha))
