class_name UpgradeCard
extends PanelContainer
## Card individual de um upgrade dentro das abas do painel lateral.
##
## Totalmente desacoplado: lê dados de UpgradeData/GameState e emite
## Events.upgrade_purchase_requested ao clicar no botão.

var upgrade_id: StringName = &""

@onready var _title_label: Label = %TitleLabel
@onready var _level_label: Label = %LevelLabel
@onready var _desc_label: Label = %DescLabel
@onready var _buy_button: Button = %BuyButton


func setup(data: UpgradeData) -> void:
	upgrade_id = data.id
	if is_node_ready():
		refresh()


func _ready() -> void:
	_buy_button.pressed.connect(_on_buy_pressed)
	Events.resource_changed.connect(_on_state_changed_res)
	Events.upgrade_purchased.connect(_on_upgrade_purchased)
	Events.buy_multiplier_changed.connect(_on_multiplier_changed)
	Events.era_changed.connect(_on_era_changed)
	Events.game_loaded.connect(refresh)
	if upgrade_id != &"":
		refresh()


func refresh() -> void:
	var data: UpgradeData = GameState.get_upgrade(upgrade_id)
	if data == null:
		visible = false
		return

	var unlocked: bool = GameState.is_upgrade_unlocked(upgrade_id)
	visible = unlocked
	if not unlocked:
		return

	var level: int = GameState.get_upgrade_level(upgrade_id)
	_title_label.text = data.display_name
	if data.max_level > 0:
		_level_label.text = "Nv. %d/%d" % [level, data.max_level]
	else:
		_level_label.text = "Nv. %d" % level
	_desc_label.text = data.description

	if data.is_maxed(level):
		_buy_button.text = "MÁXIMO"
		_buy_button.disabled = true
		modulate = Color(0.82, 0.95, 0.82, 1.0)
		return

	var mult: int = GameState.buy_multiplier
	var amount: int = GameState.resolve_purchase_amount(upgrade_id, mult)
	var cost: float = GameState.get_purchase_cost(upgrade_id, mult)
	var can_buy: bool = GameState.can_purchase_upgrade(upgrade_id, mult)
	var res_icon: String = _get_resource_icon(data.cost_resource)
	var amount_prefix: String = ""
	if mult == GameState.BUY_MAX and amount > 1:
		amount_prefix = "+%d · " % amount
	elif mult > 1 and amount > 0:
		amount_prefix = "+%d · " % amount

	_buy_button.text = "%s%s %s" % [amount_prefix, res_icon, GameState.format_number(cost)]
	_buy_button.disabled = not can_buy
	modulate = Color.WHITE if can_buy else Color(0.75, 0.75, 0.75, 0.92)


static func _get_resource_icon(res_id: StringName) -> String:
	match res_id:
		GameState.RES_BONES:
			return "🦴"
		GameState.RES_MINERALS:
			return "💎"
		GameState.RES_DNA:
			return "🧬"
		GameState.RES_AMBER:
			return "🟠"
	return "•"


func _on_buy_pressed() -> void:
	if upgrade_id != &"":
		Events.upgrade_purchase_requested.emit(upgrade_id, GameState.buy_multiplier)


func _on_state_changed_res(_res_id: StringName, _amount: float, _delta: float) -> void:
	refresh()


func _on_upgrade_purchased(_upg_id: StringName, _new_level: int) -> void:
	refresh()


func _on_multiplier_changed(_mult: int) -> void:
	refresh()


func _on_era_changed(_era_idx: int) -> void:
	refresh()
