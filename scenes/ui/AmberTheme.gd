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
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path) as Texture2D
	if tex != null:
		_icon_cache[icon_key] = tex
	return tex


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
	return null


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
