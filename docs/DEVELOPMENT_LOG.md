# BANGER / FÓSSIL RUSH — LOG DE DESENVOLVIMENTO (CICLO 1)

- **Commit base analisado:** `c278451` (`fix(b7): release AudioStreamGeneratorPlayback reference on exit`)
- **Engine:** Godot 4.7.1 stable (`GDScript` com checagem estrita de tipagem)
- **Direção Visual:** Inspirada em *The Gnorp Apologue* (`#2A2B38` céu noturno estrelado, bordas nítidas de `2px`, construções line-art clicáveis no cenário, rocha escalonada à direita e telemetria lateral esquerda)

---

## 1. Diagnóstico Inicial

Na auditoria pós-refatoração parcial sobre `c278451`, foram identificados os seguintes bloqueadores e lacunas:

1. **Integração incompleta da UI Gnorp Apologue:**
   - Cenas e referências antigas de painel lateral (`UpgradePanel`) coexistiam com o novo fluxo em cenário (`WorldBuilding` / `BuildingPanel`), enquanto `DinoSwarm` ainda operava em lógica de órbita top-down em vez de visão lateral.
   - `DigSite` apresentava erro de compilação com constante não-constante (`BUILDING_SPECS`) e dependência de cache de classes globais antes da reimportação.
   - Em execução `--headless`, `VfxAudioManager` vazava 1 instância `AudioStreamGeneratorPlayback` no driver `"Dummy"`.
2. **Sistemas de Gameplay do GDD Incompletos:**
   - Papéis dos dinossauros (`DinoData.Role`) sem sinergias mecânicas diferenciadas na simulação.
   - Clonagem de dinossauros restrita a `1x` (sem suporte a `10x` / `100x` / `Máx`).
   - Dano excedente ao quebrar uma camada era perdido (sem overkill carryover) e drops de minério/fragmento puniam golpes fortes.
   - Faltavam os veios especiais clicáveis na rocha (GDD §3) e a condição de vitória real do **Projeto Arca** (GDD §7).
3. **Ausência de Testes e Singularidade Econômica:**
   - Sem simulador de economia ou suíte QA automatizada no repositório.
   - Ao rodar a primeira simulação (`tests/simulate_runs.gd`), a economia original (`bones_per_damage` subindo até `80` e bônus multiplicativos sem teto) causava explosão exponencial: na Run 1, `STRAT_HYBRID` saltava direto para o **Núcleo Primordial (`148m`, `4.83Sx` ossos, `+69.4B` Âmbar)**.

---

## 2. Arquitetura & Cenas Consolidadas

- `autoload/Events.gd`: Signal Bus ampliado nas regiões originais com `vein_spawned`, `vein_cracked`, `ark_victory_achieved` e `audio_mute_toggled`.
- `autoload/GameState.gd` & `data/DinoData.gd`: Fonte única da verdade ampliada com compra em lote de dinos, 8 sinergias de papel com teto seguro, carryover de overkill entre camadas da mesma Era, normalização de drops por dano, veios especiais e API do **Projeto Arca**.
- `autoload/SaveManager.gd`: Persistência atômica protegida com flag `autosave_enabled` em `prestige_completed`, `_notification` e `import_save_string()` para testes sem sobrescrever `user://savegame.json`.
- `scenes/ui/UITheme.gd`: Tema Gnorp unificado (`build_gnorp_theme()`), caixas de `2px`, botões com inversão no hover e controle global de mudo (`audio_muted`).
- `scenes/dig_site/DigSite.gd` & `scenes/dig_site/DigSite.tscn`: Visão lateral com 5 construções (`Oficina`, `Incubadora`, `Fábrica`, `Bunker`, `Templo`), pilha de ossos na base, veios especiais brilhantes (`VEIO!`), partículas de impacto e atalhos (`Espaço` para escavar, `1`–`5` para construções).
- `scenes/world/WorldBuilding.gd` & `scenes/world/BuildingPanel.gd`: Construções line-art com indicador de compra disponível e tabela flutuante `[nome | nível/qtd | custo]` + tooltip lateral com descrição da sinergia.
- `scenes/dinos/DinoSwarm.gd`: Movimentação lateral integrada via `setup_world(_dig_site)` respeitando papéis (atacantes na face da rocha, Compsognatos transportando ossos, Pterodáctilos em voo com minérios, Braquiossauros em suporte).
- `scenes/ui/HUD.gd`, `scenes/title/TitleScreen.gd`, `scenes/meteor/MeteorOverlay.gd`, `scenes/dig_site/VfxAudioManager.gd`, `scenes/main/Main.gd`: Barra superior enxuta + botão `[ARCA?]`, telemetria `Dano`/`Coleta` à esquerda, controles `[♪] [💾] [⚙] [⌂]` à direita, tela inicial Gnorp, checklist/botão do Projeto Arca em `MeteorOverlay` e guarda contra leak em driver de áudio `Dummy`.

---

## 3. Sistemas de Gameplay Implementados

### 3.1 Sinergias Únicas dos 8 Papéis (`GameState.gd`)
| Papel | Espécie | Sinergia Mecânica |
|---|---|---|
| `COLLECTOR` | Compsognato | `+1.5%` ossos totais por unidade (máx 30 unid = `+45%`) |
| `FAST` | Velociraptor | `+2%` dano próprio por unidade (máx 30 unid = `+60%`) |
| `AREA` | Tricerátopo | `+1.5%` dano de clique e máquinas por unidade (máx 30 unid = `+45%`) |
| `BREAKER` | T-Rex | `+20%` dano por Era geológica avançada |
| `TRANSPORT` | Pterodáctilo | `+3%` multiplicador de chance de minério por unidade (máx 25 unid = `+75%`) |
| `SUPPORT` | Braquiossauro | Aura global de `+4%` dano para todos os dinos por unidade (máx 20 unid = `+80%`) |
| `DEFENSE` | Anquilossauro | `+2%` de escudo contra meteoro/unid e `+40% * escudo` de dano próprio |
| `ELEMENTAL` | Dilofossauro | Ácido corrosivo contínuo (`min(0.2% * qtd, 4%)` do HP da camada/s com teto de DPS) |

### 3.2 Demais Mecânicas
- **Clonagem em Lote (`1x / 10x / 100x / Máx`):** `DinoData.get_bulk_unit_cost()` e `get_max_affordable_units()` via soma/log de PG; a 1ª montagem (`count == 0`) exige `fragments_required` e resolve sempre para `1` unidade. Multiplicador de marco recalibrado para `1.5×`.
- **Overkill & Drops Normalizados:** `apply_dig_damage()` propaga dano excedente por até 8 camadas e interrompe exatamente ao cruzar para uma nova Era geológica; chances de minério e fragmento escalam por `hit_equiv` (`0.35..6.0`), com bônus garantido de minério ao quebrar camada.
- **Veios Especiais (`crack_rock_vein`):** Veios cintilantes aparecem na rocha e concedem surto de ossos, `2× mineral_amount` e `50%` de chance de fragmento ao clique.
- **Vitória Projeto Arca (`GDD §7`):** Exige `amber_ark_project >= Nv 5`, `escudo >= 75%` e `Era >= Triássico (index >= 3)`. Desativa o avanço imediato da ameaça (reseta timer), concede `+25` Âmbar na primeira conclusão (`ark_completed = true`) e libera o modo infinito.

---

## 4. Calibração Econômica & Simulação Real (`tests/simulate_runs.gd`)

Ajustes aplicados em `data/eras/*.tres`, `data/dinos/*.tres`, `data/upgrades/**/*.tres`, `data/DinoData.gd` e `autoload/GameState.gd`:
- Dureza crescente nas Eras profundas (`bones_per_damage`: `1.0 → 0.32 → 0.11 → 0.04 → 0.018 → 0.008`) com custos de espécies escalonados (`1.30–1.35×` crescimento) e tetos de nível nos multiplicadores críticos.
- Fórmula de Âmbar ajustada para `floor((run_total_bones / 6000)^0.19 * (1 + depth * 0.04) * (1 + shield_ratio) * amber_mult)` e `amber_fossil_mastery` calibrado como multiplicador exponencial (`×2.30^nível`).

Resultados reais obtidos com `Godot_v4.7.1-stable_win64_console.exe --headless -s res://tests/simulate_runs.gd` (`dt = 0.5s`, `seed = 424242`):

### Run 1 Comparativo (900s)
| Estratégia | Era Final | Profund. | Ossos Totais | DPS Pico | Dinos | Escudo | Âmbar |
|---|---|---|---|---|---|---|---|
| `STRAT_CLICKS` | Jurássico | 24m | 888K | 1.47K/s | 0 | 0% | +5 |
| `STRAT_DINOS` | Triássico | 29m | 2.40M | 75.1K/s | 87 | 0% | +6 |
| `STRAT_MACHINES` | Jurássico | 27m | 2.04M | 4.67K/s | 0 | 0% | +6 |
| `STRAT_ECONOMY` | Jurássico | 19m | 196K | 362/s | 47 | 0% | +3 |
| `STRAT_DEFENSE` | Jurássico | 18m | 22.4K | 174/s | 27 | 85% | +4 |
| `STRAT_HYBRID` | Triássico | 39m | 175M | 1.58M/s | 174 | 100% | +36 |

### Progressão Multi-Run (`STRAT_HYBRID` + Gasto de Âmbar)
| Run | Duração | Era Final | Profund. | Ossos Totais | DPS Pico | Dinos | Escudo | Âmbar Ganho | Arca Pronta? |
|---|---|---|---|---|---|---|---|---|---|
| `#1` | 15:00 | Triássico | 39m | 175M | 1.58M/s | 174 | 100% | +36 | Nv 0/5 |
| `#2` | 15:00 | Permiano | 49m | 8.14B | 10.5M/s | 278 | 100% | +147 | Nv 2/5 |
| `#3` | 16:00 | Permiano | 54m | 269B | 22.6M/s | 377 | 100% | +431 | Nv 4/5 |
| `#4` | 19:00 | Permiano | 57m | 2.84T | 37.4M/s | 444 | 100% | +904 | **SIM** |
| `#5` | 21:00 | Núcleo Primordial | 59m | 19.1T | 45.1M/s | 497 | 100% | +1.48K | **SIM** |

---

## 5. Suíte QA Automatizada (`tests/run_tests.gd`)

Execução com `Godot_v4.7.1-stable_win64_console.exe --headless -s res://tests/run_tests.gd`:
- **Resultado:** `EXIT: 0`, **139/139 asserções aprovadas (`ALL TESTS PASSED`)**, `0` erros/warnings de script e `0` vazamentos de `ObjectDB`.
- **Cobertura validada:**
  1. Integridade do banco (8 dinos, 22 upgrades, 6 eras ordenadas `0..5`).
  2. Matemática de compra em lote `1x / 10x / 100x / BUY_MAX` (upgrades e dinos), trava de 1ª montagem e marco de 25 unidades (`1.5×`).
  3. Todas as 8 sinergias com tetos, carryover de overkill parando na entrada da Era 1 (`Cretáceo`), e `crack_rock_vein()`.
  4. `perform_prestige()` (reset vs upgrades permanentes) e `activate_ark_victory()` (bônus único de `+25` Âmbar).
  5. Round-trip `to_save_dict`/`load_save_dict`, `export_save_string`/`import_save_string` em Base64 e `apply_offline_progress(3600s)` sem avançar o meteoro.
  6. Instanciação completa de `Main.tscn` + redimensionamento em `1280×720`, `1600×900` e `1920×1080`, abertura/fechamento das construções `0..3` no `BuildingPanel` e abertura do modal de Âmbar pelo `Templo (#4)` em `MeteorOverlay`.
- **Validação final de boot:** `--headless --quit` finalizado com `EXIT: 0` e saída limpa.

---

## 6. Limitações Conhecidas & Próximo Ciclo (P2/P3)

- **Limitações atuais:** sprites das espécies usam quadro estático com animação procedural de salto/recuo/rotação; build Web HTML5 ainda não foi empacotada para publicação.
- **Backlog Ciclo 2 (P2/P3):**
  - `[P2]` Spritesheets multi-frame de caminhada e ataque para os 8 dinossauros.
  - `[P2]` Preset de exportação Web (HTML5) e testes de performance em navegador.
  - `[P2]` Variações sonoras procedurais por Era geológica e trilha ambiente opcional.
  - `[P3]` Sistema de conquistas in-world e desafios de mutação genética pós-Projeto Arca.
