# DEVLOG — Fóssil Rush (`fix/estabilidade`)

## 1. Resumo e Commit-Base
- **Branch de trabalho:** `fix/estabilidade`
- **Commit-base (`origin/main`):** `198aa31` (`docs: add IDEIAS.md with future dino specialization, resource, and structure upgrade concepts`), construído sobre `b1a7d24` (`docs: set official Godot version to 4.7.2 in README.md, AGENTS.md, and project.godot`).
- **Objetivo:** Estabilizar a base do projeto para desenvolvimento paralelo (engine alvo, versionamento de `.uid`, correção do bug crítico de duplicação de Âmbar no prestígio, correções P2 de sinais/Rocha Laranja/pausa do meteoro/migração v1 e suíte automatizada headless).

---

## 2. Decisões Técnicas

### 2.1 Versão Oficial da Engine: Godot 4.7+
- `project.godot` mantém `config/features=PackedStringArray("4.7", "GL Compatibility")` e a validação executada usa **Godot 4.7.1 stable**.
- `AGENTS.md` e `docs/GDD.md` (§10) foram alinhados para **Godot 4.7+** porque versões 4.2–4.6 não compilam nem carregam o projeto sem erros:
  1. `@warning_ignore_start("unused_signal")` em `autoload/Events.gd` falha no parser de GDScript ≤ 4.3.
  2. `offset_transform_enabled` e `offset_transform_scale` em `scenes/ui/UpgradeCard.gd` e `scenes/ui/DinoCard.gd` foram introduzidos no Godot 4.7.
  3. Arquivos `.uid` dos scripts/recursos (obrigatórios a partir do Godot 4.4+) estavam sendo ignorados por `*.uid` no `.gitignore`. A regra foi removida e todos os `.uid` faltantes (incluindo `scenes/ui/test_ui_layout.gd.uid`, `tests/*.gd.uid` e `addons/gut/**/*.uid`) foram gerados e versionados.

### 2.2 Framework de Testes: GUT v9.7.1 vs gdUnit4
- **Escolha:** **GUT v9.7.1** (`addons/gut`, configuração em `.gutconfig.json`).
- **Justificativa:**
  1. Compatibilidade imediata e validada com **Godot 4.7.1** em modo `--headless`, com suporte nativo a `watch_signals`, `assert_signal_emitted` / `assert_signal_not_emitted` e `assert_push_warning` (essencial para validar a detecção de save inconsistente e migração `v1 → v2` sem falhar o runner).
  2. Leveza e simplicidade de execução em CLI (`-s res://addons/gut/gut_cmdln.gd`) sem depender de plugin de editor ativo ou dependências pesadas, facilitando execução rápida em PowerShell, Bash e CI.

### 2.3 Fix do Bug de Âmbar Duplicado no Prestígio (`4714 → 9428`)
- **Causa raiz identificada:**
  1. Em `GameState.perform_prestige()`, `Events.prestige_completed.emit(...)` era disparado **antes** de `_reset_run_state()`. Como `SaveManager` salva exatamente ao receber `prestige_completed`, o `user://savegame.json` gravava o Âmbar novo (`4714`) **junto** com `meteor_time_left = 0.0` e `run_total_bones` da run encerrada.
  2. Ao fechar sem novo autosave e reabrir o jogo, `SaveManager.load_game()` carregava `meteor_time_left = 0.0` com `meteor_active = true`; no primeiro frame, `_tick_meteor()` disparava `trigger_meteor_impact()` e `perform_prestige()` novamente, dobrando o Âmbar para `9428`.
  3. Durante a animação de impacto (`is_impacting = true`), um close/focus-out ou autosave podia persistir o estado intermediário antes da conclusão do prestígio.
- **Correção aplicada em 3 pontos (`SAVE_VERSION = 2` preservada):**
  1. `GameState.perform_prestige()`: emite `Events.prestige_completed` **após** `_reset_run_state()` (mantendo `Events.run_started` em seguida), garantindo que o save gravado no prestígio já contenha `run_total_bones = 0.0` e `meteor_time_left = meteor_total_time`.
  2. `GameState.load_save_dict()`: se `meteor_active and meteor_time_left <= 0.0`, emite `push_warning`, chama `_reset_run_state()` e retorna imediatamente **sem** reaplicar prestígio (protegendo também saves legados já corrompidos).
  3. `SaveManager.save_game()`: bloqueia salvamento enquanto `GameState.is_impacting` for `true` (e respeita `autosave_enabled` em `prestige_completed`, `_notification` e `import_save_string`).

### 2.4 Estabilidade Headless (Áudio Dummy)
- Em `--headless`, o driver de áudio `Dummy` retinha 1 referência interna de `AudioStreamGeneratorPlayback` (`ObjectDB` leak + `Orphan StringName: Master` ao sair de `Main.tscn`).
- Em `scenes/dig_site/VfxAudioManager.gd`, `_setup_procedural_audio()` agora retorna cedo quando `AudioServer.get_driver_name() == "Dummy"`, eliminando o leak em `--quit-after 600` e nos testes sem alterar o áudio real em desktop/web.

### 2.5 Correções P2 (Sinais, Rocha Laranja, Pausa do Meteoro e Migração v1)
1. **Signal morto `dino_fossil_completed` → Ligado:**
   - Emitido em `GameState.add_fragments()` quando a quantidade de fósseis específicos cruza `data.get_fragments_required(owned)` (respeitando `can_spawn_more(owned)`), e conectado em `HUD.gd` para exibir toast ao jogador avisando que o dino pode ser revivido.
2. **Auditoria dos 4 sinais emitidos sem ouvinte:**
   | Signal | Ação | Justificativa |
   |---|---|---|
   | `layer_resources_extracted` | **Ligado** (`HUD.gd`) | Exibe toast conciso com o bônus de ossos/minérios extraídos ao quebrar a camada. |
   | `game_saved` | **Ligado** (`SaveModals.gd`) | Atualiza `_status_label` com feedback de salvamento automático quando o modal de configurações está aberto sem mensagem prévia. |
   | `scenario_changed` | **Ligado** (`VfxAudioManager.gd`) | Dispara transição sonora curta e suave ao alternar entre Superfície e Escavação. |
   | `layer_break_blocked_by_crust` | **Removido** (`Events.gd` e `GameState.gd`) | Redundante: a linha seguinte em `GameState.apply_dig_damage()` já emite `Events.notification_requested` com a mensagem completa de bloqueio da Crosta. |
3. **Rocha Laranja disparando `dig_hit` falso sempre crítico:**
   - Removido `Events.dig_hit.emit(0.0, hit_pos, true)` de `SurfaceScene.gd`.
   - `VfxAudioManager.gd` agora escuta diretamente `Events.orange_rock_hit` para tocar o SFX normal de impacto em rocha e emitir partículas laranja sem gerar falso golpe crítico de escavação.
4. **Timer do meteoro correndo com o modal de Âmbar aberto:**
   - Adicionado `Events.prestige_modal_visibility_changed(is_open: bool)`.
   - `MeteorOverlay.gd` notifica abertura/fechamento de `_modal_backdrop` (e reset em `_exit_tree()`), e `GameState._tick_meteor()` pausa a contagem regressiva enquanto `is_prestige_modal_open` for `true`.
5. **Migração `v1 → v2` descartando save sem avisar o jogador:**
   - `SaveManager.gd` registra a versão antiga descartada em `last_migrated_reset_version` e emite `Events.notification_requested` após `Events.game_loaded` avisando que o save antigo (`v1`) era incompatível e um novo jogo foi iniciado.
   - `SaveModals.gd` exibe o aviso específico em `_status_label` ao importar saves `v1` em Base64 em vez de exibir mensagem genérica de sucesso.

---

## 3. Testes e Como Rodar

### Arquivos adicionados
- `.gutconfig.json`
- `tests/test_save_system.gd`: round-trip v2 (disco e Base64), prestígio + fechar sem salvar + recarregar sem duplicar Âmbar (`4714 → 4714`), carregamento seguro de save bugado (`meteor_time_left = 0.0`), bloqueio de `save_game()` durante `is_impacting`, e notificação na migração `v1 → v2`.
- `tests/test_economy_basic.gd`: validação matemática de compras `1x / 10x / 100x / BUY_MAX` (incluindo upgrades com `max_level` e recurso `&"amber"`) comparadas à soma sequencial de compras `1x`.
- `tests/test_smoke_main.gd`: instancia `Main.tscn` e executa 600 frames sem erros, checando avanço do timer do meteoro e subcenas ativas.
- `tests/test_p2_fixes.gd`: clique na Rocha Laranja sem `dig_hit` falso, pausa do timer do meteoro com modal de Âmbar aberto, emissão de `dino_fossil_completed`, e verificação estática de que todo sinal em `Events.gd` possui ao menos um emissor e um ouvinte.
- `tools/run_tests.ps1` e `tools/run_tests.sh`: scripts únicos que executam GUT → `test_ui_layout.gd` → smoke `--quit-after 600`, falhando em código de saída `!= 0`, `SCRIPT ERROR:`, `Parse Error:` ou `ObjectDB instance was leaked`.

### Comandos
```powershell
# Windows PowerShell (usa GODOT_BIN, godot no PATH ou fallback local 4.7.1)
powershell -NoProfile -ExecutionPolicy Bypass -File .\tools\run_tests.ps1
```
```bash
# Linux / macOS / Git Bash
./tools/run_tests.sh

# Sobrescrevendo o executável do Godot:
GODOT_BIN=/caminho/para/godot ./tools/run_tests.sh
```

---

## 4. Problemas Conhecidos (Fora do Escopo desta Branch)
Mantidos intocados conforme regra de não alterar fórmulas de economia, `.tres` ou cenas visuais:
1. **`DinoData.gd` / `GameState.gd`:** compras de dinossauros operam apenas em `1x` (sem multiplicador `10x/100x/Máx` de clonagem nesta base).
2. **`README.md`:** adicionado em `b1a7d24`/`198aa31` fora da lista de arquivos desta tarefa; ainda menciona `Godot 4.7.2` e `--quit-after 2` (recomenda-se alinhar com `AGENTS.md` ao integrar).
3. **`GameState.assemble_dino`:** ainda chama `Events.dino_milestone_reached.emit(dino_id, new_count)`; caso no futuro exista compra em lote de dinos, `new_count` pode diferir do marco exato cruzado.
4. **Economia `1x/10x/100x/MAX` em `UpgradeData.gd`:** todos os casos testados em `test_economy_basic.gd` bateram dentro da tolerância numérica de ponto flutuante (`max(spent * 1e-6, 1e-4)`), sem divergência discreta de nível entre `BUY_MAX` e compras `1x` sequenciais.

---

## 5. Próximos Passos
1. Mergear/rebasear as branches paralelas sobre `fix/estabilidade` (ou após integrá-la em `main`) para herdarem Godot 4.7+, `.uid` versionados, fix do Âmbar e a suíte `tools/run_tests.*`.
2. Atualizar `README.md` na integração final para apontar para `Godot 4.7+` e `./tools/run_tests.*`.
3. Adicionar workflow de CI (GitHub Actions) executando `./tools/run_tests.sh` com Godot 4.7+ headless a cada PR.
