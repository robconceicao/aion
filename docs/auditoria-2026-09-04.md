# Auditoria Aion — 2026-09-04

Auditoria completa do Aion (Flutter + FastAPI + Supabase), com correções aplicadas e build de APK release.

**Autoria:** Roberto Tadeu da Conceição, com Claude Opus 5 (Claude Code).

---

## Sumário executivo

| | |
|---|---|
| Achados | **2 P0**, **14 P1**, **11 P2** |
| Corrigidos e no ar | 2 P0 + 12 P1 |
| Pendentes | 1 P1 por decisão de produto, 1 P1 adiado, 10 P2 |
| Testes | **73 → 131** passando |
| `dart analyze` | 0 erros, 0 warnings (125 infos, todos `withOpacity`) |
| APK release | **1.0.4+5 gerado e verificado** — §7 |

*Atualizado em 05/09/2026, após as correções entrarem em produção. Dois achados novos surgiram durante o próprio trabalho de correção e estão marcados como tal.*

O achado de maior impacto não estava na lista de suspeitas: `GET /episodes/` devolvia **500 em produção** havia semanas, e o CI estava verde o tempo todo.

O segundo: **todo APK publicado pelo CI travava na abertura**. O build passava, o artefato era publicado, e o app morria no lançamento. Foi o *sucesso* do build que escondeu o problema.

E o terceiro só apareceu ao cruzar o dump real do RLS com o código: **as rotas de escrita de `episodes` gravavam pelo cliente anon**, que o RLS nega. Os dois primeiros se escondiam um atrás do outro — enquanto o `GET` dava 500, ninguém chegava a descobrir que o `POST` também não funcionava. Isso corrige uma conclusão errada que este relatório trazia na versão anterior: a tabela vazia não era falta de conteúdo, era impossibilidade de cadastrar.

Duas das premissas do escopo original não se confirmaram (§2.1).

---

## 1. Escopo e método

Auditoria em 6 etapas: mapeamento → CI/imports → autenticação (TD-01) → varredura de bugs → conferência das melhorias → correções → build.

**Método de verificação.** Nenhum achado desta auditoria foi reportado por leitura de código isolada. Cada um foi confirmado por execução: sondagem contra produção, reprodução local do erro, ou teste automatizado. Onde houve correção, os testes foram validados **por mutação** — o teste tinha de reprovar o código sem a correção, não apenas passar com ela. Testes que só passam não provam nada sobre o que protegem.

**Uma correção de percurso, registrada.** No meio da Etapa 3 reportei como P0 que o projeto Supabase estava fora do ar, baseado em falha de DNS. Estava errado: a falha era transitória na máquina de auditoria. O projeto sempre esteve no ar. A hipótese foi retirada e a investigação seguiu até a causa real (o `TypeError` do postgrest). Fica o registro porque o relatório deve refletir o que aconteceu, não uma versão limpa.

### 1.1 Ambiente auditado

| | |
|---|---|
| Flutter | 3.41.7 (stable) · Dart 3.11.5 |
| Python | 3.12.9 local · **3.11 no CI** |
| App | `version: 1.0.3+4` |
| Backend | https://aion-vvx7.onrender.com (Render free tier) |
| Deps chave | fastapi 0.104.1 · pydantic 2.5.2 · httpx 0.28.1 · supabase 2.16.0 · postgrest 1.1.1 · anthropic 0.104.1 |

### 1.2 Estado do repositório no início

O repositório local estava **16 commits atrás** do `origin/main` e com 10 arquivos modificados não commitados que não existiam em nenhuma branch. Os 16 commits ausentes introduziam um sistema inteiro de licenciamento (Tadeu Apps).

Auditar a árvore local teria produzido um relatório sobre código obsoleto e um APK sem o gate de licenciamento. O trabalho local foi preservado, rebaseado sobre `main` e submetido no PR #4; a auditoria seguiu sobre `main`.

**O APK instalado no aparelho de QA (05/08) foi construído do estado local**, não de `main` — ele não contém licenciamento. Isso importa para interpretar qualquer teste feito nele.

---

## 2. Achados por severidade

### 2.1 Premissas do escopo que não se confirmaram

Registradas porque descartar uma hipótese com evidência tem valor próprio.

**"CI falhando: 4 arquivos não coletados por ImportError."** Não havia falha. Os 8 runs anteriores do workflow estavam `success`, e a suíte passava localmente nos dois modos de invocação. Os três itens específicos:

- `get_supabase_service` **existe** em `backend/app/database.py:32` e é importado sem erro por 5 routers.
- `httpx.HTTPStatusError` — **zero ocorrências** no código.
- `jose.JWTError` — resolve normalmente; `test_jwt_verify.py` passa.

A intuição por trás da suspeita — *"mudança de versão de dependência quebrou um dependente"* — estava **certa**, mas no arquivo errado: era o `postgrest`, e não erro de import, e sim de execução (§2.2, P0-1).

**"Loop agêntico de tool-calling degradando em provider de fallback."** Não existe tool-calling no projeto. `grep` por `tools=`, `tool_use`, `tool_calls`, `function_call` no backend: zero ocorrências. A cascata faz uma chamada única por provider. O problema real de degradação era outro (P1-3).

**"Cascata Claude → Gemini → DeepSeek."** DeepSeek foi substituído por xAI (Grok) no commit `dbd44a8`. Só sobrevive em `.pyc` obsoletos.

### 2.2 P0

#### P0-1 · `GET /episodes/` retornava 500 em produção — **CORRIGIDO E NO AR**

`backend/app/routers/episodes.py:14` chamava `.order("number", ascending=True)`. `ascending` era o kwarg do postgrest antigo; a assinatura instalada é `order(column, *, desc=False, nullsfirst=None, foreign_table=None)`. O `TypeError` subia sem tratamento e virava 500.

`requirements.txt` pina `supabase>=2.11.0,<3` — faixa flutuante. O Render instalou uma versão que já havia removido o parâmetro.

```
antes:  500 0.955s / 500 0.317s / 500 0.283s   (3/3, falha rápida)
depois: 200 0.924s
```

Única ocorrência no repositório — `dreams.py:312` e `:433` já usavam `desc=True`. O endpoint é público e alimenta a tela do Canal Mito & Psique.

**Por que o CI não pegou:** `test_episode_model.py` valida só o modelo Pydantic. Nenhum teste exercitava a rota.

#### P0-2 · Todo APK do CI travava na abertura — **CORRIGIDO E NO AR**

`.github/workflows/build-apk.yml` rodava `flutter build apk --release` cru, sem nenhum `--dart-define`. O app lê as chaves via `String.fromEnvironment` **sem default** (`frontend/lib/src/core/supabase_config.dart:13-17`), e `frontend/lib/main.dart:20` chama `assertConfigured()` — que lança `StateError` — **antes do `runApp`**.

O build **passava**: artefato de 32 MB publicado, CI verde. O app morria no lançamento. Foi o sucesso do build que escondeu o problema.

A correção (PR #5) injeta os `--dart-define` a partir de GitHub Secrets, falha cedo com mensagem se os obrigatórios faltarem, e — o passo que mais importa — **verifica o artefato depois do build**: como `String.fromEnvironment` é dobrado em tempo de compilação, o host do Supabase tem de aparecer no binário; se não aparecer, o job falha em vez de publicar artefato quebrado.

Ela própria introduziu uma regressão, corrigida no PR #10 (P1-14) — registrada aqui porque uma correção que quebra o que conserta merece ficar visível.

### 2.3 P1

| # | Achado | Local | Status |
|---|---|---|---|
| 1 | **Modo JSON desligado no fallback.** `call_xai` decidia `response_format` por `"JSON" in system_prompt`, mas `synthesize_dual` chama com `system=""` e o prompt no user content → JSON desligado no último degrau da cascata. `call_gemini` nunca pedia JSON. | `ai_service.py:111`, `:257` | **corrigido** (PR #5) |
| 2 | **Cascata de IA sem timeout.** SDK Anthropic usa default de 600s; 3 modelos em série = até 30 min pendurado, com o cliente já tendo desistido em 180s. | `ai_service.py:56`, `:86`, `:228` | **corrigido** (PR #5) |
| 3 | **keep-alive nunca acordou o Render.** `--max-time 30` contra cold start medido em **32,5 s**, e `bash -e` abortando antes do `if`. Passava só quando o servidor já estava quente. | `keep-alive.yml` | **corrigido** (PR #5), mas ver §2.6 — o workflow ficou correto e ainda assim não resolve o problema |
| 4 | **`setState` após `await` sem guarda `mounted`** — 5 ocorrências; em duas o `setState` vem *antes* do `if (mounted)`. | `record_dream_screen.dart:73, 94, 123, 132, 157` | **corrigido** (PR #7) — eram 6, não 5 |
| 5 | **`missing_token` do cliente indistinguível do servidor** — causa do diagnóstico errado de TD-01 (§3). | `api_service.dart:112` | **corrigido** (PR #7) |
| 6 | **`ALLOWED_ORIGINS` derruba o boot.** `pydantic-settings` tenta `json.loads` no valor por ser campo `list`. Reproduzido: `ALLOWED_ORIGINS="https://a.com,https://b.com"` → `SettingsError`. Só não quebra porque a var não está setada no Render. | `config.py:6` | **corrigido** (PR #7) |
| 7 | **Tadeu com default de TESTE** em backend e app (`tadeu-apps-core-test2.vercel.app`). | `tadeu_metering.py:12`, `tadeu_license_service.dart:107` | mitigado no CI (PR #5) |
| 8 | **Licenciamento é fail-open.** `TADEU_LICENSE_ENFORCED` default `"false"`: sem `X-Tadeu-Token` o backend loga warning e libera. Burla-se omitindo o header. O commit chama-se "Enable AION licensing by default", mas o default no código é `false`. | `tadeu_metering.py:14, 22-31` | pendente — decisão de produto |
| 9 | **RLS de `dreams`/`episodes` não versionada.** Migrations cobrem só `feedback` e `narracao_cache`. As políticas existem apenas no painel. | `backend/migrations/` | **corrigido** (PR #8) — `006_rls_policies.sql` |
| 10 | **Zero jargão sem verificação determinística** (§6, item 3). | `ai_service.py:411` | **corrigido** (PR #9) |
| 11 | **Retry multiplica o custo de IA.** Se a síntese estourar os 180 s de `receiveTimeout`, o interceptor repete a request até 2×, e cada repetição dispara uma cascata de LLM completa. Uma síntese lenta vira três sínteses pagas. | `api_service.dart:206-227` | **pendente** — adiado, merece tratamento próprio |
| 12 | **Contraste abaixo do mínimo** no Interview Mode (§6, item 5). | `interview_screen.dart` | **corrigido** (PR #7) |
| 13 | **Escrita de `episodes` usava o cliente anon.** ⚠️ *Achado após a primeira versão deste relatório.* As três rotas autenticavam o admin via `Depends(get_current_admin)` e gravavam pelo client anon. As políticas de escrita são `TO authenticated` com claim de admin no JWT — o anon tem role `anon`, nenhuma política permissiva se aplica, e o RLS nega. Admin passava na API, escrita morria no banco. | `episodes.py:29, 49, 62` | **corrigido** (PR #8) |
| 14 | **Build do APK quebrava com secret contendo espaço.** ⚠️ *Regressão introduzida pela própria correção do P0-2.* Os `--dart-define` opcionais eram acumulados numa string expandida sem aspas; um valor com espaço virava vários argumentos e o Flutter falhava com `Target file "secret" not found.` — mensagem que não aponta para a causa. | `build-apk.yml` | **corrigido** (PR #10) |

### 2.4 P2

- **Vazamento de `TextEditingController`** — `auth_screen.dart:18-20` (3 controllers) e `onboarding_screen.dart:18` não têm `dispose()`.
- **Endpoints de analytics são stubs silenciosos** — `/admin/stats/geo` e `/admin/stats/daily` devolvem `[]` com HTTP 200 (`analytics.py:36, 41`), porque `analytics_events` nunca migrou do MongoDB. O dashboard mostra "sem dados" em vez de "indisponível". `/admin/dashboard` engole exceções e devolve `0` (`:20-25`), então falha de Supabase vira "0 usuários".
- **`except:` pelado** em `ai_service.py:137` — engole `KeyboardInterrupt`/`SystemExit`.
- ~~**`dist/` não está no `.gitignore`**~~ — **corrigido** (PR #11): `dist/`, `*.apk` e `*.aab` agora ignorados.
- **`_buscarSemantico` sem null-check de sessão** (`dream_history_screen.dart:71`) — único caminho da tela sem a guarda que `_loadHistory` tem.
- **I/O síncrono em handler async** — `file.file.read()` em `voice.py:51` bloqueia o event loop em uploads de até 15 MB.
- **Código morto** — `analyze_dream` e `analyze_dream_narrative`, marcados DEPRECATED desde 07/07 com "REMOVER em P2".
- **Workflow órfão duplicado** — `frontend/.github/workflows/deploy.yml` (o GitHub só lê o da raiz).
- **`datetime.utcnow()` depreciado** — `dreams.py:81`, `interpretacoes.py:228`.
- **Actions em Node 20 depreciado** — `actions/checkout@v3`, `actions/setup-python@v4`.
- **129 `withOpacity` depreciados** — único ruído do `dart analyze`.

### 2.5 Documentação desatualizada (`CLAUDE.md`)

O `CLAUDE.md` orienta o trabalho no projeto, então erros nele custam tempo real. Quatro afirmações não correspondem ao código:

| Afirma | Realidade |
|---|---|
| "MongoDB + Supabase — Dual DB" | Não há driver Mongo em `requirements.txt` nem uso no código. Só dois comentários em `analytics.py`. O projeto é Supabase-only. |
| "`SUPABASE_URL` e `anonKey` estão **hardcodadas** em `main.dart`" | Falso — `main.dart:22-23` usa `SupabaseConfig`, que lê de `--dart-define`. O próprio documento se contradiz adiante ("Não colocar a anonKey... em nenhum arquivo .dart"). |
| "`generate_embedding()` retorna `[0.0] * 768` como fallback silencioso" | Retorna `None` (`ai_service.py:30, 41, 44`) — corrigido no A-02. |
| Tabela de endpoints | Omite `/interpretacoes/*` (áudio e narração), já em produção. |

---

### 2.6 O keep-alive ficou correto — e ainda assim não resolve o problema

Registro isto porque um workflow verde passa a impressão de que a questão foi resolvida, e não foi.

A correção do P1-3 é real: o primeiro run após ela passou em **44 s**, enquanto todos os anteriores falhavam em 36 s — prova direta de que o `--max-time 30` era o defeito.

Mas o objetivo era manter o Render acordado, e isso continua sem acontecer. O `cron` pede execução a cada 10 minutos; o histórico real mostra intervalos de **3 a 4 horas**, porque o GitHub estrangula agressivamente workflows agendados em repositórios de baixa atividade. O Render free tier dorme após 15 minutos de inatividade. Em 05/09, com o workflow já corrigido, medi **33,7 s** de cold start.

Ou seja: o workflow deixou de mentir, mas a abordagem não alcança o objetivo. As saídas reais são tier pago no Render ou um pinger externo com agendador confiável. Enquanto isso, o retry do Dio (que o `CLAUDE.md` manda preservar) continua sendo o que salva a experiência no primeiro acesso do dia.

---

## 3. TD-01 — autenticação JWT: causa raiz

**Sintoma:** telas de Interview Mode e histórico retornando `HTTP 401 [missing_token]`.

### 3.1 O que ficou provado

**Não é descompasso ES256 vs HS256.** `missing_token` e a validação de JWT são caminhos **mutuamente exclusivos**:

| Probe contra produção | Resposta |
|---|---|
| sem header | `401 {"detail":"missing_token"}` |
| `Bearer garbage.token.here` | `401 {"detail":"invalid_token"}` |
| `Bearer ` (vazio) | `401 {"detail":"missing_token"}` |

`missing_token` é emitido em `auth.py:35-37`, **antes de qualquer trabalho de JWT**. Um token com algoritmo errado sai como `invalid_token`. A validação já cobre os dois casos: ES256/RS* via JWKS com refresh em rotação de `kid` (`jwt_verify.py:118`), HS256 legado (`:138`), e um terceiro fallback via GoTrue (`auth.py:48`). O JWKS de produção responde 200 e serve uma chave **ES256** — o desenho está correto.

**Não é o gateway.** Um `Authorization` arbitrário atravessa o Render intacto e chega ao verificador — se algo o removesse, a resposta seria `missing_token`, não `invalid_token`.

**Por eliminação: o cliente não enviou Bearer utilizável.**

### 3.2 O defeito que fez isso ser mal diagnosticado

O cliente **fabrica uma resposta 401 com o formato idêntico ao do servidor**:

```dart
// api_service.dart:108-120
static DioException _missingTokenException(RequestOptions options) {
  return DioException(
    response: Response(statusCode: 401, data: {'detail': 'missing_token'}),
```

Disparada localmente em `api_service.dart:179`, **sem nenhum pacote sair do dispositivo**. A UI (`dream_history_screen.dart:157-161`) renderiza `HTTP $status [$detail]` — produzindo `HTTP 401 [missing_token]` de forma **idêntica** para uma rejeição do servidor e para um bloqueio puramente local.

A string do sintoma aponta para o servidor. A origem provável é o cliente bloqueando a si mesmo. Foi isso que levou a investigação para JWT.

A mudança 403 → 401 é intencional e está documentada em `auth.py:8-9` (`HTTPBearer(auto_error=False)`). Os dois códigos sempre significaram a mesma coisa: header ausente.

### 3.3 O que não foi possível fechar

O APK do aparelho é de 05/08, posterior aos fixes de auth (`2001706` de 12/07, `a689cbd` de 14/07) — então **contém** o fail-closed e o fallback de sessão. Isso elimina a hipótese de build antigo.

No código atual, tanto o histórico (`dream_history_screen.dart:112-121`) quanto a entrevista (`record_dream_screen.dart:185-202`) chamam `ensureFreshSession()` e abortam com mensagem **diferente** se vier null, anexando Bearer explícito só depois. Restam duas explicações, e não escolho uma sem evidência:

- **(b)** a sessão fica null **entre** o check e o request (janela de corrida);
- **(c)** a tela que falha é outra — `_buscarSemantico` (`dream_history_screen.dart:71`) não faz null-check antes de `authOptions`, caindo direto no fail-closed local.

**Instrumento para fechar:** renomear o erro fabricado para `client_missing_token` (P1-5). A partir daí a própria mensagem na tela diz de que lado o token se perdeu, e essa classe de bug deixa de custar uma investigação.

---

## 4. O que foi corrigido

| PR | Conteúdo | Estado |
|---|---|---|
| [#3](https://github.com/robconceicao/aion/pull/3) | P0-1: `.order(ascending=)` → `desc=False` + 3 testes de rota | merged |
| [#4](https://github.com/robconceicao/aion/pull/4) | Trabalho local resgatado (LGPD, mito espelho, busca) + 12 testes de posse | merged |
| [#5](https://github.com/robconceicao/aion/pull/5) | P0-2 + P1-1, P1-2, P1-3 + 16 testes | merged |
| [#7](https://github.com/robconceicao/aion/pull/7) | P1-4, P1-5, P1-6, P1-12 + item 4 da Etapa 4 | merged |
| [#8](https://github.com/robconceicao/aion/pull/8) | P1-9 (RLS versionada) + P1-13 (escrita de `episodes`) + 5 testes | merged |
| [#9](https://github.com/robconceicao/aion/pull/9) | P1-10 (jargão determinístico) + 16 testes | merged |
| [#10](https://github.com/robconceicao/aion/pull/10) | P1-14 (quoting no build do APK) | merged |
| [#11](https://github.com/robconceicao/aion/pull/11) | Versão 1.0.4+5 + `dist/` no `.gitignore` | aberto |
| [#6](https://github.com/robconceicao/aion/pull/6) | Este relatório | aberto |

### 4.1 Validação por mutação

Cada correção teve os testes verificados nos dois sentidos:

| Mutação aplicada | Resultado |
|---|---|
| `.order(desc=False)` → `ascending=True` | 2 failed, `TypeError` em `episodes.py:14` |
| `delete_dream` sem `.eq("user_id", ...)` | 2 failed, incluindo user-b apagando sonho de user-a |
| `delete_account` sem `.eq("user_id", ...)` | 1 failed |
| `_wants_json` volta a olhar só o system | 2 failed |
| `synthesize_dual` sem `json_mode` | 1 failed |
| remover os 4 timeouts da cascata | 4 failed |
| escrita de `episodes` de volta para o cliente anon | 3 failed |
| `ALLOWED_ORIGINS` de volta como campo `list` | módulo nem importa — `SettingsError` na coleta |
| remover a verificação de jargão | 4 failed |
| fallback da entrevista voltando a usar "psique" | 2 failed |

Todos os arquivos mutados foram restaurados e verificados idênticos ao HEAD.

### 4.2 Cobertura de testes

```
início da auditoria:  73 passed
final (main):         131 passed  (+58)
```

*Nota de contagem: durante o trabalho, cada branch reportava 73 mais os seus próprios testes, porque partiam do `main` em momentos diferentes. O número que vale é o do `main` com tudo integrado: **131**.*

Os testes novos cobrem exatamente onde o CI estava cego: rota do Canal, separação de clientes anon/service_role, posse nos endpoints destrutivos, modo JSON no fallback, tetos de tempo, parsing de `ALLOWED_ORIGINS` e filtro de jargão.

Nenhum deles foi aceito só por passar. Cada um foi verificado por mutação — o teste tinha de **reprovar** o código sem a correção. Dois casos revelaram problemas que a leitura não pegaria: a mutação de `delete_dream` mostrou o cenário real de vazamento (usuário B apagando sonho de A), e a de `ALLOWED_ORIGINS` mostrou que o defeito impede até o import do módulo, não só a validação.

---

## 5. O que ficou pendente e por quê

| Item | Por quê |
|---|---|
| ~~P1-4, P1-5, P1-6, P1-12~~ | **Resolvidos** no PR #7. |
| ~~P1-9~~ | **Resolvido** no PR #8, com as políticas reais transcritas do dump de `pg_policies`. |
| ~~P1-10~~ | **Resolvido** no PR #9. |
| P1-8 (licenciamento fail-open) | **Decidido em 04/09/2026: manter desligado por ora.** Ligar `TADEU_LICENSE_ENFORCED` bloquearia todo cliente sem token, inclusive o APK de 05/08 no aparelho. Reavaliar quando houver um build distribuído com o interceptor de licença — ver §9.5. |
| P1-11 (retry multiplica custo de IA) | **Continua pendente.** É o item aberto de maior impacto financeiro: uma síntese lenta pode virar três sínteses pagas. Merece tratamento próprio, não um remendo. |
| Cold start do Render (§2.6) | O keep-alive foi corrigido, mas a abordagem não alcança o objetivo. Resolver exige tier pago ou pinger externo — decisão de custo. |
| Todos os P2 | Fora da priorização P0→P1 acordada. |
| **Etapa 6 (APK)** | Bloqueada — §7. |

---

## 6. Checklist da Etapa 4 — as 8 melhorias

| # | Item | Veredito |
|---|---|---|
| 1 | Fallback do `ensureFreshSession()` | **IMPLEMENTADO** |
| 2 | Status HTTP explícito (incl. voz) | **IMPLEMENTADO** ⚠️ |
| 3 | Zero jargão na entrevista | **PARCIAL** → corrigido (PR #9) |
| 4 | Duração no loading | **PARCIAL** → corrigido (PR #7) |
| 5 | Contraste no Interview Mode | **PARCIAL** → corrigido (PR #7) |
| 6 | Descoberta da busca semântica | **IMPLEMENTADO** |
| 7 | Narração ElevenLabs | **IMPLEMENTADO** ⚠️ |
| 8 | dart-define / CORS / RLS | **2 de 3 confirmados** |

**1 · IMPLEMENTADO** — `api_service.dart:68-72`: quando o refresh falha, prefere o token atual ainda utilizável antes de declarar sessão expirada, com terceira tentativa relendo `currentSession`. O `catch` externo (`:73-77`) repete a lógica. `_isAccessTokenUsable` aplica margem de 30 s (`:18-26`).

**2 · IMPLEMENTADO, com ressalva** — Transcrição (`record_dream_screen.dart:134-153`) nomeia o status em todos os ramos: 401/403, 400, 500, timeout, genérico. Histórico idem (`dream_history_screen.dart:157-168`). Narração mapeia 9 códigos (`api_service.dart:280-325`). **Ressalva:** "HTTP 401" pode ser servidor ou bloqueio local (§3.2) — o status é explícito, mas não confiável.

**3 · PARCIAL — falha dos dois lados.** A regra existe no prompt (`ai_service.py:411`): *"✗ ABSOLUTAMENTE PROIBIDO: qualquer jargão psicológico nas perguntas: arquétipo, Self, individuação, inconsciente coletivo, anima, animus, Sombra, psique, complexo, limiar arquetípico, monomito"*. Três falhas concretas explicam o observado:

- **Não há pós-processamento.** `generate_interview_questions` devolve `data.get("perguntas", [])` cru (`:296`). A regra é probabilística e nada a faz valer.
- **A blocklist não cobre os termos que apareceram.** "Divine Child"/"Criança Divina" e "Velho Sábio" **não estão na lista**. "Self emergente" escapa porque nada verifica a saída.
- **O fallback viola a própria regra.** As 3 perguntas fixas (`:299-301`) dizem *"o que sua psique está tentando integrar"* — e "psique" está na lista de proibidos. Em degradação, o app serve jargão por construção.

**Verificação determinística proposta:** um `_validar_perguntas(perguntas) -> list[str]` com blocklist normalizada (sem acento, case-insensitive, com fronteira de palavra para não pegar "psicólogo") aplicado à saída. Reprovação dispara **uma** regeneração citando as violações; se reprovar de novo, cai para o fallback — que precisa ser reescrito antes, para ele mesmo passar no filtro. Testável offline com saídas contendo "Divine Child"/"Self emergente".

**4 · PARCIAL** — Presente onde a espera é maior: síntese, *"Isso pode levar de 1 a 2 minutos"* (`interview_screen.dart:204`); cold start, *"até 1 minuto na primeira vez"* (`record_dream_screen.dart:178`). **Ausente** na geração de perguntas (`:207`) e na transcrição (`:109`) — e a geração de perguntas é justamente a chamada que dispara a cascata de LLM.

**5 · PARCIAL** — Texto principal corrigido; secundários não. Calculado sobre `darkVoid #070810`:

| Uso | Cor | Razão | AA (4.5:1) |
|---|---|---|---|
| Pergunta, 17/15px (`:347`, `:364`) | `#F5F5F5` | 18,32:1 | passa |
| Contador, 13px (`:258`) | `silver` @0.6 | **3,17:1** | falha |
| Auxiliar, 14px (`:369`) | `silver` @0.55 | **~2,85:1** | falha |
| Cabeçalho (`:229`, `:234`) | `silver` @0.5 | **2,54:1** | falha |
| Rótulo, 10px (`:399`) | `gold` @0.5 | **2,87:1** | falha |

`silver` puro (`#9898B8`) dá **7,15:1** e passa com folga — o problema é inteiramente a opacidade.

**Corrigido no PR #7**, exceto o ornamento decorativo `✦` (`:399`), isento do requisito de contraste de texto por ser decoração pura. Os quatro elementos de texto e ícone foram para 7,15:1.

**6 · IMPLEMENTADO** — `dream_history_screen.dart:375-424`: `TextField` com `hintText: 'Buscar no diário...'`, `prefixIcon: Icons.search`, botão de limpar, wrapper `Semantics`, indicador de busca ativa. Nota de UX: dispara só no `onSubmitted` — exige Enter, sem botão explícito nem busca incremental.

**7 · IMPLEMENTADO, com um ponto não verificável** — Os quatro `voice_settings` batem **exatamente** com a especificação (`config.py:40-43`): stability `0.80`, similarity_boost `0.75`, style `0.05`, speed `0.92`. Chave lida do ambiente (`:33`), usada só no header (`tts_service.py:163`), **nunca hardcoded**, com falha explícita se ausente (`:151-152`). Narração é opcional — só roda quando o usuário toca em ouvir (`dual_interpretation_screen.dart:163-171`). A degradação não é silenciosa: mostra mensagem e mantém *"O texto continua disponível para leitura"*, o que é melhor que silêncio.

**Não verificável:** `ELEVENLABS_VOICE_ID` não tem default no código (`config.py:34`). O `tAkJipX1HdgNSt3HObzr` aparece só em `docs/voice-design.md:6` e nos manifestos de calibração. Confirmar o valor na env do Render.

**8 · 2 de 3**

- **Chaves via `--dart-define`: IMPLEMENTADO** — `supabase_config.dart` sem defaults, `assertConfigured()` falha explícito, zero chave hardcoded em `.dart`. **Mas** o pipeline violava a própria regra (P0-2).
- **CORS restrito: CONFIRMADO ao vivo** — origem não autorizada não recebe `access-control-allow-origin`; origem autorizada recebe o eco com `allow-credentials: true`.
- **RLS: NÃO VERIFICÁVEL** de fora. Anon lê `dreams` e vê `Content-Range: */0`, compatível com RLS ativo — mas tabela vazia dá o mesmo resultado. O projeto Supabase do Aion está em outra conta. Para fechar, no SQL Editor:

```sql
select tablename, rowsecurity from pg_tables
where schemaname='public' and tablename in ('dreams','episodes');
```

```sql
select tablename, policyname, cmd, qual, with_check
from pg_policies where schemaname='public' order by tablename;
```

---

## 7. Etapa 6 — build do APK release

**Realizado em 05/09/2026.** Versão **`1.0.4+5`** (`versionCode=5`, `versionName=1.0.4`, `minSdk=24`).

### 7.1 Assinatura

`android/key.properties` e `*.keystore`/`*.jks` estão no `.gitignore` — nenhum segredo de assinatura versionado. `dart_define.json` idem, e confirmadamente não rastreado.

Isso cria uma consequência que só apareceu ao olhar o `build.gradle.kts`:

```kotlin
signingConfig = if (hasKeystore) signingConfigs.getByName("release")
                else            signingConfigs.getByName("debug")
```

No CI o keystore não existe, então `hasKeystore` é `false` e o APK sai assinado com a chave de **debug** — silenciosamente, sem aviso, com o build passando. Um APK assim não instala por cima de uma versão release-signed (conflito de assinatura) nem serve para a Play Store.

Por isso o build de distribuição foi feito **localmente** (caminho A), mantendo a chave fora do CI. A alternativa — levar o keystore para o GitHub como secret — foi descartada por opção do responsável.

O APK do CI continua útil para QA em aparelho limpo, mas não é o artefato de distribuição.

### 7.2 Artefatos

| Arquivo | Tamanho |
|---|---|
| `dist/aion-1.0.4+5-release.apk` (universal) | 59,2 MB |
| `dist/aion-1.0.4+5-arm64-v8a.apk` | **24,3 MB** |
| `dist/aion-1.0.4+5-armeabi-v7a.apk` | 22,0 MB |
| `dist/aion-1.0.4+5-x86_64.apk` | 25,6 MB |

O `--split-per-abi` acabou valendo a pena por dois motivos que só apareceram na prática: reduz o download em ~58% para o usuário final, e cada arquivo fica abaixo dos limites usuais de transferência. Para a Play Store o alvo correto continua sendo o appbundle, não estes APKs.

### 7.3 Verificações do artefato

Medidas, não presumidas:

| Verificação | Resultado |
|---|---|
| Assinatura | `CN=Aion Dream Analysis, OU=Mobile, O=Roberto Tadeu` · RSA 2048 · esquema v2 |
| É a chave de debug? | **Não** |
| Instala por cima do APK do aparelho? | **Sim** — SHA-256 do certificado idêntico ao do build de 05/08 |
| Supabase de produção no binário | ✅ nos 4 artefatos |
| `aion-vvx7.onrender.com` no binário | ✅ nos 4 artefatos |

**Uma armadilha que quase inverteu a conclusão:** `keytool -printcert -jarfile` respondeu *"não é um arquivo jar assinado"*, o que soa como APK sem assinatura. Não é — o `keytool` só entende assinatura v1 (JAR), e o APK usa o esquema v2. Aceitar aquela saída teria levado ao oposto do verdadeiro. A ferramenta correta é o `apksigner`, do Android SDK build-tools.

O ponto de maior valor prático é a terceira linha: como o certificado é o mesmo do build de 05/08, a atualização instala por cima **sem desinstalar**, preservando a sessão e os dados locais do Hive.

### 7.4 Ressalva — o Tadeu aponta para teste

Os quatro artefatos foram compilados com `TADEU_APPS_URL` no default, `tadeu-apps-core-test2.vercel.app` — o **ambiente de teste**. Não há ambiente de produção do Tadeu Apps definido, e os secrets correspondentes não foram configurados.

Sem efeito prático hoje, porque `TADEU_LICENSE_ENFORCED` está desligado por decisão de produto (P1-8). Mas isto **passa a importar no momento em que o licenciamento for ligado**: um build com este default validaria licenças contra o ambiente errado. Resolver o P1-7 é pré-requisito de ligar o P1-8.

---

## 8. Roteiro de teste manual no aparelho

Executar com o `aion-1.0.4+5-arm64-v8a.apk`. Anotar o que divergir.

**Pré-condições:**

- **Instalar por cima, sem desinstalar.** O certificado é o mesmo do build de 05/08 (§7.3), então a atualização preserva a sessão e os dados locais do Hive. *Isto corrige a instrução da versão anterior deste relatório, que mandava desinstalar — desnecessário, e destruiria o histórico local de teste.*
- **Rede móvel, não Wi-Fi** — expõe a latência real.
- **A primeira chamada do dia leva ~30 s**, pelo cold start do Render. É esperado, não é falha (§2.6).
- O backend já está em produção com todas as correções desde 05/09; o app é a parte que estava atrasada.

### A. Abertura e sessão
1. Abrir o app. **Deve** chegar à tela de login. Se travar na splash, os `--dart-define` não entraram.
2. Login. Fechar o app pelo gerenciador de tarefas e reabrir → deve entrar direto, sem novo login.
3. Deixar o app fechado por mais de 1 h e reabrir → deve renovar a sessão sozinho. Um `HTTP 401 [missing_token]` aqui é o TD-01 (§3).

### B. Entrevista
4. Novo sonho por texto, ~5 linhas, com uma figura e um lugar concretos.
5. Marcar tags de emoção, temas e resíduos diurnos.
6. Avançar para a entrevista. Observar o loading: hoje diz *"Preparando perguntas"* **sem duração** (§6, item 4).
7. **Ler as 3 perguntas com atenção.** Anotar qualquer jargão: "arquétipo", "Self", "Criança Divina", "Divine Child", "Velho Sábio", "psique", "individuação". Copiar a pergunta inteira — é o insumo do P1-10.
8. Verificar se cada pergunta cita algo **concreto** do seu sonho. Perguntas genéricas indicam degradação para o fallback fixo.
9. **Contraste:** em ambiente claro, ver se o contador de perguntas e os textos auxiliares cinza estão legíveis (§6, item 5, medidos em 2,5–3,2:1).
10. Responder as três e enviar.

### C. Síntese
11. Loading deve dizer *"Isso pode levar de 1 a 2 minutos"*. Cronometrar — esperado ~80-100 s.
12. **Se passar de 3 min:** anotar. Pode ser o retry disparando cascatas repetidas (P1-11).
13. Na tela de resultado, conferir as seções **Mito espelho** e **Prospecção**. Se vierem vazias, o PR #4 não está no build.
14. Verificar que a interpretação se apresenta como *leitura possível* ("uma forma de olhar para isso", "segundo Jung") e não como veredito — mudança do PR #4.

### D. Histórico e busca
15. Abrir o histórico. Deve listar o sonho recém-criado. `HTTP 401 [missing_token]` aqui é o TD-01.
16. Buscar por uma palavra do sonho. **Confirmar que exige Enter** — não há botão de busca (§6, item 6).
17. Buscar por termo inexistente → deve tratar sem travar.
18. Aplicar filtros de emoção e de fase; limpar e confirmar que a lista volta ao normal.

### E. Narração
19. Na interpretação, tocar em ouvir. Primeira geração demora; as seguintes vêm do cache.
20. Avaliar a voz: estável em narração longa, sem oscilação (preset "mais_estavel").
21. Pausar, retomar e parar.
22. **Colocar o aparelho em modo avião e tocar em ouvir** → deve mostrar mensagem clara e **manter o texto legível**, nunca tela vazia.
23. Repetir a narração do mesmo sonho → deve vir instantânea (cache).

### F. Voz e Canal
24. Novo sonho por voz. Gravar ~30 s. Conferir a transcrição.
25. Gravar 1 s de silêncio e enviar → deve dar erro claro com status HTTP (§6, item 2).
26. Abrir o Canal. Deve carregar **sem erro** — era o 500 do P0-1. Se a lista vier vazia, é falta de conteúdo cadastrado, não bug: a tabela `episodes` está vazia.

### G. Estabilidade
27. **Sair da tela durante a transcrição** (voltar assim que aparecer "Transcrevendo"). Um crash aqui é o P1-4 (`setState` após dispose).
28. Repetir saindo durante a síntese.
29. Girar a tela nas telas de resultado e histórico.
30. Alternar para outro app durante a síntese e voltar depois de 1 min.

### H. LGPD
31. Excluir um sonho pelo histórico. Confirmar o diálogo. O item deve sumir da lista.
32. **Testar o rollback:** modo avião, tentar excluir → o item deve **voltar** para a lista.
33. Excluir a conta. Confirmar que o login deixa de funcionar e que os sonhos sumiram.

---

## 9. Recomendações, em ordem

Os itens 1, 2, 4 e 6 da versão anterior deste relatório já foram executados. O que resta:

1. **Instalar o `1.0.4+5` no aparelho e rodar o roteiro da §8.** É a única verificação que este relatório não consegue fazer sozinho — tudo aqui foi medido contra código, CI e produção, mas nada contra um dedo numa tela.

2. **Tratar o P1-11 — o retry que multiplica o custo de IA.** É o item aberto de maior impacto financeiro. Se a síntese estourar os 180 s de `receiveTimeout`, o interceptor repete a request até 2×, e cada repetição dispara uma cascata de LLM completa. Uma síntese lenta vira três sínteses pagas, sem que ninguém perceba. Merece desenho próprio: provavelmente excluir do retry as rotas caras, ou tornar a síntese idempotente por chave de requisição.

3. **Estreitar o pin do `supabase`** em `requirements.txt`. A faixa `>=2.11.0,<3` aceita qualquer 2.x, e foi exatamente isso que permitiu o P0-1 — um `TypeError` em produção com o CI verde.

4. **Decidir sobre o cold start** (§2.6). O keep-alive está correto mas não alcança o objetivo, e o `GET /` continua levando ~33 s no primeiro acesso do dia. Tier pago no Render ou pinger externo — é decisão de custo, não técnica.

5. **`TADEU_LICENSE_ENFORCED` — decidido: fica desligado por ora** (P1-8).

   Consequência aceita conscientemente: **o licenciamento não está sendo aplicado**. Sem o header `X-Tadeu-Token`, o backend registra um warning e libera a operação (`tadeu_metering.py:22-31`) — qualquer cliente contorna a cota simplesmente omitindo o header. Não é uma falha a corrigir agora; é uma janela de transição escolhida, para não quebrar os APKs já distribuídos que não têm o interceptor de licença.

   **Condição para reavaliar:** quando houver um build distribuído contendo `TadeuLicenseInterceptor`. Ao ligar, ligar primeiro em ambiente de teste — e antes disso resolver o P1-7 (§7.4), senão o backend valida contra `tadeu-apps-core-test2.vercel.app`.

6. **Atualizar o `CLAUDE.md`** (§2.5) — quatro afirmações desatualizadas, uma delas contradizendo o próprio documento. Como ele orienta o trabalho no projeto, erros ali custam tempo real: a seção "Dual DB" descreve um MongoDB que não existe mais no código, e a nota sobre chaves hardcoded contradiz a regra que o próprio documento estabelece adiante.

7. **Cadastrar episódios no Canal.** A tela funciona desde o PR #3, e o cadastro desde o PR #8 — mas a tabela `episodes` está vazia, então o Canal abre no estado vazio. Agora é falta de conteúdo de verdade, não bug.

8. **Endereçar os P2 restantes** (§2.4), especialmente os stubs silenciosos de `/admin/stats/*`, que devolvem `[]` com HTTP 200 e fazem um dashboard vazio parecer um dashboard sem dados.

---

## 10. Nota de método

Duas escolhas moldaram este trabalho e valem registro para auditorias futuras.

**Nenhum achado foi reportado por leitura de código isolada.** Cada um foi confirmado por execução — sondagem contra produção, reprodução local do erro, ou teste automatizado. Isso custou tempo e evitou pelo menos dois erros: a hipótese de descompasso ES256/HS256 no TD-01, descartada por probe; e a de que o Supabase estava fora do ar, que cheguei a reportar como P0 e retirei ao descobrir que a falha de DNS era transitória na máquina de auditoria.

**Nenhum teste foi aceito só por passar.** Cada um foi verificado por mutação: quebrar deliberadamente o código corrigido e confirmar que o teste reprova. Isso revelou coisas que a leitura não pegaria — a mutação de `delete_dream` mostrou o cenário concreto de vazamento entre usuários, e a de `ALLOWED_ORIGINS` mostrou que o defeito impede até o import do módulo, não apenas a validação de um campo.

Três achados desta auditoria surgiram **durante o próprio trabalho de correção**, não no levantamento: a escrita de `episodes` pelo cliente anon (P1-13), o quoting no build do APK (P1-14, regressão introduzida por mim ao corrigir o P0-2) e a assinatura de debug no CI (§7.1). Nenhum deles apareceria numa auditoria puramente estática.
