@warning_ignore_start("unsafe_method_access", "unsafe_property_access")
extends SceneTree
## Simulador Headless de Economia & Estratégias de Run do Fóssil Rush.
## Execução: Godot_v4.7.1-stable_win64_console.exe --headless -s res://tests/simulate_runs.gd
##
## Premissas documentadas:
##   • Passo fixo dt = 0.5s (1800 passos para uma run base de 900s).
##   • Semente fixa RNG (seed = 424242) para comparação determinística entre estratégias.
##   • Taxa de cliques ativos:
##       - STRAT_CLICKS: 4.0 cliques/s
##       - STRAT_MACHINES: 1.5 cliques/s (build passiva)
##       - Demais estratégias: 2.5 cliques/s
##   • SaveManager.autosave_enabled = false para nunca alterar o save real do jogador.

const DT: float = 0.5
const STRATEGIES: PackedStringArray = [
	"STRAT_CLICKS",
	"STRAT_DINOS",
	"STRAT_MACHINES",
	"STRAT_ECONOMY",
	"STRAT_DEFENSE",
	"STRAT_HYBRID",
]

var _frame: int = 0
var _gs: Node
var _sm: Node


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 2:
		return false
	_gs = root.get_node("/root/GameState")
	_sm = root.get_node("/root/SaveManager")
	_sm.autosave_enabled = false
	_run_simulations()
	quit(0)
	return true


func _run_simulations() -> void:
	print("==========================================================================")
	print("FÓSSIL RUSH — SIMULADOR DE ECONOMIA & BALANCEAMENTO (dt = 0.5s, seed=424242)")
	print("==========================================================================")

	print("\n### 1. Comparativo de Estratégias — Run 1 (900s)")
	print("| Estratégia | Era Final | Profund. | Ossos Totais | DPS Pico | Dinos | Escudo | Âmbar |")
	print("|---|---|---|---|---|---|---|---|")

	for strat: String in STRATEGIES:
		seed(424242)
		_gs.start_new_game()
		var clicks_per_sec: float = 4.0 if strat == "STRAT_CLICKS" else (1.5 if strat == "STRAT_MACHINES" else 2.5)
		var dino_timers: Dictionary[StringName, float] = {}
		var res: Dictionary = _simulate_single_run(strat, clicks_per_sec, dino_timers)
		var peak_dps: float = float(res["peak_dps"])
		var era: EraData = _gs.get_current_era()
		var era_name: String = era.display_name if era != null else "—"
		var total_dinos: int = _count_all_dinos()
		var shield_pct: int = roundi(float(_gs.get_shield_ratio()) * 100.0)
		var amber: float = float(_gs.calculate_amber_reward())
		print("| %s | %s | %dm | %s | %s/s | %d | %d%% | +%s |" % [
			strat,
			era_name,
			int(_gs.depth),
			str(_gs.format_number(_gs.run_total_bones)),
			str(_gs.format_number(peak_dps)),
			total_dinos,
			shield_pct,
			str(_gs.format_number(amber)),
		])

	print("\n### 2. Progressão Multi-Run (Runs 1 -> 5, STRAT_HYBRID + Gasto de Âmbar)")
	print("| Run | Duração | Era Final | Profund. | Ossos Totais | DPS Pico | Dinos | Escudo | Âmbar Ganho | Arca Pronta? |")
	print("|---|---|---|---|---|---|---|---|---|---|")

	seed(424242)
	_gs.start_new_game()
	for run_idx: int in range(1, 6):
		var dino_timers: Dictionary[StringName, float] = {}
		var res: Dictionary = _simulate_single_run("STRAT_HYBRID", 2.5, dino_timers)
		var era: EraData = _gs.get_current_era()
		var era_name: String = era.display_name if era != null else "—"
		var final_depth: int = int(_gs.depth)
		var total_dinos: int = _count_all_dinos()
		var shield_pct: int = roundi(float(_gs.get_shield_ratio()) * 100.0)
		var ark_ready: String = "SIM" if _gs.can_activate_ark_victory() else "Nv %d/5" % int(_gs.get_upgrade_level(&"amber_ark_project"))
		var gained: float = float(_gs.perform_prestige())
		print("| #%d | %s | %s | %dm | %s | %s/s | %d | %d%% | +%s | %s |" % [
			run_idx,
			str(_gs.format_time(float(res["elapsed"]))),
			era_name,
			final_depth,
			str(_gs.format_number(float(res["run_bones"]))),
			str(_gs.format_number(float(res["peak_dps"]))),
			total_dinos,
			shield_pct,
			str(_gs.format_number(gained)),
			ark_ready,
		])
		_spend_amber_wisely()


func _simulate_single_run(strat: String, clicks_per_sec: float, dino_timers: Dictionary[StringName, float]) -> Dictionary:
	var duration: float = float(_gs.meteor_total_time)
	var elapsed: float = 0.0
	var peak_dps: float = 0.0
	var crit_chance: float = clampf(float(_gs.get_stat(_gs.STAT_CLICK_CRIT_CHANCE, 0.05)), 0.0, 0.95)
	var click_accum: float = 0.0

	while elapsed < float(_gs.meteor_total_time):
		elapsed += DT
		click_accum += clicks_per_sec * DT
		var clicks_now: int = floori(click_accum)
		click_accum -= float(clicks_now)
		for _c: int in range(clicks_now):
			var dmg: float = float(_gs.get_click_damage())
			if randf() < crit_chance:
				dmg *= 2.5
			_gs.apply_dig_damage(dmg, Vector2.ZERO)

		for data: DinoData in _gs.get_dinos_sorted():
			var count: int = int(_gs.get_dino_count(data.id))
			if count <= 0 or data.attack_interval <= 0.0:
				continue
			var t: float = dino_timers.get(data.id, 0.0) + DT
			if t >= data.attack_interval:
				var swings: int = floori(t / data.attack_interval)
				t = fmod(t, data.attack_interval)
				var d_dmg: float = float(_gs.get_dino_damage(data.id)) * float(count) * float(swings)
				if randf() < data.crit_chance:
					d_dmg *= data.crit_multiplier
				_gs.apply_dig_damage(d_dmg, Vector2.ZERO)
			dino_timers[data.id] = t

		var dna_rate: float = float(_gs.get_dna_per_second())
		if dna_rate > 0.0:
			_gs.add_resource(_gs.RES_DNA, dna_rate * DT)
		var passive_dps: float = float(_gs.get_auto_dps()) + float(_gs.get_acid_dot_dps())
		if passive_dps > 0.0:
			_gs.apply_dig_damage(passive_dps * DT, Vector2.ZERO)

		_buy_for_strategy(strat)
		peak_dps = maxf(peak_dps, float(_gs.get_total_dps()) + float(_gs.get_click_damage()) * clicks_per_sec)
		duration = float(_gs.meteor_total_time)

	return {
		"elapsed": duration,
		"peak_dps": peak_dps,
		"run_bones": float(_gs.run_total_bones),
	}


func _buy_for_strategy(strat: String) -> void:
	for _step: int in range(4):
		var bought: bool = false
		match strat:
			"STRAT_CLICKS":
				bought = _try_upgrades([
					&"tools_diamond_chisel", &"tools_sharp_pickaxe", &"tools_fine_brush",
					&"machines_conveyor_belt", &"tools_geologist_lens",
				])
			"STRAT_DINOS":
				bought = _try_dinos_first() or _try_upgrades([
					&"dinos_primal_fury", &"dinos_dna_synthesizer", &"dinos_apex_jaw",
					&"dinos_raptor_claws", &"dinos_pack_instinct", &"tools_geologist_lens",
					&"tools_sharp_pickaxe", &"tools_fine_brush",
				])
			"STRAT_MACHINES":
				bought = _try_upgrades([
					&"machines_geo_laser", &"machines_dynamite_rig", &"machines_conveyor_belt",
					&"machines_pneumatic_drill", &"tools_mineral_scanner", &"tools_sharp_pickaxe",
					&"tools_fine_brush",
				])
			"STRAT_ECONOMY":
				bought = _try_upgrades([
					&"tools_fine_brush", &"machines_conveyor_belt", &"tools_geologist_lens",
					&"tools_mineral_scanner", &"dinos_dna_synthesizer", &"tools_sharp_pickaxe",
				]) or _try_dinos_first()
			"STRAT_DEFENSE":
				bought = _try_upgrades([
					&"defense_thermal_dome", &"defense_orbital_radar", &"defense_reinforced_bunker",
					&"tools_mineral_scanner", &"tools_sharp_pickaxe",
				]) or _try_specific_dino(&"ankylosaurus") or _try_dinos_first()
			"STRAT_HYBRID":
				bought = _buy_hybrid_best()
		if not bought:
			break


func _buy_hybrid_best() -> bool:
	for data: DinoData in _gs.get_dinos_sorted():
		if int(_gs.get_dino_count(data.id)) == 0 and bool(_gs.can_assemble_dino(data.id, 1)):
			return bool(_gs.assemble_dino(data.id, 1))

	var best_kind: String = ""
	var best_id: StringName = &""
	var best_score: float = 0.0
	var bones: float = float(_gs.get_resource(_gs.RES_BONES))
	var current_dps: float = maxf(float(_gs.get_total_dps()) + float(_gs.get_click_damage()) * 2.5, 2.5)

	for data: DinoData in _gs.get_dinos_sorted():
		if int(_gs.get_dino_count(data.id)) <= 0 or not bool(_gs.can_assemble_dino(data.id, 1)):
			continue
		var cost: float = float(_gs.get_dino_purchase_cost(data.id, 1))
		var unit_dps: float = float(_gs.get_dino_damage(data.id)) / maxf(data.attack_interval, 0.01)
		var score: float = unit_dps / maxf(cost, 1.0)
		if score > best_score:
			best_score = score
			best_kind = "dino"
			best_id = data.id

	for upg: UpgradeData in _gs.upgrades_db.values():
		if upg.is_permanent or not bool(_gs.can_purchase_upgrade(upg.id, 1)):
			continue
		var cost_u: float = float(_gs.get_purchase_cost(upg.id, 1))
		var norm_cost: float = cost_u * (500.0 if upg.cost_resource == _gs.RES_MINERALS else (80.0 if upg.cost_resource == _gs.RES_DNA else 1.0))
		var gain: float = 0.0
		match upg.stat_id:
			_gs.STAT_CLICK_DAMAGE:
				gain = upg.effect_value * 2.5
			_gs.STAT_AUTO_DPS:
				gain = upg.effect_value
			_gs.STAT_BONES_MULT:
				gain = current_dps * upg.effect_value * 0.75
			_gs.STAT_DINO_DAMAGE:
				gain = float(_gs.get_total_dino_dps()) * (upg.effect_value if upg.effect_type == UpgradeData.EffectType.MULTIPLY_PERCENT else (upg.effect_value - 1.0))
			_gs.STAT_FRAGMENT_CHANCE:
				gain = current_dps * 0.18 if int(_gs.get_upgrade_level(upg.id)) < 4 else 0.0
			_gs.STAT_MINERAL_CHANCE:
				gain = current_dps * 0.12 if int(_gs.get_upgrade_level(upg.id)) < 4 else 0.0
			_gs.STAT_METEOR_SHIELD:
				if bones > 600.0 or upg.cost_resource == _gs.RES_MINERALS:
					gain = current_dps * 0.14
			_gs.STAT_METEOR_TIME:
				gain = current_dps * 0.08
			_gs.STAT_DNA_MULT:
				gain = current_dps * 0.15
		if upg.stat_id.begins_with("dino_damage:"):
			var sp: StringName = StringName(String(upg.stat_id).split(":")[1])
			var sp_cnt: int = int(_gs.get_dino_count(sp))
			if sp_cnt > 0:
				var sp_d: DinoData = _gs.get_dino(sp)
				if sp_d != null:
					gain = float(_gs.get_dino_damage(sp)) * float(sp_cnt) / maxf(sp_d.attack_interval, 0.1) * upg.effect_value
		var score_u: float = gain / maxf(norm_cost, 1.0)
		if score_u > best_score:
			best_score = score_u
			best_kind = "upg"
			best_id = upg.id

	if best_kind == "dino":
		return bool(_gs.assemble_dino(best_id, 1))
	if best_kind == "upg":
		return bool(_gs.purchase_upgrade(best_id, 1))
	return false


func _try_upgrades(order: Array[StringName]) -> bool:
	for id: StringName in order:
		if bool(_gs.can_purchase_upgrade(id, 1)):
			return bool(_gs.purchase_upgrade(id, 1))
	return false


func _try_dinos_first() -> bool:
	var list: Array[DinoData] = _gs.get_dinos_sorted()
	for data: DinoData in list:
		if int(_gs.get_dino_count(data.id)) == 0 and bool(_gs.can_assemble_dino(data.id, 1)):
			return bool(_gs.assemble_dino(data.id, 1))
	for i: int in range(list.size() - 1, -1, -1):
		if bool(_gs.can_assemble_dino(list[i].id, 1)):
			return bool(_gs.assemble_dino(list[i].id, 1))
	return false


func _try_specific_dino(id: StringName) -> bool:
	if bool(_gs.can_assemble_dino(id, 1)):
		return bool(_gs.assemble_dino(id, 1))
	return false


func _spend_amber_wisely() -> void:
	var order: Array[StringName] = [
		&"amber_fossil_mastery",
		&"amber_fragment_magnet",
		&"amber_ark_project",
		&"amber_extra_time",
		&"amber_offline_lab",
	]
	for _round: int in range(20):
		var bought: bool = false
		for id: StringName in order:
			if bool(_gs.can_purchase_upgrade(id, 1)):
				_gs.purchase_upgrade(id, 1)
				bought = true
		if not bought:
			break


func _count_all_dinos() -> int:
	var total: int = 0
	for k: StringName in _gs.dino_counts:
		total += int(_gs.get_dino_count(k))
	return total
