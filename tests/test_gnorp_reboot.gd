extends GutTest
## Testes automatizados do núcleo econômico, coleta controlada da pilha, progressão emergente,
## combate ao meteoro (45K HP) e persistência do reboot GnorpGame.


func before_each() -> void:
	if SaveManager != null:
		SaveManager.autosave_enabled = false
	GnorpGame.reset_campaign()
	GnorpGame.delete_save()


func after_all() -> void:
	GnorpGame.reset_campaign()
	GnorpGame.delete_save()


func test_physical_cycle_click_pile_compress_and_deposit() -> void:
	watch_signals(GnorpGame)
	assert_almost_eq(GnorpGame.pile_fragments, 0.0, 0.0001)
	assert_almost_eq(GnorpGame.fragments, 0.0, 0.0001)
	assert_eq(GnorpGame.compression_tier, 0)
	assert_almost_eq(GnorpGame.METEOR_MAX_HP, 45000.0, 0.001)
	assert_almost_eq(GnorpGame.meteor_max_hp, 45000.0, 0.001)

	# Enche a pilha para testar scoop manual controlado (4.0 base) e fluxo em 2 etapas (take + deliver).
	GnorpGame.pile_fragments = 20.0
	var scooped_default: float = GnorpGame.scoop_pile()
	assert_almost_eq(scooped_default, 4.0, 0.001, "scoop_pile() padrão deve colher exatamente 4 lascas iniciais")
	assert_almost_eq(GnorpGame.fragments, 4.0, 0.001)
	assert_almost_eq(GnorpGame.pile_fragments, 16.0, 0.001)
	assert_signal_emitted(GnorpGame, "deposit_collected")

	# Transporte físico em 2 etapas para Compys (take_from_pile -> deliver_to_deposit).
	var carried: float = GnorpGame.take_from_pile(6.0, "compy")
	assert_almost_eq(carried, 6.0, 0.001)
	assert_almost_eq(GnorpGame.pile_fragments, 10.0, 0.001)
	assert_almost_eq(GnorpGame.fragments, 4.0, 0.001, "take_from_pile não deve creditar antes do Compy chegar ao Depósito")
	var delivered: float = GnorpGame.deliver_to_deposit(carried, "compy")
	assert_almost_eq(delivered, 6.0, 0.001)
	assert_almost_eq(GnorpGame.fragments, 10.0, 0.001)
	assert_gt(GnorpGame.get_fragments_per_second(), 0.0, "Telemetria get_fragments_per_second() deve registrar entregas")

	# Clique no Monólito adiciona fragmentos físicos na Pilha.
	GnorpGame.pile_fragments = 0.0
	var gained: float = GnorpGame.click_rock()
	assert_gt(gained, 0.0, "click_rock() deve gerar fragmentos")
	assert_eq(GnorpGame.rock_clicks_total, 1)
	assert_almost_eq(GnorpGame.pile_fragments, gained, 0.001)
	assert_signal_emitted(GnorpGame, "rock_hit")
	assert_signal_emitted(GnorpGame, "pile_changed")

	# Encher a Pilha além de get_pile_capacity() dispara pile_compressed e incrementa compression_tier.
	var cap: float = GnorpGame.get_pile_capacity()
	var safety_clicks: int = 0
	while GnorpGame.compression_tier == 0 and safety_clicks < 250:
		GnorpGame.click_rock()
		safety_clicks += 1
	assert_gt(GnorpGame.compression_tier, 0, "Encher a pilha até %.1f deve incrementar compression_tier" % cap)
	assert_signal_emitted(GnorpGame, "pile_compressed")
	assert_gt(GnorpGame.get_compression_multiplier(), 1.0, "Compressão ativa deve multiplicar o valor da pilha")

	# Coletar da pilha comprimida aplica o multiplicador e zera compression_tier ao esvaziar.
	var mult: float = GnorpGame.get_compression_multiplier()
	var pile_now: float = GnorpGame.pile_fragments
	var frag_before: float = GnorpGame.fragments
	var collected: float = GnorpGame.collect_from_pile(pile_now + 100.0, "compy")
	assert_almost_eq(collected, pile_now * mult, 0.01)
	assert_almost_eq(GnorpGame.fragments, frag_before + collected, 0.01)
	assert_almost_eq(GnorpGame.pile_fragments, 0.0, 0.001)
	assert_eq(GnorpGame.compression_tier, 0, "Esvaziar a pilha deve resetar compression_tier")


func test_emergent_progression_unlocks() -> void:
	assert_false(GnorpGame.is_structure_unlocked("pachy_nest"), "pachy_nest deve iniciar bloqueado abaixo de 12 fragmentos")
	assert_false(GnorpGame.is_structure_unlocked("compy_den"))
	assert_false(GnorpGame.is_structure_unlocked("ptero_perch"))
	assert_false(GnorpGame.is_structure_unlocked("ankylo_lair"), "ankylo_lair não deve aparecer no início")
	assert_false(GnorpGame.is_structure_unlocked("trex_altar"))
	assert_false(GnorpGame.is_structure_unlocked("meteor_cannon"))

	# Gera >= 12 fragmentos via clique + coleta controlada na Pilha para alcançar o primeiro limiar (12).
	while GnorpGame.total_run_fragments < 12.0:
		GnorpGame.click_rock()
		GnorpGame.scoop_pile()
	assert_true(GnorpGame.is_structure_unlocked("pachy_nest"), "pachy_nest deve desbloquear ao atingir 12 fragmentos")
	assert_false(GnorpGame.is_structure_unlocked("ankylo_lair"), "ankylo_lair ainda deve exigir 950 fragmentos")

	# Alcança progressão mid-game (950), late-game (4200) e canhão (14000).
	GnorpGame.fragments = 950.0
	GnorpGame.total_run_fragments = 950.0
	assert_true(GnorpGame.is_structure_unlocked("ankylo_lair"), "ankylo_lair deve desbloquear em 950 fragmentos")
	assert_false(GnorpGame.is_structure_unlocked("trex_altar"), "trex_altar ainda deve exigir 4200 fragmentos")

	GnorpGame.fragments = 4200.0
	GnorpGame.total_run_fragments = 4200.0
	assert_true(GnorpGame.is_structure_unlocked("trex_altar"), "trex_altar deve desbloquear em 4200 fragmentos")
	assert_false(GnorpGame.is_structure_unlocked("meteor_cannon"), "meteor_cannon ainda deve exigir 14000 fragmentos")

	GnorpGame.fragments = 14000.0
	GnorpGame.total_run_fragments = 14000.0
	assert_true(GnorpGame.is_structure_unlocked("meteor_cannon"), "meteor_cannon deve desbloquear em 14000 fragmentos")


func test_recruit_upgrades_roar_and_cannon_victory() -> void:
	watch_signals(GnorpGame)
	GnorpGame.fragments = 500000.0
	GnorpGame.total_run_fragments = 500000.0

	# Constrói Pachy e recruta + compra os 3 tipos de upgrades.
	assert_true(GnorpGame.build_structure("pachy_nest"))
	assert_true(GnorpGame.is_structure_built("pachy_nest"))
	assert_eq(GnorpGame.get_dino_count("pachy"), 1)
	assert_signal_emitted(GnorpGame, "structure_built")

	var cost_1: float = GnorpGame.get_dino_cost("pachy_nest")
	assert_true(GnorpGame.recruit_dino("pachy_nest"))
	assert_eq(GnorpGame.get_dino_count("pachy"), 2)
	assert_gt(GnorpGame.get_dino_cost("pachy_nest"), cost_1)
	assert_signal_emitted(GnorpGame, "dino_recruited")

	var base_pachy_power: float = GnorpGame.get_dino_hit_power("pachy")
	var base_pachy_speed: float = GnorpGame.get_dino_speed_multiplier("pachy")
	assert_true(GnorpGame.buy_upgrade("pachy_helmet"))
	assert_true(GnorpGame.buy_upgrade("pachy_frenzy"))
	assert_true(GnorpGame.buy_upgrade("pachy_ricochet"))
	assert_false(GnorpGame.buy_upgrade("pachy_helmet"), "Upgrade já comprado não pode ser recomprado")
	assert_true(GnorpGame.is_upgrade_owned("pachy_helmet"))
	assert_true(GnorpGame.is_upgrade_owned("pachy_frenzy"))
	assert_true(GnorpGame.is_upgrade_owned("pachy_ricochet"))
	assert_gt(GnorpGame.get_dino_hit_power("pachy"), base_pachy_power)
	assert_gt(GnorpGame.get_dino_speed_multiplier("pachy"), base_pachy_speed)
	assert_signal_emitted(GnorpGame, "upgrade_purchased")

	var pachy_shards: float = GnorpGame.apply_dino_hit("pachy")
	assert_gt(pachy_shards, GnorpGame.get_dino_hit_power("pachy"), "pachy_ricochet deve somar estilhaços extras")

	# Constrói Compy, Ptero, Anquilo, T-Rex e Canhão e testa Rugido Alfa.
	assert_true(GnorpGame.build_structure("compy_den"))
	assert_true(GnorpGame.buy_upgrade("compy_pouch"))
	assert_almost_eq(GnorpGame.get_compy_carry_capacity(), 12.0, 0.001)

	assert_true(GnorpGame.build_structure("ptero_perch"))
	assert_true(GnorpGame.buy_upgrade("ptero_sky_beam"))
	var hp_pre_ptero: float = GnorpGame.meteor_hp
	GnorpGame.apply_ptero_meteor_shot(50.0)
	assert_lt(GnorpGame.meteor_hp, hp_pre_ptero, "Ptero com ptero_sky_beam deve causar dano ao Meteoro")

	assert_true(GnorpGame.build_structure("ankylo_lair"))
	assert_true(GnorpGame.buy_upgrade("ankylo_quake"))
	assert_gt(GnorpGame.apply_dino_hit("ankylo"), 0.0)

	assert_true(GnorpGame.build_structure("trex_altar"))
	assert_true(GnorpGame.buy_upgrade("trex_alpha"))
	assert_true(GnorpGame.buy_upgrade("trex_apex"))
	GnorpGame.trigger_trex_roar()
	assert_gt(GnorpGame.roar_time_left, 4.5, "trex_alpha deve estender o Rugido Alfa")
	assert_almost_eq(GnorpGame.roar_multiplier, 2.2, 0.001)
	assert_signal_emitted(GnorpGame, "roar_triggered")
	var hp_pre_apex: float = GnorpGame.meteor_hp
	assert_gt(GnorpGame.apply_dino_hit("trex"), 0.0)
	assert_lt(GnorpGame.meteor_hp, hp_pre_apex, "trex_apex deve ferir o Meteoro na mordida")

	assert_true(GnorpGame.build_structure("meteor_cannon"))
	assert_true(GnorpGame.buy_upgrade("cannon_barrel"))
	assert_true(GnorpGame.buy_upgrade("cannon_overclock"))
	assert_true(GnorpGame.buy_upgrade("cannon_amber_core"))

	# Dispara o Canhão contra o Meteoro (45K HP) até zerar HP e atingir vitória.
	var hp_before: float = GnorpGame.meteor_hp
	var volley_dmg: float = GnorpGame.fire_cannon_volley("cannon")
	assert_gt(volley_dmg, 0.0)
	assert_lt(GnorpGame.meteor_hp, hp_before)
	assert_gt(GnorpGame.get_meteor_dps(), 0.0)
	assert_signal_emitted(GnorpGame, "cannon_fired")

	var guard: int = 0
	while GnorpGame.run_state == "playing" and guard < 120:
		GnorpGame.fire_cannon_volley("cannon")
		guard += 1
	assert_eq(GnorpGame.run_state, "victory")
	assert_almost_eq(GnorpGame.meteor_hp, 0.0, 0.001)
	assert_eq(GnorpGame.total_victories, 1)
	assert_gt(GnorpGame.amber_pure, 0.0)
	assert_signal_emitted(GnorpGame, "run_ended")

	# Testa transição para Modo Infinito após vitória.
	GnorpGame.continue_endless_mode()
	assert_eq(GnorpGame.run_state, "endless")
	assert_gt(GnorpGame.meteor_hp, 0.0)


func test_impact_talents_next_run_persistence_and_format() -> void:
	watch_signals(GnorpGame)
	GnorpGame.fragments = 2000.0
	GnorpGame.total_run_fragments = 2000.0
	assert_true(GnorpGame.build_structure("pachy_nest"))

	# Impacto do meteoro concede Âmbar Puro e encerra a run.
	var earned: float = GnorpGame.end_run_by_impact()
	assert_gt(earned, 0.0)
	assert_eq(GnorpGame.run_state, "impact")
	assert_almost_eq(GnorpGame.amber_pure, earned, 0.001)
	assert_signal_emitted(GnorpGame, "run_ended")

	# Garante saldo suficiente e checa alerta can_afford_any_talent().
	GnorpGame.amber_pure += 20.0
	assert_true(GnorpGame.can_afford_any_talent())
	var base_click: float = GnorpGame.get_click_damage()
	var base_scoop: float = GnorpGame.get_manual_scoop_amount()
	assert_true(GnorpGame.buy_talent("talent_claw_click"))
	assert_eq(GnorpGame.get_talent_rank("talent_claw_click"), 1)
	assert_gt(GnorpGame.get_click_damage(), base_click)
	assert_almost_eq(GnorpGame.get_manual_scoop_amount(), base_scoop + 2.0, 0.001)
	assert_true(GnorpGame.buy_talent("talent_headstart"))
	assert_eq(GnorpGame.get_talent_rank("talent_headstart"), 1)
	assert_signal_emitted(GnorpGame, "talent_purchased")

	# Nova run limpa estruturas da run anterior, preserva talentos/âmbar e aplica headstart (+40).
	var amber_saved: float = GnorpGame.amber_pure
	GnorpGame.start_next_run(false)
	assert_eq(GnorpGame.run_number, 2)
	assert_eq(GnorpGame.run_state, "playing")
	assert_false(GnorpGame.is_structure_built("pachy_nest"))
	assert_almost_eq(GnorpGame.amber_pure, amber_saved, 0.001)
	assert_almost_eq(GnorpGame.fragments, 40.0, 0.001, "talent_headstart nível 1 deve iniciar com 40 fragmentos")
	assert_signal_emitted(GnorpGame, "run_started")

	# Persistência: save_game -> corrompe memória -> load_game -> delete_save.
	GnorpGame.fragments = 432.0
	assert_true(GnorpGame.build_structure("pachy_nest"))
	assert_true(GnorpGame.save_game())
	assert_true(FileAccess.file_exists(GnorpGame.SAVE_PATH))

	var saved_frags: float = GnorpGame.fragments
	GnorpGame.fragments = 0.0
	GnorpGame.structures_built.clear()
	GnorpGame.talent_ranks.clear()
	GnorpGame.amber_pure = 0.0
	GnorpGame.run_number = 1

	assert_true(GnorpGame.load_game())
	assert_almost_eq(GnorpGame.fragments, saved_frags, 0.001)
	assert_true(GnorpGame.is_structure_built("pachy_nest"))
	assert_eq(GnorpGame.get_talent_rank("talent_claw_click"), 1)
	assert_almost_eq(GnorpGame.amber_pure, amber_saved, 0.001)
	assert_eq(GnorpGame.run_number, 2)

	GnorpGame.delete_save()
	assert_false(FileAccess.file_exists(GnorpGame.SAVE_PATH), "delete_save() deve remover o arquivo de save de teste")

	# Formatação de números.
	assert_eq(GnorpGame.format_number(0.0), "0")
	assert_eq(GnorpGame.format_number(3.5), "3.5")
	assert_eq(GnorpGame.format_number(42.0), "42")
	assert_eq(GnorpGame.format_number(1500.0), "1.5K")
	assert_eq(GnorpGame.format_number(2500000.0), "2.5M")
	assert_eq(GnorpGame.format_number(1200000000.0), "1.2B")
	assert_eq(GnorpGame.format_number(3000000000000.0), "3.0T")
