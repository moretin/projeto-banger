class_name UITheme
extends RefCounted
## Estilo visual do Fóssil Rush, inspirado em Gnorp Apologue:
## fundo escuro azulado, traço branco, bordas finas de 2px, sem sombras,
## fonte pixel e hover invertido (fundo branco / texto escuro).

const G_BG := Color("#2A2B38")
const G_BG_DEEP := Color("#1F2029")
const G_FG := Color("#F2F2F2")
const G_DIM := Color("#8A8CA0")
const G_GOOD := Color("#7CFC6A")
const G_BAD := Color("#FF6B6B")
const G_WARN := Color("#FF9F43")
const G_AMBER := Color("#FFB347")

const FONT_PATH := "res://assets/fonts/PixelifySans.ttf"

static var audio_muted: bool = false

# Mantidas por compatibilidade com cenas antigas (UpgradePanel/UpgradeCard/DinoCard).
const COLOR_BLUE_TOP := Color("#2185D5")
const COLOR_GREEN_BTN := Color("#2ECC71")
const COLOR_AMBER_BTN := Color("#F39C12")
const COLOR_RED_BTN := Color("#D93829")
const COLOR_DARK_BTN := Color("#37474F")
const COLOR_PANEL_BG := G_BG
const COLOR_CARD_BG := G_BG


static func load_sprite(file_name: String) -> Texture2D:
	var res_path: String = "res://assets/sprites/" + file_name
	if ResourceLoader.exists(res_path):
		var loaded: Texture2D = load(res_path) as Texture2D
		if loaded != null:
			return loaded
	var img := Image.new()
	var abs_path: String = ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(abs_path) and img.load(abs_path) == OK:
		return ImageTexture.create_from_image(img)
	return null


static func get_dino_sprite(dino_id: StringName) -> Texture2D:
	return load_sprite(String(dino_id) + ".png")


static func get_font() -> Font:
	if ResourceLoader.exists(FONT_PATH):
		return load(FONT_PATH) as Font
	return null


static func res_suffix(res_id: StringName) -> String:
	match res_id:
		GameState.RES_BONES:
			return "ossos"
		GameState.RES_MINERALS:
			return "min"
		GameState.RES_DNA:
			return "dna"
		GameState.RES_AMBER:
			return "âmbar"
	return ""


# ---------------------------------------------------------------- Gnorp boxes

static func make_gnorp_box(
	bg: Color = G_BG, border: Color = G_FG, px: int = 2, pad_h: int = 10, pad_v: int = 8
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(px)
	sb.set_corner_radius_all(0)
	sb.anti_aliasing = false
	sb.content_margin_left = float(pad_h)
	sb.content_margin_right = float(pad_h)
	sb.content_margin_top = float(pad_v)
	sb.content_margin_bottom = float(pad_v)
	return sb


static func style_gnorp_button(btn: Button, font_size: int = 16, accent: Color = G_FG) -> void:
	if btn == null:
		return
	btn.add_theme_stylebox_override("normal", make_gnorp_box(G_BG, accent, 2, 10, 3))
	btn.add_theme_stylebox_override("hover", make_gnorp_box(accent, accent, 2, 10, 3))
	btn.add_theme_stylebox_override("pressed", make_gnorp_box(accent, accent, 2, 10, 3))
	btn.add_theme_stylebox_override("hover_pressed", make_gnorp_box(accent, accent, 2, 10, 3))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_stylebox_override("disabled", make_gnorp_box(G_BG, G_DIM, 2, 10, 3))
	btn.add_theme_color_override("font_color", accent)
	btn.add_theme_color_override("font_hover_color", G_BG)
	btn.add_theme_color_override("font_pressed_color", G_BG)
	btn.add_theme_color_override("font_hover_pressed_color", G_BG)
	btn.add_theme_color_override("font_focus_color", accent)
	btn.add_theme_color_override("font_disabled_color", G_DIM)
	btn.add_theme_constant_override("outline_size", 0)
	btn.add_theme_font_size_override("font_size", font_size)


## Botão "texto puro": sem borda, só inverte no hover (estilo das linhas do Gnorp).
static func style_gnorp_flat(btn: Button, font_size: int = 16) -> void:
	style_gnorp_button(btn, font_size)
	btn.add_theme_stylebox_override("normal", make_gnorp_box(G_BG, Color(0, 0, 0, 0), 0, 8, 2))
	btn.add_theme_stylebox_override("disabled", make_gnorp_box(G_BG, Color(0, 0, 0, 0), 0, 8, 2))


static func style_gnorp_label(lbl: Label, font_size: int = 16, col: Color = G_FG) -> void:
	if lbl == null:
		return
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", col)
	lbl.add_theme_constant_override("outline_size", 0)


static func style_gnorp_bar(bar: ProgressBar, fill: Color = G_FG) -> void:
	if bar == null:
		return
	var bg := make_gnorp_box(G_BG, fill, 2, 0, 0)
	var fg := StyleBoxFlat.new()
	fg.bg_color = fill
	fg.anti_aliasing = false
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fg)
	bar.show_percentage = false


static func build_gnorp_theme() -> Theme:
	var t := Theme.new()
	var f: Font = get_font()
	if f != null:
		t.default_font = f
	t.default_font_size = 16

	t.set_stylebox("panel", "PanelContainer", make_gnorp_box())
	t.set_stylebox("panel", "Panel", make_gnorp_box())
	t.set_stylebox("normal", "Button", make_gnorp_box(G_BG, G_FG, 2, 10, 3))
	t.set_stylebox("hover", "Button", make_gnorp_box(G_FG, G_FG, 2, 10, 3))
	t.set_stylebox("pressed", "Button", make_gnorp_box(G_FG, G_FG, 2, 10, 3))
	t.set_stylebox("hover_pressed", "Button", make_gnorp_box(G_FG, G_FG, 2, 10, 3))
	t.set_stylebox("disabled", "Button", make_gnorp_box(G_BG, G_DIM, 2, 10, 3))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", G_FG)
	t.set_color("font_hover_color", "Button", G_BG)
	t.set_color("font_pressed_color", "Button", G_BG)
	t.set_color("font_hover_pressed_color", "Button", G_BG)
	t.set_color("font_focus_color", "Button", G_FG)
	t.set_color("font_disabled_color", "Button", G_DIM)
	t.set_color("font_color", "Label", G_FG)

	var bar_bg := make_gnorp_box(G_BG, G_FG, 2, 0, 0)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = G_FG
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)

	t.set_stylebox("panel", "TabContainer", make_gnorp_box())
	t.set_stylebox("tab_selected", "TabContainer", make_gnorp_box(G_FG, G_FG, 2, 10, 4))
	t.set_stylebox("tab_unselected", "TabContainer", make_gnorp_box(G_BG, G_DIM, 2, 10, 4))
	t.set_stylebox("tab_hovered", "TabContainer", make_gnorp_box(G_BG, G_FG, 2, 10, 4))
	t.set_color("font_selected_color", "TabContainer", G_BG)
	t.set_color("font_unselected_color", "TabContainer", G_DIM)
	t.set_color("font_hovered_color", "TabContainer", G_FG)

	t.set_stylebox("normal", "TextEdit", make_gnorp_box(G_BG_DEEP, G_DIM, 2, 8, 6))
	t.set_stylebox("focus", "TextEdit", make_gnorp_box(G_BG_DEEP, G_FG, 2, 8, 6))
	t.set_color("font_color", "TextEdit", G_FG)
	return t


# ------------------------------------------- compat (cenas antigas não usadas)

static func make_arcade_box(
	bg: Color, border_col: Color = Color.BLACK, border_px: int = 4,
	_shadow_px: int = 5, pad_h: int = 12, pad_v: int = 8
) -> StyleBoxFlat:
	return make_gnorp_box(bg, border_col, border_px, pad_h, pad_v)


static func style_badge(panel: PanelContainer, bg: Color = G_BG) -> void:
	if panel != null:
		panel.add_theme_stylebox_override("panel", make_gnorp_box(bg))


static func style_button(btn: Button, _bg: Color = G_BG, font_size: int = 16) -> void:
	style_gnorp_button(btn, font_size)


static func style_label(lbl: Label, font_size: int = 16, col: Color = G_FG, _outline_px: int = 0) -> void:
	style_gnorp_label(lbl, font_size, col)
