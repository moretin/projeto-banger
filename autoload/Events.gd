extends Node
## Events — Signal Bus global do Fóssil Rush.
##
## REGRA DE OURO: cenas de áreas diferentes (UI, escavação, dinos, meteoro)
## NUNCA se referenciam diretamente. Elas emitem e escutam sinais daqui.
##
## Uso:
##   Events.dig_hit.emit(10.0, global_position, false)
##   Events.resource_changed.connect(_on_resource_changed)
##
## CONVENÇÃO ANTI-CONFLITO NO GIT:
##   Cada branch adiciona sinais SOMENTE dentro da sua própria seção (#region).
##   Sempre adicione no FINAL da seção, com tipagem completa e comentário de quem emite.

# Este script só declara sinais; eles são emitidos por outros scripts.
@warning_ignore_start("unused_signal")


#region Economia & Recursos  [B1 · feat/core-economy]
## Emissor: GameState. Um recurso (ossos, minérios, DNA, âmbar) mudou.
signal resource_changed(resource_id: StringName, new_amount: float, delta: float)
## Emissor: GameState. Fragmentos de fóssil de uma espécie mudaram.
signal fragments_changed(dino_id: StringName, new_amount: int)
## Emissor: GameState. Multiplicadores/estatísticas foram recalculados (após compra de upgrade, marco etc.).
signal stats_recalculated()
## Emissor: GameState. Recursos estruturais provenientes de uma camada da Terra foram extraídos ao quebrá-la.
signal layer_resources_extracted(era_index: int, bones_bonus: float, minerals_bonus: float)
## Emissor: GameState. A primeira camada da Terra (Crosta) resistiu à quebra por estar nas primeiras runs.
signal layer_break_blocked_by_crust(era_index: int, required_run: int)
## Emissor: GameState. Quantidade X do fóssil específico de um dinossauro foi completada na escavação.
signal dino_fossil_completed(dino_id: StringName, current_fragments: int, required_fragments: int)
#endregion


#region Upgrades & UI  [B2 · feat/ui-upgrades]
## Emissor: UI. Jogador clicou em comprar. amount = 1, 10, 100 ou GameState.BUY_MAX (-1).
signal upgrade_purchase_requested(upgrade_id: StringName, amount: int)
## Emissor: GameState. Compra concluída com sucesso.
signal upgrade_purchased(upgrade_id: StringName, new_level: int)
## Emissor: GameState. Multiplicador de compra (1x / 10x / 100x / Máx) mudou.
signal buy_multiplier_changed(multiplier: int)
## Emissor: qualquer área. Pede um toast/notificação na tela.
signal notification_requested(text: String, icon: Texture2D)
## Emissor: HUD. Abre o modal da árvore de Âmbar / Prestígio.
signal prestige_modal_requested()
## Emissor: HUD. Abre o modal de Save / Configurações.
signal settings_modal_requested()
#endregion


#region Escavação  [B3 · feat/dig-site]
## Emissor: escavação (clique) ou dinos (ataque). GameState aplica dano e gera recompensas.
signal dig_hit(damage: float, world_position: Vector2, is_crit: bool)
## Emissor: GameState. Vida da camada atual mudou.
signal layer_hp_changed(current_hp: float, max_hp: float)
## Emissor: GameState. Uma camada foi quebrada (depth = total de camadas quebradas na run).
signal layer_broken(era_index: int, layer_index: int, depth: int)
## Emissor: GameState. Entramos em uma nova era geológica.
signal era_changed(era_index: int)
## Emissor: GameState. Recompensa gerada por um golpe (para números flutuantes / partículas).
signal loot_dropped(resource_id: StringName, amount: float, world_position: Vector2)
## Emissor: GameState. Um fragmento de fóssil caiu.
signal fragment_dropped(dino_id: StringName, world_position: Vector2)
## Emissor: Superfície ou Escavação. Pede transição suave entre &"surface" e &"dig_site".
signal scenario_transition_requested(target_scenario: StringName)
## Emissor: Main. Transição de cenário iniciada/concluída.
signal scenario_changed(current_scenario: StringName)
## Emissor: Superfície. Jogador clicou na Rocha Laranja inicial.
signal orange_rock_hit(damage: float, world_position: Vector2)
## Emissor: GameState. Vida da Rocha Laranja inicial mudou.
signal orange_rock_hp_changed(current_hp: float, max_hp: float)
## Emissor: GameState. Rocha Laranja quebrada → spawna o Dinossauro Principal em Pixel Art!
signal orange_rock_broken()
## Emissor: Superfície. Jogador clicou para reconstruir/melhorar um escombro de pedra.
signal rubble_rebuild_requested(rubble_id: StringName)
## Emissor: GameState. Escombro de pedra reconstruído/melhorado.
signal rubble_rebuilt(rubble_id: StringName, new_level: int)
#endregion


#region Dinos  [B4 · feat/dinos]
## Emissor: UI. Jogador quer montar/comprar mais uma unidade de um dino.
signal dino_assembly_requested(dino_id: StringName)
## Emissor: GameState. Quantidade de um dino mudou (cena de dinos spawna/remove instâncias).
signal dino_count_changed(dino_id: StringName, new_count: int)
## Emissor: GameState. Primeira unidade de uma espécie revivida (momento de celebração).
signal dino_unlocked(dino_id: StringName)
## Emissor: GameState. Marco de produção atingido (25, 50, 100...).
signal dino_milestone_reached(dino_id: StringName, milestone: int)
#endregion


#region Meteoro & Prestígio  [B5 · feat/meteor-prestige]
## Emissor: GameState (a cada frame enquanto o meteoro está ativo).
signal meteor_timer_changed(time_left: float, total_time: float)
## Emissor: UI. Jogador decidiu antecipar o impacto.
signal meteor_early_impact_requested()
## Emissor: GameState. Timer zerou ou foi antecipado → cena do meteoro toca a cinemática
## e depois chama GameState.perform_prestige(shield_ratio).
signal meteor_impact_started()
## Emissor: GameState. Prestígio concluído.
signal prestige_completed(amber_gained: float, run_number: int)
## Emissor: GameState. Uma nova run começou.
signal run_started(run_number: int)
#endregion


#region Progressão Visual  [B7 · feat/vfx-audio]
## Emissor: GameState. 0.0 = mundo cinza/terroso, 1.0 = totalmente colorido.
signal color_progress_changed(progress: float)
## Emissor: GameState. 0.0 = céu calmo, 1.0 = céu vermelho (meteoro iminente).
signal danger_level_changed(level: float)
#endregion


#region Save & Offline  [B6 · feat/save-system]
## Emissor: SaveManager.
signal game_saved()
## Emissor: SaveManager. Estado restaurado — UIs devem se atualizar por completo.
signal game_loaded()
## Emissor: SaveManager. Ganhos offline calculados (para mostrar o popup "Enquanto você estava fora...").
signal offline_progress_applied(seconds: float, gains: Dictionary)
#endregion
