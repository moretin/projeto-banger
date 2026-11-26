extends Control

const UPGRADE_META: Dictionary = {
	"pachy_helmet": {"short": "Elmo", "detail": "Visual: adiciona elmo dourado nos Pachys e no ninho."},
	"pachy_frenzy": {"short": "Frenesi", "detail": "Visual: rastro acelerado nas investidas."},
	"pachy_ricochet": {"short": "Ricochete", "detail": "Visual: gera estilhaços extras ao colidir."},
	"compy_pouch": {"short": "Bolsa 2x", "detail": "Visual: cristais maiores carregados nas costas."},
	"compy_sprint": {"short": "Corrida", "detail": "Visual: corrida rápida entre Pilha e Depósito."},
	"compy_magnet": {"short": "Imã +25%", "detail": "Visual: brilho magnético na entrega de estilhaços."},
	"ptero_dive": {"short": "Mergulho", "detail": "Visual: rasante veloz contra o Monólito."},
	"ptero_sky_beam": {"short": "Raio Céu", "detail": "Visual: dispara feixes âmbar diretamente no Meteoro!"},
	"ptero_flock": {"short": "Bando", "detail": "Visual: voo em formação com cadência maior."},
	"ankylo_club": {"short": "Clava", "detail": "Visual: cauda reforçada com impacto sísmico."},
	"ankylo_compress": {"short": "Pressão", "detail": "Visual: fortalece a compressão cristalina da Pilha."},
	"ankylo_quake": {"short": "Terremoto", "detail": "Visual: tremor de chão gera estilhaços extras."},
	"trex_alpha": {"short": "Alfa 2.2x", "detail": "Visual: onda dourada expansiva mais longa e forte."},
	"trex_terrify": {"short": "Terror", "detail": "Visual: aura imponente amplifica todo o enxame."},
	"trex_apex": {"short": "Lança", "detail": "Visual: mordida dispara lanças de energia no Meteoro!"},
	"cannon_barrel": {"short": "Cano +75%", "detail": "Visual: cano reforçado e feixe espesso no Meteoro."},
	"cannon_overclock": {"short": "Cadência", "detail": "Visual: recarga acelerada com faíscas contínuas."},
	"cannon_amber_core": {"short": "Núcleo", "detail": "Visual: núcleo pulsante acelera disparos por fragmentos."},
}

@onready var _valley_world: Node2D = $ValleyWorld
@onready var _lbl_fragments: Label = %FragmentsLabel
@onready var _lbl_pile: Label = %PileLabel
@onready var _lbl_compression: Label = %CompressionBadge
@onready var _lbl_amber: Label = %AmberLabel
@onready var _lbl_swarm: Label = %SwarmCountLabel
@onready var _meteor_bar: ProgressBar = %MeteorProgressBar
@onready var _lbl_meteor_hp: Label = %MeteorHpLabel
@onready var _lbl_meteor_timer: Label = %MeteorTimerLabel
@onready var _roar_badge: PanelContainer = %RoarBadge
@onready var _lbl_roar: Label = %RoarLabel

@onready var _btn_cam_monolith: Button = %CamMonolithButton
@onready var _btn_cam_pile: Button = %CamPileButton
@onready var _btn_cam_valley: Button = %CamValleyButton
@onready var _btn_cam_cannon: Button = %CamCannonButton
@onready var _btn_talents: Button = %TalentsButton
@onready var _btn_settings: Button = %SettingsButton

@onready var _hint_banner: PanelContainer = %HintBanner
@onready var _command_tray: PanelContainer = %CommandTray
@onready var _lbl_tray_status: Label = %TrayStatusLabel
@onready var _btn_tray_toggle: Button = %TrayToggleButton
@onready var _cards_scroll: ScrollContainer = %CardsScroll
@onready var _cards_row: HBoxContainer = %CardsRow

@onready var _talent_modal: Control = %TalentModal
@onready var _settings_modal: Control = %SettingsModal

@onready var _run_end_modal: Control = %RunEndModal
@onready var _lbl_run_end_title: Label = %RunEndTitle
@onready var _lbl_run_end_subtitle: Label = %RunEndSubtitle
@onready var _lbl_run_end_stats: Label = %RunEndStatsLabel
@onready var _btn_run_endless: Button = %RunEndEndlessButton
@onready var _btn_run_talents: Button = %RunEndTalentsButton
@onready var _btn_run_next: Button = %RunEndNextButton

var _tray_expanded: bool = true
var _built_struct_keys: Array[String] = []
var _card_refs: Dictionary = {}
var _empty_hint_card: PanelContainer = null
var _telemetry_timer: float = 0.0
var _edge_pan_overlay: Control = null
var _talents_btn_label: Label = null

var _style_up_owned: StyleBoxFlat = null
var _style_up_ready: StyleBoxFlat = null
var _style_up_locked: StyleBoxFlat = null
var _style_card_unbuilt: StyleBoxFlat = null
var _style_card_built: StyleBoxFlat = null


func _ready() -> void:
	_setup_hud_polish()
	_build_dynamic_styles()
	_connect_ui_signals()
	_connect_game_signals()
	_rebuild_structure_cards()
	_refresh_all_hud()
	_sync_pan_guards()


func _exit_tree() -> void:
	_clear_cards()
	_card_refs.clear()
	_built_struct_keys.clear()
	_edge_pan_overlay = null
	_talents_btn_label = null
	_style_up_owned = null
	_style_up_ready = null
	_style_up_locked = null
	_style_card_unbuilt = null
	_style_card_built = null


func _process(delta: float) -> void:
	if GnorpGame == null:
		return
	_refresh_roar_indicator()
	_refresh_hint_visibility()
	_telemetry_timer += delta
	if _telemetry_timer >= 0.25:
		_telemetry_timer = 0.0
		_refresh_tray_telemetry()
	if _edge_pan_overlay != null:
		_edge_pan_overlay.queue_redraw()


func _setup_hud_polish() -> void:
	_talents_btn_label = _btn_talents.get_node_or_null("Content/Text") as Label
	_lbl_tray_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_tray_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_lbl_tray_status.clip_text = true

	var hud_root: Control = get_node_or_null("%HudRoot") as Control
	if hud_root != null:
		_edge_pan_overlay = Control.new()
		_edge_pan_overlay.name = "EdgePanOverlay"
		_edge_pan_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_edge_pan_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_edge_pan_overlay.draw.connect(_on_draw_edge_pan_overlay)
		hud_root.add_child(_edge_pan_overlay)
		hud_root.move_child(_edge_pan_overlay, 0)


func _on_draw_edge_pan_overlay() -> void:
	if _edge_pan_overlay == null or _valley_world == null:
		return
	if not _valley_world.has_method("get_pan_indicator_state"):
		return
	var state: Dictionary = _valley_world.call("get_pan_indicator_state") as Dictionary
	var vp_size: Vector2 = _edge_pan_overlay.get_rect().size
	var mid_y: float = vp_size.y * 0.5 - 24.0
	var ls: float = float(state.get("left_strength", 0.0))
	var rs: float = float(state.get("right_strength", 0.0))
	if bool(state.get("can_left", false)) and ls > 0.02:
		var a_l: float = clampf(0.25 + ls * 0.65, 0.0, 0.9)
		_edge_pan_overlay.draw_circle(Vector2(28.0, mid_y), 18.0, Color(0.14, 0.10, 0.08, a_l * 0.55))
		_edge_pan_overlay.draw_polyline(
			PackedVector2Array([Vector2(33.0, mid_y - 9.0), Vector2(21.0, mid_y), Vector2(33.0, mid_y + 9.0)]),
			Color(1.0, 0.86, 0.44, a_l),
			3.0
		)
	if bool(state.get("can_right", false)) and rs > 0.02:
		var a_r: float = clampf(0.25 + rs * 0.65, 0.0, 0.9)
		var rx: float = vp_size.x - 28.0
		_edge_pan_overlay.draw_circle(Vector2(rx, mid_y), 18.0, Color(0.14, 0.10, 0.08, a_r * 0.55))
		_edge_pan_overlay.draw_polyline(
			PackedVector2Array([Vector2(rx - 5.0, mid_y - 9.0), Vector2(rx + 7.0, mid_y), Vector2(rx - 5.0, mid_y + 9.0)]),
			Color(1.0, 0.86, 0.44, a_r),
			3.0
		)


func _sync_pan_guards() -> void:
	if _valley_world != null and _valley_world.has_method("set_hud_pan_guards"):
		_valley_world.call("set_hud_pan_guards", 82.0, 224.0 if _tray_expanded else 56.0)


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	if key.keycode == KEY_M and key.ctrl_pressed and key.shift_pressed:
		if GnorpGame != null:
			GnorpGame.fast_forward_meteor(3.0)
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_ESCAPE:
		if _talent_modal.visible:
			_talent_modal.call("close_modal")
			get_viewport().set_input_as_handled()
		elif _settings_modal.visible:
			_settings_modal.call("close_modal")
			get_viewport().set_input_as_handled()


func _build_dynamic_styles() -> void:
	_style_up_owned = StyleBoxFlat.new()
	_style_up_owned.bg_color = Color(0.15, 0.34, 0.23, 1.0)
	_style_up_owned.border_color = Color(0.42, 0.84, 0.56, 1.0)
	_style_up_owned.set_border_width_all(1)
	_style_up_owned.border_width_bottom = 2
	_style_up_owned.set_corner_radius_all(4)
	_style_up_owned.set_content_margin_all(4)

	_style_up_ready = StyleBoxFlat.new()
	_style_up_ready.bg_color = Color(0.85, 0.65, 0.34, 1.0)
	_style_up_ready.border_color = Color(0.98, 0.84, 0.50, 1.0)
	_style_up_ready.set_border_width_all(1)
	_style_up_ready.border_width_bottom = 2
	_style_up_ready.set_corner_radius_all(4)
	_style_up_ready.set_content_margin_all(4)

	_style_up_locked = StyleBoxFlat.new()
	_style_up_locked.bg_color = Color(0.13, 0.20, 0.18, 1.0)
	_style_up_locked.border_color = Color(0.27, 0.37, 0.34, 1.0)
	_style_up_locked.set_border_width_all(1)
	_style_up_locked.set_corner_radius_all(4)
	_style_up_locked.set_content_margin_all(4)

	_style_card_unbuilt = StyleBoxFlat.new()
	_style_card_unbuilt.bg_color = Color(0.12, 0.19, 0.18, 0.96)
	_style_card_unbuilt.border_color = Color(0.68, 0.52, 0.30, 1.0)
	_style_card_unbuilt.set_border_width_all(1)
	_style_card_unbuilt.border_width_left = 3
	_style_card_unbuilt.set_corner_radius_all(6)
	_style_card_unbuilt.set_content_margin_all(8)

	_style_card_built = StyleBoxFlat.new()
	_style_card_built.bg_color = Color(0.14, 0.22, 0.20, 0.96)
	_style_card_built.border_color = Color(0.32, 0.52, 0.44, 1.0)
	_style_card_built.set_border_width_all(1)
	_style_card_built.border_width_left = 3
	_style_card_built.set_corner_radius_all(6)
	_style_card_built.set_content_margin_all(8)


func _connect_ui_signals() -> void:
	_btn_cam_monolith.pressed.connect(_focus_camera_x.bind(340.0))
	_btn_cam_pile.pressed.connect(_focus_camera_x.bind(610.0))
	_btn_cam_valley.pressed.connect(_focus_camera_x.bind(1500.0))
	_btn_cam_cannon.pressed.connect(_focus_camera_x.bind(2680.0))

	_btn_talents.pressed.connect(_open_talent_modal)
	_btn_settings.pressed.connect(_open_settings_modal)
	_btn_tray_toggle.pressed.connect(_on_toggle_tray_pressed)

	_talent_modal.connect("closed", _on_modal_closed)
	_settings_modal.connect("closed", _on_modal_closed)

	_btn_run_endless.pressed.connect(_on_run_endless_pressed)
	_btn_run_talents.pressed.connect(_open_talent_modal)
	_btn_run_next.pressed.connect(_on_run_next_pressed)


func _connect_game_signals() -> void:
	if GnorpGame == null:
		return
	GnorpGame.resources_changed.connect(_on_resources_changed)
	GnorpGame.pile_changed.connect(_on_pile_changed)
	GnorpGame.pile_compressed.connect(_on_pile_compressed)
	GnorpGame.structure_built.connect(_on_structure_built)
	GnorpGame.dino_recruited.connect(_on_dino_recruited)
	GnorpGame.upgrade_purchased.connect(_on_upgrade_purchased)
	GnorpGame.roar_triggered.connect(_on_roar_triggered)
	GnorpGame.meteor_tick.connect(_on_meteor_tick)
	GnorpGame.run_ended.connect(_on_run_ended)
	GnorpGame.run_started.connect(_on_run_started)


func _focus_camera_x(world_x: float) -> void:
	if _valley_world != null and _valley_world.has_method("focus_world_x"):
		_valley_world.call("focus_world_x", world_x)


func _sync_viewport_blocking() -> void:
	var blocked: bool = _talent_modal.visible or _settings_modal.visible or _run_end_modal.visible
	if _valley_world != null and _valley_world.has_method("set_viewport_blocking"):
		_valley_world.call("set_viewport_blocking", blocked)


func _open_talent_modal() -> void:
	_settings_modal.visible = false
	_talent_modal.call("open_modal")
	_sync_viewport_blocking()


func _open_settings_modal() -> void:
	_talent_modal.visible = false
	_settings_modal.call("open_modal")
	_sync_viewport_blocking()


func _on_modal_closed() -> void:
	_sync_viewport_blocking()


func _on_toggle_tray_pressed() -> void:
	_tray_expanded = not _tray_expanded
	_cards_scroll.visible = _tray_expanded
	if _tray_expanded:
		_command_tray.offset_top = -212.0
		_btn_tray_toggle.text = "▼ Recolher"
	else:
		_command_tray.offset_top = -44.0
		_btn_tray_toggle.text = "▲ Enxame"
	_sync_pan_guards()
	_refresh_hint_visibility()


func _refresh_all_hud() -> void:
	if GnorpGame == null:
		return
	_refresh_top_stats()
	_refresh_meteor_panel()
	_refresh_roar_indicator()
	_refresh_hint_visibility()
	_ensure_cards_match_unlocks()
	_refresh_cards_state()


func _refresh_top_stats() -> void:
	_lbl_fragments.text = GnorpGame.format_number(GnorpGame.fragments)
	var pile_cap: float = GnorpGame.get_pile_capacity()
	_lbl_pile.text = "%s/%s" % [
		GnorpGame.format_number(GnorpGame.pile_fragments),
		GnorpGame.format_number(pile_cap)
	]
	var comp_mult: float = GnorpGame.get_compression_multiplier()
	_lbl_compression.text = "C%d x%.1f" % [GnorpGame.compression_tier, comp_mult]
	_lbl_amber.text = GnorpGame.format_number(GnorpGame.amber_pure)
	_lbl_swarm.text = str(GnorpGame.get_total_dino_count())
	var can_talent: bool = GnorpGame.can_afford_any_talent()
	if _talents_btn_label != null:
		_talents_btn_label.text = "Talentos (!)" if can_talent else "Talentos"
	_btn_talents.modulate = Color(1.08, 0.98, 0.78, 1.0) if can_talent else Color.WHITE
	_refresh_tray_telemetry()


func _refresh_tray_telemetry() -> void:
	if GnorpGame == null:
		return
	var fps: float = GnorpGame.get_fragments_per_second()
	var dps: float = GnorpGame.get_meteor_dps()
	var line: String = "Run #%d · +%s/s · Total: %s" % [
		GnorpGame.run_number,
		GnorpGame.format_number(fps),
		GnorpGame.format_number(GnorpGame.total_run_fragments)
	]
	if dps > 0.05:
		line += " · Meteoro: -%s/s" % GnorpGame.format_number(dps)
	var next_struct: Dictionary = GnorpGame.get_next_locked_structure()
	if not next_struct.is_empty():
		line += " · Próx: %s (%s)" % [
			str(next_struct.get("name", "")),
			GnorpGame.format_number(float(next_struct.get("unlock_fragments", 0.0)))
		]
	_lbl_tray_status.text = line


func _refresh_meteor_panel() -> void:
	var max_hp: float = maxf(GnorpGame.meteor_max_hp, 1.0)
	_meteor_bar.max_value = max_hp
	_meteor_bar.value = clampf(GnorpGame.meteor_hp, 0.0, max_hp)
	_lbl_meteor_hp.text = "%s / %s" % [
		GnorpGame.format_number(GnorpGame.meteor_hp),
		GnorpGame.format_number(max_hp)
	]
	if GnorpGame.run_state == "endless":
		_lbl_meteor_timer.text = "INFINITO"
		_lbl_meteor_timer.add_theme_color_override("font_color", Color(0.56, 0.94, 0.72, 1.0))
	else:
		var secs: int = maxi(int(ceil(GnorpGame.meteor_time_left)), 0)
		var mins: int = secs / 60
		var rem_secs: int = secs % 60
		_lbl_meteor_timer.text = "%02d:%02d" % [mins, rem_secs]
		if secs <= 30:
			_lbl_meteor_timer.add_theme_color_override("font_color", Color(1.0, 0.42, 0.30, 1.0))
		else:
			_lbl_meteor_timer.add_theme_color_override("font_color", Color(0.98, 0.90, 0.76, 1.0))


func _refresh_roar_indicator() -> void:
	if GnorpGame.roar_time_left > 0.0:
		_roar_badge.visible = true
		_lbl_roar.text = "RUGIDO x%.1f (%ds)" % [
			GnorpGame.roar_multiplier,
			int(ceil(GnorpGame.roar_time_left))
		]
	else:
		_roar_badge.visible = false


func _refresh_hint_visibility() -> void:
	if GnorpGame == null:
		return
	var show_hint: bool = GnorpGame.total_run_fragments < 12.0 and GnorpGame.run_state == "playing"
	_hint_banner.visible = show_hint
	if show_hint:
		var tray_h: float = 212.0 if _tray_expanded else 44.0
		_hint_banner.offset_bottom = -(tray_h + 10.0)
		_hint_banner.offset_top = -(tray_h + 44.0)


func _compute_visible_struct_keys() -> Array[String]:
	var keys: Array[String] = []
	if GnorpGame == null:
		return keys
	for raw_item: Variant in GnorpGame.get_structure_list():
		var s_def: Dictionary = raw_item as Dictionary
		var s_id: String = str(s_def.get("id", ""))
		if GnorpGame.is_structure_unlocked(s_id) or GnorpGame.is_structure_built(s_id):
			var state_tag: String = "B" if GnorpGame.is_structure_built(s_id) else "U"
			keys.append("%s:%s" % [s_id, state_tag])
	return keys


func _ensure_cards_match_unlocks() -> void:
	var desired: Array[String] = _compute_visible_struct_keys()
	if desired == _built_struct_keys:
		return
	_rebuild_structure_cards()


func _clear_cards() -> void:
	if _cards_row != null:
		for child: Node in _cards_row.get_children():
			_cards_row.remove_child(child)
			child.queue_free()
	_empty_hint_card = null
	_card_refs.clear()


func _rebuild_structure_cards() -> void:
	_clear_cards()
	_built_struct_keys = _compute_visible_struct_keys()
	if GnorpGame == null:
		return

	var structs: Array = GnorpGame.get_structure_list()
	var added_count: int = 0
	for raw_item: Variant in structs:
		var s_def: Dictionary = raw_item as Dictionary
		var s_id: String = str(s_def.get("id", ""))
		var built: bool = GnorpGame.is_structure_built(s_id)
		var unlocked: bool = GnorpGame.is_structure_unlocked(s_id)
		if not built and not unlocked:
			continue
		_create_structure_card(s_def, built)
		added_count += 1

	if added_count == 0:
		var card: PanelContainer = PanelContainer.new()
		card.custom_minimum_size = Vector2(460.0, 146.0)
		card.add_theme_stylebox_override("panel", _style_card_unbuilt)
		var vbox: VBoxContainer = VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 6)
		card.add_child(vbox)
		var title: Label = Label.new()
		title.text = "Despertar do Vale"
		title.add_theme_font_size_override("font_size", 15)
		title.add_theme_color_override("font_color", Color(0.98, 0.84, 0.46, 1.0))
		vbox.add_child(title)
		var body: Label = Label.new()
		body.text = "Clique no Monólito de Âmbar à esquerda para soltar lascas e na Pilha para recolher.\nCom 12 Fragmentos, o primeiro Ninho de Dinossauros será revelado!"
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_theme_font_size_override("font_size", 12)
		vbox.add_child(body)
		_cards_row.add_child(card)
		_empty_hint_card = card


func _create_structure_card(s_def: Dictionary, built: bool) -> void:
	var s_id: String = str(s_def.get("id", ""))
	var s_name: String = str(s_def.get("name", s_id))
	var species: String = str(s_def.get("species", ""))
	var role_text: String = str(s_def.get("role", ""))
	var icon_path: String = str(s_def.get("icon", ""))

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(276.0, 162.0)
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	card.add_theme_stylebox_override("panel", _style_card_built if built else _style_card_unbuilt)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 5)
	card.add_child(vbox)

	# Header
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 7)
	vbox.add_child(header)

	var icon_tile: PanelContainer = PanelContainer.new()
	icon_tile.theme_type_variation = &"BenchIconTile"
	icon_tile.custom_minimum_size = Vector2(34.0, 34.0)
	header.add_child(icon_tile)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon_rect.custom_minimum_size = Vector2(24.0, 24.0)
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if icon_path != "" and ResourceLoader.exists(icon_path):
		icon_rect.texture = load(icon_path) as Texture2D
	icon_tile.add_child(icon_rect)

	var title_box: VBoxContainer = VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 0)
	header.add_child(title_box)

	var name_lbl: Label = Label.new()
	name_lbl.text = s_name
	name_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_lbl.add_theme_font_size_override("font_size", 13)
	name_lbl.add_theme_color_override("font_color", Color(0.98, 0.88, 0.56, 1.0))
	title_box.add_child(name_lbl)

	var role_lbl: Label = Label.new()
	role_lbl.text = role_text
	role_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	role_lbl.add_theme_font_size_override("font_size", 11)
	role_lbl.add_theme_color_override("font_color", Color(0.76, 0.86, 0.78, 1.0))
	title_box.add_child(role_lbl)

	var count_badge: Label = Label.new()
	count_badge.visible = built
	count_badge.add_theme_font_size_override("font_size", 13)
	count_badge.add_theme_color_override("font_color", Color(0.56, 0.94, 0.68, 1.0))
	header.add_child(count_badge)

	var refs: Dictionary = {
		"species": species,
		"built": built,
		"count_badge": count_badge,
		"upgrades": {},
	}

	if not built:
		var desc_lbl: Label = Label.new()
		desc_lbl.text = "%s · Desbloqueia %s no vale." % [
			str(s_def.get("dino_name", species)),
			role_text
		]
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc_lbl.add_theme_font_size_override("font_size", 11)
		vbox.add_child(desc_lbl)

		var build_btn: Button = Button.new()
		build_btn.custom_minimum_size = Vector2(0.0, 34.0)
		build_btn.focus_mode = Control.FOCUS_NONE
		build_btn.pressed.connect(_on_build_structure_pressed.bind(s_id))
		vbox.add_child(build_btn)
		refs["build_btn"] = build_btn
	else:
		var recruit_btn: Button = Button.new()
		recruit_btn.custom_minimum_size = Vector2(0.0, 30.0)
		recruit_btn.focus_mode = Control.FOCUS_NONE
		recruit_btn.pressed.connect(_on_recruit_dino_pressed.bind(s_id))
		vbox.add_child(recruit_btn)
		refs["recruit_btn"] = recruit_btn

		var up_row: HBoxContainer = HBoxContainer.new()
		up_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		up_row.add_theme_constant_override("separation", 4)
		vbox.add_child(up_row)

		var upgrades: Array = GnorpGame.get_upgrades_for_structure(s_id)
		var up_map: Dictionary = {}
		for raw_up: Variant in upgrades:
			var up_def: Dictionary = raw_up as Dictionary
			var up_id: String = str(up_def.get("id", ""))
			var up_icon_path: String = str(up_def.get("icon", ""))
			var up_btn: Button = Button.new()
			up_btn.custom_minimum_size = Vector2(82.0, 48.0)
			up_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			up_btn.focus_mode = Control.FOCUS_NONE
			up_btn.pressed.connect(_on_buy_upgrade_pressed.bind(up_id))

			var btn_vbox: VBoxContainer = VBoxContainer.new()
			btn_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			btn_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
			btn_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
			btn_vbox.add_theme_constant_override("separation", 1)
			up_btn.add_child(btn_vbox)

			var top_line: HBoxContainer = HBoxContainer.new()
			top_line.alignment = BoxContainer.ALIGNMENT_CENTER
			top_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			top_line.add_theme_constant_override("separation", 3)
			btn_vbox.add_child(top_line)

			var up_icon: TextureRect = TextureRect.new()
			up_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			up_icon.custom_minimum_size = Vector2(14.0, 14.0)
			up_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			up_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			up_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			up_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			if up_icon_path != "" and ResourceLoader.exists(up_icon_path):
				up_icon.texture = load(up_icon_path) as Texture2D
			top_line.add_child(up_icon)

			var up_name_lbl: Label = Label.new()
			up_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			up_name_lbl.add_theme_font_size_override("font_size", 11)
			top_line.add_child(up_name_lbl)

			var up_cost_lbl: Label = Label.new()
			up_cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			up_cost_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			up_cost_lbl.add_theme_font_size_override("font_size", 10)
			btn_vbox.add_child(up_cost_lbl)

			up_row.add_child(up_btn)
			up_map[up_id] = {
				"button": up_btn,
				"name_lbl": up_name_lbl,
				"cost_lbl": up_cost_lbl,
				"def": up_def,
			}
		refs["upgrades"] = up_map

	_cards_row.add_child(card)
	_card_refs[s_id] = refs


func _refresh_cards_state() -> void:
	if GnorpGame == null:
		return
	for raw_key: Variant in _card_refs:
		var s_id: String = str(raw_key)
		var refs: Dictionary = _card_refs[s_id] as Dictionary
		var built: bool = bool(refs.get("built", false))
		var s_def: Dictionary = GnorpGame.get_structure_def(s_id)
		var species: String = str(refs.get("species", ""))

		if not built:
			var build_btn: Button = refs.get("build_btn") as Button
			if build_btn != null:
				var cost: float = GnorpGame.get_structure_cost(s_id)
				build_btn.text = "Construir (%s)" % GnorpGame.format_number(cost)
				build_btn.disabled = GnorpGame.fragments < cost
			continue

		var count: int = GnorpGame.get_dino_count(species)
		var max_dinos: int = int(s_def.get("max_dinos", 10))
		var badge: Label = refs.get("count_badge") as Label
		if badge != null:
			badge.text = "x%d" % count

		var recruit_btn: Button = refs.get("recruit_btn") as Button
		if recruit_btn != null:
			if count >= max_dinos:
				recruit_btn.text = "Enxame Máx (%d/%d)" % [count, max_dinos]
				recruit_btn.disabled = true
			else:
				var r_cost: float = GnorpGame.get_dino_cost(s_id)
				recruit_btn.text = "+ Recrutar (%s) %d/%d" % [
					GnorpGame.format_number(r_cost),
					count,
					max_dinos
				]
				recruit_btn.disabled = GnorpGame.fragments < r_cost

		var up_map: Dictionary = refs.get("upgrades", {}) as Dictionary
		for raw_uid: Variant in up_map:
			var up_id: String = str(raw_uid)
			var entry: Dictionary = up_map[up_id] as Dictionary
			var up_btn: Button = entry["button"] as Button
			var up_name_lbl: Label = entry["name_lbl"] as Label
			var up_cost_lbl: Label = entry["cost_lbl"] as Label
			var up_def: Dictionary = entry["def"] as Dictionary
			var meta: Dictionary = UPGRADE_META.get(up_id, {}) as Dictionary
			var short_name: String = str(meta.get("short", str(up_def.get("short", up_def.get("name", up_id)))))
			var detail: String = str(meta.get("detail", ""))
			var full_name: String = str(up_def.get("name", short_name))
			var desc: String = str(up_def.get("desc", ""))
			var up_cost: float = GnorpGame.get_upgrade_cost(up_id)
			var owned: bool = GnorpGame.is_upgrade_owned(up_id)

			if owned:
				up_name_lbl.text = "✓ %s" % short_name
				up_cost_lbl.text = "ATIVO"
				up_name_lbl.add_theme_color_override("font_color", Color(0.68, 0.96, 0.74, 1.0))
				up_cost_lbl.add_theme_color_override("font_color", Color(0.56, 0.90, 0.64, 1.0))
				up_btn.disabled = true
				up_btn.add_theme_stylebox_override("disabled", _style_up_owned)
				up_btn.tooltip_text = "%s [COMPRADO]\n%s\n%s" % [full_name, desc, detail]
			else:
				var can_buy: bool = GnorpGame.fragments >= up_cost
				up_name_lbl.text = short_name
				up_cost_lbl.text = GnorpGame.format_number(up_cost)
				up_btn.disabled = not can_buy
				if can_buy:
					up_name_lbl.add_theme_color_override("font_color", Color(0.12, 0.09, 0.06, 1.0))
					up_cost_lbl.add_theme_color_override("font_color", Color(0.18, 0.12, 0.06, 1.0))
					up_btn.add_theme_stylebox_override("normal", _style_up_ready)
					up_btn.tooltip_text = "%s [DISPONÍVEL — %s Frag.]\n%s\n%s" % [
						full_name,
						GnorpGame.format_number(up_cost),
						desc,
						detail
					]
				else:
					up_name_lbl.add_theme_color_override("font_color", Color(0.74, 0.80, 0.76, 1.0))
					up_cost_lbl.add_theme_color_override("font_color", Color(0.64, 0.72, 0.68, 1.0))
					up_btn.add_theme_stylebox_override("disabled", _style_up_locked)
					up_btn.tooltip_text = "%s [Faltam Fragmentos — %s]\n%s\n%s" % [
						full_name,
						GnorpGame.format_number(up_cost),
						desc,
						detail
					]


func _on_build_structure_pressed(struct_id: String) -> void:
	if GnorpGame != null:
		GnorpGame.build_structure(struct_id)
		_focus_struct_if_needed(struct_id)


func _focus_struct_if_needed(struct_id: String) -> void:
	var s_def: Dictionary = GnorpGame.get_structure_def(struct_id)
	if not s_def.is_empty():
		_focus_camera_x(float(s_def.get("world_x", 1500.0)))


func _on_recruit_dino_pressed(struct_id: String) -> void:
	if GnorpGame != null:
		GnorpGame.recruit_dino(struct_id)


func _on_buy_upgrade_pressed(upgrade_id: String) -> void:
	if GnorpGame != null:
		GnorpGame.buy_upgrade(upgrade_id)


func _on_resources_changed() -> void:
	_refresh_top_stats()
	_refresh_hint_visibility()
	_ensure_cards_match_unlocks()
	_refresh_cards_state()


func _on_pile_changed(_pile_amount: float, _tier: int, _capacity: float) -> void:
	_refresh_top_stats()


func _on_pile_compressed(_new_tier: int, _multiplier: float) -> void:
	_refresh_top_stats()


func _on_structure_built(_struct_id: String, _world_x: float) -> void:
	_rebuild_structure_cards()
	_refresh_all_hud()


func _on_dino_recruited(_species_id: String, _new_count: int, _struct_x: float) -> void:
	_refresh_top_stats()
	_refresh_cards_state()


func _on_upgrade_purchased(_upgrade_id: String) -> void:
	_refresh_top_stats()
	_refresh_cards_state()


func _on_roar_triggered(_duration: float, _multiplier: float) -> void:
	_refresh_roar_indicator()


func _on_meteor_tick(_time_left: float, _hp: float, _max_hp: float) -> void:
	_refresh_meteor_panel()


func _on_run_ended(outcome: String, amber_earned: float) -> void:
	_run_end_modal.visible = true
	if outcome == "victory":
		_lbl_run_end_title.text = "METEORO DESTRUÍDO! VITÓRIA!"
		_lbl_run_end_title.add_theme_color_override("font_color", Color(0.56, 0.96, 0.68, 1.0))
		_lbl_run_end_subtitle.text = "Seu enxame pulverizou o meteoro em órbita! O bônus de Âmbar Puro foi recolhido."
		_btn_run_endless.visible = true
		_btn_run_next.text = "Nova Run (+Prestígio)"
	else:
		_lbl_run_end_title.text = "O METEORO ATINGIU O VALE!"
		_lbl_run_end_title.add_theme_color_override("font_color", Color(1.0, 0.56, 0.36, 1.0))
		_lbl_run_end_subtitle.text = "O impacto encerrou esta expedição, mas seu Âmbar Puro permanece intacto."
		_btn_run_endless.visible = false
		_btn_run_next.text = "Iniciar Nova Run"

	_lbl_run_end_stats.text = (
		"Fragmentos na Run: %s\n" % GnorpGame.format_number(GnorpGame.total_run_fragments)
		+ "Dinossauros no Enxame: %d\n" % GnorpGame.get_total_dino_count()
		+ "Vitórias Totais: %d\n" % GnorpGame.total_victories
		+ "Âmbar Puro Ganho: +%s (Total: %s)" % [
			GnorpGame.format_number(amber_earned),
			GnorpGame.format_number(GnorpGame.amber_pure)
		]
	)
	_sync_viewport_blocking()


func _on_run_started(_run_num: int) -> void:
	_run_end_modal.visible = false
	_rebuild_structure_cards()
	_refresh_all_hud()
	_sync_viewport_blocking()


func _on_run_endless_pressed() -> void:
	_run_end_modal.visible = false
	if GnorpGame != null:
		GnorpGame.continue_endless_mode()
	_refresh_meteor_panel()
	_sync_viewport_blocking()


func _on_run_next_pressed() -> void:
	_run_end_modal.visible = false
	if GnorpGame != null:
		GnorpGame.start_next_run(false)
	_sync_viewport_blocking()
