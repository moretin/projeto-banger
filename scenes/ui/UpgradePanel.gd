class_name UpgradePanel
extends PanelContainer
## Painel lateral direito de upgrades com seletor de multiplicador (1x, 10x, 100x, Máx)
## e 4 abas:
##   0: ⛏️ Ferramentas
##   1: 🦖 Dinos (Montagem de Espécies + Upgrades de Dinos)
##   2: 🏭 Máquinas
##   3: 🛡️ Defesa

const UPGRADE_CARD_SCENE: PackedScene = preload("res://scenes/ui/UpgradeCard.tscn")
const DINO_CARD_SCENE: PackedScene = preload("res://scenes/ui/DinoCard.tscn")

@onready var _btn_1x: Button = %Btn1x
@onready var _btn_10x: Button = %Btn10x
@onready var _btn_100x: Button = %Btn100x
@onready var _btn_max: Button = %BtnMax
@onready var _tab_container: TabContainer = %TabContainer

@onready var _tools_list: VBoxContainer = %ToolsList
@onready var _dinos_species_list: VBoxContainer = %DinosSpeciesList
@onready var _dinos_upgrades_list: VBoxContainer = %DinosUpgradesList
@onready var _machines_list: VBoxContainer = %MachinesList
@onready var _defense_list: VBoxContainer = %DefenseList


func _ready() -> void:
	_tab_container.set_tab_title(0, "⛏️ Ferramentas")
	_tab_container.set_tab_title(1, "🦖 Dinos")
	_tab_container.set_tab_title(2, "🏭 Máquinas")
	_tab_container.set_tab_title(3, "🛡️ Defesa")

	_btn_1x.pressed.connect(func() -> void: GameState.set_buy_multiplier(1))
	_btn_10x.pressed.connect(func() -> void: GameState.set_buy_multiplier(10))
	_btn_100x.pressed.connect(func() -> void: GameState.set_buy_multiplier(100))
	_btn_max.pressed.connect(func() -> void: GameState.set_buy_multiplier(GameState.BUY_MAX))
	_tab_container.tab_changed.connect(_on_tab_changed)

	Events.buy_multiplier_changed.connect(_update_multiplier_buttons)
	_populate_all()
	_update_multiplier_buttons(GameState.buy_multiplier)
	grab_initial_focus()


## Garante foco inicial para navegação por teclado/gamepad (godot-ui-control).
func grab_initial_focus() -> void:
	if _btn_1x != null and _btn_1x.is_visible_in_tree():
		_btn_1x.grab_focus()


func _populate_all() -> void:
	_populate_upgrade_list(_tools_list, UpgradeData.Category.TOOLS)
	_populate_dino_species(_dinos_species_list)
	_populate_upgrade_list(_dinos_upgrades_list, UpgradeData.Category.DINOS)
	_populate_upgrade_list(_machines_list, UpgradeData.Category.MACHINES)
	_populate_upgrade_list(_defense_list, UpgradeData.Category.DEFENSE)


func _populate_upgrade_list(container: VBoxContainer, category: UpgradeData.Category) -> void:
	for child: Node in container.get_children():
		child.queue_free()
	for data: UpgradeData in GameState.get_upgrades_by_category(category):
		var card: UpgradeCard = UPGRADE_CARD_SCENE.instantiate() as UpgradeCard
		container.add_child(card)
		card.setup(data)


func _populate_dino_species(container: VBoxContainer) -> void:
	for child: Node in container.get_children():
		child.queue_free()
	for data: DinoData in GameState.get_dinos_sorted():
		var card: DinoCard = DINO_CARD_SCENE.instantiate() as DinoCard
		container.add_child(card)
		card.setup(data)


func _update_multiplier_buttons(mult: int) -> void:
	_btn_1x.button_pressed = (mult == 1)
	_btn_10x.button_pressed = (mult == 10)
	_btn_100x.button_pressed = (mult == 100)
	_btn_max.button_pressed = (mult == GameState.BUY_MAX)


func _on_tab_changed(_tab: int) -> void:
	var vp: Viewport = get_viewport()
	if vp != null and vp.gui_get_focus_owner() == null:
		grab_initial_focus()
