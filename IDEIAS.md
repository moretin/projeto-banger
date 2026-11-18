# 💡 Banco de Ideias e Design Futuro — Fóssil Rush

> **Status**: Documento de consulta e planejamento (ideias **não implementadas** no código ainda, mantidas como referência para desenvolvimento futuro pelo time, Codex e Antigravity).

---

## 1. Recursos, Economia e Especialização por Dinossauro

Cada espécie de dinossauro possui uma **função única no ecossistema**, atuando em um ponto específico do cenário/estrutura para produzir um recurso próprio:

| Dinossauro | Local / Atividade | Recurso Gerado | Papel na Economia |
| :--- | :--- | :--- | :--- |
| **Paquicefalossauro** (*Pachycephalosaurus*) | **Montanha / Pedreira** (quebra a rocha da montanha às cabeçadas) | **🪨 Pedra** | Construção de estruturas, fundações e expansão da base. |
| **Bariônix** (*Baryonyx*) | **Rio / Lago de Pesca** (mergulha e pesca na água) | **🐟 Peixe** | Alimentação/sustento dos dinossauros, buffs de vigor e reprodução/clonagem. |
| **Dinossauro Voador Pequeno** (*Microraptor* / *Archaeopteryx* / *Pterodáctilo*) | **Céu / Copa das Árvores** (caça pássaros em voo) | **🪶 Pena** | Confecção de equipamentos leves, melhorias de velocidade/crítico e comércio. |
| **Troodonte** (*Troodon* — conhecido pela alta inteligência) | **Universidade** (entra na universidade para estudar e pesquisar) | **🧪 Ciência** | Desbloqueio de novas tecnologias, ressurreição de espécies e árvores de upgrade avançadas. |

---

## 2. Estruturas Vinculadas e Upgrades Intuitivos (Equipamentos dos Dinos)

Cada estrutura está diretamente ligada ao dinossauro daquela função. O objetivo das estruturas e de seus upgrades é **melhorar os atributos dos dinossauros de maneira visual, bem-humorada e intuitiva**, equipando-os com itens que fazem sentido para a tarefa:

### ⛰️ Montanha / Pedreira (Paquicefalossauros → 🪨 Pedra)
- **Conceito**: Os Paquicefalossauros correm e dão cabeçadas na encosta da montanha para extrair pedra.
- **Exemplos de Upgrades Intuitivos**:
  - **Capacetes de Couro / Ferro / Titânio**: protege a cabeça do Paquicefalossauro e aumenta o dano de impacto por cabeçada.
  - **Botas de Tração**: aumenta a velocidade de investida até a montanha.
  - **Capacete com Britadeira / Lanterna**: adiciona chance crítica de extrair blocos gigantes de pedra.

### 🎣 Pesqueiro / Lago (Bariônix → 🐟 Peixe)
- **Conceito**: O Bariônix usa seu focinho longo e garras para pescar nas águas da superfície.
- **Exemplos de Upgrades Intuitivos**:
  - **Nadadeiras nos Pés / Cauda**: aumenta a agilidade na água e a frequência de pesca.
  - **Óculos de Mergulho / Snorkel**: permite pescar em águas mais profundas (peixes maiores/mais valiosos).
  - **Cesto de Pesca / Rede Lateral**: aumenta a capacidade de carga de peixes por viagem.

### 🦅 Torre de Caça / Céu (Voador Pequeno → 🪶 Pena)
- **Conceito**: Um pequeno dinossauro voador patrulha os céus caçando pássaros para coletar penas.
- **Exemplos de Upgrades Intuitivos**:
  - **Óculos de Aviador**: melhora a precisão e chance de captura aérea.
  - **Asas Enfaixadas / Aerodinâmicas**: aumenta a velocidade de voo e reduz o tempo entre caçadas.
  - **Garras Afiadas / Luvas de Rapina**: permite capturar múltiplos pássaros num único rasante.

### 🎓 Universidade (Troodonte → 🧪 Ciência)
- **Conceito**: O Troodonte (dinossauro mais inteligente) frequenta salas de aula e laboratórios na Universidade para estudar e gerar pontos de Ciência.
- **Exemplos de Upgrades Intuitivos**:
  - **Óculos de Grau / Lupa**: aumenta a leitura e o ganho base de Ciência por estudo.
  - **Mochila de Livros & Enciclopédias**: multiplica o conhecimento acumulado por ciclo.
  - **Jaleco de Cientista / Quadro-Negro / Telescópio**: desbloqueia descobertas críticas e novas fórmulas para reviver espécies.

---

## 3. Progressão, Balanceamento e Ressurreição de Novos Dinossauros

Com uma curva de balanceamento progressivo (usando os recursos gerados + Ciência da Universidade), o jogador pode **reviver novos dinossauros** para atuar nas funções existentes ou expandir cada cadeia produtiva:

1. **Escalonamento na Mesma Função (Mais produção do recurso base)**:
   - Reviver mais unidades da mesma espécie ou espécies maiores da mesma linha (ex.: *Espinossauro* auxiliando o *Bariônix* na pesca; *Anquilossauro* auxiliando o *Paquicefalossauro* na montanha; *Quetzalcoatlus* auxiliando nos céus).
2. **Geração de Recursos Novos Relacionados (Sub-recursos / Tier 2)**:
   - Novos dinossauros revividos para aquela estrutura podem produzir **recursos secundários derivados** daquela atividade:
     - **Na Montanha**: além de `🪨 Pedra`, extrair **💎 Cristais / Minério Bruto**.
     - **No Lago**: além de `🐟 Peixe`, coletar **🦪 Pérolas / Escamas Raras / Algas**.
     - **No Céu**: além de `🪶 Pena`, coletar **🥚 Ovos Raros / Plumas Douradas**.
     - **Na Universidade**: além de `🧪 Ciência`, sintetizar **🧬 DNA Puro / Projetos de Engenharia**.
3. **Fórmula de Balanceamento Sugerida (Referência Futura)**:
   - Custo de reviver/clonar escalando exponencialmente por espécie e unidade:
     $$\text{Custo}(n) = \text{CustoBase} \times \text{Crescimento}^{n}$$
   - Produção da estrutura combinando a quantidade de dinos ativos, o bônus dos equipamentos (capacetes, nadadeiras, etc.) e sinergias da Universidade:
     $$\text{Produção/s} = (\text{DinosAtivos} \times \text{TaxaBase}) \times (1 + \text{BônusEquipamento}) \times (1 + \text{MultiplicadorCiência})$$

---

*Adicione novas seções abaixo conforme surgirem novas ideias de mecânicas, dinossauros, eventos ou estruturas.*
