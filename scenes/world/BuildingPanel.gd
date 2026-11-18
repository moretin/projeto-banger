class_name BuildingPanel
extends Control
## Painel de upgrades flutuante (estilo "SLAM CLUB" do Gnorp Apologue).
## Abre acima da construção clicada, com tabela [nome | nível | custo]
## e um painel lateral de descrição ao passar o mouse sobre uma linha.

const PANEL_W: float = 560.0
const TIP_W: float = 300.0

var _building: WorldBuilding = null
var _box: PanelContainer
var _title: Label
var _subtitle: Label
var _mult_buttons: Dictionary[int, Button] = {}
var _scroll: ScrollContainer
var _grid: GridContainer
var _empty_label: Label

var _tip: PanelContainer
var _tip_action: Label
var _tip_name: Label
var _tip_desc: Label
var _tip_stats: Label

var _rows: Array[Dictionary] = []
var _row_ids: Array[StringName] = []
var _hover_index: int = -1
var _dirty: bool = true
var _acc: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	visible = false

	Events.resource_changed.connect(func(_r: StringName, _a: float, _d: float) -> void: _dirty = true)
	Events.upgrade_purchased.connect(func(_u: StringName, _l: int) -> void: _dirty = true)
	Events.fragments_changed.connect(func(_d: StringName, _a: int) -> void: _dirty = true)
	Events.dino_count_changed.connect(func(_d: StringName, _c: int) -> void: _dirty = true)
	Events.era_changed.connect(func(_e: int) -> void: _dirty = true)
	Events.buy_multiplier_changed.connect(func(m: int) -> void:
		_update_mult_buttons(m)
		_dirty = true
	)
	Events.game_loaded.connect(func() -> void: _dirty = true)


func _process(delta: float) -> void:
	if not visible:
		return
	_acc += delta
	if _dirty and _acc >= 0.12:
		_acc = 0.0
		_dirty = false
		_refresh()
	_reposition()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ public

func open_for(b: WorldBuilding) -> void:
	if _building == b and visible:
		close()
		return
	_building = b
	_title.text = b.title.to_upper()
	_subtitle.text = b.subtitle
	_row_ids.clear()
	_hover_index = -1
	_tip.visible = false
	visible = true
	_refresh()
	_update_mult_buttons(GameState.buy_multiplier)
	_box.size = Vector2(PANEL_W, 0)
	_reposition()


func close() -> void:
	visible = false
	_building = null
	_tip.visible = false


func is_open_for(b: WorldBuilding) -> bool:
	return visible and _building == b


# ------------------------------------------------------------------ build

func _build_ui() -> void:
	_box = PanelContainer.new()
	_box.mouse_filter = Control.MOUSE_FILTER_STOP
	_box.custom_minimum_size = Vector2(PANEL_W, 0)
	_box.add_theme_stylebox_override("panel", UITheme.make_gnorp_box(UITheme.G_BG, UITheme.G_FG, 2, 14, 10))
	add_child(_box)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_box.add_child(v)

	var head := HBoxContainer.new()
	v.add_child(head)
	var spacer_l := Control.new()
	spacer_l.custom_minimum_size = Vector2(32, 0)
	head.add_child(spacer_l)
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_gnorp_label(_title, 18)
	head.add_child(_title)
	var close_btn := Button.new()
	close_btn.text = "x"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.custom_minimum_size = Vector2(32, 26)
	UITheme.style_gnorp_flat(close_btn, 16)
	close_btn.pressed.connect(close)
	head.add_child(close_btn)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_gnorp_label(_subtitle, 13, UITheme.G_DIM)
	v.add_child(_subtitle)

	var mult_row := HBoxContainer.new()
	mult_row.alignment = BoxContainer.ALIGNMENT_CENTER
	mult_row.add_theme_constant_override("separation", 8)
	v.add_child(mult_row)
	var buy_lbl := Label.new()
	buy_lbl.text = "comprar:"
	UITheme.style_gnorp_label(buy_lbl, 14, UITheme.G_DIM)
	mult_row.add_child(buy_lbl)
	for m: int in [1, 10, 100, GameState.BUY_MAX]:
		var b := Button.new()
		b.text = "máx" if m == GameState.BUY_MAX else "%dx" % m
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(56, 24)
		UITheme.style_gnorp_button(b, 14)
		var mult: int = m
		b.pressed.connect(func() -> void: GameState.set_buy_multiplier(mult))
		mult_row.add_child(b)
		_mult_buttons[m] = b

	v.add_child(_hline())

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(PANEL_W - 28.0, 40.0)
	v.add_child(_scroll)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 3)
	_scroll.add_child(_grid)

	_empty_label = Label.new()
	_empty_label.text = "nada disponível ainda. escave mais fundo."
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UITheme.style_gnorp_label(_empty_label, 14, UITheme.G_DIM)
	v.add_child(_empty_label)

	# Painel lateral de descrição
	_tip = PanelContainer.new()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip.custom_minimum_size = Vector2(TIP_W, 0)
	_tip.add_theme_stylebox_override("panel", UITheme.make_gnorp_box(UITheme.G_BG, UITheme.G_FG, 2, 12, 10))
	add_child(_tip)
	var tv := VBoxContainer.new()
	tv.add_theme_constant_override("separation", 6)
	_tip.add_child(tv)
	_tip_action = Label.new()
	UITheme.style_gnorp_label(_tip_action, 14, UITheme.G_GOOD)
	tv.add_child(_tip_action)
	_tip_name = Label.new()
	UITheme.style_gnorp_label(_tip_name, 16)
	tv.add_child(_tip_name)
	_tip_desc = Label.new()
	_tip_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_desc.custom_minimum_size = Vector2(TIP_W - 24, 0)
	UITheme.style_gnorp_label(_tip_desc, 13)
	tv.add_child(_tip_desc)
	_tip_stats = Label.new()
	_tip_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_stats.custom_minimum_size = Vector2(TIP_W - 24, 0)
	UITheme.style_gnorp_label(_tip_stats, 13, UITheme.G_DIM)
	tv.add_child(_tip_stats)
	_tip.visible = false


func _hline() -> ColorRect:
	var r := ColorRect.new()
	r.color = UITheme.G_FG
	r.custom_minimum_size = Vector2(0, 2)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _update_mult_buttons(mult: int) -> void:
	for m: int in _mult_buttons:
		_mult_buttons[m].set_pressed_no_signal(m == mult)


# ------------------------------------------------------------------ rows

func _is_dino_shop() -> bool:
	return _building != null and _building.category == -1


func _collect_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	if _building == null:
		return ids
	if _is_dino_shop():
		for d: DinoData in GameState.get_dinos_sorted():
			var count: int = GameState.get_dino_count(d.id)
			var frags: int = GameState.get_fragments(d.id)
			if GameState.current_era_index >= d.unlock_era_index or frags > 0 or count > 0:
				ids.append(d.id)
		for u: UpgradeData in GameState.get_upgrades_by_category(UpgradeData.Category.DINOS):
			if GameState.is_upgrade_unlocked(u.id):
				ids.append(u.id)
	else:
		for u: UpgradeData in GameState.get_upgrades_by_category(_building.category as UpgradeData.Category):
			if GameState.is_upgrade_unlocked(u.id):
				ids.append(u.id)
	return ids


func _refresh() -> void:
	if _building == null:
		return
	var ids: Array[StringName] = _collect_ids()
	if ids != _row_ids:
		_rebuild(ids)
	for i: int in range(_rows.size()):
		_update_row(i)
	if _hover_index >= 0:
		_show_tip(_hover_index)


func _rebuild(ids: Array[StringName]) -> void:
	for c: Node in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_rows.clear()
	_row_ids = ids.duplicate()
	_empty_label.visible = ids.is_empty()
	_scroll.visible = not ids.is_empty()
	_scroll.custom_minimum_size = Vector2(PANEL_W - 28.0, minf(float(ids.size()) * 30.0 + 8.0, 320.0))

	for i: int in range(ids.size()):
		var id: StringName = ids[i]
		var is_dino: bool = GameState.get_dino(id) != null and _is_dino_shop()

		var name_lbl := Label.new()
		name_lbl.custom_minimum_size = Vector2(250, 26)
		name_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UITheme.style_gnorp_label(name_lbl, 15)

		var info_lbl := Label.new()
		info_lbl.custom_minimum_size = Vector2(90, 26)
		info_lbl.mouse_filter = Control.MOUSE_FILTER_STOP
		info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UITheme.style_gnorp_label(info_lbl, 15, UITheme.G_DIM)

		var buy := Button.new()
		buy.custom_minimum_size = Vector2(150, 26)
		buy.focus_mode = Control.FOCUS_NONE
		buy.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		UITheme.style_gnorp_flat(buy, 15)

		var idx: int = i
		for c: Control in [name_lbl, info_lbl, buy]:
			c.mouse_entered.connect(func() -> void: _show_tip(idx))
			c.mouse_exited.connect(func() -> void: _hide_tip(idx))
		buy.pressed.connect(func() -> void: _purchase(idx))
		name_lbl.gui_input.connect(func(e: InputEvent) -> void: _row_click(e, idx))

		_grid.add_child(name_lbl)
		_grid.add_child(info_lbl)
		_grid.add_child(buy)
		_rows.append({"id": id, "dino": is_dino, "name": name_lbl, "info": info_lbl, "buy": buy})


func _row_click(e: InputEvent, idx: int) -> void:
	var mb := e as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_purchase(idx)


func _purchase(idx: int) -> void:
	if idx < 0 or idx >= _rows.size():
		return
	var row: Dictionary = _rows[idx]
	var id: StringName = row["id"]
	if row["dino"]:
		Events.dino_assembly_requested.emit(id)
	else:
		Events.upgrade_purchase_requested.emit(id, GameState.buy_multiplier)
	_dirty = true


func _update_row(idx: int) -> void:
	var row: Dictionary = _rows[idx]
	var id: StringName = row["id"]
	var name_lbl: Label = row["name"]
	var info_lbl: Label = row["info"]
	var buy: Button = row["buy"]

	if row["dino"]:
		var d: DinoData = GameState.get_dino(id)
		var count: int = GameState.get_dino_count(id)
		var frags: int = GameState.get_fragments(id)
		var mult: int = GameState.buy_multiplier if count >= 1 else 1
		var amount: int = GameState.resolve_dino_purchase_amount(id, mult)
		var cost: float = GameState.get_dino_purchase_cost(id, mult)
		var can: bool = GameState.can_assemble_dino(id, mult)
		name_lbl.text = "♦ " + d.display_name
		if count == 0:
			info_lbl.text = "%d/%d frag" % [frags, d.fragments_required]
			buy.text = "reviver · %s" % GameState.format_number(cost)
		else:
			info_lbl.text = "×%d" % count
			var prefix: String = "+%d" % amount if (mult != 1 and amount > 0) else "+1"
			buy.text = "%s · %s" % [prefix, GameState.format_number(cost)]
		buy.disabled = not can
		name_lbl.add_theme_color_override("font_color", UITheme.G_FG if can else UITheme.G_DIM)
		return

	var u: UpgradeData = GameState.get_upgrade(id)
	var level: int = GameState.get_upgrade_level(id)
	name_lbl.text = "↑ " + u.display_name
	info_lbl.text = ("%d/%d" % [level, u.max_level]) if u.max_level > 0 else ("nv %d" % level)
	if u.is_maxed(level):
		buy.text = "MÁX"
		buy.disabled = true
		name_lbl.add_theme_color_override("font_color", UITheme.G_DIM)
		return
	var mult: int = GameState.buy_multiplier
	var amount: int = GameState.resolve_purchase_amount(id, mult)
	var cost_u: float = GameState.get_purchase_cost(id, mult)
	var can_u: bool = GameState.can_purchase_upgrade(id, mult)
	var prefix: String = ("+%d · " % amount) if (mult != 1 and amount > 0) else ""
	buy.text = "%s%s %s" % [prefix, GameState.format_number(cost_u), UITheme.res_suffix(u.cost_resource)]
	buy.disabled = not can_u
	name_lbl.add_theme_color_override("font_color", UITheme.G_FG if can_u else UITheme.G_DIM)


# ------------------------------------------------------------------ tooltip

func _show_tip(idx: int) -> void:
	if idx < 0 or idx >= _rows.size():
		return
	_hover_index = idx
	var row: Dictionary = _rows[idx]
	var id: StringName = row["id"]

	if row["dino"]:
		var d: DinoData = GameState.get_dino(id)
		var count: int = GameState.get_dino_count(id)
		var frags: int = GameState.get_fragments(id)
		var mult: int = GameState.buy_multiplier if count >= 1 else 1
		var amount: int = GameState.resolve_dino_purchase_amount(id, mult)
		var can: bool = GameState.can_assemble_dino(id, mult)
		if count == 0:
			_set_action("Reviver" if can else "Faltam fragmentos (%d/%d)" % [frags, d.fragments_required], can)
		else:
			_set_action("Clonar +%d" % maxi(amount, 1) if can else "Ossos insuficientes", can)
		_tip_name.text = d.display_name
		_tip_desc.text = d.description
		var unit_dps: float = GameState.get_dino_damage(id) / maxf(d.attack_interval, 0.01)
		var next_m: int = d.get_next_milestone(count)
		var lines: PackedStringArray = [
			"— DPS por unidade: %s/s" % GameState.format_number(unit_dps),
			"— DPS total: %s/s" % GameState.format_number(unit_dps * float(count)),
			"— DNA: +%s/s" % GameState.format_number(d.dna_per_second * float(count)),
			"— %s" % GameState.get_dino_synergy_description(id),
		]
		if next_m > 0:
			lines.append("— próximo marco ×2: %d/%d" % [count, next_m])
		_tip_stats.text = "\n".join(lines)
	else:
		var u: UpgradeData = GameState.get_upgrade(id)
		var level: int = GameState.get_upgrade_level(id)
		if u.is_maxed(level):
			_set_action("Máximo atingido", true)
		else:
			var can_u: bool = GameState.can_purchase_upgrade(id, GameState.buy_multiplier)
			_set_action("Comprar" if can_u else "Recursos insuficientes", can_u)
		_tip_name.text = u.display_name
		_tip_desc.text = u.description
		var lvl_txt: String = ("%d / %d" % [level, u.max_level]) if u.max_level > 0 else str(level)
		_tip_stats.text = "— nível atual: %s\n— paga com: %s" % [lvl_txt, UITheme.res_suffix(u.cost_resource)]

	_tip.visible = true
	_tip.size = Vector2(TIP_W, 0)


func _hide_tip(idx: int) -> void:
	if _hover_index == idx:
		_hover_index = -1
		_tip.visible = false


func _set_action(text: String, ok: bool) -> void:
	_tip_action.text = text
	_tip_action.add_theme_color_override("font_color", UITheme.G_GOOD if ok else UITheme.G_BAD)


# ------------------------------------------------------------------ layout

func _reposition() -> void:
	if _building == null or not is_instance_valid(_building):
		return
	var parent_rect: Rect2 = get_parent_area_size_rect()
	var anchor: Vector2 = _building.get_anchor_top() - global_position
	var box_size: Vector2 = _box.get_combined_minimum_size()
	_box.size = box_size
	var pos := Vector2(anchor.x - box_size.x * 0.5, anchor.y - box_size.y - 36.0)
	pos.x = clampf(pos.x, 12.0, maxf(parent_rect.size.x - box_size.x - TIP_W - 24.0, 12.0))
	pos.y = clampf(pos.y, 108.0, maxf(parent_rect.size.y - box_size.y - 80.0, 108.0))
	_box.position = pos.round()
	if _tip.visible:
		_tip.size = _tip.get_combined_minimum_size()
		_tip.position = (pos + Vector2(box_size.x + 10.0, 0.0)).round()


func get_parent_area_size_rect() -> Rect2:
	var p := get_parent() as Control
	if p != null:
		return Rect2(Vector2.ZERO, p.size)
	return get_viewport_rect()
