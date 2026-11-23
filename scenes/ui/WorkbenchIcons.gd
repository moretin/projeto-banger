extends RefCounted
## Atlas da bancada na ordem de leitura, da esquerda para a direita.

const ATLAS: Texture2D = preload("res://assets/sprites/icons/upgrade_atlas.png")
const CELL: Vector2 = Vector2(96.0, 96.0)
const COLUMNS: int = 8
const ICON_IDS: Array[StringName] = [
	&"tools_sharp_pickaxe", &"tools_metal_pick", &"tools_diamond_chisel", &"tools_fine_brush",
	&"forest_sawmill_blades", &"forest_resin_refinery", &"forest_amber_sap", &"forest_berry_tonic",

	&"tools_geologist_lens", &"tools_mineral_scanner", &"field_helmet", &"field_fins",
	&"forest_spore_greenhouse", &"forest_canopy_ritual", &"field_ice_crampons", &"field_aurora_prism",

	&"field_goggles", &"field_lens", &"field_timber_harness", &"field_botanic_basket",
	&"snow_cryo_drill", &"snow_glacial_lens", &"snow_cryo_vault", &"snow_aurora_beacon",

	&"snow_arctic_chronometer", &"snow_polar_shield", &"uni_cleaning_speed", &"uni_clean_double",
	&"dinos_paleo_treatise", &"dinos_raptor_claws", &"dinos_scale_armor", &"dinos_sky_scouts",

	&"uni_fossil_luck", &"defense_reinforced_bunker", &"defense_thermal_dome", &"defense_orbital_radar",
	&"amber_ark_project", &"amber_extra_time", &"amber_fossil_mastery", &"amber_fragment_magnet",

	&"dinos_beak_talons", &"dinos_dna_synthesizer", &"dinos_fish_banquet", &"dinos_pack_instinct",
	&"amber_offline_lab", &"amber_tectonic_breaker", &"__build_station", &"__expand_station",
]

static var _icons: Dictionary[StringName, AtlasTexture] = {}


static func get_icon(item_id: StringName) -> Texture2D:
	if _icons.has(item_id):
		return _icons[item_id]
	var index: int = ICON_IDS.find(item_id)
	if index < 0:
		return null

	var tile: Vector2 = Vector2(index % COLUMNS, floori(float(index) / COLUMNS))
	var icon: AtlasTexture = AtlasTexture.new()
	icon.atlas = ATLAS
	icon.region = Rect2(tile * CELL, CELL)
	icon.filter_clip = true
	_icons[item_id] = icon
	return icon
