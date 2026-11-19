# 🦖 Fóssil Rush

Jogo incremental 2D de escavação, reconstrução de acampamento e dinossauros com sistema de prestígio por impacto de meteoro, desenvolvido em **Godot 4.7+** (GDScript 2.0).

## 👥 Equipe & Organização do Repositório
Projeto desenvolvido em parceria por:
- **Pedro Moretin (`moretin`)**
- **Gabriel (`gabrielarroyoc`)**

> [!IMPORTANT]
> **Sobre os arquivos de apoio (`AGENTS.md`, `IDEIAS.md`, `docs/PROMPTS_CHATS.md`)**:
> - O arquivo [`AGENTS.md`](AGENTS.md) e os guias em `docs/PROMPTS_CHATS.md` são configurações **exclusivas do fluxo de assistentes de IA (Codex & Antigravity) utilizado pelo Pedro (`moretin`)**.
> - O **Gabriel (`gabrielarroyoc`)** pode ignorar completamente o `AGENTS.md` em seu ambiente local: ele não interfere na execução do jogo no Godot nem altera o fluxo normal de Git/branches do Gabriel.
> - Para evitar conflitos entre os dois desenvolvedores, **nenhum agente de IA deve dar force-push ou sobrescrever commits/branches do Gabriel**, e qualquer ideia listada em [`IDEIAS.md`](IDEIAS.md) é apenas um rascunho de consulta (não implementada sem alinhamento prévio).

## ⚙️ Requisitos
- **Godot Engine**: **v4.7+** (`GL Compatibility`)
- **Resolução Base**: `1920×1080` (janela padrão `1600×900`, `canvas_items` + `expand`)

## 🗺️ Estrutura de Cenários
O jogo possui 2 cenários verticais conectados por transição suave em [`scenes/main/Main.tscn`](scenes/main/Main.tscn):
1. **Superfície (`scenes/surface/SurfaceScene.tscn`)**:
   - Clique no ovo de âmbar para chocar o Compsognato. Desça à jazida e reúna 15 rochas para instalar o primeiro posto.
   - Clique diretamente em uma construção para abrir a bancada. Use as setas para examinar um item por vez. As ferramentas da expedição ficam disponíveis desde a chegada. Instalar o posto inicia a produção do especialista e libera seu equipamento.
   - A pedreira produz rochas para construção, o pesqueiro fornece peixes e abriga a incubadora, a torre recolhe penas e a universidade gera ciência e concentra a pesquisa permanente de âmbar. Cada ampliação aumenta a produção do local.
2. **Escavação (`scenes/dig_site/DigSite.tscn`)**:
   - Corte geológico lateral com as **5 camadas da Terra** (`Terra (Crosta)`, `Pedra`, `Rocha Incandescente`, `Magma`, `Núcleo`).
   - Enxame de dinossauros (`scenes/dinos/DinoSwarm.tscn`) e botão superior `▲ VOLTAR PARA A SUPERFÍCIE`.

## 🧪 Validação via Linha de Comando (Headless)
```bash
godot --headless --path . --quit-after 2
godot --headless --path . -s res://scenes/ui/test_ui_layout.gd
```

## 💡 Ideias e Planejamento Futuro
Consulte [`IDEIAS.md`](IDEIAS.md) para o banco de ideias de design, novos recursos, estruturas e especializações de dinossauros anotados para consulta futura (sem impacto no código atual).
