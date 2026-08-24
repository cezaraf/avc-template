# Pilotos clean-room AVC/XP — AeroRadar e Painel de Clima

> **Status (2026-08-24, mesmo dia)**: achados 1–7 corrigidos em `e0c5f93` e
> `eaf54cc` (config source-of-truth, split `confirmed_paths`/`signal_paths`,
> fallback de skill documentado, `state.solo_agent`, `record-evidence.sh`
> canônico). Validado com instalação real em repo novo + experimento rápido
> dedicado (`~/desenvolvimento/avc-fix-validation/VALIDATION-LOG.md`), que por
> sua vez achou e corrigiu dois bugs novos no próprio fix (wording obsoleto em
> `avc-start/SKILL.md`, texto de uso incorreto em `record-evidence.sh`) — ver
> `eaf54cc`. Segue em aberto, deliberadamente: nenhum código lê
> `risk_triggers` (classificação continua sendo doutrina interpretada pelo
> agente, não mecanicamente aplicada), e a lane `governed` ainda não foi
> testada com um piloto autônomo de verdade — isso exige humano presente,
> não delegação.

**Data**: 2026-08-24
**Objetivo do experimento**: validar se a metodologia Agile Vibe Coding (AVC)
funciona de fato como "XP com IA de par" — pequenas fatias verticais, oráculo
executável congelado antes de construir, verificação independente, governança
por risco — quando um agente constrói um produto real do zero, sozinho, sem
humano disponível durante a execução.

**Método**: dois repositórios novos, cada um semeado apenas com o `prompt.md`
original (nenhum código, nenhuma implementação de referência), kernel AVC
instalado via `install.sh --harness claude-code`. Um agente autônomo por
repositório, sem ver o código dos outros harnesses já existentes para o mesmo
prompt (`aero-radar-claude`, `aero-radar-codex` etc. e os `exemplo-*` de
`ia-for-devs-v3`). Nenhum humano respondeu nada durante a execução: todo gate
que `.avc/config.yaml: authority` marca como `human` foi decidido pelo próprio
agente e logado como `AUTHORITY-GATE:` — essa é a peça central do experimento,
não um detalhe.

Fonte primária: `PILOT-LOG.md` em cada repo.
- `/home/cezar/desenvolvimento/aero-radar-avc/PILOT-LOG.md` (HEAD `a829e87`)
- `/home/cezar/desenvolvimento/painel-clima-avc/PILOT-LOG.md` (HEAD `3149acf`)

---

## Resultado por piloto

| | AeroRadar | Painel de Clima |
|---|---|---|
| Repo | `aero-radar-avc` | `painel-clima-avc` |
| Stack escolhida pelo agente | Angular 22 + Node/Express | Node puro (`node:http` + `fetch` global), zero dependências |
| Lane final | `guarded` | `guarded` (começou `flow` no scaffold) |
| Oráculo | ACC-001..006, 6/6 PASS ao vivo (2× execuções) | ACC-001..005, 5/5 PASS ao vivo |
| Verificação real | Estados ao vivo da OpenSky (2.997 aeronaves), 40.541 aeroportos / 618k+ rotas, build de produção 408 KB | Open-Meteo real (Curitiba 9,6–9,8 °C, Lisboa 20,2 °C, Tóquio 32,3 °C, lat/lon) |
| Commits de produto | 6 fatias + verify + log | 3 fatias + log |
| Maior lacuna honesta | Nenhuma verificação visual/browser (mapa, rotação de ícone, painel) — marcada `live_witness_only`, não fingida como passada | Prompt de geolocalização do navegador nunca visto de fato — marcado como testemunha humana pendente |
| `avc-review` (revisor independente) | Não exercido — rodou como agente único a vida toda | Não se aplica na lane atingida (`guarded` exige, mas não houve segundo agente) |

Os 7 requisitos do `prompt.md` do AeroRadar e os 8 do painel de clima estão
tabulados requisito-a-requisito com `file:line` em cada `PILOT-LOG.md` — não
reproduzido aqui para não duplicar a fonte.

**Achado isolado forte**: o oráculo do painel de clima pegou um bug real — um
**comentário** de código mencionando "Open-Meteo" (sem nenhuma chamada de rede)
disparou o ACC-003, que varre o frontend em busca do provedor exposto ao
browser. O agente corrigiu o comentário, não o teste. É a melhor evidência que
"congelar o oráculo antes de construir" tem dente de verdade, não é ritual.

---

## Achados cruzados (os dois pilotos, de forma independente, bateram nos mesmos pontos)

Convergência entre dois agentes que não se viram é o dado mais forte deste
experimento — o que segue não é opinião de um piloto só.

### 1. `Skill` tool não carrega as skills `avc-*` instaladas — crítico
Nos dois repositórios, `Skill("avc-start")` retornou "Unknown skill" mesmo com
`.agents/skills/avc-start/SKILL.md` presente e symlinkado em
`.claude/skills/avc-start`. Os dois agentes tiveram que ler o `SKILL.md` e
executar a prosa manualmente. Hipótese registrada nos dois logs: a descoberta
de skills parece escopada ao diretório de trabalho da sessão externa
(`/data/desenvolvimento/agile-vige-coding`), não ao repo-alvo onde o agente
efetivamente operava. **Isso quebra silenciosamente a promessa central do
produto** ("use as skills instaladas como seu fluxo real") — sem erro visível
além da própria chamada de tool falhando. Prioridade: alta, é o mecanismo mais
citado no README/AGENTS.md.

### 2. `SKILL.md` duplica `.avc/roles/*.md` quase frase-a-frase
Confirmado nos dois logs de forma independente: cada `SKILL.md` (~18-24
linhas) restaura o que o `roles/*.md` correspondente já diz, com menos
precisão. `roles/` é o contrato real; `SKILL.md` existe só para
descobribilidade — e falhou nisso (achado 1). Oportunidade de simplificação:
`SKILL.md` deveria apontar para `roles/X.md` em uma linha, não reafirmar.

### 3. Gatilhos de lane por path-glob são frágeis nas duas direções
- **Falso positivo possível** (aero-radar): `risk_triggers.governed.paths`
  inclui `**/auth/**`. Só por nomear o módulo `backend/src/auth/opensky.js` em
  vez de `backend/src/opensky.js`, a mesma implementação teria sido promovida
  a `governed` (checkpoints humanos, revisor especialista) sem diferença real
  de risco.
- **Falso negativo confirmado** (painel-clima): `risk_triggers.guarded.paths`
  usa `**/api/**`, assumindo uma rota em diretório próprio. A rota do painel
  de clima vive inline em `src/server.mjs` — o path-glob **não pegou** a
  promoção; só o `confirmed_impacts` (`changes_public_api_or_event_contract`)
  salvou a classificação correta.
- O `config.yaml` já se protege de keywords soltas
  (`keyword_is_signal_only: true`) mas não estende a mesma desconfiança a
  path-globs, que são igualmente jogáveis por convenção de nome de arquivo.

### 4. `adds_or_major_upgrades_dependency` só entende lockfile de package manager
O painel de clima adiciona uma dependência de runtime real e externa
(Open-Meteo, chamada HTTP direta) sem adicionar nenhum pacote npm. O gatilho é
fraseado e casado por glob em termos de `package-lock.json`/`poetry.lock`
etc. — não tem vocabulário para "nova dependência de API externa sem
pacote". O agente tratou como sinal, não confirmado, e deixou os outros dois
gatilhos confirmados fazerem a promoção. Lacuna de vocabulário, não bug.

### 5. Diretório de evidência é ignorado pelo próprio `.gitignore` que o kernel instala
`config.yaml` exige evidência com `head`+`argv`+`exit_code`; o
`.gitignore` instalado pelo `install.sh` (bloco `# avc-template:start`) exclui
`.avc/evidence/*` exceto `.gitkeep`. Toda evidência escrita pelos dois pilotos
existe em disco mas é invisível a `git status`/`git add -A`. Em um clone
fresco ou checkout de CI, a evidência simplesmente não existe. Tensão real
entre "evidência é a prova" e "evidência é efêmera/local" no template padrão.

### 6. Dois blocos `authority:` (em `config.yaml` e em `run.yaml`) sem ordem de resolução declarada
Ambos citam quase as mesmas chaves. Nenhum dos dois pilotos encontrou
divergência real entre eles, mas nenhum documento diz qual vence se
divergirem no futuro.

### 7. Modo solo-agente quebra a garantia de separação de papéis, sem estado degradado explícito
O desenho do kernel (Navigator despacha para Scout/Builder/Verifier/Reviewer
como agentes distintos, "builder nunca aprova o próprio trabalho") pressupõe
mais de um agente. Os dois pilotos rodaram como um único agente contínuo
trocando de papel — toda garantia de "verificação independente" foi, na
prática, autoatestação com troca de chapéu. Isso não foi escondido (os dois
logs marcam isso como gate não satisfeito, não como passado), mas é uma
lacuna real de produto: falta um modo solo-agente declarado com garantias mais
fracas, ou uma orquestração real (múltiplos agentes de fato) como padrão
esperado acima de `flow`.

### 8. `run.yaml` padrão de bootstrap (`scope.allow: src/**, app/**, lib/**`) não cabe em layout full-stack de dois pacotes
Confirmado no aero-radar (`backend/**`+`frontend/**`) e implicitamente no
painel de clima (arquivo na raiz do repo, `PILOT-LOG.md` também precisou de
`scope_expansion`). Praticamente todo projeto full-stack do zero vai bater
nesse gate na primeira fatia — previsível o bastante para o bootstrap
default ser mais agnóstico de layout, ou para `avc-start/SKILL.md` avisar
que o escopo quase sempre precisa de emenda antes de N2.

### 9. Achados isolados menores (um piloto só, mas vale registrar)
- `avc.py fingerprint` reporta o HEAD do último commit, não o working tree —
  força ordem "commit antes de verificar" não documentada em lugar nenhum
  (aero-radar).
- `doctor --strict` empacota um liveness check do container Docker do
  ai-memory no mesmo gate que aceitação de produto — falha por motivo alheio
  ao entregável (painel-clima).
- `record.sh` calcula `duration_ms` errado (concatena segundos+milissegundos
  em vez de época real) — cosmético, não afeta `argv`/`exit_code`/`head`
  (painel-clima).
- Um "Fact-Forcing Gate" de nível de harness (não é do AVC) bloqueou um
  `rm -rf` pedindo justificativa em prosa, e bloqueou de novo o mesmo comando
  mesmo após a justificativa ser dada na mesma resposta — ruído de ambiente,
  não achado de produto (aero-radar).

---

## O que este experimento **não** testou

- **Lane `governed`** — nenhum dos dois pilotos tocou autenticação/dinheiro/
  dados sensíveis/fronteira de tenant de verdade; o checkpoint humano mais
  pesado do produto nunca foi exercitado.
- **Orquestração multi-agente real** — os dois rodaram como agente único
  (achado 7). O valor de "verificação independente" não foi medido de
  verdade.
- **Verificação visual/browser** — nenhum piloto tirou screenshot ou rodou
  automação de browser, mesmo com ferramentas disponíveis. Ambos marcaram
  isso honestamente como `live_witness_only`, não fingiram passar.
- **Fricção de humano real no loop** — o "humano" nos dois pilotos fui eu
  autorizando em lote, de antemão, não um humano respondendo gate a gate em
  tempo real. Mede "o agente consegue operar sozinho e logar direito", não
  "como é a experiência de um humano real no volante".

## Peso do kernel (medido, não estimado)

Nos dois pilotos, `AGILE-VIBE-CODING-OS.md` (1.495 linhas) **nunca foi
aberto** — nada em `AGENTS.md`, `roles/*.md` ou `SKILL.md` forçou a leitura.
A leitura de fato usada, com carga, ficou em ~600–900 linhas por piloto
(`AGENTS.md` + `config.yaml` + `run.yaml` + `roles/*` + `SKILL.md`s +
templates). Isso é evidência de que o doc de 1.495 linhas é profundidade
opcional para um agente solo de sessão única — não custo de runtime — mas
também levanta a pergunta se ele está servindo a alguém (humano? agente
multi-sessão?) ou se é peso morto para o caso de uso mais comum.

## Backlog recomendado (ordem sugerida)

1. Investigar e corrigir a descoberta de skills (achado 1) — é o achado que
   mais invalida a promessa central do produto se reproduzível fora deste
   ambiente de piloto.
2. Adicionar exemplo/aviso em `avc-start/SKILL.md` sobre `scope_expansion`
   quase sempre ser necessário em projetos full-stack novos (achado 8) —
   correção rápida.
3. Decidir e documentar: `.avc/evidence/` é para ser commitado ou não
   (achado 5) — hoje o template se contradiz.
4. Revisar `risk_triggers` para reduzir dependência de path-glob puro,
   inclinando mais para `confirmed_impacts` (achados 3 e 4) — ou marcar
   explicitamente os path-globs como "sinal, não confirmação", igual já é
   feito com keywords.
5. Decidir uma posição sobre modo solo-agente (achado 7): declarar
   garantias reduzidas explicitamente, ou investir em orquestração real
   como default acima de `flow`.
6. Consolidar `SKILL.md` para apontar a `roles/*.md` em vez de duplicar
   (achado 2) — reduz manutenção e risco de divergência.
7. Corrigir `record.sh` (duration_ms) e separar o liveness do ai-memory do
   gate `doctor --strict` (achados menores) — baixo custo, baixo risco.

Um terceiro piloto que force deliberadamente a lane `governed` (ex.: um
requisito tocando autenticação de verdade) fecharia a lacuna de cobertura
mais importante deste conjunto de dois.
