class_name SurfaceScene
extends Control

const LANDMARK: Script = preload("res://scenes/surface/FieldLandmark.gd")
# Coordenadas dos pés de cada marco no atlas de 480 × 240.
const SITES: Dictionary = {
	&"rubble_forge": Vector2(55, 128), &"rubble_nest": Vector2(157, 168),
	&"egg": Vector2(236, 135), &"rubble_silo": Vector2(317, 121),
	&"rubble_bunker": Vector2(416, 144),
}
const WORKBENCH_NAMES: Dictionary = {
	UpgradeData.Category.TOOLS: "Ferramentas", UpgradeData.Category.DINOS: "Bando",
	UpgradeData.Category.MACHINES: "Máquinas", UpgradeData.Category.DEFENSE: "Defesa",
}

@onready var _map: Control = %Map
@onready var _site_name: Label = %SiteName
@onready var _stock: Label = %Stock
@onready var _groups: HBoxContainer = %Groups
@onready var _item_title: Label = %ItemTitle
@onready var _details: Label = %Details
@onready var _actions: HBoxContainer = %ActionRow
@onready var _prev: Button = %Prev
@onready var _next: Button = %Next
@onready var _page_label: Label = %Page
@onready var _quantity: Button = %Quantity
@onready var _buy: Button = %Buy
@onready var _descend: Button = %ToDigSiteButton

var _landmarks: Dictionary = {}
var _site: StringName = &""
var _section: StringName = &""
var _items: Array[StringName] = []
var _page: int = 0
var _refresh_pending: bool = false


func _ready() -> void:
	for id: Variant in SITES:
		var spot: FieldLandmark = LANDMARK.new() as FieldLandmark
		spot.station = id
		spot.name = String(id)
		_map.add_child(spot)
		_landmarks[id] = spot
		spot.pressed.connect(_visit.bind(StringName(id)))
	_map.resized.connect(_layout_landmarks)
	_prev.pressed.connect(_turn.bind(-1))
	_next.pressed.connect(_turn.bind(1))
	_quantity.pressed.connect(GameState.cycle_buy_multiplier)
	_buy.pressed.connect(_purchase)
	_descend.pressed.connect(func() -> void: Events.scenario_transition_requested.emit(&"dig_site"))
	Events.scenario_changed.connect(_on_scenario_changed)
	Events.station_research_requested.connect(_visit_lab)
	Events.resource_changed.connect(_queue_refresh.unbind(3))
	Events.buy_multiplier_changed.connect(_queue_refresh.unbind(1))
	Events.rubble_rebuilt.connect(_queue_refresh.unbind(2))
	Events.upgrade_purchased.connect(_queue_refresh.unbind(2))
	Events.dino_count_changed.connect(_queue_refresh.unbind(2))
	Events.fragments_changed.connect(_queue_refresh.unbind(2))
	Events.era_changed.connect(_queue_refresh.unbind(1))
	Events.orange_rock_hp_changed.connect(_refresh_egg.unbind(2))
	Events.orange_rock_broken.connect(_refresh_egg)
	Events.run_started.connect(_reset_visit.unbind(1))
	Events.game_loaded.connect(_reset_visit)
	_layout_landmarks()
	_reset_visit()
	(_landmarks[&"egg"] as Button).grab_focus.call_deferred()


func _layout_landmarks() -> void:
	for id: Variant in _landmarks:
		var button: Control = _landmarks[id]
		var foot: Vector2 = (SITES[id] as Vector2) / Vector2(480, 240) * _map.size
		var width: float = _map.size.x * (0.13 if id == &"egg" else 0.187)
		var art_height: float = minf(width * 0.76, _map.size.y * 0.30)
		button.size = Vector2(width, art_height + 35)
		button.position = (foot - Vector2(width * 0.5, art_height * 0.92)).round()


func _on_scenario_changed(scenario: StringName) -> void:
	if scenario == &"surface":
		var target: Button = _landmarks.get(_site, _landmarks[&"egg"]) as Button
		target.grab_focus()


func _reset_visit() -> void:
	_site = &""
	_section = &""
	_items.clear()
	_page = 0
	_refresh_egg()
	_refresh()


func _visit(id: StringName) -> void:
	if id == &"egg":
		var egg: FieldLandmark = _landmarks[id]
		if not GameState.orange_rock_broken:
			egg.pulse = 1.0
			Events.orange_rock_hit.emit(GameState.get_click_damage(), egg.get_global_rect().get_center())
		_reset_visit()
		return
	_site = id
	_build_groups()
	_select_section(&"site")


func _visit_lab() -> void:
	Events.scenario_transition_requested.emit(&"surface")
	_visit(&"rubble_bunker")
	_select_section(&"amber")
	(_landmarks[_site] as Button).grab_focus()


func _build_groups() -> void:
	for child: Node in _groups.get_children():
		child.free()
	_add_group(&"site", "Ofício")
	var site_data: Dictionary = GameState.RUBBLE_DEFS[_site]
	_add_group(&"upgrades", WORKBENCH_NAMES[site_data["category"]])
	if _site == &"rubble_nest":
		_add_group(&"species", "Incubadora")
	if _site == &"rubble_bunker":
		_add_group(&"amber", "Âmbar")


func _add_group(id: StringName, title: String) -> void:
	var button: Button = Button.new()
	button.name = String(id)
	button.text = title
	button.toggle_mode = true
	button.pressed.connect(_select_section.bind(id))
	_groups.add_child(button)


func _select_section(section: StringName) -> void:
	_section = section
	_page = 0
	_items.clear()
	var def: Dictionary = GameState.RUBBLE_DEFS[_site]
	match section:
		&"site":
			_items.append(_site)
			_items.append(def["gear"])
		&"species":
			for dino: DinoData in GameState.get_dinos_sorted():
				_items.append(dino.id)
		_:
			var category: UpgradeData.Category = UpgradeData.Category.AMBER if section == &"amber" else def["category"]
			for upgrade: UpgradeData in GameState.get_upgrades_by_category(category):
				_items.append(upgrade.id)
	for child: Node in _groups.get_children():
		(child as Button).set_pressed_no_signal(child.name == section)
	_refresh()


func _turn(direction: int) -> void:
	if not _items.is_empty():
		_page = wrapi(_page + direction, 0, _items.size())
		_refresh()


func _refresh_egg() -> void:
	(_landmarks[&"egg"] as FieldLandmark).refresh()


func _queue_refresh() -> void:
	if not _refresh_pending and _site != &"":
		_refresh_pending = true
		_refresh.call_deferred()


func _refresh() -> void:
	_refresh_pending = false
	for key: Variant in _landmarks:
		var spot: FieldLandmark = _landmarks[key]
		spot.selected = (key == _site)
		spot.queue_redraw()
	_groups.visible = _site != &""
	_actions.visible = not _items.is_empty()
	if _site == &"":
		_site_name.text = "Acampamento"
		_stock.text = "Superfície"
		_item_title.text = "Seu primeiro escavador" if not GameState.orange_rock_broken else "O bando está a postos"
		_details.text = "Clique no ovo de âmbar até a casca se abrir." if not GameState.orange_rock_broken else "Desça à jazida para reunir rochas. Com 15, você instala a pedreira."
		if GameState.orange_rock_broken and GameState.get_rubble_level(&"rubble_forge") > 0:
			_details.text = "Escolha um posto para equipar o especialista. No pesqueiro, a incubadora revive os fósseis da jazida."
		return
	var def: Dictionary = GameState.RUBBLE_DEFS[_site]
	var product: StringName = def["product"]
	_site_name.text = def["title"]
	_stock.text = "%s · %s %s · +%.1f/s" % [def["worker"], GameState.format_number(GameState.get_resource(product)), GameState.RESOURCE_NAMES[product], GameState.get_station_rate(_site)]
	if _items.is_empty():
		return
	var item: StringName = _items[_page]
	_page_label.text = "%d / %d" % [_page + 1, _items.size()]
	_quantity.visible = item != _site
	_quantity.text = "Lote ×%d" % GameState.buy_multiplier if GameState.buy_multiplier > 0 else "Lote máx."
	if item == _site:
		var level: int = GameState.get_rubble_level(_site)
		_item_title.text = "Instalar posto de trabalho" if level == 0 else "Ampliar posto · Nv. %d" % level
		_details.text = "%s. Produção local +%.1f %s/s." % [def["desc"], float(def["rate"]), GameState.RESOURCE_NAMES[product]]
		_price("Construir" if level == 0 else "Ampliar", GameState.RES_ROCKS, GameState.get_rubble_cost(_site), GameState.can_rebuild_rubble(_site))
	elif _section == &"species":
		_show_species(item)
	else:
		_show_upgrade(item)


func _show_upgrade(id: StringName) -> void:
	var data: UpgradeData = GameState.get_upgrade(id)
	var level: int = GameState.get_upgrade_level(id)
	_item_title.text = "%s · Nv. %d" % [data.display_name, level]
	_details.text = data.description
	if data.required_station != &"":
		_details.text += " Produção local +%d%% por nível." % roundi(GameState.FIELD_GEAR_YIELD_BONUS * 100)
	if data.is_maxed(level):
		_unavailable("Nível máximo")
	elif not GameState.is_upgrade_unlocked(id):
		if data.required_station != &"":
			_unavailable("Instale o posto primeiro")
		elif GameState.current_era_index < data.required_era_index:
			_unavailable("Alcance %s" % GameState.eras[data.required_era_index].display_name)
		else:
			_unavailable("Requer %s · Nv. %d" % [GameState.get_upgrade(data.required_upgrade).display_name, data.required_level])
	else:
		var count: int = maxi(1, GameState.resolve_purchase_amount(id))
		_price("Equipar +%d" % count, data.cost_resource, GameState.get_purchase_cost(id), GameState.can_purchase_upgrade(id))


func _show_species(id: StringName) -> void:
	var data: DinoData = GameState.get_dino(id)
	var count: int = GameState.get_dino_count(id)
	_item_title.text = "%s · %d no bando" % [data.display_name, count]
	_details.text = data.description
	var needed: int = GameState.get_required_fragments_for_dino(id) if count == 0 or data.fragments_growth_per_unit > 0 else 0
	if GameState.current_era_index < data.unlock_era_index and GameState.get_fragments(id) == 0 and count == 0:
		_unavailable("Procure fósseis em %s" % GameState.eras[data.unlock_era_index].display_name)
	elif not data.can_spawn_more(count):
		_unavailable("Bando completo")
	else:
		if needed > 0:
			_details.text += "  Fósseis: %d/%d." % [GameState.get_fragments(id), needed]
		var action: String = "Reviver" if count == 0 else "Clonar +%d" % maxi(1, GameState.resolve_dino_purchase_amount(id))
		_price(action, GameState.RES_BONES, GameState.get_dino_purchase_cost(id), GameState.can_assemble_dino(id))


func _price(action: String, currency: StringName, cost: float, affordable: bool) -> void:
	_buy.text = "%s · %s %s" % [action, GameState.format_number(cost), GameState.RESOURCE_NAMES[currency]]
	_buy.disabled = not affordable
	_buy.tooltip_text = "Saldo: %s %s" % [GameState.format_number(GameState.get_resource(currency)), GameState.RESOURCE_NAMES[currency]]


func _unavailable(reason: String) -> void:
	_buy.text = reason
	_buy.tooltip_text = reason
	_buy.disabled = true


func _purchase() -> void:
	if _items.is_empty() or _buy.disabled:
		return
	var id: StringName = _items[_page]
	if id == _site:
		Events.rubble_rebuild_requested.emit(id)
	elif _section == &"species":
		Events.dino_assembly_requested.emit(id)
	else:
		Events.upgrade_purchase_requested.emit(id, GameState.buy_multiplier)
	(_landmarks[_site] as FieldLandmark).pulse = 1.0
	_refresh()
