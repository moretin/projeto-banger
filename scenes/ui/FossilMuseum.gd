class_name FossilMuseum
extends Control
## Laudo do Fóssil (revelação de raridade com carimbo de laboratório) + Museu Paleontológico.
##
## • Ao receber `Events.fossil_found` do GameState, exibe um cartão não-bloqueante com batida
##   de carimbo inclinado e reflete o acervo mantido no GameState nas vitrines do Museu.
## • Botão "Museu" no HUD ou clique no Laudo abre a galeria das 8 espécies.

const STAMP_SHOW_DURATION: float = 3.8

const RARITY_LABELS: PackedStringArray = [
	"CATALOGADO · COMUM",
	"CATALOGADO · INCOMUM",
	"EXEMPLAR RARO",
	"HOLÓTIPO LENDÁRIO",
]

const RARITY_COLORS: Array[Color] = [
	Color(0.84, 0.76, 0.60, 1.0),
	Color(0.45, 0.90, 0.56, 1.0),
	Color(0.42, 0.78, 1.00, 1.0),
	Color(1.00, 0.82, 0.28, 1.0),
]

@onready var _laudo_card: PanelContainer = %LaudoCard
@onready var _laudo_badge_icon: TextureRect = %LaudoBadgeIcon
@onready var _laudo_header_label: Label = %LaudoHeaderLabel
@onready var _laudo_sprite: TextureRect = %LaudoSprite
@onready var _laudo_species_label: Label = %LaudoSpeciesLabel
@onready var _laudo_part_label: Label = %LaudoPartLabel
@onready var _laudo_meta_label: Label = %LaudoMetaLabel
@onready var _stamp_badge: PanelContainer = %StampBadge
@onready var _stamp_label: Label = %StampLabel

@onready var _museum_backdrop: ColorRect = %MuseumBackdrop
@onready var _museum_icon: TextureRect = %MuseumIcon
@onready var _museum_close_btn: Button = %MuseumCloseButton
@onready var _museum_summary_label: Label = %MuseumSummaryLabel
@onready var _vitrines_grid: GridContainer = %VitrinesGrid

var _laudo_timer: float = 0.0
var _batch_count: int = 1
var _current_shown_rarity: int = -1
var _stamp_tween: Tween = null


func _ready() -> void:
	_laudo_card.visible = false
	_museum_backdrop.visible = false
	_laudo_badge_icon.texture = AmberTheme.get_icon(&"fragment")
	_museum_icon.texture = AmberTheme.get_icon(&"museum")

	_stamp_badge.rotation = deg_to_rad(-8.5)
	_museum_close_btn.pressed.connect(func() -> void: _museum_backdrop.visible = false)
	_laudo_card.gui_input.connect(_on_laudo_gui_input)

	Events.fossil_found.connect(_on_fossil_found)
	Events.museum_modal_requested.connect(open_museum)
	Events.meteor_impact_started.connect(func() -> void: _laudo_card.visible = false)
	Events.prestige_modal_requested.connect(func() -> void: _laudo_card.visible = false)
	Events.run_started.connect(_on_run_started)
	Events.game_loaded.connect(_refresh_museum_if_open)


func _process(delta: float) -> void:
	if _laudo_card.visible and _laudo_timer > 0.0:
		_laudo_timer -= delta
		if _laudo_timer <= 0.0:
			_laudo_card.visible = false
			_current_shown_rarity = -1
			_batch_count = 1


func open_museum() -> void:
	_refresh_museum()
	_museum_backdrop.visible = true


## Simula ou exibe programaticamente um Laudo via GameState (inclusive para capturas/testes).
func present_evaluation(dino_id: StringName, forced_rarity: int = -1) -> void:
	GameState.register_fossil_found(dino_id, forced_rarity)


func _on_fossil_found(_dino_id: StringName, _rarity: int) -> void:
	# Notificações visuais no canto inferior direito removidas; mantém apenas atualização silenciosa do acervo no Museu.
	_laudo_card.visible = false
	_laudo_timer = 0.0
	_refresh_museum_if_open()


func _animate_stamp_slam() -> void:
	if not is_inside_tree():
		return
	if _stamp_tween != null and _stamp_tween.is_valid():
		_stamp_tween.kill()
	_stamp_badge.pivot_offset = _stamp_badge.size * 0.5
	_stamp_badge.scale = Vector2(1.85, 1.85)
	_stamp_badge.modulate.a = 0.0
	_stamp_tween = create_tween().set_parallel(true)
	_stamp_tween.tween_property(_stamp_badge, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_stamp_tween.tween_property(_stamp_badge, "modulate:a", 1.0, 0.14)


func _on_laudo_gui_input(event: InputEvent) -> void:
	var mb: InputEventMouseButton = event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		open_museum()


func _on_run_started(_run: int) -> void:
	_batch_count = 1
	_current_shown_rarity = -1
	_laudo_card.visible = false
	_refresh_museum_if_open()


func _refresh_museum_if_open() -> void:
	if _museum_backdrop.visible:
		_refresh_museum()


func _refresh_museum() -> void:
	var museum_bonus_pct: int = roundi((GameState.get_museum_collection_multiplier() - 1.0) * 100.0)
	_museum_summary_label.text = "Fósseis catalogados no Museu: %d  ·  Holótipos Lendários: %d  ·  Bônus do Acervo: +%d%% Ossos" % [
		GameState.total_fossils_evaluated,
		GameState.total_legendary_fossils,
		museum_bonus_pct,
	]
	for child: Node in _vitrines_grid.get_children():
		child.queue_free()

	for data: DinoData in GameState.get_dinos_sorted():
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(190.0, 198.0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var pad := MarginContainer.new()
		pad.add_theme_constant_override("margin_left", 10)
		pad.add_theme_constant_override("margin_top", 8)
		pad.add_theme_constant_override("margin_right", 10)
		pad.add_theme_constant_override("margin_bottom", 8)
		card.add_child(pad)

		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 5)
		pad.add_child(vbox)

		var tex_rect := TextureRect.new()
		tex_rect.texture = AmberTheme.get_dino_sprite(data.id, data.sprite)
		tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex_rect.custom_minimum_size = Vector2(56.0, 56.0)
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

		var frags: int = GameState.get_fragments(data.id)
		var count: int = GameState.get_dino_count(data.id)
		var rec: Dictionary = GameState.fossil_catalog.get(data.id, {}) as Dictionary
		var cat_count: int = int(rec.get("count", 0))
		var known: bool = frags > 0 or count > 0 or cat_count > 0
		if not known:
			tex_rect.modulate = Color(0.18, 0.12, 0.08, 0.72)
		vbox.add_child(tex_rect)

		var title := Label.new()
		title.text = data.display_name
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 14)
		vbox.add_child(title)

		var sub := Label.new()
		sub.text = "%s (%d/%d)" % [data.get_fossil_display_name(), frags, data.fragments_required]
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.add_theme_font_size_override("font_size", 11)
		sub.add_theme_color_override("font_color", Color(0.86, 0.78, 0.64))
		sub.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vbox.add_child(sub)

		var badge := Label.new()
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_theme_font_size_override("font_size", 11)
		if cat_count > 0:
			var best_r: int = clampi(int(rec.get("best_rarity", 0)), 0, 3)
			badge.text = "[ %s · %dx ]" % [RARITY_LABELS[best_r], cat_count]
			badge.add_theme_color_override("font_color", RARITY_COLORS[best_r])
		elif known:
			badge.text = "[ ACERVO ATIVO ]"
			badge.add_theme_color_override("font_color", RARITY_COLORS[0])
		else:
			badge.text = "[ NÃO ESCAVADO ]"
			badge.add_theme_color_override("font_color", Color(0.62, 0.52, 0.40, 0.75))
		vbox.add_child(badge)

		_vitrines_grid.add_child(card)
