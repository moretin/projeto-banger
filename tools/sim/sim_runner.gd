@warning_ignore_start("unsafe_method_access", "unsafe_property_access")
extends SceneTree
## Simulador Headless Determinístico de Economia & Balanceamento (Fóssil Rush).
## Executa contra o autoload real `/root/GameState`, desabilitando autosave.
##
## Uso:
##   godot --headless --path . -s res://tools/sim/sim_runner.gd
##   godot --headless --path . -s res://tools/sim/sim_runner.gd -- --mode=all --json=out.json

const DT: float = 0.25
const VEIN_INTERVAL: float = 35.0
const SEED_BASE: int = 424242

const STRATEGIES: PackedStringArray = [
	"CLIQUE",
	"DINOS",
	"MAQUINAS",
	"ECONOMIA",
	"DEFESA",
	"HIBRIDA",
]

var _frame: int = 0
var _gs: Node
var _sm: Node
var _ev: Node

var _mode: String = "all"
var _json_out: String = ""
var _max_campaign_runs: int = 80
var _strike_rate: float = 0.5


func _init() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mode="):
			_mode = arg.trim_prefix("--mode=")
		elif arg.begins_with("--json="):
			_json_out = arg.trim_prefix("--json=")
		elif arg.begins_with("--max-runs="):
			_max_campaign_runs = maxi(int(arg.trim_prefix("--max-runs=")), 1)
		elif arg.begins_with("--strike-rate="):
			_strike_rate = clampf(float(arg.trim_prefix("--strike-rate=")), 0.0, 1.0)


func _process(_delta: float) -> bool:
	_frame += 1
	if _frame < 2:
		return false
	_gs = root.get_node("/root/GameState")
	_sm = root.get_node("/root/SaveManager")
	_ev = root.get_node("/root/Events")
	_sm.autosave_enabled = false

	var report: Dictionary = {}
	if _mode == "all" or _mode == "run1":
		report["run1"] = _run_strategy_comparison(_strike_rate)
	if _mode == "all" or _mode == "precise":
		report["precise_strike_matrix"] = _run_precise_strike_matrix()
	if _mode == "all" or _mode == "campaign":
		report["campaign"] = _run_campaign_to_ark(_strike_rate)
	if _mode == "all" or _mode == "audits":
		report["audits"] = _run_audits()

	if _json_out != "":
		var f: FileAccess = FileAccess.open(_json_out, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(report, "\t"))
			f.close()
			print("\n[SIM] JSON salvo em: %s" % _json_out)

	quit(0)
	return true


# ==============================================================================
# 1. COMPARATIVO DE 6 ESTRATÉGIAS NA RUN 1
# ==============================================================================

func _run_strategy_comparison(strike_rate: float = 0.5) -> Dictionary:
	print("==========================================================================")
	print("SIMULACAO RUN 1 — 6 ESTRATEGIAS (dt=%.2fs, seed=%d, golpe_preciso=%.0f%%)" % [DT, SEED_BASE, strike_rate * 100.0])
	print("==========================================================================")

	var all_upgrades_bought: Dictionary = {}
	for upg_id: StringName in _gs.upgrades_db:
		all_upgrades_bought[String(upg_id)] = 0

	var results: Array[Dictionary] = []
	for strat: String in STRATEGIES:
		seed(SEED_BASE)
		_gs.start_new_game()
		var run_data: Dictionary = _simulate_run(strat, all_upgrades_bought, -1, strike_rate)
		results.append(run_data)

	print("\n### Resumo Run 1 por Estrategia (Golpe Preciso %.0f%%)" % [strike_rate * 100.0])
	print("| Estrategia | Dur | 1o Upg | 1a Auto | 1o Dino | Gap<=5m | Era Final | Prof | Ossos | DPS Pico | Dinos | GP(P/G/M) | Fosseis(Lend) | Escudo | Ambar | Compras Perm |")
	print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
	for r: Dictionary in results:
		print("| %s | %s | %s | %s | %s | %s | %s | %dm | %s | %s/s | %d | %d/%d/%d | %d(%d) | %d%% | +%s | %d |" % [
			str(r["strategy"]),
			str(_gs.format_time(float(r["duration"]))),
			_fmt_opt_time(float(r["t_first_upgrade"])),
			_fmt_opt_time(float(r["t_first_automation"])),
			_fmt_opt_time(float(r["t_first_dino"])),
			_fmt_opt_time(float(r["max_gap_5m"])),
			str(r["era_name"]),
			int(r["depth"]),
			str(_gs.format_number(float(r["bones"]))),
			str(_gs.format_number(float(r["peak_dps"]))),
			int(r["total_dinos"]),
			int(r["strikes_perfect"]),
			int(r["strikes_good"]),
			int(r["strikes_miss"]),
			int(r["fossils_run"]),
			int(r["legendaries_run"]),
			int(r["shield_pct"]),
			str(_gs.format_number(float(r["amber"]))),
			int(r["amber_upgrades_buyable"]),
		])

	print("\n### DPS por Minuto (Run 1)")
	for r: Dictionary in results:
		var dps_arr: Array = r["dps_per_minute"]
		var parts: PackedStringArray = []
		for i: int in range(dps_arr.size()):
			parts.append("m%d:%s" % [i + 1, str(_gs.format_number(float(dps_arr[i])))])
		print("  %-9s => %s" % [str(r["strategy"]), ", ".join(parts)])

	print("\n### Tempos por Era & Primeiras Camadas (Run 1)")
	for r: Dictionary in results:
		var eras_dict: Dictionary = r["t_eras"]
		var era_parts: PackedStringArray = []
		for k: Variant in eras_dict:
			era_parts.append("Era%s=%.1fs" % [str(k), float(eras_dict[k])])
		var layers_arr: Array = r["t_layers"]
		var layer_parts: PackedStringArray = []
		var max_show: int = mini(layers_arr.size(), 10)
		for i: int in range(max_show):
			layer_parts.append("%dm:%.0fs" % [i + 1, float(layers_arr[i])])
		print("  %-9s => Eras=[%s] | Camadas(1..%d)=[%s]" % [
			str(r["strategy"]),
			", ".join(era_parts),
			max_show,
			", ".join(layer_parts),
		])

	# Detector de estrategia dominante
	var ambers: Array[float] = []
	var bones_list: Array[float] = []
	var max_amber: float = -1.0
	var max_amber_strat: String = ""
	var max_bones: float = -1.0
	var max_bones_strat: String = ""
	for r: Dictionary in results:
		var a: float = float(r["amber"])
		var b: float = float(r["bones"])
		ambers.append(a)
		bones_list.append(b)
		if a > max_amber:
			max_amber = a
			max_amber_strat = str(r["strategy"])
		if b > max_bones:
			max_bones = b
			max_bones_strat = str(r["strategy"])
	ambers.sort()
	bones_list.sort()
	var med_amber: float = (ambers[2] + ambers[3]) * 0.5
	var med_bones: float = (bones_list[2] + bones_list[3]) * 0.5
	var amber_dom_ratio: float = max_amber / maxf(med_amber, 1.0)
	var bones_dom_ratio: float = max_bones / maxf(med_bones, 1.0)

	print("\n### Auditoria de Estrategia Dominante (Run 1)")
	print("  Maior Ambar: %s (+%s) vs Mediana (+%s) => razao %.2fx" % [
		max_amber_strat, str(_gs.format_number(max_amber)), str(_gs.format_number(med_amber)), amber_dom_ratio
	])
	print("  Maior Ossos: %s (%s) vs Mediana (%s) => razao %.2fx" % [
		max_bones_strat, str(_gs.format_number(max_bones)), str(_gs.format_number(med_bones)), bones_dom_ratio
	])

	# Upgrades nao comprados na Run 1 (nao permanentes)
	var unused_run1: PackedStringArray = []
	for upg_id: StringName in _gs.upgrades_db:
		var upg: UpgradeData = _gs.get_upgrade(upg_id)
		if upg != null and not upg.is_permanent:
			if int(all_upgrades_bought.get(String(upg_id), 0)) == 0:
				unused_run1.append(String(upg_id))
	print("  Upgrades de run com 0 compras nas 6 estrategias (Run 1): %s" % (
		", ".join(unused_run1) if not unused_run1.is_empty() else "nenhum"
	))

	return {
		"strategies": results,
		"amber_dominance_ratio": amber_dom_ratio,
		"bones_dominance_ratio": bones_dom_ratio,
		"max_amber_strat": max_amber_strat,
		"max_bones_strat": max_bones_strat,
		"unused_run1_upgrades": Array(unused_run1),
		"upgrade_counts_run1": all_upgrades_bought,
	}


# ==============================================================================
# 2. CAMPANHA MULTI-RUN ATÉ PROJETO ARCA (ESTRATÉGIA HIBRIDA)
# ==============================================================================

func _run_precise_strike_matrix() -> Dictionary:
	print("\n==========================================================================")
	print("MATRIZ GOLPE PRECISO (0%, 50%, 90%) — IMPACTO NA DOMINANCIA E CAMPANHA")
	print("==========================================================================")
	var rates: Array[float] = [0.0, 0.5, 0.9]
	var rows: Array[Dictionary] = []
	print("\n| Taxa GP | Estrategia | Era Final | Prof | Ossos | Ambar+ | GP (P/G/M) | Fosseis(Lend) |")
	print("|---|---|---|---|---|---|---|---|")
	for rate: float in rates:
		var dummy_counts: Dictionary = {}
		var best_bones: float = -1.0
		var best_strat: String = ""
		var strat_bones: Array[float] = []
		var strat_ambers: Array[float] = []
		var max_amber: float = -1.0
		var max_amber_strat: String = ""
		for strat: String in STRATEGIES:
			seed(SEED_BASE)
			_gs.start_new_game()
			var r: Dictionary = _simulate_run(strat, dummy_counts, -1, rate)
			var b: float = float(r["bones"])
			var a: float = float(r["amber"])
			strat_bones.append(b)
			strat_ambers.append(a)
			if b > best_bones:
				best_bones = b
				best_strat = strat
			if a > max_amber:
				max_amber = a
				max_amber_strat = strat
			print("| %.0f%% | %s | %s | %dm | %s | +%s | %d/%d/%d | %d(%d) |" % [
				rate * 100.0,
				strat,
				str(r["era_name"]),
				int(r["depth"]),
				str(_gs.format_number(b)),
				str(_gs.format_number(a)),
				int(r["strikes_perfect"]),
				int(r["strikes_good"]),
				int(r["strikes_miss"]),
				int(r["fossils_run"]),
				int(r["legendaries_run"]),
			])
		strat_bones.sort()
		strat_ambers.sort()
		var med_b: float = (strat_bones[2] + strat_bones[3]) * 0.5
		var med_a: float = (strat_ambers[2] + strat_ambers[3]) * 0.5
		var dom_b: float = best_bones / maxf(med_b, 1.0)
		var dom_a: float = max_amber / maxf(med_a, 1.0)

		var camp_summary: Dictionary = _run_campaign_to_ark(rate, false)
		rows.append({
			"strike_rate": rate,
			"max_bones_strat": best_strat,
			"bones_dominance_ratio": dom_b,
			"max_amber_strat": max_amber_strat,
			"amber_dominance_ratio": dom_a,
			"ark_run": int(camp_summary["ark_ready_run"]),
			"ark_hours": float(camp_summary["ark_ready_hours"]),
			"run1_depth": int(camp_summary["run1_depth"]),
			"run2_recover_ratio": float(camp_summary["run2_recover_ratio"]),
			"museum_fossils_total": int(camp_summary["museum_fossils_total"]),
			"museum_legendaries_total": int(camp_summary["museum_legendaries_total"]),
			"museum_species_total": int(camp_summary["museum_species_total"]),
		})
	print("\n### Sumario Comparativo Golpe Preciso (0% vs 50% vs 90%)")
	print("| Taxa GP | Maior Ossos (Dom) | Maior Ambar (Dom) | Prof R1 | Recup R2 | Arca (Run/Horas) | Museu Campanha (Foss/Lend/Esp) |")
	print("|---|---|---|---|---|---|---|")
	for row: Dictionary in rows:
		print("| %.0f%% | %s (%.2fx) | %s (%.2fx) | %dm | %.1f%% | Run #%d (%.2fh) | %d / %d / %d/8 |" % [
			float(row["strike_rate"]) * 100.0,
			str(row["max_bones_strat"]),
			float(row["bones_dominance_ratio"]),
			str(row["max_amber_strat"]),
			float(row["amber_dominance_ratio"]),
			int(row["run1_depth"]),
			float(row["run2_recover_ratio"]) * 100.0,
			int(row["ark_run"]),
			float(row["ark_hours"]),
			int(row["museum_fossils_total"]),
			int(row["museum_legendaries_total"]),
			int(row["museum_species_total"]),
		])
	return {"matrix": rows}


func _run_campaign_to_ark(strike_rate: float = 0.5, verbose: bool = true) -> Dictionary:
	if verbose:
		print("\n==========================================================================")
		print("SIMULACAO CAMPANHA COMPLETA ATE PROJETO ARCA (HIBRIDA, GP=%.0f%%)" % [strike_rate * 100.0])
		print("==========================================================================")
	seed(SEED_BASE)
	_gs.start_new_game()

	var campaign_upgrades: Dictionary = {}
	for upg_id: StringName in _gs.upgrades_db:
		campaign_upgrades[String(upg_id)] = 0

	var runs: Array[Dictionary] = []
	var total_seconds: float = 0.0
	var run1_depth: int = 0
	var run1_duration: float = 0.0
	var run2_recover_time: float = -1.0
	var run2_recover_ratio: float = -1.0
	var prev_depth: int = -1
	var monotonic_depth: bool = true
	var ark_ready_run: int = -1
	var ark_ready_hours: float = -1.0

	for run_idx: int in range(1, _max_campaign_runs + 1):
		var target_depth_for_recovery: int = run1_depth if run_idx == 2 else -1
		var r: Dictionary = _simulate_run("HIBRIDA", campaign_upgrades, target_depth_for_recovery, strike_rate)
		total_seconds += float(r["duration"])
		var cur_depth: int = int(r["depth"])
		if run_idx == 1:
			run1_depth = cur_depth
			run1_duration = float(r["duration"])
		elif run_idx == 2:
			run2_recover_time = float(r["t_recover_target"])
			if run2_recover_time >= 0.0 and run1_duration > 0.0:
				run2_recover_ratio = run2_recover_time / run1_duration
		if cur_depth <= prev_depth:
			monotonic_depth = false
		prev_depth = cur_depth

		var ark_ready: bool = bool(_gs.can_activate_ark_victory())
		if ark_ready and ark_ready_run < 0:
			ark_ready_run = run_idx
			ark_ready_hours = total_seconds / 3600.0
			_gs.activate_ark_victory()

		var gained_amber: float = float(_gs.perform_prestige())
		var perm_bought: Array[String] = _spend_amber_campaign(campaign_upgrades)

		r["run_number"] = run_idx
		r["cum_hours"] = total_seconds / 3600.0
		r["amber_gained"] = gained_amber
		r["ark_ready"] = ark_ready
		r["ark_level"] = int(_gs.get_upgrade_level(&"amber_ark_project"))
		r["perm_bought"] = perm_bought
		runs.append(r)

		if ark_ready:
			break

	var unused_campaign: PackedStringArray = []
	for upg_id: StringName in _gs.upgrades_db:
		if int(campaign_upgrades.get(String(upg_id), 0)) == 0:
			unused_campaign.append(String(upg_id))

	var museum_fossils: int = int(_gs.total_fossils_evaluated)
	var museum_legendaries: int = int(_gs.total_legendary_fossils)
	var museum_species: int = int(_gs.fossil_catalog.size())

	if verbose:
		print("\n| Run | Dur | Tempo Acum | Era Final | Prof | Recup R1 | Ossos | DPS Pico | Dinos | GP(P/G/M) | Fosseis(Lend) | Escudo | Ambar+ | Arca Nv | Compras Perm |")
		print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
		for r: Dictionary in runs:
			var rec_str: String = "—"
			if int(r["run_number"]) == 2:
				rec_str = "%.0fs (%.1f%%)" % [run2_recover_time, run2_recover_ratio * 100.0] if run2_recover_time >= 0.0 else "N/A"
			var pb: Array = r["perm_bought"]
			var pb_str: String = ", ".join(pb) if not pb.is_empty() else "poupa"
			print("| #%d | %s | %.2fh | %s | %dm | %s | %s | %s/s | %d | %d/%d/%d | %d(%d) | %d%% | +%s | %d/5 | %s |" % [
				int(r["run_number"]),
				str(_gs.format_time(float(r["duration"]))),
				float(r["cum_hours"]),
				str(r["era_name"]),
				int(r["depth"]),
				rec_str,
				str(_gs.format_number(float(r["bones"]))),
				str(_gs.format_number(float(r["peak_dps"]))),
				int(r["total_dinos"]),
				int(r["strikes_perfect"]),
				int(r["strikes_good"]),
				int(r["strikes_miss"]),
				int(r["fossils_run"]),
				int(r["legendaries_run"]),
				int(r["shield_pct"]),
				str(_gs.format_number(float(r["amber_gained"]))),
				int(r["ark_level"]),
				pb_str,
			])

		print("\n### Sumario Campanha (GP=%.0f%%)" % [strike_rate * 100.0])
		print("  Projeto Arca concluido?: %s (Run #%d, %.2f horas acumuladas)" % [
			"SIM" if ark_ready_run > 0 else "NAO (limite %d runs)" % _max_campaign_runs,
			ark_ready_run,
			ark_ready_hours if ark_ready_run > 0 else total_seconds / 3600.0,
		])
		print("  Run 2 recupera profundidade da Run 1 (%dm): %s (meta <= 40%%)" % [
			run1_depth,
			("%.1fs / %.1fs = %.1f%%" % [run2_recover_time, run1_duration, run2_recover_ratio * 100.0]) if run2_recover_time >= 0.0 else "NAO RECUPEROU",
		])
		print("  Toda run alcancou profundidade nova?: %s" % ("SIM" if monotonic_depth else "NAO"))
		print("  Acervo do Museu ao concluir Arca: %d fosseis catalogados (%d lendarios), %d/8 especies" % [
			museum_fossils, museum_legendaries, museum_species,
		])
		print("  Upgrades com 0 compras em toda a campanha: %s" % (
			", ".join(unused_campaign) if not unused_campaign.is_empty() else "nenhum"
		))

	return {
		"strike_rate": strike_rate,
		"runs": runs,
		"ark_ready_run": ark_ready_run,
		"ark_ready_hours": ark_ready_hours,
		"total_hours": total_seconds / 3600.0,
		"run1_depth": run1_depth,
		"run2_recover_time": run2_recover_time,
		"run2_recover_ratio": run2_recover_ratio,
		"monotonic_depth": monotonic_depth,
		"museum_fossils_total": museum_fossils,
		"museum_legendaries_total": museum_legendaries,
		"museum_species_total": museum_species,
		"unused_campaign_upgrades": Array(unused_campaign),
		"campaign_upgrade_counts": campaign_upgrades,
	}


# ==============================================================================
# 3. AUDITORIAS ESPECIFICAS (DROPS, OFFLINE, ANTECIPAR IMPACTO)
# ==============================================================================

func _run_audits() -> Dictionary:
	print("\n==========================================================================")
	print("AUDITORIAS TECNICAS (DROPS / OFFLINE / ANTECIPAR IMPACTO)")
	print("==========================================================================")

	# A) Drops: 1 golpe de 100.000 vs 1.000 golpes de 100 (camada de 1e7 HP na Era 1)
	seed(SEED_BASE)
	_gs.start_new_game()
	_gs.current_era_index = 1
	_gs.layer_max_hp = 1e7
	_gs.layer_hp = 1e7
	_gs.apply_dig_damage(100000.0, Vector2.ZERO)
	var single_min: float = float(_gs.get_resource(_gs.RES_MINERALS))
	var single_frags: int = _total_fragments()

	seed(SEED_BASE)
	_gs.start_new_game()
	_gs.current_era_index = 1
	_gs.layer_max_hp = 1e7
	_gs.layer_hp = 1e7
	for _i: int in range(1000):
		_gs.apply_dig_damage(100.0, Vector2.ZERO)
	var multi_min: float = float(_gs.get_resource(_gs.RES_MINERALS))
	var multi_frags: int = _total_fragments()
	var drop_ratio_min: float = single_min / maxf(multi_min, 1.0)
	var drop_ratio_frag: float = float(single_frags) / maxf(float(multi_frags), 1.0)

	print("  [Drops 100k dano]")
	print("    1x 100.000  => minerios=%.0f, fragmentos=%d" % [single_min, single_frags])
	print("    1000x 100   => minerios=%.0f, fragmentos=%d" % [multi_min, multi_frags])
	print("    Razao (1 golpe / 1000 golpes): minerios=%.2fx, fragmentos=%.2fx" % [drop_ratio_min, drop_ratio_frag])

	# B) Offline vs Ativo
	seed(SEED_BASE)
	_gs.start_new_game()
	_gs.dino_counts[&"compsognathus"] = 5
	_gs.dino_counts[&"velociraptor"] = 3
	_gs.upgrade_levels[&"dinos_pack_instinct"] = 3
	_gs.recalculate_stats()
	var active_bps: float = float(_gs.get_bones_per_second())
	var active_1h_bones: float = active_bps * 3600.0
	var off_1h_lv0: Dictionary = _gs.apply_offline_progress(3600.0)
	var off_bones_lv0: float = float(off_1h_lv0.get(_gs.RES_BONES, 0.0))

	var off_upg: UpgradeData = _gs.get_upgrade(&"amber_offline_lab")
	var max_off_lvl: int = off_upg.max_level if (off_upg != null and off_upg.max_level > 0) else 10
	_gs.permanent_upgrade_levels[&"amber_offline_lab"] = max_off_lvl
	_gs.recalculate_stats()
	var off_1h_lvmax: Dictionary = _gs.apply_offline_progress(3600.0)
	var off_bones_lvmax: float = float(off_1h_lvmax.get(_gs.RES_BONES, 0.0))
	var off_24h_lvmax: Dictionary = _gs.apply_offline_progress(24.0 * 3600.0)
	var off_bones_24h: float = float(off_24h_lvmax.get(_gs.RES_BONES, 0.0))
	var ratio_lv0: float = off_bones_lv0 / maxf(active_1h_bones, 1.0)
	var ratio_lvmax: float = off_bones_lvmax / maxf(active_1h_bones, 1.0)
	var eff_hours_24h: float = off_bones_24h / maxf(off_bones_lvmax, 1.0)

	print("  [Offline vs Ativo (base passiva)]")
	print("    Ativo 1h: %s | Offline 1h Nv0: %s (%.2fx)" % [
		str(_gs.format_number(active_1h_bones)), str(_gs.format_number(off_bones_lv0)), ratio_lv0
	])
	print("    Offline 1h NvMax(%d): %s (%.2fx) | Offline 24h NvMax: %s (equiv %.1fh)" % [
		max_off_lvl, str(_gs.format_number(off_bones_lvmax)), ratio_lvmax,
		str(_gs.format_number(off_bones_24h)), eff_hours_24h
	])

	# C) Antecipar Impacto sem progresso (2 cliques em t=0)
	seed(SEED_BASE)
	_gs.start_new_game()
	var early_allowed_t0: bool = true
	for _click: int in range(2):
		_ev.meteor_early_impact_requested.emit()
		if bool(_gs.is_impacting):
			_gs.perform_prestige()
	var run_after_2_early: int = int(_gs.run_number)
	var amber_after_2_early: float = float(_gs.get_resource(_gs.RES_AMBER))
	if run_after_2_early == 1:
		early_allowed_t0 = false

	print("  [Antecipar Impacto em t=0 (2 cliques)]")
	print("    Bloqueado?: %s | run_number apos 2 cliques=%d | Ambar=%s" % [
		"SIM" if not early_allowed_t0 else "NAO (EXPLOIT!)",
		run_after_2_early,
		str(_gs.format_number(amber_after_2_early)),
	])

	return {
		"drops_single_min": single_min,
		"drops_single_frags": single_frags,
		"drops_multi_min": multi_min,
		"drops_multi_frags": multi_frags,
		"drops_ratio_min": drop_ratio_min,
		"drops_ratio_frag": drop_ratio_frag,
		"offline_ratio_lv0": ratio_lv0,
		"offline_ratio_lvmax": ratio_lvmax,
		"offline_cap_hours_in_gs": eff_hours_24h,
		"early_impact_blocked_at_t0": not early_allowed_t0,
		"run_after_2_early_clicks": run_after_2_early,
	}


# ==============================================================================
# NUCLEO DE SIMULACAO DE UMA RUN
# ==============================================================================

func _simulate_run(strat: String, upgrade_counts: Dictionary, recover_depth_target: int = -1, strike_rate: float = 0.5) -> Dictionary:
	var clicks_per_sec: float = _strategy_cps(strat)
	var dino_timers: Dictionary[StringName, float] = {}
	var elapsed: float = 0.0
	var click_accum: float = 0.0
	var vein_accum: float = 0.0
	var peak_dps: float = 0.0

	var start_fossils: int = int(_gs.total_fossils_evaluated)
	var start_legendaries: int = int(_gs.total_legendary_fossils)
	var dial_cooldown: float = 0.0
	var dial_active: bool = false
	var dial_reaction_left: float = 0.0
	var strikes_perfect: int = 0
	var strikes_good: int = 0
	var strikes_miss: int = 0
	var perfect_share_when_hit: float = 0.065 / 0.19

	var t_first_upgrade: float = -1.0
	var t_first_automation: float = -1.0
	var t_first_dino: float = -1.0
	var t_recover_target: float = -1.0

	var last_buy_t_5m: float = 0.0
	var max_gap_5m: float = 0.0
	var prev_depth: int = 0
	var prev_era: int = 0
	var t_layers: Array[float] = []
	var t_eras: Dictionary = {0: 0.0}
	var dps_per_minute: Array[float] = []
	var next_minute_mark: float = 60.0

	while elapsed < float(_gs.meteor_total_time):
		elapsed += DT

		if dial_cooldown > 0.0:
			dial_cooldown = maxf(dial_cooldown - DT, 0.0)

		# 0. Fase inicial na Superfície: quebrar o Ovo de Âmbar (Rocha Laranja) antes de descer
		var clicks_for_dig: int = 0
		click_accum += clicks_per_sec * DT
		var clicks_now: int = floori(click_accum)
		click_accum -= float(clicks_now)

		if not bool(_gs.orange_rock_broken):
			for _oc: int in range(clicks_now):
				if not bool(_gs.orange_rock_broken):
					_ev.orange_rock_hit.emit(maxf(float(_gs.get_click_damage()), 1.0), Vector2.ZERO)
				else:
					clicks_for_dig += 1
		else:
			clicks_for_dig = clicks_now

		# 1. Cliques ativos na Escavação
		var crit_chance: float = clampf(float(_gs.get_stat(_gs.STAT_CLICK_CRIT_CHANCE, 0.05)), 0.0, 0.95)
		for _c: int in range(clicks_for_dig):
			var dmg: float = float(_gs.get_click_damage())
			if randf() < crit_chance:
				dmg *= 2.5
			_gs.apply_dig_damage(dmg, Vector2.ZERO)

		# 2. Ataques por espécie
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

		# 3. Passivos (DNA, Máquinas, Ácido Elemental)
		var dna_rate: float = float(_gs.get_dna_per_second())
		if dna_rate > 0.0:
			_gs.add_resource(_gs.RES_DNA, dna_rate * DT)
		var passive_dps: float = float(_gs.get_auto_dps()) + float(_gs.get_acid_dot_dps())
		if passive_dps > 0.0:
			_gs.apply_dig_damage(passive_dps * DT, Vector2.ZERO)

		# 3b. Sismógrafo Golpe Preciso (quando ativado por quebra de camada)
		if dial_active:
			dial_reaction_left -= DT
			if dial_reaction_left <= 0.0:
				dial_active = false
				var res: StringName = &"miss"
				if randf() < strike_rate:
					res = &"perfect" if randf() < perfect_share_when_hit else &"good"
				if res == &"perfect":
					strikes_perfect += 1
				elif res == &"good":
					strikes_good += 1
				else:
					strikes_miss += 1
				_gs.resolve_precise_strike(res, Vector2.ZERO)

		# 4. Veios especiais periódicos
		vein_accum += DT
		if vein_accum >= VEIN_INTERVAL:
			vein_accum -= VEIN_INTERVAL
			_gs.crack_rock_vein(Vector2.ZERO)

		# 5. Decisão de compra da estratégia
		var bought_any: bool = false
		for _step: int in range(4):
			var bought_kind: StringName = _buy_best_for_strategy(strat, upgrade_counts)
			if bought_kind == &"":
				break
			bought_any = true
			if (bought_kind == &"upgrade" or bought_kind == &"auto_upgrade") and t_first_upgrade < 0.0:
				t_first_upgrade = elapsed
			if bought_kind == &"auto_upgrade" and t_first_automation < 0.0:
				t_first_automation = elapsed
			if bought_kind == &"dino":
				if t_first_dino < 0.0:
					t_first_dino = elapsed
				if t_first_automation < 0.0:
					t_first_automation = elapsed

		# Reconstrução de estações do Acampamento com RES_ROCKS acumulado
		for rubble_id: StringName in _gs.RUBBLE_ORDER:
			if bool(_gs.can_rebuild_rubble(rubble_id)):
				_gs.rebuild_rubble(rubble_id)

		if bought_any and elapsed <= 300.0:
			max_gap_5m = maxf(max_gap_5m, elapsed - last_buy_t_5m)
			last_buy_t_5m = elapsed

		# 6. Camadas, Eras e Recuperação (+ ativação de dial do Golpe Preciso)
		var cur_depth: int = int(_gs.depth)
		if cur_depth > prev_depth and not dial_active and dial_cooldown <= 0.0:
			var cfg: Object = _gs.balance
			var cd: float = float(cfg.precise_strike_dial_cooldown) if cfg != null else 5.5
			var dur: float = float(cfg.precise_strike_dial_duration) if cfg != null else 2.6
			dial_cooldown = cd
			dial_active = true
			dial_reaction_left = minf(1.0, dur * 0.45)
		while prev_depth < cur_depth:
			prev_depth += 1
			t_layers.append(elapsed)
		if recover_depth_target > 0 and t_recover_target < 0.0 and cur_depth >= recover_depth_target:
			t_recover_target = elapsed

		var cur_era: int = int(_gs.current_era_index)
		while prev_era < cur_era:
			prev_era += 1
			t_eras[prev_era] = elapsed

		var eff_click_dps: float = float(_gs.get_click_damage()) * (1.0 + crit_chance * 1.5) * clicks_per_sec
		var cur_dps: float = float(_gs.get_total_dps()) + eff_click_dps
		peak_dps = maxf(peak_dps, cur_dps)
		while elapsed >= next_minute_mark - 0.001:
			dps_per_minute.append(cur_dps)
			next_minute_mark += 60.0

	if last_buy_t_5m < 300.0:
		max_gap_5m = maxf(max_gap_5m, minf(elapsed, 300.0) - last_buy_t_5m)

	var amber: float = float(_gs.calculate_amber_reward())
	var amber_stats: Dictionary = _evaluate_amber_tree_purchasable(amber)
	var era: EraData = _gs.get_current_era()
	var era_name: String = era.display_name if era != null else "—"

	return {
		"strategy": strat,
		"duration": float(_gs.meteor_total_time),
		"t_first_upgrade": t_first_upgrade,
		"t_first_automation": t_first_automation,
		"t_first_dino": t_first_dino,
		"max_gap_5m": max_gap_5m,
		"t_recover_target": t_recover_target,
		"t_layers": t_layers,
		"t_eras": t_eras,
		"dps_per_minute": dps_per_minute,
		"era_index": int(_gs.current_era_index),
		"era_name": era_name,
		"depth": int(_gs.depth),
		"bones": float(_gs.run_total_bones),
		"peak_dps": peak_dps,
		"total_dinos": _count_all_dinos(),
		"shield_pct": roundi(float(_gs.get_shield_ratio()) * 100.0),
		"amber": amber,
		"amber_upgrades_buyable": int(amber_stats["buyable_count"]),
		"amber_tree_pct_levels": float(amber_stats["pct_levels"]),
		"amber_tree_pct_cost": float(amber_stats["pct_cost"]),
		"strikes_perfect": strikes_perfect,
		"strikes_good": strikes_good,
		"strikes_miss": strikes_miss,
		"fossils_run": int(_gs.total_fossils_evaluated) - start_fossils,
		"legendaries_run": int(_gs.total_legendary_fossils) - start_legendaries,
		"museum_species": int(_gs.fossil_catalog.size()),
	}


# ==============================================================================
# HEURÍSTICA DE COMPRA UNIFICADA POR ESTRATÉGIA
# ==============================================================================

func _strategy_cps(strat: String) -> float:
	match strat:
		"CLIQUE":
			return 4.0
		"MAQUINAS":
			return 2.0
		"HIBRIDA":
			return 3.0
		_:
			return 2.5


func _buy_best_for_strategy(strat: String, upgrade_counts: Dictionary) -> StringName:
	var best_kind: StringName = &""
	var best_id: StringName = &""
	var best_score: float = 0.0

	var cps: float = _strategy_cps(strat)
	var crit_chance: float = clampf(float(_gs.get_stat(_gs.STAT_CLICK_CRIT_CHANCE, 0.05)), 0.0, 0.95)
	var click_dps: float = float(_gs.get_click_damage()) * (1.0 + crit_chance * 1.5) * cps
	var dino_dps: float = float(_gs.get_total_dino_dps())
	var auto_dps: float = float(_gs.get_auto_dps())
	var cur_dps: float = maxf(click_dps + dino_dps + auto_dps, 1.0)
	var first_pick_lvl: int = int(_gs.get_upgrade_level(&"tools_sharp_pickaxe"))

	# 1) Dinossauros
	for data: DinoData in _gs.get_dinos_sorted():
		if not bool(_gs.can_assemble_dino(data.id, 1)):
			continue
		var count: int = int(_gs.get_dino_count(data.id))
		var cost: float = maxf(float(_gs.get_dino_purchase_cost(data.id, 1)), 1.0)
		var unit_dps: float = float(data.get_base_dps())
		if count > 0:
			var crit_f: float = 1.0 + data.crit_chance * (data.crit_multiplier - 1.0)
			unit_dps = float(_gs.get_dino_damage(data.id)) * crit_f / maxf(data.attack_interval, 0.05)

		var role_utility: float = 0.0
		match data.role:
			DinoData.Role.COLLECTOR:
				role_utility = cur_dps * 0.035
			DinoData.Role.AREA:
				role_utility = (click_dps + auto_dps) * 0.025
			DinoData.Role.TRANSPORT:
				role_utility = cur_dps * 0.030
			DinoData.Role.SUPPORT:
				role_utility = maxf(dino_dps, cur_dps * 0.4) * 0.05
			DinoData.Role.DEFENSE:
				role_utility = cur_dps * 0.045
			DinoData.Role.ELEMENTAL:
				role_utility = cur_dps * 0.04
			DinoData.Role.BREAKER:
				role_utility = unit_dps * 0.25
			DinoData.Role.FAST:
				role_utility = unit_dps * 0.20

		var gain: float = unit_dps + role_utility
		if count == 0:
			# Bônus ao reviver 1ª unidade da espécie
			gain *= 3.0 if strat == "HIBRIDA" else 2.2
		var w: float = _dino_weight_for_strategy(strat, data)
		var score: float = (gain * w) / cost
		if score > best_score:
			best_score = score
			best_kind = &"dino"
			best_id = data.id

	# 2) Upgrades da Run
	for upg: UpgradeData in _gs.upgrades_db.values():
		if upg.is_permanent or not bool(_gs.can_purchase_upgrade(upg.id, 1)):
			continue
		if strat == "DEFESA" and first_pick_lvl == 0 and upg.id != &"tools_sharp_pickaxe" and upg.stat_id == _gs.STAT_METEOR_SHIELD:
			continue

		var cost_u: float = maxf(float(_gs.get_purchase_cost(upg.id, 1)), 1.0)
		var norm_cost: float = cost_u
		if upg.cost_resource == _gs.RES_MINERALS:
			norm_cost = cost_u * 80.0
		elif upg.cost_resource == _gs.RES_DNA:
			norm_cost = cost_u * 25.0

		var lvl: int = int(_gs.get_upgrade_level(upg.id))
		var cur_eff: float = upg.get_effect_at_level(lvl)
		var next_eff: float = upg.get_effect_at_level(lvl + 1)
		var rel_delta: float = (next_eff - cur_eff) / maxf(cur_eff, 1.0)
		var gain: float = 0.0

		match upg.stat_id:
			_gs.STAT_CLICK_DAMAGE:
				gain = upg.effect_value * (1.0 + crit_chance * 1.5) * cps
			_gs.STAT_AUTO_DPS:
				gain = upg.effect_value
			_gs.STAT_BONES_MULT:
				gain = cur_dps * rel_delta
			_gs.STAT_DINO_DAMAGE, &"dino_evo_mult":
				gain = maxf(dino_dps, cur_dps * 0.25) * rel_delta
			_gs.STAT_FRAGMENT_CHANCE:
				gain = cur_dps * 0.22 * (next_eff - cur_eff)
			_gs.STAT_MINERAL_CHANCE:
				gain = cur_dps * 0.18 * (next_eff - cur_eff)
			_gs.STAT_METEOR_SHIELD:
				gain = cur_dps * 0.18 * (upg.effect_value / 0.05)
			_gs.STAT_METEOR_TIME:
				gain = cur_dps * 0.10
			_gs.STAT_DNA_MULT:
				gain = cur_dps * 0.14 * rel_delta

		if upg.stat_id.begins_with("dino_damage:"):
			var sp: StringName = StringName(String(upg.stat_id).split(":")[1])
			var sp_cnt: int = int(_gs.get_dino_count(sp))
			if sp_cnt > 0:
				var sp_d: DinoData = _gs.get_dino(sp)
				if sp_d != null:
					var sp_dps: float = float(_gs.get_dino_damage(sp)) * float(sp_cnt) / maxf(sp_d.attack_interval, 0.1)
					gain = sp_dps * rel_delta

		var w_u: float = _upgrade_weight_for_strategy(strat, upg)
		var score_u: float = (gain * w_u) / norm_cost
		if score_u > best_score:
			best_score = score_u
			best_kind = &"upgrade"
			best_id = upg.id

	if best_kind == &"dino":
		if bool(_gs.assemble_dino(best_id, 1)):
			return &"dino"
	elif best_kind == &"upgrade":
		var chosen_upg: UpgradeData = _gs.get_upgrade(best_id)
		if bool(_gs.purchase_upgrade(best_id, 1)):
			var key: String = String(best_id)
			upgrade_counts[key] = int(upgrade_counts.get(key, 0)) + 1
			if chosen_upg != null and chosen_upg.stat_id == _gs.STAT_AUTO_DPS:
				return &"auto_upgrade"
			return &"upgrade"
	return &""


func _dino_weight_for_strategy(strat: String, data: DinoData) -> float:
	match strat:
		"CLIQUE":
			return 3.5 if data.role == DinoData.Role.AREA else 0.7
		"DINOS":
			return 3.5
		"MAQUINAS":
			return 2.5 if (data.role == DinoData.Role.TRANSPORT or data.role == DinoData.Role.AREA) else 0.7
		"ECONOMIA":
			return 3.5 if (data.role == DinoData.Role.COLLECTOR or data.role == DinoData.Role.TRANSPORT) else 0.9
		"DEFESA":
			return 3.5 if data.role == DinoData.Role.DEFENSE else 0.8
		"HIBRIDA":
			return 1.25
	return 1.0


func _upgrade_weight_for_strategy(strat: String, upg: UpgradeData) -> float:
	match strat:
		"CLIQUE":
			if upg.stat_id == _gs.STAT_CLICK_DAMAGE:
				return 3.8
			if upg.category == UpgradeData.Category.TOOLS:
				return 2.0
			return 0.75
		"DINOS":
			if upg.category == UpgradeData.Category.DINOS or upg.stat_id == _gs.STAT_FRAGMENT_CHANCE:
				return 3.5
			return 0.85
		"MAQUINAS":
			if upg.category == UpgradeData.Category.MACHINES or upg.stat_id == _gs.STAT_MINERAL_CHANCE:
				return 3.6
			return 0.8
		"ECONOMIA":
			if upg.stat_id in [_gs.STAT_BONES_MULT, _gs.STAT_FRAGMENT_CHANCE, _gs.STAT_MINERAL_CHANCE, _gs.STAT_DNA_MULT]:
				return 3.6
			return 0.85
		"DEFESA":
			if upg.category == UpgradeData.Category.DEFENSE:
				return 4.2
			if upg.stat_id == _gs.STAT_MINERAL_CHANCE:
				return 2.4
			return 0.85
		"HIBRIDA":
			return 1.2
	return 1.0


# ==============================================================================
# ÁRVORE DE ÂMBAR (AVALIAÇÃO E COMPRA NA CAMPANHA)
# ==============================================================================

func _evaluate_amber_tree_purchasable(amber_budget: float) -> Dictionary:
	var perms: Array[UpgradeData] = []
	var total_levels: int = 0
	var total_cost: float = 0.0
	var sim_levels: Dictionary = {}

	for u: UpgradeData in _gs.get_upgrades_by_category(UpgradeData.Category.AMBER):
		perms.append(u)
		var cap: int = u.max_level if u.max_level > 0 else 10
		total_levels += cap
		total_cost += u.get_bulk_cost(0, cap)
		sim_levels[u.id] = int(_gs.get_upgrade_level(u.id))

	var rem: float = amber_budget
	var bought: int = 0
	while true:
		var cheapest: UpgradeData = null
		var cheapest_cost: float = INF
		for u: UpgradeData in perms:
			var lvl: int = int(sim_levels[u.id])
			if u.is_maxed(lvl):
				continue
			var c: float = u.get_cost(lvl)
			if c <= rem and c < cheapest_cost:
				cheapest_cost = c
				cheapest = u
		if cheapest == null:
			break
		rem -= cheapest_cost
		sim_levels[cheapest.id] = int(sim_levels[cheapest.id]) + 1
		bought += 1

	var pct_levels: float = (float(bought) / float(maxi(total_levels, 1))) * 100.0
	var pct_cost: float = (minf(amber_budget, total_cost) / maxf(total_cost, 1.0)) * 100.0
	return {
		"buyable_count": bought,
		"pct_levels": pct_levels,
		"pct_cost": pct_cost,
	}


func _spend_amber_campaign(campaign_upgrades: Dictionary) -> Array[String]:
	var bought_names: Array[String] = []
	var ark_lvl: int = int(_gs.get_upgrade_level(&"amber_ark_project"))
	var ark_upg: UpgradeData = _gs.get_upgrade(&"amber_ark_project")
	var next_ark_cost: float = ark_upg.get_cost(ark_lvl) if ark_upg != null else INF

	# Se pode comprar a Arca agora e sobra para melhorias basicas, compra a Arca;
	# caso contrario, garante primeiro 1 nivel de poder permanente nesta run para nunca estagnar.
	var bought_power_this_round: bool = false

	for _round: int in range(30):
		var chosen: UpgradeData = null
		var best_score: float = 0.0
		var cur_amber: float = float(_gs.get_resource(_gs.RES_AMBER))
		ark_lvl = int(_gs.get_upgrade_level(&"amber_ark_project"))
		next_ark_cost = ark_upg.get_cost(ark_lvl) if ark_upg != null else INF
		var save_for_ark: bool = (ark_lvl < 5 and cur_amber >= next_ark_cost * 0.35 and cur_amber < next_ark_cost)

		var must_buy_first_mastery: bool = (
			not bought_power_this_round
			and bool(_gs.can_purchase_upgrade(&"amber_fossil_mastery", 1))
		)

		for u: UpgradeData in _gs.get_upgrades_by_category(UpgradeData.Category.AMBER):
			if not bool(_gs.can_purchase_upgrade(u.id, 1)):
				continue
			var c: float = u.get_cost(int(_gs.get_upgrade_level(u.id)))
			var is_power: bool = (u.id == &"amber_fossil_mastery")
			if must_buy_first_mastery and not is_power:
				continue
			# Garante 1 nivel de Mestria antes de poupar todo o resto para a Arca
			var force_one_power: bool = (not bought_power_this_round and is_power)
			if save_for_ark and u.id != &"amber_ark_project" and not force_one_power:
				continue
			var w: float = 1.0
			match u.id:
				&"amber_ark_project":
					w = 14.0 if (ark_lvl < 5 and bought_power_this_round) else 0.5
				&"amber_fossil_mastery":
					w = 9.0
				&"amber_tectonic_breaker":
					w = 2.2 if int(_gs.get_upgrade_level(u.id)) < 6 else 0.15
				&"amber_extra_time":
					w = 2.0 if int(_gs.get_upgrade_level(u.id)) < 12 else 0.4
				&"amber_fragment_magnet":
					w = 1.4 if int(_gs.get_upgrade_level(u.id)) < 4 else 0.05
				&"amber_offline_lab":
					w = 0.8 if int(_gs.get_upgrade_level(u.id)) < 2 else 0.03
			var sc: float = w / maxf(c, 1.0)
			if u.id == &"amber_fossil_mastery" and int(_gs.get_upgrade_level(&"amber_fossil_mastery")) >= 3 and ark_lvl < 5:
				# No mid/late game, prioriza sempre manter fossil_mastery acompanhando o ritmo antes de extras secundarios
				sc = (w * 2.0) / maxf(c, 1.0)
			if sc > best_score:
				best_score = sc
				chosen = u
		if chosen == null:
			break
		if bool(_gs.purchase_upgrade(chosen.id, 1)):
			if chosen.id == &"amber_fossil_mastery":
				bought_power_this_round = true
			var k: String = String(chosen.id)
			campaign_upgrades[k] = int(campaign_upgrades.get(k, 0)) + 1
			bought_names.append("%s(%d)" % [k.trim_prefix("amber_"), int(_gs.get_upgrade_level(chosen.id))])
	return bought_names


# ==============================================================================
# HELPERS
# ==============================================================================

func _count_all_dinos() -> int:
	var total: int = 0
	for k: StringName in _gs.dino_counts:
		total += int(_gs.get_dino_count(k))
	return total


func _total_fragments() -> int:
	var total: int = 0
	for k: StringName in _gs.fragments:
		total += int(_gs.get_fragments(k))
	return total


func _fmt_opt_time(sec: float) -> String:
	if sec < 0.0:
		return "N/A"
	return "%.1fs" % sec
