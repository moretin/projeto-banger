# Fóssil Rush — A Arca dos Vivos

**Proposta final (V2) para implementação.** O escopo imediato é o **Protótipo 1 na Bacia do Âmbar**, da abertura ao retorno após o primeiro impacto. A proposta incorpora o veredito do Antigravity e do Pedro, preservado no fim deste arquivo. A base técnica analisada é a `main` no commit `b87d951`.

## Visão do jogo

**Você é o primeiro dinossauro que voltou à vida. Seu bando ainda está enterrado. Encontre-o, faça a colônia crescer e construa uma Arca capaz de levar todos adiante.**

Fóssil Rush é um **incremental de colônia e campanha com descoberta**. As pistas dão um motivo para explorar. Os dinos tornam a colônia mais produtiva e abrem possibilidades no mapa. A Arca, visível junto ao Ovo de Âmbar, mostra o que a campanha acumulou. O meteoro fecha uma expedição a cada **20 minutos de jogo ativo** e dá uma oportunidade de ganhar Âmbar e preparar o próximo ciclo.

O resgate é uma conquista permanente a partir do momento em que o dino acorda. O embarque acontece automaticamente, com espaço para representá-lo visualmente. As alas da Arca liberam funções e projetos. Perto do impacto, o jogador escolhe qual **ganho extra** vale perseguir. A frase que queremos ouvir é “o Anquilossauro já está com a gente. Qual ala dá pra terminar antes do impacto?”.

**Ciclo da campanha** · Seguir uma pista → revelar um fóssil → reviver um dino → ver sua habilidade mudar a colônia → investir na Arca → voltar do impacto com um próximo objetivo.

## Protótipo 1 — O Anquilossauro da Pedreira

O protótipo entrega **uma pista, uma extração, um resgate, uma decisão opcional no fim do ciclo e um retorno com consequência visível**. O primeiro resgate deve acontecer nos minutos iniciais. O relógio de produção continua em 20 minutos, com avanço rápido disponível em teste interno para validar a transição.

| Momento | O que colocar na build | O que observar |
| --- | --- | --- |
| **1. Abrir o ovo** | O Compsognato nasce e pia. A Pedreira do Casco responde com uma batida e uma trinca ou nuvem de poeira. Junto ao ovo, a base da Arca mostra espaço para o primeiro módulo. | A pessoa segue a pista e encontra a entrada sozinha? |
| **2. Extrair a placa** | Ao interagir na Pedreira, abre uma extração dedicada de **20 a 40 segundos**. Escovar revela a cauda do Anquilossauro. Acertar o Golpe Preciso acelera a retirada. É possível concluir só com a escova. A recompensa garantida é **uma placa especial**, seguida de retorno direto à superfície. | A pessoa reconhece o fóssil e consegue terminar mesmo se errar o golpe? |
| **3. Reviver e abrir o veio** | Uma bancada simples recebe a placa e desperta o Anquilossauro sem depender da Universidade. Ele gira a cauda, derruba a laje e abre um veio. A Pedreira ganha acesso à sua produção de **Metal**. O destino inicial desse recurso já existe na economia da superfície: o Bosque das Sequoias custa **15 Metal**. | A pessoa percebe tanto o efeito no cenário quanto o que o Metal permite fazer? |
| **4. Fazer um último investimento** | A Arca mostra uma obra e o que falta para concluí-la. Proposta para o primeiro ciclo: finalizar um reforço pode render Âmbar extra no impacto. O jogador também pode usar o tempo para explorar o veio ou juntar Metal para a próxima construção. Mostrar qual recompensa extra ainda pode alcançar. | A pessoa consegue dizer onde escolheu investir o tempo e por quê? |
| **5. Voltar à Bacia** | O Anquilossauro reaparece perto do ovo e volta ao trabalho. A laje segue removida, a Arca mostra o avanço realizado e a Gazeta registra o que a expedição ganhou. O primeiro minuto da volta oferece um destino claro, como levar o Metal ao Bosque. | A pessoa reconhece a consequência e tem um plano para a partida seguinte? |

A extração usa a escovação e o Golpe Preciso como referência para a interação, com recompensa e retorno conectados à Superfície. O escopo da extração é a placa especial. A economia ativa segue a dos postos, e o fluxo de camadas e moedas do `DigSite` legado fica fora desta entrega. Reutilizar o cenário da Pedreira, os sprites e as animações existentes sempre que funcionarem para a cena. [Pedreira e Bosque](../autoload/GameState.gd), [referência de escovação e Golpe Preciso](../scenes/dig_site/DigSite.gd)

### O que atravessa o impacto

| Progresso | Regra de design |
| --- | --- |
| **Companheiro revivido** | Entra na campanha no despertar. A aparição e a contribuição na estação voltam a partir desse registro, inclusive ao carregar o save. |
| **Mudança no mapa** | O primeiro resgate conserva a passagem aberta. A mesma conquista que registra o resgate alimenta a representação visual antes e depois do impacto. |
| **Arca e pesquisa permanente** | Módulos concluídos e Âmbar ganho ficam na campanha. O avanço da Arca aparece no cenário. O escudo favorece a recompensa de prestígio. |
| **Descobertas na Universidade** | Na etapa do segundo fóssil, preservar os fragmentos obtidos, os fósseis na fila e o progresso de limpeza. Um jogador que chegou a `2/3` retoma dali. |

Hoje, o reset de prestígio limpa os especialistas ativos, a fila e os fragmentos. A coleção de espécies descobertas representa histórico e, sozinha, não prova um resgate. Ao definir o estado permanente, usar o registro de espécies efetivamente revividas e aproveitar o estado já salvo quando ele representa esse fato. Qualquer mudança na estrutura do save deve ser versionada e migrada no `SaveManager`. A Gazeta atual fala em porcentagem de espécimes preservados. Na V2, ela celebra o bando, a mudança no campo e o Âmbar ganho. [Reset e dados de save](../autoload/GameState.gd), [migrações](../autoload/SaveManager.gd), [Gazeta do impacto](../scenes/meteor/MeteorOverlay.gd)

### Arca física e condição de vitória

No protótipo, a Arca precisa dar para encontrar junto ao ovo e mostrar **o que está pronto, o que falta para o próximo módulo e qual bônus está em jogo no impacto**. Uma plataforma, um módulo inicial e uma mudança visual bastam para validar essa leitura.

A progressão final pode aproveitar `GameState.get_ark_progress()` e ligar a conclusão a uma ação jogável de lançamento por `GameState.activate_ark_victory()`. Hoje, os cinco níveis iniciais do Projeto Arca somam **3.720 Âmbar**, além dos requisitos de escudo e profundidade ou revives da condição atual. Revisar essa curva na etapa de campanha antes de adotá-la como caminho principal. O alvo de design é o jogador conseguir olhar para a Arca e dizer “a estrutura está pronta, falta o isolamento da Cordilheira”. [Condição de vitória](../autoload/GameState.gd), [custos do Projeto Arca](../data/upgrades/amber/amber_ark_project.tres)

## Workflow até o jogo final

| Etapa | Entrega | Critério de avanço |
| --- | --- | --- |
| **1. Primeiro resgate** | Colocar na Bacia a sequência do ovo à pista, extração, despertar e abertura da laje. Dar um destino visível ao Metal. | As pessoas encontram a jazida e explicam o que o Anquilossauro fez sem ajuda de quem testa. |
| **2. Primeiro impacto e retorno** | Arca física, um reforço opcional, resumo do impacto e retorno com companheiro e passagem visíveis. Verificar save e recarga dos dois lados do prestígio. | O jogador entende o ganho extra e consegue apontar uma mudança permanente e seu próximo destino. |
| **3. Segundo fóssil e Universidade** | Levar os demais resgates pela Universidade. Testar uma pista dirigida para o primeiro fragmento da segunda espécie, contador legível e curva inicial de fragmentos como **3 → 5 → 8 → 10**. | Medir tempo até a pista, o primeiro fragmento limpo e o resgate. A segunda descoberta ganha um objetivo que o jogador consegue perseguir entre impactos. |
| **4. Biomas e equipamentos** | Usar os mapas, estruturas e recursos atuais da Floresta e da Cordilheira em projetos da Arca. Testar também um equipamento que mude o comportamento de um trabalhador. | O jogador visita cada região por algo que consegue nomear e percebe qual trabalho a automação assumiu. |
| **5. Campanha e lançamento** | Montar os atos de primeiro resgate, expedições do bando e lançamento. O epílogo mostra as espécies resgatadas ocupando um novo vale. | Uma pessoa chega ao lançamento a partir de um save limpo pelo percurso normal e entende o resultado da sua campanha. |
| **6. Beta e acabamento** | Ajustar o ritmo, os custos, a leitura das pistas, som, controles e saves a partir dos playtests. | Os testes técnicos passam e os trechos que travavam ou faziam o jogador só esperar melhoram em novas sessões. |

Para a Floresta e a Cordilheira, começar pelas relações que já existem. **Bacia** pode fornecer a estrutura e o Metal. **Floresta** pode contribuir com madeira e resina. **Cordilheira** pode fornecer cristais para o isolamento ou para um módulo de operação em condições extremas. Materiais e custos entram como hipóteses de balanceamento após o primeiro playtest. A ideia para upgrades importantes é produzir uma ação visível. Por exemplo, o carrinho permite que o Paquicefalossauro descarregue os blocos sozinho e libera o Compsognato para investigar outra pista.

## Encaminhamento de implementação para o Antigravity

**Implementar primeiro as etapas 1 e 2, como uma única build jogável.** Usar a Bacia atual e os sistemas de superfície como referência. O ponto de encontro das duas frentes é o registro do resgate permanente, lido pela Arca e pela Pedreira quando o mapa é carregado.

- **Frente A — Pista, extração e resgate.** Ligar o Ovo à pista da Pedreira, encaixar a extração curta, conceder a placa especial uma vez e representar o despertar, a laje removida e o acesso ao Metal.
- **Frente B — Arca, impacto e consequência.** Fazer a Arca aparecer junto ao ovo, mostrar o reforço opcional, preservar o resgate no prestígio, restaurar a presença do Anquilossauro e atualizar a Gazeta.
- **Integração com o Gabriel.** Antes de mexer no tremor ou em `scenes/main/Main.gd` para o impacto, alinhar a integração de `origin/fix/meteor-tremor-polish-20261120` com o Gabriel, conforme o veredito. O resgate, a Arca e a restauração da passagem podem ser trabalhados em paralelo com esse alinhamento.
- **Validação técnica.** Demonstrar o fluxo completo num save novo, conferir migração com save existente e recarregar antes e depois do impacto. Conferir que o dino, a placa especial e as recompensas não duplicam ao recarregar. Rodar a [suíte oficial do Godot 4.7+](../tools/run_tests.ps1) conforme o `AGENTS.md`.
- **Playtest.** Observar cinco pessoas sem instruções de quem testa e usar pelo menos uma sessão com o ciclo real de 20 minutos. Registrar quando encontram a pista, o que entendem do Anquilossauro, o que fazem entre o resgate e o impacto e qual é o plano ao retornar. Se houver espera demais entre o resgate e o impacto, ajustar o que a produção libera antes de ampliar o mapa.

**A build está pronta para a primeira rodada quando o jogador volta do impacto, reconhece o Anquilossauro e a Pedreira que ele mudou, e encontra uma razão concreta para seguir em direção à Floresta.**

---

## Revisão e Veredito Técnico/Design (Antigravity + Pedro)

> **Diretriz fechada pelo Pedro (`moretin`) para a V2 desta proposta:**
> O conceito central da **Arca dos Vivos** faz muito sentido para dar propósito emocional e campanha ao jogo, **porém o jogo continuará sendo um incremental de colônia/campanha com descoberta — NÃO um roguelike punitivo**. O meteoro funciona como **pressionador positivo e ritmo de prestígio** (ciclo de 20 minutos em `b87d951`), nunca como punição que faz o jogador perder um dinossauro que deu trabalho para reviver.

### Veredito ponto a ponto

| # | Ponto da proposta original | Veredito | Parecer técnico e de game design (para reformular a V2) |
| --- | --- | --- | --- |
| **1** | **Premissa narrativa da "Arca dos Vivos"** (você é o primeiro dino vivo e precisa reunir seu bando e construir a Arca) | **APROVADO** | Excelente gancho emocional. Conecta o Ovo de Âmbar inicial, a busca por fósseis, a evolução da base e a ameaça do meteoro num objetivo único e memorável. |
| **2** | **Arca visível no mapa junto ao Ovo ligada à condição de vitória** | **APROVADO** | Fecha uma ponta solta real do código: `GameState.get_ark_progress()`, `GameState.activate_ark_victory()` (`autoload/GameState.gd`) e o feedback em `scenes/ui/HUD.gd` já existem, mas hoje não há Arca física na Superfície nem ação jogável. Ver a Arca evoluir junto ao Ovo dá meta visual desde o minuto 1. |
| **3** | **Sinal imediato na abertura** (ao nascer do ovo, o Compsognato ouve batida / vê trinca na Pedreira) | **APROVADO** | Guia orgânico perfeito para substituir tutorial seco e puxar o jogador imediatamente para a primeira ação relevante. |
| **4** | **Primeiro fóssil garantido na Pedreira e limpeza em bancada simples vs. Universidade atual** | **AJUSTAR** | Hoje `BASE_RAW_FOSSIL_CHANCE = 0.001`, a Universidade custa `1100` rochas e reviver exige `10` fragmentos × `40s`. Um jogador novo demora demais para ver um fóssil por sorte. **Como conciliar na V2:** o **Anquilossauro da Pedreira** vira o **1º resgate guiado** (1 placa especial garantida nos primeiros minutos, acordada sem precisar esperar a Universidade completa); os outros **7 dinossauros** continuam usando a Universidade e fragmentos, preferencialmente com curva escalonada (ex.: `3 → 5 → 8 → 10` em vez de `10` fixo em todos) para manter impacto sem exagero inicial. |
| **5** | **Reuso da cena de escavação (`scenes/dig_site/DigSite.gd`) + Golpe Preciso para a jazida da Pedreira** | **AJUSTAR (CRÍTICO TÉCNICO)** | Em `b87d951`, a economia foi consolidada na Superfície: `ossos`, `minérios`, `DNA` e upgrades de `click_damage` / `dino_damage` já foram aposentados e removidos do HUD e das compras. **Não** reabrir o `DigSite` antigo soltando moedas legadas desconectadas. Se a jazida da Pedreira abrir uma cena dedicada, ela deve ser um **minigame curto de extração (20–40s)** só com escova + Golpe Preciso para soltar a placa do fóssil/veio da superfície e retornar direto à Superfície. |
| **6** | **Habilidade física do dino mudando o mapa** (Anquilossauro derruba laje/escombro e libera passagem antes de ajudar na Pedreira) | **APROVADO** | Casa perfeitamente com o objetivo de tornar cada resgate um grande marco — além do multiplicador `×2.5` e do recurso Tier-2 (`Metal`), o dino transforma fisicamente o cenário. |
| **7** | **Ciclo de 8–12 min, vagas limitadas excludentes na Arca e chance de perder/deixar dino para trás no impacto** | **NÃO SEGUIR (DECISÃO FECHADA)** | Transformaria o jogo em um roguelike punitivo e contradiz o ciclo atual de **20 minutos (`1200s`)** definido para dar ritmo confortável de construção. **Como reformular na V2:** **1)** todo dinossauro revivido e embarcado na Arca fica **salvo permanentemente** entre runs (zero perda punitiva); **2)** não forçar escolha excludente que faça "perder" outro companheiro — a Arca pode expandir em **alas/módulos** conforme os biomas progridem; **3)** o dilema pré-impacto antes do meteoro passa a ser **ganho extra opcional** (*"consigo concluir mais uma asa da Arca, embarcar o próximo dino ou buscar um ovo/bônus de Âmbar antes da queda?"*). |
| **8** | **Consequência visível pós-impacto e registro curto na Gazeta** | **AJUSTAR** | Manter a consequência **positiva e física** na abertura da run seguinte (o Anquilossauro salvo já reaparece perto do Ovo e o atalho/escombro removido continua visível/desbloqueado) e o registro curto no resumo de impacto/Gazeta. Remover o ramo punitivo ("se ficar para trás, cratera para reencontrá-lo"). |
| **9** | **Equipamentos e upgrades mudando comportamento visível na base** (ex.: carrinho do Paquicefalossauro libera o Compsognato) | **APROVADO** | Alinha 100% com o `IDEIAS.md` (capacetes, nadadeiras, óculos, mochilas) e resolve upgrades genéricos só de porcentagem. Usar como padrão de evolução dos upgrades-chave da colônia sem criar sistemas paralelos. |
| **10** | **Mecânicas artesanais exclusivas para Floresta/Neve, campanha em 3 atos e epílogo completo** | **ADIAR PARA DEPOIS DO PROTÓTIPO 1** | A `main` (`b87d951`) já possui **Floresta Ancestral** e **Cordilheira Nevada** integradas com travessia lateral, 4 estruturas, 5 recursos novos e 16 upgrades. A V2 **não deve descartar nem substituir** esse mapa já construído por mecânicas complexas (rio que baixa, escuta sob gelo) agora; primeiro validar a fatia vertical da Bacia do Âmbar, e depois conectar Floresta/Neve ao avanço da Arca (ex.: o Anquilossauro libera/acelera a travessia segura ou novos módulos da Arca exigem os recursos dos 3 biomas). |
| **11** | **Workflow por fatias e divisão em 2 frentes entre Pedro & Gabriel** | **APROVADO (COM NOTA DE GIT)** | Dividir entre **Frente A (`pista → jazida → resgate`)** e **Frente B (`Arca física → impacto → consequência`)** é enxuto e seguro. Antes de editar tremor/impacto em `scenes/main/Main.gd`, integrar a branch ativa do Gabriel (`origin/fix/meteor-tremor-polish-20261120`) na `main` para evitar conflitos. |

### Resumo direto para a V2 da proposta

- **Manter:** fantasia da Arca dos Vivos; Arca visível junto ao Ovo ligada a `activate_ark_victory()`; pista inicial na Pedreira; 1º resgate guiado do Anquilossauro; mudança física no cenário; consequência positiva visível após o impacto; upgrades visuais/comportamentais (`IDEIAS.md`); escopo enxuto do Protótipo 1 focado na Bacia do Âmbar.
- **Mudar:** ciclo punitivo de 8–12 min → ritmo confortável de **20 min** com decisão de **risco/recompensa positivo**; vagas que sacrificam dinos → **progresso permanente na Arca com expansão por alas**; `DigSite` antigo → **minigame curto de extração** sem ressuscitar `ossos`/`minérios`/`DNA`; exigência única de 10 fósseis na Universidade → **1º resgate guiado (1 placa)** + Universidade escalonada nos demais 7 dinos; respeitar e integrar os biomas atuais (Floresta Ancestral e Cordilheira Nevada).
- **Cortar (por ora):** perda de dinossauros no meteoro, escolhas que punem o jogador por explorar, moedas legadas do `DigSite` e mecânicas exclusivas pesadas de Floresta/Neve antes do playtest do Protótipo 1.
