# AGENTS.md — Guia para Agentes de IA (Fluxo do Pedro: Codex & Antigravity)

> **Aviso de Escopo Colaborativo (`moretin` & `gabrielarroyoc`)**:
> Este arquivo é de uso **exclusivo do fluxo de trabalho com IA (Codex e Antigravity) do Pedro (`moretin`)**.
> O projeto **Fóssil Rush** é desenvolvido em dupla com o **Gabriel (`gabrielarroyoc`)**. Portanto, qualquer agente de IA que leia este arquivo deve seguir estritamente as regras de convivência abaixo para **nunca gerar conflito com o trabalho do Gabriel**:
> 1. **Sempre faça `git fetch origin` antes de editar ou subir commits**, verificando se o Gabriel (`gabrielarroyoc`) enviou novos commits na `main` ou em qualquer branch.
> 2. **NUNCA faça `git push --force`** nem sobrescreva branches em que o Gabriel esteja trabalhando.
> 3. **Não implemente automaticamente ideias do arquivo `IDEIAS.md`**: o `IDEIAS.md` é apenas um bloco de notas de design para consulta futura e só deve ser codificado quando solicitado explicitamente.

## 1. Regras Obrigatórias de GDScript e Versão da Engine
- **Engine Oficial**: **Godot 4.7.2** (`config/features=PackedStringArray("4.7", "GL Compatibility")` no `project.godot`).
- **Tipagem Estática Estrita (`project.godot`)**:
  - `untyped_declaration=1`, `unsafe_property_access=1`, `unsafe_method_access=1`.
  - Sempre declare tipos explícitos em variáveis, parâmetros, retornos de função e loops (`for item: Tipo in lista:`).
- **Dicionários e Iteração Segura**:
  - Use `Dictionary` padrão e itere com `for k: Variant in dict:` para evitar avisos de tipagem estrita.
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
