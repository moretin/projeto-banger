class_name AmberTheme
extends RefCounted
## Utilitário central de ícones pixel art próprios e sprites das espécies em Fóssil Rush.

const ICON_PATHS: Dictionary = {
	&"bones": "res://assets/sprites/icons/icon_bones.png",
	&"rocks": "res://assets/sprites/icons/icon_rocks.png",
	&"minerals": "res://assets/sprites/icons/icon_minerals.png",
	&"dna": "res://assets/sprites/icons/icon_dna.png",
	&"amber": "res://assets/sprites/icons/icon_amber.png",
	&"fragment": "res://assets/sprites/icons/icon_fragment.png",
	&"brush": "res://assets/sprites/icons/icon_brush.png",
	&"museum": "res://assets/sprites/icons/icon_museum.png",
	&"meteor": "res://assets/sprites/icons/icon_meteor.png",
	&"audio": "res://assets/sprites/icons/icon_audio.png",
	&"save": "res://assets/sprites/icons/icon_save.png",
	&"settings": "res://assets/sprites/icons/icon_settings.png",
	&"home": "res://assets/sprites/icons/icon_home.png",
	&"camp": "res://assets/sprites/icons/icon_camp.png",
	&"shield": "res://assets/sprites/icons/icon_shield.png",
	&"power": "res://assets/sprites/icons/icon_power.png",
	&"layers": "res://assets/sprites/icons/icon_layers.png",
	&"egg": "res://assets/sprites/icons/icon_egg.png",
	&"tools": "res://assets/sprites/icons/icon_tools.png",
	&"machines": "res://assets/sprites/icons/icon_machines.png",
}

static var _icon_cache: Dictionary = {}
static var _dino_sprite_cache: Dictionary = {}


static func get_icon(icon_key: StringName) -> Texture2D:
	if _icon_cache.has(icon_key):
		return _icon_cache[icon_key] as Texture2D
	var path: String = String(ICON_PATHS.get(icon_key, ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		var tex: Texture2D = load(path) as Texture2D
		if tex != null:
			_icon_cache[icon_key] = tex
		return tex
	var procedural: ImageTexture = _create_procedural_icon(icon_key)
	if procedural != null:
		_icon_cache[icon_key] = procedural
	return procedural


static func get_resource_icon(res_id: StringName) -> Texture2D:
	match res_id:
		GameState.RES_BONES:
			return get_icon(&"bones")
		GameState.RES_ROCKS:
			return get_icon(&"rocks")
		GameState.RES_MINERALS:
			return get_icon(&"minerals")
		GameState.RES_DNA:
			return get_icon(&"dna")
		GameState.RES_AMBER:
			return get_icon(&"amber")
		GameState.RES_FISH:
			return get_icon(&"fish")
		GameState.RES_FEATHERS:
			return get_icon(&"feathers")
		GameState.RES_SCIENCE:
			return get_icon(&"science")
		GameState.RES_RAW_FOSSILS:
			return get_icon(&"raw_fossils")
		GameState.RES_METAL:
			return get_icon(&"metal")
		GameState.RES_SCALES:
			return get_icon(&"scales")
		GameState.RES_BEAKS:
			return get_icon(&"beaks")
	return null


static func get_resource_color(res_id: StringName) -> Color:
	match res_id:
		GameState.RES_ROCKS:
			return Color(0.95, 0.78, 0.56, 1.0)
		GameState.RES_FISH:
			return Color(0.54, 0.90, 0.96, 1.0)
		GameState.RES_FEATHERS:
			return Color(0.76, 0.90, 1.0, 1.0)
		GameState.RES_SCIENCE:
			return Color(0.84, 0.68, 1.0, 1.0)
		GameState.RES_RAW_FOSSILS:
			return Color(0.96, 0.89, 0.72, 1.0)
		GameState.RES_METAL:
			return Color(0.84, 0.89, 0.95, 1.0)
		GameState.RES_SCALES:
			return Color(0.56, 0.94, 0.64, 1.0)
		GameState.RES_BEAKS:
			return Color(1.0, 0.84, 0.48, 1.0)
		GameState.RES_AMBER:
			return Color(1.0, 0.74, 0.24, 1.0)
		GameState.RES_BONES:
			return Color(0.97, 0.93, 0.82, 1.0)
		GameState.RES_MINERALS:
			return Color(0.55, 0.88, 0.96, 1.0)
		GameState.RES_DNA:
			return Color(0.62, 0.94, 0.64, 1.0)
	return Color(0.96, 0.91, 0.80, 1.0)


static func _create_procedural_icon(icon_key: StringName) -> ImageTexture:
	var outline: Color = Color(0.08, 0.05, 0.03, 1.0)
	match icon_key:
		&"fish":
			return _build_pixel_icon(
				PackedStringArray([
					"............",
					".....OOO....",
					".OO.OBBBO...",
					"OBO.OLHHLOO.",
					"OBBBLHHLLOLO",
					".OBBLHLLLLMO",
					".OBBMMMMMMMO",
					"OBBBMMMMBBO.",
					"OBO.OOBBBO..",
					".OO...OOO...",
					"............",
					"............",
				]),
				{
					"O": outline,
					"H": Color(0.78, 0.96, 1.0, 1.0),
					"L": Color(0.43, 0.83, 0.91, 1.0),
					"M": Color(0.22, 0.62, 0.72, 1.0),
					"B": Color(0.13, 0.39, 0.49, 1.0),
				},
			)
		&"feathers":
			return _build_pixel_icon(
				PackedStringArray([
					".......OOOO.",
					"......OHHHLO",
					".....OHHQLMO",
					"....OHHLQMMO",
					"...OHHLQMO..",
					"...OHLQMMOO.",
					"..OHLQMMMO..",
					"..OQLQMMO...",
					"..OQQMMO....",
					".OQQOOO.....",
					".OQO........",
					".OO.........",
				]),
				{
					"O": outline,
					"H": Color(0.97, 0.98, 1.0, 1.0),
					"L": Color(0.66, 0.87, 0.96, 1.0),
					"M": Color(0.37, 0.66, 0.84, 1.0),
					"Q": Color(1.0, 0.94, 0.82, 1.0),
				},
			)
		&"science":
			return _build_pixel_icon(
				PackedStringArray([
					"...OOOOOO...",
					"...OGGGGO...",
					"....OGGO....",
					"....OGGO....",
					"...OGHGGO...",
					"..OGHGGGGO..",
					"..OHLLLLGO..",
					".OHLLBLLMGO.",
					".OLLLMMMMGO.",
					".OMMMMMMMMO.",
					"..OOOOOOOO..",
					"............",
				]),
				{
					"O": outline,
					"G": Color(0.79, 0.85, 0.92, 1.0),
					"H": Color(1.0, 1.0, 1.0, 1.0),
					"B": Color(0.96, 0.85, 1.0, 1.0),
					"L": Color(0.78, 0.51, 1.0, 1.0),
					"M": Color(0.54, 0.27, 0.80, 1.0),
				},
			)
		&"raw_fossils":
			return _build_pixel_icon(
				PackedStringArray([
					"...OOOOOO...",
					"..OSSSSSSO..",
					".OSBBBBSSSO.",
					".OSBLLLBSSO.",
					"OSSBLSSBBSDO",
					"OSSBSSBBSBDO",
					"OSSBBSBBSBDO",
					".OSBBBBBSDO.",
					".OSSDDDDDDO.",
					"..OSDDDDDO..",
					"...OOOOOO...",
					"............",
				]),
				{
					"O": outline,
					"S": Color(0.42, 0.35, 0.28, 1.0),
					"D": Color(0.29, 0.23, 0.18, 1.0),
					"B": Color(0.87, 0.82, 0.71, 1.0),
					"L": Color(1.0, 0.96, 0.88, 1.0),
				},
			)
		&"metal":
			return _build_pixel_icon(
				PackedStringArray([
					"............",
					"............",
					"...OOOOOO...",
					"..OHHHHHLO..",
					".OHHLLLLMMO.",
					".OLLMMMMBMO.",
					"OMMMMMMMBBBO",
					"OMMMBBBBBBBO",
					"OBBBBBBBBBBO",
					".OOOOOOOOOO.",
					"............",
					"............",
				]),
				{
					"O": outline,
					"H": Color(0.95, 0.97, 0.99, 1.0),
					"L": Color(0.76, 0.82, 0.87, 1.0),
					"M": Color(0.55, 0.61, 0.67, 1.0),
					"B": Color(0.34, 0.40, 0.45, 1.0),
				},
			)
		&"scales":
			return _build_pixel_icon(
				PackedStringArray([
					"....OOOO....",
					"...OHHLLO...",
					"..OHLMMMLO..",
					".OOHMMMMHOO.",
					"OHLOOMMOOHLO",
					"OLMMOOOOOMMO",
					"OMMMBHHBMMBO",
					".OBBBLMBBBO.",
					"..OOBMMBOO..",
					"...OBBBBO...",
					"....OOOO....",
					"............",
				]),
				{
					"O": outline,
					"H": Color(0.78, 1.0, 0.74, 1.0),
					"L": Color(0.44, 0.85, 0.49, 1.0),
					"M": Color(0.22, 0.62, 0.33, 1.0),
					"B": Color(0.13, 0.39, 0.22, 1.0),
				},
			)
		&"beaks":
			return _build_pixel_icon(
				PackedStringArray([
					"............",
					".OOOOOOO....",
					"OHHHHHHLLO..",
					"OHHHLLLLMMO.",
					"OLLMMMMMMBOO",
					"OMMMMMBMMBMO",
					"OBBBBO..OBBO",
					".OOOOO...OBO",
					".OMMMBO...OO",
					"..OOOO......",
					"............",
					"............",
				]),
				{
					"O": outline,
					"H": Color(1.0, 0.95, 0.77, 1.0),
					"L": Color(0.95, 0.79, 0.42, 1.0),
					"M": Color(0.83, 0.57, 0.22, 1.0),
					"B": Color(0.56, 0.33, 0.11, 1.0),
				},
			)
	return null


static func _build_pixel_icon(rows: PackedStringArray, palette: Dictionary) -> ImageTexture:
	var img: Image = Image.create(24, 24, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	for y: int in range(mini(rows.size(), 12)):
		var row: String = rows[y]
		for x: int in range(mini(row.length(), 12)):
			var ch: String = row.substr(x, 1)
			if not palette.has(ch):
				continue
			var col: Color = palette[ch] as Color
			var px: int = x * 2
			var py: int = y * 2
			img.set_pixel(px, py, col)
			img.set_pixel(px + 1, py, col)
			img.set_pixel(px, py + 1, col)
			img.set_pixel(px + 1, py + 1, col)
	return ImageTexture.create_from_image(img)


static func get_dino_sprite(dino_id: StringName, fallback_sprite: Texture2D = null) -> Texture2D:
	if fallback_sprite != null:
		return fallback_sprite
	if _dino_sprite_cache.has(dino_id):
		return _dino_sprite_cache[dino_id] as Texture2D
	var path: String = "res://assets/sprites/%s.png" % String(dino_id)
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex != null:
		_dino_sprite_cache[dino_id] = tex
	return tex
