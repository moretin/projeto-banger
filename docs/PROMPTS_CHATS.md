# 🗂️ Prompts Prontos por Área / Branch (`[B1]` a `[B7]`)

Para trabalhar em chats separados dentro deste Projeto no Antigravity, basta clicar em **"+ New Chat"** na barra lateral do projeto e colar o bloco da área que quiser evoluir.

---

## `[B1]` Core, Economia & Balanceamento
```text
CONTEXTO DE BRANCH ATIVA: Estamos trabalhando no projeto "Fóssil Rush" (Godot 4, GDScript 2.0 estaticamente tipado).
Chat / Área Atual: [B1] Core, Economia & Balanceamento
Branch Git: feat/core-economy
Diretório Alvo: autoload/GameState.gd e data/ (dinos/, upgrades/, eras/)
Regras de Isolamento:
1. Faça checkout na branch `feat/core-economy` (sincronizada com a `main`).
2. Não altere diretamente cenas de UI, escavação, dinos ou meteoro; toda comunicação deve passar pelo singleton `autoload/Events.gd` e dados em `autoload/GameState.gd` + arquivos Resource (`.tres`).
3. Mantenha 100% de tipagem estática em GDScript 2.0 (zero warnings com `untyped_declaration=1`).
4. Ao final de cada resposta, liste: sinais adicionados ao `Events.gd`, arquivos `.gd`/`.tres` criados ou modificados, e faça o commit/push na branch `feat/core-economy`.
```

---

## `[B2]` UI & Painéis de Upgrade (4 Abas + HUD)
```text
CONTEXTO DE BRANCH ATIVA: Estamos trabalhando no projeto "Fóssil Rush" (Godot 4, GDScript 2.0 estaticamente tipado).
Chat / Área Atual: [B2] UI & Painéis de Upgrade
Branch Git: feat/ui-upgrades
Diretório Alvo: scenes/ui/ e data/upgrades/
Regras de Isolamento:
1. Faça checkout na branch `feat/ui-upgrades` (sincronizada com a `main`).
2. Não altere diretamente cenas de outras branches (`scenes/dig_site/`, `scenes/dinos/`, `scenes/meteor/`); dispare ou conecte sinais exclusivamente através do singleton `autoload/Events.gd` e leia/grave dados via `autoload/GameState.gd` e arquivos Resource (`.tres`).
3. Priorize uma interface limpa, responsiva (Control containers nativos da Godot 4), com as 4 abas (`⛏️ Ferramentas`, `🦖 Dinos`, `🏭 Máquinas`, `🛡️ Defesa`), multiplicadores (`1x`, `10x`, `100x`, `Máx`) e feedback visual imediato.
4. Entregue a árvore de nós sugerida (hierarquia da cena `.tscn`) antes do script `.gd` e valide em modo headless na Godot 4 antes de commitar na branch `feat/ui-upgrades`.
```

---

## `[B3]` Corte Lateral do Solo & Escavação
```text
CONTEXTO DE BRANCH ATIVA: Estamos trabalhando no projeto "Fóssil Rush" (Godot 4, GDScript 2.0 estaticamente tipado).
Chat / Área Atual: [B3] Corte Lateral do Solo & Escavação
Branch Git: feat/dig-site
Diretório Alvo: scenes/dig_site/ e data/eras/
Regras de Isolamento:
1. Faça checkout na branch `feat/dig-site` (sincronizada com a `main`).
2. Não referencie nós da UI ou dos dinos diretamente; emita `Events.dig_hit` nos cliques e escute `Events.layer_hp_changed`, `Events.layer_broken`, `Events.era_changed`, `Events.color_progress_changed` e `Events.danger_level_changed`.
3. Entregue a árvore de nós sugerida (hierarquia da cena `.tscn`) antes do script `.gd` e valide em modo headless na Godot 4 antes de commitar na branch `feat/dig-site`.
```

---

## `[B4]` Dinos, IA & MultiMeshInstance2D
```text
CONTEXTO DE BRANCH ATIVA: Estamos trabalhando no projeto "Fóssil Rush" (Godot 4, GDScript 2.0 estaticamente tipado).
Chat / Área Atual: [B4] Dinos, IA & MultiMeshInstance2D
Branch Git: feat/dinos
Diretório Alvo: scenes/dinos/ e data/dinos/
Regras de Isolamento:
1. Faça checkout na branch `feat/dinos` (sincronizada com a `main`).
2. Não referencie nós da UI ou da rocha diretamente; escute `Events.dino_count_changed` e emita `Events.dig_hit` para aplicar o dano das espécies.
3. Mantenha alta performance com `MultiMeshInstance2D` para suportar centenas de dinos na tela a 60+ FPS.
4. Entregue a árvore de nós sugerida (hierarquia da cena `.tscn`) antes do script `.gd` e valide em modo headless na Godot 4 antes de commitar na branch `feat/dinos`.
```

---

## `[B5]` Meteoro, Timer & Árvore de Âmbar (Prestígio)
```text
CONTEXTO DE BRANCH ATIVA: Estamos trabalhando no projeto "Fóssil Rush" (Godot 4, GDScript 2.0 estaticamente tipado).
Chat / Área Atual: [B5] Meteoro, Timer & Árvore de Âmbar
Branch Git: feat/meteor-prestige
Diretório Alvo: scenes/meteor/ e data/upgrades/amber/
Regras de Isolamento:
1. Faça checkout na branch `feat/meteor-prestige` (sincronizada com a `main`).
2. Comunique-se exclusivamente via `Events.gd` (`meteor_timer_changed`, `meteor_impact_started`, `prestige_completed`, `prestige_modal_requested`) e `GameState.gd`.
3. Entregue a árvore de nós sugerida (hierarquia da cena `.tscn`) antes do script `.gd` e valide em modo headless na Godot 4 antes de commitar na branch `feat/meteor-prestige`.
```

---

## `[B6]` Save/Load, Progresso Offline & Configurações
```text
CONTEXTO DE BRANCH ATIVA: Estamos trabalhando no projeto "Fóssil Rush" (Godot 4, GDScript 2.0 estaticamente tipado).
Chat / Área Atual: [B6] Save/Load, Progresso Offline & Configurações
Branch Git: feat/save-system
Diretório Alvo: autoload/SaveManager.gd e scenes/ui/SaveModals.*
Regras de Isolamento:
1. Faça checkout na branch `feat/save-system` (sincronizada com a `main`).
2. Mantenha escrita atômica em JSON + backup, progresso offline via `Events.offline_progress_applied` e export/import Base64.
3. Entregue a árvore de nós sugerida (hierarquia da cena `.tscn`) antes do script `.gd` e valide em modo headless na Godot 4 antes de commitar na branch `feat/save-system`.
```

---

## `[B7]` Partículas GPU (`GPUParticles2D`), Shaders & Áudio
```text
CONTEXTO DE BRANCH ATIVA: Estamos trabalhando no projeto "Fóssil Rush" (Godot 4, GDScript 2.0 estaticamente tipado).
Chat / Área Atual: [B7] Partículas GPU, Shaders & Áudio
Branch Git: feat/vfx-audio
Diretório Alvo: assets/, scenes/dig_site/VfxAudioManager.* e scenes/meteor/
Regras de Isolamento:
1. Faça checkout na branch `feat/vfx-audio` (sincronizada com a `main`).
2. Escute apenas sinais de `Events.gd` (`dig_hit`, `layer_broken`, `upgrade_purchased`, `dino_unlocked`, `meteor_impact_started`) para disparar partículas em pool (`GPUParticles2D`) e efeitos sonoros.
3. Entregue a árvore de nós sugerida (hierarquia da cena `.tscn`) antes do script `.gd` e valide em modo headless na Godot 4 antes de commitar na branch `feat/vfx-audio`.
```
