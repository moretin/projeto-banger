class_name HUD
extends PanelContainer
## Barra inferior de recursos ativos da superfície, barra visual do meteoro e atalhos de modais.

const RESOURCE_DISPLAY_NAMES: Dictionary = {
	GameState.RES_ROCKS: "Rochas",
	GameState.RES_FISH: "Peixes",
	GameState.RES_FEATHERS: "Penas",
	GameState.RES_SCIENCE: "Ciência",
	GameState.RES_RAW_FOSSILS: "Fósseis Brutos",
	GameState.RES_METAL: "Metal",
	GameState.RES_SCALES: "Escamas",
	GameState.RES_BEAKS: "Bicos",
	GameState.RES_AMBER: "Âmbar",
}

const NAME_COLOR: Color = Color(0.84, 0.77, 0.66, 1.0)
const RATE_COLOR: Color = Color(0.80, 0.89, 0.71, 1.0)
const METEOR_COLOR_CALM: Color = Color(0.89, 0.62, 0.20, 0.95)
const METEOR_COLOR_WARN: Color = Color(0.96, 0.44, 0.14, 0.98)
const METEOR_COLOR_CRIT: Color = Color(0.94, 0.20, 0.14, 1.0)

@onready var _meteor_icon: TextureRect = %MeteorIcon
@onready var _meteor_bar: ProgressBar = %MeteorBar
@onready var _resources_center: HBoxContainer = %ResourcesCenter
@onready var _toast_label: Label = %ToastLabel
@onready var _museum_button: Button = %MuseumButton
@onready var _prestige_button: Button = %PrestigeButton
@onready var _settings_button: Button = %SettingsButton

var _toast_timer: float = 0.0
var _refresh_pending: bool = false
var _active_order: Array[StringName] = []
var _resource_chips: Dictionary = {}
var _meteor_fill_style: StyleBoxFlat = null


func _ready() -> void:
	_meteor_icon.texture = AmberTheme.get_icon(&"meteor")
	_setup_meteor_bar_style()

	_museum_button.icon = AmberTheme.get_icon(&"museum")
	_prestige_button.icon = AmberTheme.get_icon(&"amber")
	_settings_button.icon = AmberTheme.get_icon(&"save")

	_museum_button.pressed.connect(func() -> void: Events.museum_modal_requested.emit())
	_prestige_button.pressed.connect(func() -> void: Events.prestige_modal_requested.emit())
	_settings_button.pressed.connect(func() -> void: Events.settings_modal_requested.emit())

	Events.resource_changed.connect(_on_resource_changed)
	Events.rubble_rebuilt.connect(_on_rubble_rebuilt)
	Events.orange_rock_broken.connect(_queue_refresh)
	Events.stats_recalculated.connect(_queue_refresh)
	Events.dino_count_changed.connect(_queue_refresh.unbind(2))
	Events.era_changed.connect(_on_era_changed)
	Events.layer_broken.connect(_queue_refresh.unbind(3))
	Events.layer_hp_changed.connect(_on_layer_hp_changed)
	Events.layer_resources_extracted.connect(_on_layer_resources_extracted)
	Events.meteor_timer_changed.connect(_on_meteor_timer_changed)
	Events.danger_level_changed.connect(_on_danger_level_changed)
	Events.dino_unlocked.connect(_on_dino_unlocked)
	Events.dino_milestone_reached.connect(_on_dino_milestone_reached)
	Events.dino_fossil_completed.connect(_on_dino_fossil_completed)
	Events.vein_cracked.connect(_on_vein_cracked)
	Events.ark_victory_achieved.connect(_on_ark_victory_achieved)
	Events.notification_requested.connect(_on_notification_requested)
	Events.game_loaded.connect(_on_full_state_changed)
	Events.run_started.connect(_on_run_started)

	_sync_active_resources()
	_on_meteor_timer_changed(GameState.meteor_time_left, GameState.meteor_total_time)
	_update_meteor_bar_color(GameState.danger_level)


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_label.text = ""


func get_displayed_resources() -> Array[StringName]:
	return _active_order.duplicate()


func get_resource_chip(res_id: StringName) -> Control:
	if not _resource_chips.has(res_id):
		return null
	var entry: Dictionary = _resource_chips[res_id] as Dictionary
	return entry["root"] as Control


func _setup_meteor_bar_style() -> void:
	var base_style: StyleBox = _meteor_bar.get_theme_stylebox("fill")
	if base_style is StyleBoxFlat:
		_meteor_fill_style = (base_style as StyleBoxFlat).duplicate() as StyleBoxFlat
	else:
		_meteor_fill_style = StyleBoxFlat.new()
		_meteor_fill_style.set_corner_radius_all(4)
	_meteor_bar.add_theme_stylebox_override("fill", _meteor_fill_style)


func _update_meteor_bar_color(danger: float) -> void:
	var d: float = clampf(danger, 0.0, 1.0)
	var col: Color
	if d < 0.55:
		col = METEOR_COLOR_CALM.lerp(METEOR_COLOR_WARN, d / 0.55)
	else:
		col = METEOR_COLOR_WARN.lerp(METEOR_COLOR_CRIT, (d - 0.55) / 0.45)
	if _meteor_fill_style != null:
		_meteor_fill_style.bg_color = col
	_meteor_icon.modulate = Color.WHITE.lerp(Color(1.0, 0.72, 0.58, 1.0), d)


func _queue_refresh() -> void:
	if not _refresh_pending:
		_refresh_pending = true
		_flush_refresh.call_deferred()


func _flush_refresh() -> void:
	_refresh_pending = false
	_sync_active_resources()


func _sync_active_resources() -> void:
	var raw_active: Array[StringName] = GameState.get_active_surface_resources()
	var active: Array[StringName] = []
	for res_id: StringName in raw_active:
		if res_id == GameState.RES_BONES or res_id == GameState.RES_MINERALS or res_id == GameState.RES_DNA:
			continue
		if res_id not in active:
			active.append(res_id)

	var order_changed: bool = active.size() != _active_order.size()
	if not order_changed:
		for i: int in range(active.size()):
			if active[i] != _active_order[i]:
				order_changed = true
				break

	if order_changed:
		var to_remove: Array[StringName] = []
		for existing_key: Variant in _resource_chips:
			var existing_id: StringName = existing_key as StringName
			if existing_id not in active:
				to_remove.append(existing_id)
		for remove_id: StringName in to_remove:
			var old_entry: Dictionary = _resource_chips[remove_id] as Dictionary
			var old_root: Control = old_entry["root"] as Control
			if old_root != null:
				if old_root.get_parent() == _resources_center:
					_resources_center.remove_child(old_root)
				old_root.queue_free()
			_resource_chips.erase(remove_id)

		for idx: int in range(active.size()):
			var res_id: StringName = active[idx]
			if not _resource_chips.has(res_id):
				var entry: Dictionary = _create_resource_chip(res_id)
				_resource_chips[res_id] = entry
				_resources_center.add_child(entry["root"] as Control)
			var chip_entry: Dictionary = _resource_chips[res_id] as Dictionary
			var chip_root: Control = chip_entry["root"] as Control
			_resources_center.move_child(chip_root, idx)

		_active_order = active
		_resources_center.add_theme_constant_override("separation", 14 if active.size() >= 8 else 22)

	_refresh_all_chip_values()


func _create_resource_chip(res_id: StringName) -> Dictionary:
	var chip: HBoxContainer = HBoxContainer.new()
	chip.name = "ResourceChip_%s" % String(res_id)
	chip.set_meta(&"resource_id", res_id)
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chip.add_theme_constant_override("separation", 7)

	var icon: TextureRect = TextureRect.new()
	icon.name = "Icon"
	icon.texture = AmberTheme.get_resource_icon(res_id)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(24.0, 24.0)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chip.add_child(icon)

	var readout: VBoxContainer = VBoxContainer.new()
	readout.name = "Readout"
	readout.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	readout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	readout.add_theme_constant_override("separation", 0)
	chip.add_child(readout)

	var name_label: Label = Label.new()
	name_label.name = "ResourceName"
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	name_label.text = _get_resource_display_name(res_id)
	name_label.add_theme_color_override("font_color", NAME_COLOR)
	name_label.add_theme_font_size_override("font_size", 13)
	readout.add_child(name_label)

	var balance: HBoxContainer = HBoxContainer.new()
	balance.name = "Balance"
	balance.mouse_filter = Control.MOUSE_FILTER_IGNORE
	balance.add_theme_constant_override("separation", 6)
	readout.add_child(balance)

	var amount_label: Label = Label.new()
	amount_label.name = "AmountLabel"
	amount_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	amount_label.text = "0"
	amount_label.add_theme_color_override("font_color", AmberTheme.get_resource_color(res_id))
	amount_label.add_theme_font_size_override("font_size", 21)
	balance.add_child(amount_label)

	var rate_label: Label = Label.new()
	rate_label.name = "RateLabel"
	rate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rate_label.text = ""
	rate_label.visible = false
	rate_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rate_label.add_theme_color_override("font_color", RATE_COLOR)
	rate_label.add_theme_font_size_override("font_size", 13)
	balance.add_child(rate_label)

	return {
		"root": chip,
		"amount": amount_label,
		"rate": rate_label,
	}


func _get_resource_display_name(res_id: StringName) -> String:
	if RESOURCE_DISPLAY_NAMES.has(res_id):
		return String(RESOURCE_DISPLAY_NAMES[res_id])
	return String(GameState.RESOURCE_NAMES.get(res_id, String(res_id))).capitalize()


func _refresh_all_chip_values() -> void:
	for res_id: StringName in _active_order:
		_update_chip_value(res_id, GameState.get_resource(res_id))


func _update_chip_value(res_id: StringName, amount: float) -> void:
	if not _resource_chips.has(res_id):
		return
	var entry: Dictionary = _resource_chips[res_id] as Dictionary
	var amount_label: Label = entry["amount"] as Label
	var rate_label: Label = entry["rate"] as Label
	amount_label.text = GameState.format_number(amount)
	var rate: float = GameState.get_resource_rate(res_id)
	if rate > 0.0:
		rate_label.text = "+%s/s" % GameState.format_number(rate)
		rate_label.visible = true
	else:
		rate_label.text = ""
		rate_label.visible = false


func _on_resource_changed(res_id: StringName, amount: float, _delta: float) -> void:
	if res_id == GameState.RES_BONES or res_id == GameState.RES_MINERALS or res_id == GameState.RES_DNA:
		return
	if _resource_chips.has(res_id):
		_update_chip_value(res_id, amount)
		if res_id == GameState.RES_RAW_FOSSILS and amount <= 0.0:
			_sync_active_resources()
	elif amount > 0.0:
		_sync_active_resources()


func _on_rubble_rebuilt(_rubble_id: StringName, _new_level: int) -> void:
	_sync_active_resources()


func _on_full_state_changed() -> void:
	_sync_active_resources()
	_on_meteor_timer_changed(GameState.meteor_time_left, GameState.meteor_total_time)
	_update_meteor_bar_color(GameState.danger_level)


func _on_run_started(_run_num: int) -> void:
	_on_full_state_changed()


func _on_era_changed(_era_idx: int) -> void:
	_queue_refresh()


func _on_layer_hp_changed(_current_hp: float, _max_hp: float) -> void:
	pass


func _on_layer_resources_extracted(_era_idx: int, _bones_bonus: float, _minerals_bonus: float) -> void:
	_queue_refresh()


func _on_meteor_timer_changed(time_left: float, total_time: float) -> void:
	var max_val: float = maxf(total_time, 1.0)
	_meteor_bar.max_value = max_val
	_meteor_bar.value = clampf(time_left, 0.0, max_val)
	_update_meteor_bar_color(GameState.danger_level)


func _on_danger_level_changed(level: float) -> void:
	_update_meteor_bar_color(level)


func _on_dino_unlocked(dino_id: StringName) -> void:
	var data: DinoData = GameState.get_dino(dino_id)
	if data != null:
		show_toast("%s revivido pela primeira vez!" % data.display_name)


func _on_dino_milestone_reached(dino_id: StringName, milestone: int) -> void:
	var data: DinoData = GameState.get_dino(dino_id)
	if data != null:
		show_toast("Marco atingido: %d x %s (Produção x%s)!" % [milestone, data.display_name, GameState.format_number(data.milestone_multiplier)])


func _on_vein_cracked(bonus_bones: float, bonus_minerals: float, _dino_id: StringName) -> void:
	show_toast("Veio aberto! +%s Ossos · +%s Minérios" % [GameState.format_number(bonus_bones), GameState.format_number(bonus_minerals)])


func _on_ark_victory_achieved(run_num: int, total_amber: float) -> void:
	show_toast("Projeto Arca concluído na Run #%d! (%s Âmbar acumulado)" % [run_num, GameState.format_number(total_amber)], 6.0)


func _on_dino_fossil_completed(dino_id: StringName, current_fragments: int, required_fragments: int) -> void:
	var data: DinoData = GameState.get_dino(dino_id)
	if data != null:
		show_toast("🧩 %s completo (%d/%d)! Pronto para reviver!" % [data.get_fossil_display_name(), current_fragments, required_fragments])


func _on_notification_requested(text: String, _icon: Texture2D) -> void:
	show_toast(text)


func show_toast(text: String, duration: float = 4.0) -> void:
	_toast_label.text = _strip_system_emojis(text)
	_toast_timer = duration


static func _strip_system_emojis(raw: String) -> String:
	var out: String = ""
	for i: int in range(raw.length()):
		var cp: int = raw.unicode_at(i)
		if cp >= 0x1F000 or (cp >= 0x2600 and cp <= 0x27BF) or cp == 0xFE0F:
			continue
		out += char(cp)
	return out.strip_edges()
