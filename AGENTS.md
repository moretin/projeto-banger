# AGENTS.md — Guia para Agentes de IA (Codex & Antigravity)

Este arquivo é lido automaticamente pelo **Codex** e pelo **Antigravity** para manter consistência arquitetural e evitar conflitos de merge no projeto **Fóssil Rush** (Godot 4.x).

## 1. Regras Obrigatórias de GDScript e Compatibilidade
- **Tipagem Estática Estrita (`project.godot`)**:
  - `untyped_declaration=1`, `unsafe_property_access=1`, `unsafe_method_access=1`.
  - Sempre declare tipos explícitos em variáveis, parâmetros, retornos de função e loops (`for item: Tipo in lista:`).
- **Compatibilidade com Godot 4.2 / 4.3 / 4.4+**:
  - **NUNCA** use sintaxe de dicionário tipado do Godot 4.4+ (`Dictionary[K, V]`). Use sempre `Dictionary` simples e itere com `for k: Variant in dict:`.
  - Mantenha `config/features=PackedStringArray("4.2", "GL Compatibility")` no `project.godot`.
- **Save System (`autoload/SaveManager.gd`)**:
  - Se alterar a estrutura de eras, recursos ou chaves salvas no `GameState.gd`, incremente `SAVE_VERSION` e trate a migração em `_migrate()`.

## 2. Arquitetura do Jogo
- **Autoloads (Singletons)**:
  - `autoload/Events.gd`: Barramento de sinais global (Signal Bus). Cenas nunca se acoplam diretamente umas às outras.
  - `autoload/GameState.gd`: Estado único da partida, cálculo de multiplicadores, economia, 5 camadas da Terra (`data/eras/`), dinossauros (`data/dinos/`), upgrades (`data/upgrades/`), Rocha Laranja e Escombros da Superfície.
  - `autoload/SaveManager.gd`: Persistência JSON atômica em `user://savegame.json`.
- **Dinâmica de 2 Cenários Verticais (`scenes/main/Main.tscn`)**:
  - **Cenário 1 — Superfície (`scenes/surface/SurfaceScene.tscn`)**: Onde o jogo começa. Possui a Rocha Laranja inicial (que libera o Dinossauro Principal com sprite `res://assets/sprites/compsognathus.png`), 4 Escombros de Pedra reconstruídos com `🪨 Rochas` (`RES_ROCKS`) e o botão inferior `▼ ESCAVAÇÃO`.
  - **Cenário 2 — Escavação (`scenes/dig_site/DigSite.tscn`)**: Corte lateral com as 5 camadas da Terra (`Terra (Crosta)`, `Pedra`, `Rocha Incandescente`, `Magma`, `Núcleo`), enxame de dinos (`DinoSwarm.tscn`) e botão superior `▲ VOLTAR PARA A SUPERFÍCIE`.

## 3. Áreas e Branches de Trabalho
- `main`: Branch principal integrada e estável.
- `[B1]` `feat/core-economy` → `autoload/GameState.gd`, `data/`
- `[B2]` `feat/ui-upgrades` → `scenes/ui/`
- `[B3]` `feat/dig-site` → `scenes/dig_site/DigSite.*`, `scenes/surface/SurfaceScene.*`
- `[B4]` `feat/dinos` → `scenes/dinos/`
- `[B5]` `feat/meteor-prestige` → `scenes/meteor/`
- `[B6]` `feat/save-system` → `autoload/SaveManager.gd`, `scenes/ui/SaveModals.*`
- `[B7]` `feat/vfx-audio` → `scenes/dig_site/VfxAudioManager.*`

## 4. Validação antes de Commit / PR
Sempre valide se não há erros de compilação ou layout antes de concluir:
```bash
godot --headless --path . --quit-after 2
godot --headless --path . -s res://scenes/ui/test_ui_layout.gd
```
