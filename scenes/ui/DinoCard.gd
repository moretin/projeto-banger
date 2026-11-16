class_name DinoCard
extends PanelContainer
## Card de uma espécie na aba 🦖 Dinos.
##
## Exibe:
##   • Nome, papel, cor de destaque e quantidade de unidades vivas.
##   • Progresso de fragmentos (🧩 X / Y) para reviver o 1º esqueleto.
##   • DPS atual da espécie e barra de progresso rumo ao próximo marco (25, 50, 100...).
##   • Botão de Montar Esqueleto (1ª vez) / Clonar Unidade (+1).

var dino_id: StringName = &""

@onready var _color_Pip: ColorRect = %ColorPip
@onready var _name_label: Label = %NameLabel
@onready var _count_label: Label = %CountLabel
@onready var _desc_label: Label = %DescLabel
@onready var _stats_label: Label = %StatsLabel
@onready var _milestone_bar: ProgressBar = %MilestoneBar
@onready var _milestone_label: Label = %MilestoneLabel
@onready var _assemble_button: Button = %AssembleButton


func setup(data: DinoData) -> void:
	dino_id = data.id
	if is_node_ready():
		refresh()


func _ready() -> void:
	offset_transform_enabled = true
	_assemble_button.pressed.connect(_on_assemble_pressed)
	Events.resource_changed.connect(_on_resource_changed)
	Events.fragments_changed.connect(_on_fragments_changed)
	Events.dino_count_changed.connect(_on_dino_count_changed)
	Events.stats_recalculated.connect(refresh)
	Events.era_changed.connect(_on_era_changed)
	Events.game_loaded.connect(refresh)
	if dino_id != &"":
		refresh()


func refresh() -> void:
	var data: DinoData = GameState.get_dino(dino_id)
	if data == null:
		visible = false
		return

	var count: int = GameState.get_dino_count(dino_id)
	var frags: int = GameState.get_fragments(dino_id)
	# Mostra se a era já foi alcançada, se já tem fragmentos ou se já desbloqueou.
	visible = GameState.current_era_index >= data.unlock_era_index or frags > 0 or count > 0
	if not visible:
		return

	_color_Pip.color = data.accent_color
	_name_label.text = "%s  [%s]" % [data.display_name, _role_name(data.role)]
	_count_label.text = "×%d" % count
	_desc_label.text = data.description

	var unit_dmg: float = GameState.get_dino_damage(dino_id)
	var unit_dps: float = unit_dmg / maxf(data.attack_interval, 0.01)
	var total_dps: float = unit_dps * float(count)
	var mult_reached: float = data.get_milestone_multiplier(count)

	if count == 0:
		_stats_label.text = "🧩 Fragmentos: %d / %d   ·   DPS base: %s/s" % [
			frags,
			data.fragments_required,
			GameState.format_number(unit_dps),
		]
		_milestone_bar.max_value = float(maxi(data.fragments_required, 1))
		_milestone_bar.value = float(mini(frags, data.fragments_required))
		_milestone_label.text = "Junte %d fragmentos para reviver" % data.fragments_required
	else:
		var next_m: int = data.get_next_milestone(count)
		_stats_label.text = "DPS Total: %s/s   ·   🧬 +%s/s   ·   Marcos: ×%s" % [
			GameState.format_number(total_dps),
			GameState.format_number(data.dna_per_second * float(count)),
			GameState.format_number(mult_reached),
		]
		if next_m > 0:
			_milestone_bar.max_value = float(next_m)
			_milestone_bar.value = float(count)
			_milestone_label.text = "Próximo marco (×2): %d / %d unidades" % [count, next_m]
		else:
			_milestone_bar.max_value = 1.0
			_milestone_bar.value = 1.0
			_milestone_label.text = "Todos os marcos alcançados! (×%s)" % GameState.format_number(mult_reached)

	var cost: float = data.get_unit_cost(count)
	var can_buy: bool = GameState.can_assemble_dino(dino_id)
	if count == 0:
		_assemble_button.text = "Reviver\n🧩 %d/%d · 🦴 %s" % [
			frags,
			data.fragments_required,
			GameState.format_number(cost),
		]
	else:
		_assemble_button.text = "+1 Dino\n🦴 %s" % GameState.format_number(cost)
	_assemble_button.disabled = not can_buy


static func _role_name(role: DinoData.Role) -> String:
	match role:
		DinoData.Role.COLLECTOR:
			return "Coletor"
		DinoData.Role.BREAKER:
			return "Quebrador"
		DinoData.Role.AREA:
			return "Impacto"
		DinoData.Role.FAST:
			return "Veloz"
		DinoData.Role.TRANSPORT:
			return "Aéreo"
		DinoData.Role.SUPPORT:
			return "Suporte"
		DinoData.Role.DEFENSE:
			return "Defesa"
		DinoData.Role.ELEMENTAL:
			return "Ácido"
	return "Dino"


func _play_assemble_feedback() -> void:
	if not is_inside_tree():
		return
	offset_transform_scale = Vector2(1.02, 1.02)
	var tw: Tween = create_tween()
	tw.tween_property(self, "offset_transform_scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _on_assemble_pressed() -> void:
	if dino_id != &"":
		Events.dino_assembly_requested.emit(dino_id)


func _on_resource_changed(_res_id: StringName, _amount: float, _delta: float) -> void:
	refresh()


func _on_fragments_changed(changed_id: StringName, _amount: int) -> void:
	if changed_id == dino_id:
		refresh()


func _on_dino_count_changed(changed_id: StringName, _count: int) -> void:
	if changed_id == dino_id:
		refresh()
		_play_assemble_feedback()


func _on_era_changed(_era_idx: int) -> void:
	refresh()
