class_name DigSite
extends Control
## Mundo em visão lateral estilo Gnorp Apologue.
##
## • Fundo escuro com estrelas e o meteoro descendo conforme o timer acaba.
## • Chão com construções clicáveis (WorldBuilding) que abrem os upgrades no próprio cenário.
## • Rocha em degraus pixelados à direita: clique para escavar. Ela encolhe com o HP
##   da camada e ganha rachaduras; a cor das bordas muda por Era.
## • Veios especiais brilhantes na rocha (GDD §3) que concedem bônus ao clicar.
## • Os dinossauros (DinoSwarm, em DinoStage) caminham até a rocha e atacam.

const MAX_FLOATING_LABELS: int = 32
const MAX_SPARKS: int = 36
const COL_W: float = 12.0
const ERA_ACCENTS: Array[Color] = [
	Color("#5FE3E8"), Color("#7CFC6A"), Color("#4FD1A5"),
	Color("#C6E05A"), Color("#FF9F43"), Color("#FF5E5E"),
]

var _dino_stage: Node2D
var _floating_container: Control
var _panel: BuildingPanel
var _buildings: Array[WorldBuilding] = []
var _info_label: Label
var _hp_bar: ProgressBar

var _ground_y: float = 800.0
var _rock_left: float = 1200.0
var _rock_face_x: float = 1250.0
var _heights: PackedFloat32Array = PackedFloat32Array()

var _hp_ratio: float = 1.0
var _hp_vis: float = 1.0
var _shake: float = 0.0
var _time: float = 0.0
var _afford_acc: float = 0.0
var _active_labels: int = 0
var _stars: Array[Vector3] = []
var _sparks: Array[Dictionary] = []

var _shard_pile_size: float = 0.0
var _vein_active: bool = false
var _vein_pos: Vector2 = Vector2.ZERO
var _vein_spawn_timer: float = 12.0
var _vein_life: float = 0.0


func _get_building_specs() -> Array[Dictionary]:
	return [
		{"kind": WorldBuilding.Kind.WORKSHOP, "title": "Oficina", "subtitle": "ferramentas de escavação", "category": 0, "w": 150.0, "h": 120.0},
		{"kind": WorldBuilding.Kind.HATCHERY, "title": "Incubadora", "subtitle": "reviva e evolua dinossauros", "category": -1, "w": 170.0, "h": 120.0},
		{"kind": WorldBuilding.Kind.FACTORY, "title": "Fábrica", "subtitle": "máquinas de escavação automática", "category": 2, "w": 180.0, "h": 130.0},
		{"kind": WorldBuilding.Kind.BUNKER, "title": "Bunker", "subtitle": "defesas contra o meteoro", "category": 3, "w": 170.0, "h": 90.0},
		{"kind": WorldBuilding.Kind.AMBER, "title": "Templo", "subtitle": "árvore de âmbar & arca", "category": -2, "w": 90.0, "h": 130.0},
	]


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	for spec: Dictionary in _get_building_specs():
		var b := WorldBuilding.new()
		b.kind = int(spec["kind"]) as WorldBuilding.Kind
		b.title = str(spec["title"])
		b.subtitle = str(spec["subtitle"])
		b.category = int(spec["category"])
		b.size = Vector2(float(spec["w"]), float(spec["h"]))
		b.clicked.connect(_on_building_clicked)
		add_child(b)
		_buildings.append(b)

	_dino_stage = Node2D.new()
	_dino_stage.name = "DinoStage"
	add_child(_dino_stage)

	_info_label = Label.new()
	_info_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UITheme.style_gnorp_label(_info_label, 14, UITheme.G_DIM)
	add_child(_info_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_bar.custom_minimum_size = Vector2(220, 10)
	_hp_bar.size = Vector2(220, 10)
	UITheme.style_gnorp_bar(_hp_bar)
	add_child(_hp_bar)

	_floating_container = Control.new()
	_floating_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_floating_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_floating_container)

	_panel = BuildingPanel.new()
	add_child(_panel)

	for _i: int in range(90):
		_stars.append(Vector3(randf(), randf() * 0.6, randf() * TAU))

	resized.connect(_layout)
	Events.dig_hit.connect(_on_any_dig_hit)
	Events.layer_hp_changed.connect(_on_layer_hp_changed)
	Events.layer_broken.connect(_on_layer_broken)
	Events.era_changed.connect(func(_e: int) -> void: _refresh_all())
	Events.loot_dropped.connect(_on_loot_dropped)
	Events.fragment_dropped.connect(_on_fragment_dropped)
	Events.prestige_modal_requested.connect(func() -> void: _panel.close())
	Events.game_loaded.connect(_refresh_all)
	_layout()
	_refresh_all()


func get_dino_stage() -> Node2D:
	return _dino_stage


func get_ground_y() -> float:
	return _ground_y


func get_rock_face_x() -> float:
	return _rock_face_x


func get_home_x_range() -> Vector2:
	return Vector2(60.0, _rock_left - 60.0)


func get_buildings() -> Array[WorldBuilding]:
	return _buildings


func open_building(index: int) -> void:
	if index >= 0 and index < _buildings.size():
		_on_building_clicked(_buildings[index])


func is_panel_open() -> bool:
	return _panel != null and _panel.visible


# ------------------------------------------------------------------ layout

func _layout() -> void:
	var vp: Vector2 = size
	if vp.x < 10.0:
		return
	_ground_y = round(vp.y - 64.0)
	_rock_left = round(vp.x * 0.70)
	var x: float = 56.0
	var gap: float = maxf(32.0, (_rock_left - 120.0 - _total_building_width()) / float(_buildings.size()))
	for b: WorldBuilding in _buildings:
		b.position = Vector2(round(x), _ground_y - b.size.y)
		x += b.size.x + gap
	_rebuild_rock()
	_update_info()


func _total_building_width() -> float:
	var t: float = 0.0
	for b: WorldBuilding in _buildings:
		t += b.size.x
	return t


func _rock_seed() -> int:
	return GameState.current_era_index * 97 + GameState.current_layer_index * 13 + 7


func _hash(i: int) -> float:
	return fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0)


func _rebuild_rock() -> void:
	var vp: Vector2 = size
	var cols: int = ceili((vp.x - _rock_left) / COL_W) + 1
	_heights.resize(cols)
	var h_max: float = vp.y * 0.58
	var h: float = h_max * lerpf(0.28, 1.0, _hp_vis)
	var seed_v: int = _rock_seed()
	_rock_face_x = vp.x
	for c: int in range(cols):
		var t: float = float(c) / float(maxi(cols - 1, 1))
		var ramp: float = smoothstep(0.0, 0.55, t)
		var noise: float = (_hash(c / 2 + seed_v) - 0.5) * 48.0
		var v: float = maxf(h * ramp + noise * ramp, 0.0)
		v = snappedf(v, 8.0)
		_heights[c] = v
		if v >= 48.0 and _rock_face_x >= vp.x:
			_rock_face_x = _rock_left + float(c) * COL_W


# ------------------------------------------------------------------ loop

func _process(delta: float) -> void:
	_time += delta
	if absf(_hp_vis - _hp_ratio) > 0.002:
		_hp_vis = lerpf(_hp_vis, _hp_ratio, minf(delta * 8.0, 1.0))
		_rebuild_rock()
	_shake = lerpf(_shake, 0.0, minf(delta * 14.0, 1.0))
	_shard_pile_size = maxf(_shard_pile_size - delta * 0.08, 0.0)

	for s: Dictionary in _sparks:
		s["t"] = float(s["t"]) + delta
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return float(s["t"]) < 0.35)

	_tick_special_vein(delta)

	_afford_acc += delta
	if _afford_acc > 0.3:
		_afford_acc = 0.0
		_update_affordable()
	queue_redraw()


func _tick_special_vein(delta: float) -> void:
	if GameState.is_impacting or _heights.is_empty():
		return
	if _vein_active:
		_vein_life -= delta
		if _vein_life <= 0.0:
			_vein_active = false
	else:
		_vein_spawn_timer -= delta
		if _vein_spawn_timer <= 0.0:
			_spawn_special_vein()


func _spawn_special_vein() -> void:
	var candidates: Array[int] = []
	for c: int in range(_heights.size()):
		if _heights[c] >= 48.0:
			candidates.append(c)
	if candidates.is_empty():
		_vein_spawn_timer = 10.0
		return
	var pick: int = candidates[randi() % candidates.size()]
	var h: float = _heights[pick]
	_vein_pos = Vector2(
		_rock_left + float(pick) * COL_W + COL_W * 0.5,
		_ground_y - h * randf_range(0.30, 0.80)
	).round()
	_vein_active = true
	_vein_life = 14.0
	_vein_spawn_timer = randf_range(18.0, 28.0)
	Events.vein_spawned.emit(get_global_transform_with_canvas() * _vein_pos)


func _update_affordable() -> void:
	for b: WorldBuilding in _buildings:
		var any: bool = false
		if b.category == -2:
			any = GameState.can_activate_ark_victory()
			if not any:
				for u: UpgradeData in GameState.get_upgrades_by_category(UpgradeData.Category.AMBER):
					if GameState.can_purchase_upgrade(u.id, 1):
						any = true
						break
		elif b.category == -1:
			for d: DinoData in GameState.get_dinos_sorted():
				if GameState.can_assemble_dino(d.id, 1):
					any = true
					break
			if not any:
				for u: UpgradeData in GameState.get_upgrades_by_category(UpgradeData.Category.DINOS):
					if GameState.is_upgrade_unlocked(u.id) and GameState.can_purchase_upgrade(u.id, 1):
						any = true
						break
		else:
			for u: UpgradeData in GameState.get_upgrades_by_category(b.category as UpgradeData.Category):
				if GameState.is_upgrade_unlocked(u.id) and GameState.can_purchase_upgrade(u.id, 1):
					any = true
					break
		b.has_affordable = any


# ------------------------------------------------------------------ draw

func _draw() -> void:
	var vp: Vector2 = size
	var fg: Color = UITheme.G_FG
	draw_rect(Rect2(Vector2.ZERO, vp), UITheme.G_BG, true)

	# Estrelas
	for s: Vector3 in _stars:
		var a: float = 0.25 + 0.35 * (0.5 + 0.5 * sin(_time * 1.5 + s.z))
		draw_rect(Rect2(round(s.x * vp.x), round(s.y * _ground_y), 2, 2), Color(fg, a), true)

	_draw_meteor(vp)

	# Chão
	draw_rect(Rect2(0, _ground_y, vp.x, vp.y - _ground_y), UITheme.G_BG_DEEP, true)
	draw_rect(Rect2(0, _ground_y, vp.x, 3), fg, true)

	_draw_decor()
	_draw_shard_pile()
	_draw_rock()
	_draw_special_vein()

	# Faíscas de impacto (estrela de 4 pontas, como no Gnorp)
	for s: Dictionary in _sparks:
		var k: float = float(s["t"]) / 0.35
		var p: Vector2 = s["p"]
		var r: float = round(6.0 + k * 18.0)
		var col := Color(fg, 1.0 - k)
		draw_rect(Rect2(p.x - 1, p.y - r, 3, r * 2.0), col, true)
		draw_rect(Rect2(p.x - r, p.y - 1, r * 2.0, 3), col, true)
		if s["crit"]:
			draw_rect(Rect2(p.x - 4, p.y - 4, 8, 8), Color(UITheme.G_WARN, 1.0 - k), true)


func _draw_meteor(vp: Vector2) -> void:
	var total: float = maxf(GameState.meteor_total_time, 1.0)
	var p: float = clampf(1.0 - GameState.meteor_time_left / total, 0.0, 1.0)
	var start := Vector2(vp.x * 0.14, 110.0)
	var end := Vector2(vp.x * 0.80, _ground_y * 0.82)
	var pos: Vector2 = start.lerp(end, p * p).round()
	var r: float = round(8.0 + p * 26.0)
	var fg: Color = UITheme.G_FG
	# Rastro pontilhado
	for i: int in range(1, 7):
		var tp: Vector2 = pos - (end - start).normalized() * float(i) * (10.0 + r * 0.6)
		var sz: float = maxf(2.0, round(r * 0.25 - float(i)))
		draw_rect(Rect2(tp - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Color(fg, 0.5 - float(i) * 0.06), true)
	# Estrela de 4 pontas branca + núcleo laranja
	var flick: float = 1.0 + 0.12 * sin(_time * 18.0)
	var long_r: float = round(r * 1.6 * flick)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(0, -long_r), pos + Vector2(r * 0.3, 0), pos + Vector2(0, long_r), pos + Vector2(-r * 0.3, 0)
	]), fg)
	draw_colored_polygon(PackedVector2Array([
		pos + Vector2(-long_r, 0), pos + Vector2(0, r * 0.3), pos + Vector2(long_r, 0), pos + Vector2(0, -r * 0.3)
	]), fg)
	var core: float = round(r * 0.55)
	draw_rect(Rect2(pos - Vector2(core, core) * 0.5, Vector2(core, core)), UITheme.G_WARN, true)


func _draw_decor() -> void:
	var fg: Color = UITheme.G_FG
	var trees: Array[float] = [_rock_left - 150.0, _rock_left - 110.0]
	for i: int in range(trees.size()):
		var tx: float = round(trees[i])
		var th: float = 70.0 + float(i) * 18.0
		draw_colored_polygon(PackedVector2Array([
			Vector2(tx - 16, _ground_y - 8), Vector2(tx, _ground_y - th), Vector2(tx + 16, _ground_y - 8)
		]), fg)
		draw_rect(Rect2(tx - 2, _ground_y - 10, 4, 10), fg, true)
	for i: int in range(10):
		var px: float = round(_hash(i + 33) * (_rock_left - 80.0))
		draw_rect(Rect2(px, _ground_y - 4, 6, 4), Color(fg, 0.6), true)


func _draw_shard_pile() -> void:
	if _shard_pile_size <= 0.05:
		return
	var base_x: float = round(_rock_face_x - 22.0)
	var steps: int = clampi(int(_shard_pile_size * 5.0), 1, 5)
	for i: int in range(steps):
		var w: float = float((steps - i) * 10 + 8)
		var y: float = _ground_y - float(i + 1) * 4.0
		draw_rect(Rect2(base_x - w * 0.5, y, w, 4.0), UITheme.G_FG, true)


func _draw_rock() -> void:
	if _heights.is_empty():
		return
	var fg: Color = UITheme.G_FG
	var accent: Color = ERA_ACCENTS[clampi(GameState.current_era_index, 0, ERA_ACCENTS.size() - 1)]
	var danger: float = clampf(GameState.danger_level, 0.0, 1.0)
	var rock_col: Color = fg.lerp(Color("#FFD0C8"), danger * 0.5)
	var off := Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake)).round()

	var prev: float = 0.0
	for c: int in range(_heights.size()):
		var h: float = _heights[c]
		var x: float = _rock_left + float(c) * COL_W + off.x
		if h > 0.0:
			draw_rect(Rect2(x, _ground_y - h + off.y, COL_W + 1.0, h), rock_col, true)
			if h > prev:
				draw_rect(Rect2(x, _ground_y - h + off.y, 4, h - prev), accent, true)
			draw_rect(Rect2(x, _ground_y - h + off.y, COL_W + 1.0, 2), accent.lerp(fg, 0.5), true)
		prev = h

	# Rachaduras conforme dano
	var dmg: float = 1.0 - _hp_ratio
	var cracks: int = int(dmg * 9.0)
	var seed_v: int = _rock_seed()
	for i: int in range(cracks):
		var cx: float = _rock_face_x + 30.0 + _hash(seed_v + i * 5) * maxf(size.x - _rock_face_x - 60.0, 20.0)
		var col_i: int = clampi(int((cx - _rock_left) / COL_W), 0, _heights.size() - 1)
		var top: float = _ground_y - _heights[col_i]
		var cy: float = top + 20.0 + _hash(seed_v + i * 7) * maxf(_heights[col_i] - 40.0, 10.0)
		var p := Vector2(cx, cy) + off
		for _s: int in range(3):
			var np := p + Vector2((_hash(int(p.x)) - 0.5) * 24.0, 10.0 + _hash(int(p.y)) * 14.0)
			draw_line(p.round(), np.round(), UITheme.G_BG, 3.0)
			p = np


func _draw_special_vein() -> void:
	if not _vein_active:
		return
	var pulse: float = 1.0 + 0.25 * sin(_time * 8.0)
	var r: float = round(10.0 * pulse)
	var pts := PackedVector2Array([
		_vein_pos + Vector2(0, -r), _vein_pos + Vector2(r, 0),
		_vein_pos + Vector2(0, r), _vein_pos + Vector2(-r, 0),
	])
	draw_colored_polygon(pts, UITheme.G_AMBER)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), UITheme.G_BG, 2.0)
	var font: Font = get_theme_default_font()
	draw_string(font, _vein_pos + Vector2(-14.0, -r - 6.0), "VEIO!", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UITheme.G_AMBER)


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_SPACE:
		_hit_rock(Vector2(_rock_face_x + 36.0, _ground_y - 72.0))
		get_viewport().set_input_as_handled()
		return
	var idx: int = -1
	match key.keycode:
		KEY_1: idx = 0
		KEY_2: idx = 1
		KEY_3: idx = 2
		KEY_4: idx = 3
		KEY_5: idx = 4
	if idx >= 0 and idx < _buildings.size():
		_on_building_clicked(_buildings[idx])
		get_viewport().set_input_as_handled()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _vein_active and mb.position.distance_to(_vein_pos) <= 44.0:
		_vein_active = false
		_sparks.append({"p": _vein_pos, "t": 0.0, "crit": true})
		GameState.crack_rock_vein(get_global_transform_with_canvas() * _vein_pos)
		_hit_rock(mb.position)
		accept_event()
		return
	if _is_on_rock(mb.position):
		_hit_rock(mb.position)
		accept_event()
	elif _panel.visible:
		_panel.close()


func _is_on_rock(p: Vector2) -> bool:
	if p.x < _rock_left or p.y > _ground_y + 4.0:
		return false
	var c: int = int((p.x - _rock_left) / COL_W)
	if c < 0 or c >= _heights.size():
		return false
	return p.y >= _ground_y - _heights[c] - 12.0


func _hit_rock(local_pos: Vector2) -> void:
	var dmg: float = GameState.get_click_damage()
	var crit_chance: float = clampf(GameState.get_stat(GameState.STAT_CLICK_CRIT_CHANCE, 0.05), 0.0, 0.95)
	var is_crit: bool = randf() < crit_chance
	if is_crit:
		dmg *= 2.5
	_shake = maxf(_shake, 5.0 if is_crit else 2.5)
	Events.dig_hit.emit(dmg, get_global_transform_with_canvas() * local_pos, is_crit)


func _on_any_dig_hit(_dmg: float, world_pos: Vector2, is_crit: bool) -> void:
	_shard_pile_size = minf(_shard_pile_size + 0.06, 1.0)
	if _sparks.size() >= MAX_SPARKS:
		return
	var local_pos: Vector2 = Vector2(_rock_face_x + 28.0, _ground_y - randf_range(28.0, 110.0))
	if world_pos != Vector2.ZERO:
		local_pos = get_global_transform_with_canvas().affine_inverse() * world_pos
	_sparks.append({"p": local_pos, "t": 0.0, "crit": is_crit})


func _on_building_clicked(b: WorldBuilding) -> void:
	if b.category == -2:
		_panel.close()
		Events.prestige_modal_requested.emit()
		return
	_panel.open_for(b)


# ------------------------------------------------------------------ state

func _refresh_all() -> void:
	_on_layer_hp_changed(GameState.layer_hp, GameState.layer_max_hp)
	_update_info()
	_rebuild_rock()


func _update_info() -> void:
	var era: EraData = GameState.get_current_era()
	if era == null:
		return
	_info_label.text = "%s · camada %d/%d · %dm" % [
		era.display_name.to_lower(), GameState.current_layer_index + 1, era.layers_count, GameState.depth
	]
	var vp: Vector2 = size
	var info_x: float = minf(round(_rock_left + 80.0), maxf(vp.x - 240.0, 20.0))
	var top_y: float = maxf(_ground_y - vp.y * 0.58 - 64.0, 120.0)
	_info_label.position = Vector2(info_x, round(top_y))
	_hp_bar.position = Vector2(info_x, round(top_y + 24.0))


func _on_layer_hp_changed(current_hp: float, max_hp: float) -> void:
	var m: float = maxf(max_hp, 1.0)
	_hp_ratio = clampf(current_hp / m, 0.0, 1.0)
	_hp_bar.max_value = m
	_hp_bar.value = clampf(current_hp, 0.0, m)


func _on_layer_broken(_era_idx: int, _layer_idx: int, _depth: int) -> void:
	_shake = 12.0
	_hp_vis = 1.0
	_vein_active = false
	_update_info()
	_rebuild_rock()


func _on_loot_dropped(res_id: StringName, amount: float, world_pos: Vector2) -> void:
	if _active_labels >= MAX_FLOATING_LABELS:
		return
	var col: Color = UITheme.G_FG if res_id == GameState.RES_BONES else Color("#5FE3E8")
	_spawn_floating_text("+%s %s" % [GameState.format_number(amount), UITheme.res_suffix(res_id)], world_pos, col)


func _on_fragment_dropped(dino_id: StringName, world_pos: Vector2) -> void:
	var data: DinoData = GameState.get_dino(dino_id)
	var dname: String = data.display_name if data != null else String(dino_id)
	_spawn_floating_text("+1 fragmento: %s" % dname.to_lower(), world_pos, UITheme.G_AMBER)


func _spawn_floating_text(text: String, global_pos: Vector2, color: Color) -> void:
	_active_labels += 1
	var lbl := Label.new()
	lbl.text = text
	UITheme.style_gnorp_label(lbl, 15, color)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floating_container.add_child(lbl)

	var local_pos: Vector2 = _floating_container.get_global_transform_with_canvas().affine_inverse() * global_pos
	if local_pos.x <= 10.0 and local_pos.y <= 10.0:
		local_pos = Vector2(_rock_face_x + 48.0, _ground_y - 110.0)
	local_pos += Vector2(randf_range(-40.0, 40.0), randf_range(-30.0, 0.0))
	lbl.position = local_pos.round()

	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", local_pos.y - 56.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.8).set_delay(0.2)
	tw.chain().tween_callback(func() -> void:
		_active_labels = maxi(_active_labels - 1, 0)
		lbl.queue_free()
	)
