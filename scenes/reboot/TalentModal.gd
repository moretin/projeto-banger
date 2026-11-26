extends Control

signal closed

const CARD_MIN_SIZE: Vector2 = Vector2(204.0, 166.0)

@onready var _panel: PanelContainer = %TalentPanel
@onready var _lbl_amber: Label = %AmberBalanceLabel
@onready var _grid: GridContainer = %TalentGrid
@onready var _btn_close: Button = %CloseTalentButton

var _card_refs: Dictionary = {}
var _style_affordable: StyleBoxFlat = null
var _style_maxed: StyleBoxFlat = null
var _style_locked: StyleBoxFlat = null


func _ready() -> void:
	visible = false
	_build_card_styles()
	_btn_close.pressed.connect(_on_close_pressed)
	if GnorpGame != null:
		GnorpGame.talent_purchased.connect(_on_talent_or_resource_changed)
		GnorpGame.resources_changed.connect(_on_resources_changed)
		GnorpGame.run_started.connect(_on_run_started)
	resized.connect(_update_responsive_layout)
	_build_cards()
	_update_responsive_layout()


func _exit_tree() -> void:
	_card_refs.clear()
	_style_affordable = null
	_style_maxed = null
	_style_locked = null


func open_modal() -> void:
	visible = true
	_update_responsive_layout()
	refresh()


func close_modal() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func refresh() -> void:
	if GnorpGame == null:
		return
	_lbl_amber.text = "Âmbar Puro: %s" % GnorpGame.format_number(GnorpGame.amber_pure)
	var talents: Array = GnorpGame.get_talent_list()
	if _card_refs.is_empty() and not talents.is_empty():
		_build_cards()
	for raw_item: Variant in talents:
		var t_def: Dictionary = raw_item as Dictionary
		var t_id: String = str(t_def.get("id", ""))
		if not _card_refs.has(t_id):
			continue
		var refs: Dictionary = _card_refs[t_id] as Dictionary
		var card: PanelContainer = refs["card"] as PanelContainer
		var rank_lbl: Label = refs["rank"] as Label
		var btn: Button = refs["button"] as Button
		var rank: int = GnorpGame.get_talent_rank(t_id)
		var max_rank: int = int(t_def.get("max_rank", 1))
		var cost: float = float(GnorpGame.get_talent_cost(t_id))
		rank_lbl.text = "Nível %d / %d" % [rank, max_rank]
		if rank >= max_rank:
			btn.text = "DESPERTO (MÁX)"
			btn.disabled = true
			card.add_theme_stylebox_override("panel", _style_maxed)
			rank_lbl.add_theme_color_override("font_color", Color(0.58, 0.94, 0.68, 1.0))
		else:
			var can_afford: bool = GnorpGame.amber_pure >= cost
			btn.text = "Despertar (%s)" % GnorpGame.format_number(cost)
			btn.disabled = not can_afford
			if can_afford:
				card.add_theme_stylebox_override("panel", _style_affordable)
				rank_lbl.add_theme_color_override("font_color", Color(0.98, 0.80, 0.42, 1.0))
			else:
				card.add_theme_stylebox_override("panel", _style_locked)
				rank_lbl.add_theme_color_override("font_color", Color(0.76, 0.80, 0.74, 1.0))


func _build_card_styles() -> void:
	_style_affordable = StyleBoxFlat.new()
	_style_affordable.bg_color = Color(0.16, 0.25, 0.21, 1.0)
	_style_affordable.border_color = Color(0.90, 0.68, 0.34, 1.0)
	_style_affordable.set_border_width_all(2)
	_style_affordable.set_corner_radius_all(6)
	_style_affordable.set_content_margin_all(10)

	_style_maxed = StyleBoxFlat.new()
	_style_maxed.bg_color = Color(0.13, 0.27, 0.20, 1.0)
	_style_maxed.border_color = Color(0.42, 0.84, 0.56, 1.0)
	_style_maxed.set_border_width_all(2)
	_style_maxed.set_corner_radius_all(6)
	_style_maxed.set_content_margin_all(10)

	_style_locked = StyleBoxFlat.new()
	_style_locked.bg_color = Color(0.12, 0.18, 0.17, 1.0)
	_style_locked.border_color = Color(0.28, 0.38, 0.35, 1.0)
	_style_locked.set_border_width_all(1)
	_style_locked.set_corner_radius_all(6)
	_style_locked.set_content_margin_all(10)


func _build_cards() -> void:
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_card_refs.clear()
	if GnorpGame == null:
		return

	var talents: Array = GnorpGame.get_talent_list()
	for raw_item: Variant in talents:
		var t_def: Dictionary = raw_item as Dictionary
		var t_id: String = str(t_def.get("id", ""))
		var t_name: String = str(t_def.get("name", t_id))
		var t_desc: String = str(t_def.get("desc", ""))
		var t_icon: String = str(t_def.get("icon", ""))

		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = CARD_MIN_SIZE
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.size_flags_vertical = Control.SIZE_FILL
		card.add_theme_stylebox_override("panel", _style_locked)

		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		card.add_child(vbox)

		var header: HBoxContainer = HBoxContainer.new()
		header.add_theme_constant_override("separation", 6)
		vbox.add_child(header)

		if t_icon != "" and ResourceLoader.exists(t_icon):
			var icon_rect: TextureRect = TextureRect.new()
			icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon_rect.custom_minimum_size = Vector2(18.0, 18.0)
			icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.texture = load(t_icon) as Texture2D
			header.add_child(icon_rect)

		var title_lbl: Label = Label.new()
		title_lbl.text = t_name
		title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		title_lbl.add_theme_font_size_override("font_size", 14)
		title_lbl.add_theme_color_override("font_color", Color(0.98, 0.87, 0.58, 1.0))
		header.add_child(title_lbl)

		var rank_lbl: Label = Label.new()
		rank_lbl.text = "Nível 0 / 1"
		rank_lbl.add_theme_font_size_override("font_size", 12)
		header.add_child(rank_lbl)

		var desc_lbl: Label = Label.new()
		desc_lbl.text = t_desc
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc_lbl.add_theme_font_size_override("font_size", 12)
		desc_lbl.add_theme_color_override("font_color", Color(0.88, 0.86, 0.78, 1.0))
		vbox.add_child(desc_lbl)

		var btn: Button = Button.new()
		btn.custom_minimum_size = Vector2(0.0, 34.0)
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = "Despertar"
		btn.pressed.connect(_on_buy_talent_pressed.bind(t_id))
		vbox.add_child(btn)

		_grid.add_child(card)
		_card_refs[t_id] = {
			"card": card,
			"rank": rank_lbl,
			"button": btn,
		}


func _update_responsive_layout() -> void:
	if _panel == null or _grid == null:
		return
	var vp_size: Vector2 = get_viewport_rect().size
	if vp_size.x <= 10.0 or vp_size.y <= 10.0:
		return
	var target_w: float = clampf(vp_size.x - 100.0, 480.0, 980.0)
	var target_h: float = clampf(vp_size.y - 90.0, 420.0, 560.0)
	_panel.custom_minimum_size = Vector2(target_w, target_h)
	_panel.offset_left = -target_w * 0.5
	_panel.offset_right = target_w * 0.5
	_panel.offset_top = -target_h * 0.5
	_panel.offset_bottom = target_h * 0.5
	_grid.columns = 4 if target_w >= 840.0 else 2


func _on_buy_talent_pressed(talent_id: String) -> void:
	if GnorpGame != null:
		GnorpGame.buy_talent(talent_id)
		refresh()


func _on_close_pressed() -> void:
	close_modal()


func _on_talent_or_resource_changed(_talent_id: String, _new_rank: int) -> void:
	if visible:
		refresh()


func _on_resources_changed() -> void:
	if visible:
		refresh()


func _on_run_started(_run_num: int) -> void:
	if visible:
		refresh()


func _gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		var panel_rect: Rect2 = _panel.get_global_rect()
		if not panel_rect.has_point(mb.global_position):
			close_modal()
			accept_event()
