extends Resource
## Centraliza todas as constantes de economia e balanceamento do Fóssil Rush.
## Editável em `res://data/balance.tres` e carregado por `GameState`.

@export_group("Meteoro & Prestígio")
@export var base_meteor_time: float = 600.0
@export var meteor_first_run: int = 1
@export var early_impact_min_depth: int = 3
@export var early_impact_min_amber: float = 1.0
@export var prestige_dig_exponent: float = 0.28

@export_group("Fórmula de Âmbar")
@export var amber_bones_divisor: float = 2700.0
@export var amber_bones_exponent: float = 0.088
@export var amber_depth_per_layer: float = 0.042
@export var amber_layer_progress_weight: float = 0.05
@export var amber_shield_bonus: float = 0.75

@export_group("Projeto Arca")
@export var ark_required_level: int = 5
@export var ark_required_shield: float = 0.75
@export var ark_required_era: int = 3
@export var ark_first_completion_amber: float = 25.0

@export_group("Escavação, Veios & Drops")
@export var base_click_damage: float = 1.0
@export var base_click_crit_chance: float = 0.05
@export var click_crit_multiplier: float = 2.5
@export var max_overkill_layers_per_hit: int = 8
@export var drop_rolls_per_base_layer: float = 16.0
@export var drop_max_single_prob: float = 0.95
@export var layer_break_bonus_fragment_chance: float = 0.35
@export var vein_click_multiplier: float = 5.5
@export var vein_bps_seconds: float = 2.0
@export var vein_mineral_multiplier: float = 2.0
@export var vein_fragment_chance: float = 0.50
@export var rocks_per_bone_ratio: float = 0.08

@export_group("Progresso Offline")
@export var offline_base_efficiency: float = 0.20
@export var offline_max_efficiency: float = 0.50
@export var offline_max_hours: float = 8.0

@export_group("Papéis dos Dinossauros")
@export var collector_max_units: int = 30
@export var collector_default_bone_bonus: float = 0.015
@export var collector_drop_bonus_ratio: float = 1.0
@export var fast_pack_bonus_per_unit: float = 0.02
@export var fast_pack_max_units: int = 30
@export var area_tremor_bonus_per_unit: float = 0.015
@export var area_tremor_max_units: int = 30
@export var breaker_era_bonus: float = 0.25
@export var transport_max_units: int = 25
@export var transport_default_mineral_bonus: float = 0.03
@export var support_max_units: int = 20
@export var support_dna_bonus_ratio: float = 0.50
@export var defense_shield_to_dino_damage: float = 0.65
@export var shield_excavation_bonus: float = 0.85
@export var elemental_hp_pct_per_unit: float = 0.002
@export var elemental_hp_pct_cap: float = 0.04
@export var elemental_dps_cap_ratio: float = 0.45

@export_group("Museu & Golpe Preciso")
@export var fossil_rarity_weights: Array[float] = [55.0, 27.0, 13.0, 5.0]
@export var precise_strike_perfect_mult: float = 8.0
@export var precise_strike_good_mult: float = 3.5
@export var precise_strike_dial_duration: float = 2.6
@export var precise_strike_dial_cooldown: float = 5.5
