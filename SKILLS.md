# 🧠 Registro & Curadoria de Skills (`skills.sh`) — Fóssil Rush

> [!NOTE]
> **Escopo Colaborativo (`moretin` & `gabrielarroyoc`)**:
> - Este guia organiza as **Agent Skills** instaladas para o fluxo com IA (**Codex** e **Antigravity**) no projeto **Fóssil Rush** (**Godot 4.7+**, 2D, GDScript 2.0 estaticamente tipado).
> - Todas as **19 skills** do pacote filtrado de [`gamedev-skills/awesome-gamedev-agent-skills`](https://github.com/gamedev-skills/awesome-gamedev-agent-skills) foram sincronizadas em **dois locais**:
>   1. **No repositório (Antigravity / compartilhável com o time)**: `.agents/skills/<nome-da-skill>/SKILL.md`
>   2. **No Codex local do Pedro (Windows)**: `C:\Users\pedro\.codex\skills\<nome-da-skill>\SKILL.md`
> - A pasta `.agents/` contém um arquivo vazio [`.agents/.gdignore`](.agents/.gdignore) para garantir que a **Godot Engine** nunca importe nem tente compilar scripts `.gd` de exemplo/validação presentes dentro das skills.

---

## 📦 Skills Instaladas e Ativas (19 / 19)

### 🎮 Godot 4.7 (13 Skills)

| Skill | Categoria | Status | Caminhos Locais | Como atua no Fóssil Rush |
| :--- | :--- | :--- | :--- | :--- |
| **`godot-ui-control`** | Godot UI | ✅ Ativa | `.agents/skills/godot-ui-control/SKILL.md`<br>`C:\Users\pedro\.codex\skills\godot-ui-control\SKILL.md` | Layouts responsivos (`Control`/Containers), `AmberTheme`, foco e validação em `scenes/ui/` (`HUD`, `FossilMuseum`, `SaveModals`, `ui_theme.tres`, `test_ui_layout.gd`). |
| **`godot-gdscript`** | Linguagem | ✅ Ativa | `.agents/skills/godot-gdscript/SKILL.md`<br>`C:\Users\pedro\.codex\skills\godot-gdscript\SKILL.md` | GDScript 2.0 com **tipagem estática estrita** (`untyped_declaration=1`, `unsafe_property_access=1`, `unsafe_method_access=1`), `@onready`, `@export` e `Tween`. |
| **`godot-signals-groups`** | Arquitetura | ✅ Ativa | `.agents/skills/godot-signals-groups/SKILL.md`<br>`C:\Users\pedro\.codex\skills\godot-signals-groups\SKILL.md` | Mantém a **Regra de Ouro** via Signal Bus em `autoload/Events.gd` com conexões tipadas (`Callable`), sem acoplamento direto entre cenas. |
| **`godot-resources`** | Dados | ✅ Ativa | `.agents/skills/godot-resources/SKILL.md`<br>`C:\Users\pedro\.codex\skills\godot-resources\SKILL.md` | Recursos customizados (`.tres`) e `.uid` para dinos, eras, upgrades e `data/balance.tres` (`data/*.gd`). |
| **`godot-2d-movement`** | Gameplay 2D | ✅ Ativa | `.agents/skills/godot-2d-movement/SKILL.md`<br>`C:\Users\pedro\.codex\skills\godot-2d-movement\SKILL.md` | Base para a movimentação `WASD` do Dinossauro Protagonista na Superfície (`SurfaceScene`) e controle responsivo em 2D. |
| **`godot-physics`** | Física 2D | ✅ Ativa | `.agents/skills/godot-physics/SKILL.md`<br>`C:\Users\pedro\.codex\skills\godot-physics\SKILL.md` | `CharacterBody2D`, zonas de proximidade (`Area2D`) para abrir upgrades das estações e detecção de pontos de coleta/afloramentos. |
| **`godot-animation`** | Animação | ✅ Ativa | `.agents/skills/godot-animation/SKILL.md`<br>`C:\Users\pedro\.codex\skills\godot-animation\SKILL.md` | `AnimatedSprite2D`, `AnimationPlayer` e `Tween`s (movimento dos dinos, carimbo do Laudo no `FossilMuseum`, impacto em `MeteorOverlay`). |
| **`godot-nodes-scenes`** | Cenas | ✅ Ativa | `.agents/skills/godot-nodes-scenes/SKILL.md`<br>`C:\Users\pedro\.codex\skills\godot-nodes-scenes\SKILL.md` | Hierarquia `.tscn`, instanciação de `PackedScene`, `%UniqueNames` e singletons (`Main.tscn`, `SurfaceScene.tscn`, `DinoSwarm.tscn`). |
| **`godot-gdscript-headless-testing`** | Testes / QA | ✅ Ativa | `.agents/skills/godot-gdscript-headless-testing/SKILL.md`<br>`C:\Users\pedro\.codex\skills\godot-gdscript-headless-testing\SKILL.md` | Suíte headless (`godot --headless`), testes GUT em `tests/` (`tools/run_tests.ps1`), simulador `tools/sim/sim_runner.gd` e `test_ui_layout.gd`. |
| **`godot-audio`** | Áudio | ✅ Ativa | `.agents/skills/godot-audio/SKILL.md`<br>`C:\Users\pedro\.codex\skills\godot-audio\SKILL.md` | `AudioStreamPlayer`, buses de áudio e pool de SFX em `scenes/dig_site/VfxAudioManager.gd`. |
| **`godot-shaders`** | VFX / Shaders | ✅ Ativa | `.agents/skills/godot-shaders/SKILL.md`<br>`C:\Users\pedro\.codex\skills\godot-shaders\SKILL.md` | Shaders 2D (`.gdshader`) para contorno/destaque de estações por proximidade, brilho térmico do meteoro e efeitos de água/poeira. |
| **`godot-tilemap`** | Mapa 2D | ✅ Ativa | `.agents/skills/godot-tilemap/SKILL.md`<br>`C:\Users\pedro\.codex\skills\godot-tilemap\SKILL.md` | `TileMapLayer` e `TileSet` modernos da Godot 4, útil caso o terreno da Bacia do Âmbar ou um canteiro em grade migre do desenho procedural para tiles. |
| **`godot-export`** | Build | ✅ Ativa | `.agents/skills/godot-export/SKILL.md`<br>`C:\Users\pedro\.codex\skills\godot-export\SKILL.md` | Configuração de exportação (Windows/Web) compatível com Godot 4.7+ e recursos `.remap`/`.tres`. |

---

### 🧩 Disciplinas Transversais de Game Dev (6 Skills)

| Skill | Categoria | Status | Caminhos Locais | Como atua no Fóssil Rush |
| :--- | :--- | :--- | :--- | :--- |
| **`game-ui-ux`** | Design de UI | ✅ Ativa | `.agents/skills/game-ui-ux/SKILL.md`<br>`C:\Users\pedro\.codex\skills\game-ui-ux\SKILL.md` | Par oficial da `godot-ui-control`: clareza de HUD, legibilidade de custos/recursos, fluxos de bancada e acessibilidade. |
| **`game-feel`** | Polimento | ✅ Ativa | `.agents/skills/game-feel/SKILL.md`<br>`C:\Users\pedro\.codex\skills\game-feel\SKILL.md` | *Screen shake*, *hit-stop*, números flutuantes e feedback tátil ao chocar o ovo, coletar recursos e acionar o Sismógrafo. |
| **`save-systems`** | Persistência | ✅ Ativa | `.agents/skills/save-systems/SKILL.md`<br>`C:\Users\pedro\.codex\skills\save-systems\SKILL.md` | Escrita JSON atômica, backup, versionamento (`SAVE_VERSION`), migração em `_migrate()` e cálculo offline em `autoload/SaveManager.gd`. |
| **`input-systems`** | Controles | ✅ Ativa | `.agents/skills/input-systems/SKILL.md`<br>`C:\Users\pedro\.codex\skills\input-systems\SKILL.md` | Mapeamento de `InputMap`, suporte limpo a `WASD`, mouse e navegação de foco por teclado/controle. |
| **`performance-optimization`** | Performance | ✅ Ativa | `.agents/skills/performance-optimization/SKILL.md`<br>`C:\Users\pedro\.codex\skills\performance-optimization\SKILL.md` | Otimização de FPS, *object pooling* e renderização em lote via `MultiMeshInstance2D` em `scenes/dinos/DinoSwarm.gd`. |
| **`camera-systems`** | Câmera 2D | ✅ Ativa | `.agents/skills/camera-systems/SKILL.md`<br>`C:\Users\pedro\.codex\skills\camera-systems\SKILL.md` | Enquadramento 2D, transições verticais (`Main.gd`), acompanhamento do protagonista na superfície e descida estratigráfica. |

---

## 🚫 O que foi filtrado de fora (Intencionalmente Não Instalado)

Do repositório `gamedev-skills/awesome-gamedev-agent-skills` (80 skills totais), foram **excluídas** para não poluir o contexto dos agentes:
- **Engines não utilizadas**: `unity-*`, `unreal-*`, `roblox-*`, `bevy-ecs`, `ebitengine-game`, `defold-core`, `love2d-core`, `pygame-core`, `phaser-*`, `pixijs-rendering`, `threejs-*`.
- **Recursos de Godot fora do escopo**: `godot-csharp` (o projeto é 100% GDScript 2.0), `godot-3d-essentials` (o jogo é estritamente 2D) e `godot-multiplayer` (jogo single-player local).
- **Gêneros e fluxos genéricos**: `router`, `genres/*`, `workflows/*` e disciplinas não aplicáveis (ex.: `dialogue-systems`, `level-design`, `ai-behavior-trees-utility-ai`, etc.).

---

## 🔄 Como Atualizar ou Adicionar Novas Skills

Caso queira reinstalar alguma dessas 19 skills ou adicionar outra skill pontual do `skills.sh` (por exemplo, de `ziva-sh/godot-skills`), mantenha a mesma regra:
1. Copie a pasta da skill para **`.agents/skills/<nome>/`** (para o Antigravity e versionamento no projeto) **e** para **`C:\Users\pedro\.codex\skills\<nome>\`** (para o Codex local).
2. Mantenha o arquivo [`.agents/.gdignore`](.agents/.gdignore) para isolar a pasta da importação do editor Godot.
3. Registre a entrada correspondente na tabela acima neste `SKILLS.md`.
