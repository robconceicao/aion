# CLAUDE.md — Aion

> Para handoff detalhado com exemplos de JSON de resposta, ver `CLAUDE_HANDOFF.md` na raiz do projeto.

## Visão Geral
**Aion — Mito & Psique** é uma plataforma de análise junguiana de sonhos. O usuário relata seu sonho (texto ou voz), a IA realiza amplificação simbólica profunda e retorna arquétipos, símbolos, fase da Jornada do Herói, mito espelho e pergunta de reflexão.

## Stack Tecnológica

| Camada | Tecnologia | Detalhe |
|---|---|---|
| Frontend | Flutter (Dart) | Web + Android + iOS |
| Estado | Flutter Riverpod | ^2.4.9 |
| HTTP client | Dio | ^5.3.3 — com retry automático |
| Armazenamento local | Hive | ^2.2.3 |
| Auth + DB remoto | Supabase | ^2.5.4 (Flutter) |
| Backend | FastAPI (Python 3.11) | — |
| DB backend | Supabase (PostgreSQL + pgvector) | Banco único — ver seção abaixo |
| Embeddings | Gemini embedding-001 | 768 dimensões → pgvector |
| IA análise | Claude (Anthropic) com fallback | ver cadeia abaixo |
| IA transcrição de voz | Gemini 2.5 Flash | voice_service.py |
| Áudio | record ^5.1.0 | Flutter |
| Deploy frontend | Vercel (+ Firebase configurado) | — |
| Deploy backend | Render.com | cold start ~30s no free tier |
| CI/CD | GitHub Actions | `deploy.yml` (testes), `build-apk.yml` (APK), `keep-alive.yml` |
| Narração premium | ElevenLabs | `tts_service.py` — sob demanda, com cache |
| Licenciamento | Tadeu Apps | `tadeu_metering.py` — hoje **desligado** (fail-open) |
| Ferramenta de código | Antigravity | — |

## URLs de Produção
```
Backend:  https://aion-vvx7.onrender.com
Frontend: Vercel (ver .firebaserc e vercel.json para domínios)
```

## Estrutura de Diretórios Real

```
aion/
├── backend/
│   ├── app/
│   │   ├── main.py              # FastAPI app, CORS, middleware de metering Tadeu
│   │   ├── database.py          # get_supabase() [anon] e get_supabase_service()
│   │   ├── core/
│   │   │   ├── config.py        # Settings (pydantic-settings) + .env
│   │   │   ├── jwt_verify.py    # validação local do JWT: ES256 via JWKS, HS256 legado
│   │   │   ├── recurrence.py
│   │   │   └── security.py
│   │   ├── models/
│   │   │   ├── dream.py         # DreamCreate, SynthesisResult, AnaliseCompleta, MitoEspelho
│   │   │   ├── episode.py
│   │   │   ├── feedback.py
│   │   │   └── user.py
│   │   ├── routers/
│   │   │   ├── auth.py          # GET /auth/me, DELETE /auth/account (LGPD)
│   │   │   ├── dreams.py        # POST /dreams/, /interview, /search, /filter,
│   │   │   │                    #   GET /dreams/history, DELETE /dreams/{id}
│   │   │   ├── interpretacoes.py# POST /interpretacoes/{id}/audio e /narracao
│   │   │   ├── voice.py         # POST /voice/transcribe
│   │   │   ├── episodes.py      # GET público; escrita só admin + service_role
│   │   │   ├── feedback.py
│   │   │   └── analytics.py     # GET /admin/... (stats/* são stubs — ver Banco de Dados)
│   │   └── services/
│   │       ├── ai_service.py    # Toda a lógica de IA (Claude/Gemini/xAI) + filtro de jargão
│   │       ├── voice_service.py # Transcrição de áudio via Gemini
│   │       ├── tts_service.py   # ElevenLabs (narração) + Edge TTS
│   │       ├── tts_sanitizer.py
│   │       ├── audio_service.py
│   │       ├── narracao_cache.py
│   │       └── tadeu_metering.py# Cota/licença Tadeu Apps (hoje fail-open)
│   ├── migrations/              # 001..006 — 006 versiona todas as políticas de RLS
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── Procfile
│   └── tests/                   # 21 arquivos, 131 testes
├── frontend/
│   ├── lib/
│   │   ├── main.dart            # Entry point: Supabase.initialize, Hive, Riverpod ProviderScope
│   │   └── src/
│   │       ├── core/
│   │       │   ├── api_service.dart    # Dio singleton com interceptor de auth + retry
│   │       │   ├── constants.dart      # AionConfig — todas as URLs da API
│   │       │   └── theme.dart          # AionTheme (darkVoid, gold, etc.)
│   │       ├── features/
│   │       │   ├── auth/presentation/auth_screen.dart
│   │       │   ├── onboarding/presentation/onboarding_screen.dart
│   │       │   ├── profile/presentation/profile_screen.dart
│   │       │   └── dream/
│   │       │       ├── models/dream.dart
│   │       │       ├── presentation/
│   │       │       │   ├── dream_diary_screen.dart      # Dashboard principal
│   │       │       │   ├── dream_choice_screen.dart     # Texto vs Voz
│   │       │       │   ├── record_dream_screen.dart     # Entrada do sonho
│   │       │       │   ├── interview_screen.dart        # Modo Entrevista
│   │       │       │   ├── analysis_result_screen.dart  # Mapa Arquetípico
│   │       │       │   ├── narrative_result_screen.dart # Narrativa
│   │       │       │   ├── dual_interpretation_screen.dart # Interpretação dupla
│   │       │       │   ├── dream_history_screen.dart    # Histórico
│   │       │       │   ├── archetypes_screen.dart
│   │       │       │   ├── canal_screen.dart            # Episódios Mito & Psique
│   │       │       │   ├── audio_recorder.dart
│   │       │       │   ├── audio_recorder_native.dart
│   │       │       │   ├── audio_recorder_web.dart
│   │       │       │   ├── audio_recorder_platform.dart
│   │       │       │   ├── notification_service.dart
│   │       │       │   └── widgets/
│   │       │       │       ├── hero_journey_widget.dart  # Visualização Jornada do Herói
│   │       │       │       ├── mandala_spinner.dart
│   │       │       │       ├── aion_logo.dart
│   │       │       │       ├── hint_card.dart
│   │       │       │       ├── tag_selector.dart
│   │       │       │       ├── dream_tips.dart
│   │       │       │       └── loading_tip.dart
│   │       └── core/widgets/
│   │           └── cinematic_background.dart
│   ├── pubspec.yaml
│   ├── Dockerfile
│   ├── firebase.json
│   ├── vercel.json
│   └── android/, ios/, macos/, linux/, windows/, web/
├── CLAUDE_HANDOFF.md            # Handoff técnico detalhado com exemplos JSON
├── vercel.json                  # Config deploy raiz
├── cadastrar_episodio.py        # Script utilitário para inserir episódios
├── check_build.py
├── test_voice.py
└── .github/workflows/deploy.yml
```

## Endpoints da API (AionConfig.dart)

| Constante | URL | Uso |
|---|---|---|
| `apiBaseUrl` | `https://aion-vvx7.onrender.com` | Base |
| `analyzeUrl` | `/dreams/` | POST — análise completa |
| `interviewUrl` | `/dreams/interview` | POST — gera perguntas |
| `searchUrl` | `/dreams/search` | POST — busca semântica |
| `filterUrl` | `/dreams/filter` | GET — filtros por emoção/fase (query params) |
| `historyUrl` | `/dreams/history` | GET — histórico |
| `transcribeUrl` | `/voice/transcribe` | POST — transcrição de voz |
| `episodesUrl` | `/episodes/` | GET — canal Mito & Psique |
| `audioUrl(id)` | `/interpretacoes/{id}/audio` | POST — áudio Edge TTS sob demanda |
| `narracaoUrl(id)` | `/interpretacoes/{id}/narracao` | POST — narração premium ElevenLabs |

Exclusão de dados (LGPD art. 18, VI) — ambas com constante em `AionConfig`:
`DELETE /dreams/{id}` via `deleteDreamUrl(id)` e `DELETE /auth/account` via
`deleteAccountUrl`.

Existe ainda um `GET /dreams/{id}/audio` **legado** no backend (Edge TTS direto,
sem cache). Não tem constante e não é chamado pelo app — o caminho atual é
`POST /interpretacoes/{id}/audio`. Mantido só por compatibilidade.

**Importante:** ao adicionar novos endpoints, atualizar `frontend/lib/src/core/constants.dart`.

## Fluxo do Usuário

```
AuthScreen → OnboardingScreen (1ª vez) → DreamDiaryScreen (dashboard)
    │
    ├── Novo sonho → DreamChoiceScreen (texto ou voz)
    │       │
    │       ├── [voz] → AudioRecorder → transcribe (/voice/transcribe) → RecordDreamScreen
    │       └── [texto] → RecordDreamScreen
    │               │
    │               ├── Tags emocao, temas, residuos diurnos
    │               ├── → /dreams/interview → InterviewScreen (Modo Entrevista)
    │               │         └── Respostas → /dreams/ com interview_answers
    │               └── → /dreams/ (análise direta)
    │                         └── AnalysisResultScreen (Mapa Arquetípico)
    │
    ├── Busca semântica → /dreams/search (threshold 0.60)
    ├── Histórico → DreamHistoryScreen
    └── Canal → CanalScreen → /episodes/
```

## Cadeia de Fallback de IA (ai_service.py)

```python
# Ordem de tentativa para análise de sonhos:
AI_MODELS = [
    "claude-sonnet-5",            # primário
    "claude-haiku-4-5-20251001",  # fallback 1
    "claude-3-5-sonnet-20241022", # fallback 2
]
# Se todos falharem → call_gemini() com gemini-2.5-flash
# Se Gemini falhar → call_xai() (Grok)
```

**Regra:** nunca remover um modelo da lista sem confirmar disponibilidade do próximo.
Se adicionar modelos novos, inserir no início da lista `AI_MODELS`.

## Segurança — RLS (Row Level Security)

**As políticas estão versionadas em `backend/migrations/006_rls_policies.sql`**
— transcrição do estado real do banco, idempotente e dentro de `BEGIN/COMMIT`.
Antes disso viviam só no painel do Supabase, sem revisão possível.

| Tabela | RLS | Políticas |
|---|---|---|
| `public.dreams` | ✅ Ativo | SELECT/INSERT/UPDATE/DELETE com `auth.uid() = user_id` |
| `public.episodes` | ✅ Ativo | SELECT público; INSERT/UPDATE/DELETE só admin |
| `public.feedback` | ✅ Ativo | `ALL` com `auth.uid() = user_id` |
| `public.narracao_cache` | ✅ Ativo | só SELECT próprio — escrita apenas via `service_role` |
| `storage.objects` | ✅ Ativo | bucket `interpretacoes-audio` (privado), só `service_role` |

⚠️ **Pegadinha que já causou bug:** as políticas de escrita de `episodes` são
`TO authenticated` com claim de admin no JWT. O cliente **anon** tem role
`anon`, então nenhuma política permissiva se aplica e o RLS **nega**. As rotas
de escrita autenticavam o admin na API e a escrita morria no banco. Por isso
elas usam `get_supabase_service()`; a leitura continua no anon, de propósito.
Coberto por `tests/test_episodes_clients.py`.

**Admin no Supabase:** identificado via `app_metadata.is_admin = true` no JWT.
Para promover um usuário a admin, executar no SQL Editor do Supabase:
```sql
UPDATE auth.users
SET raw_app_meta_data = raw_app_meta_data || '{"is_admin": true}'::jsonb
WHERE email = 'email_do_usuario@exemplo.com';
```

⚠️ Nunca desabilitar RLS nas tabelas acima. Nunca usar `execute_sql` via MCP sem revisar o SQL completo antes.

## Banco de Dados

O projeto usa **apenas Supabase (PostgreSQL)**. Auth, dados de sonhos, pgvector
para embeddings, episódios do Canal e busca semântica — tudo lá.

> Histórico: houve um MongoDB paralelo, já removido. Não há driver Mongo em
> `requirements.txt` nem uso no código. Sobraram dois comentários em
> `analytics.py` explicando que `analytics_events` nunca foi migrado — por
> isso `/admin/stats/geo` e `/admin/stats/daily` devolvem `[]` com HTTP 200.
> São stubs, não dados vazios.

| Cliente | Quando usar | Onde |
|---|---|---|
| **anon** (`get_supabase()`) | leituras públicas — ex.: `GET /episodes/` | `SUPABASE_KEY` |
| **service_role** (`get_supabase_service()`) | toda escrita, e leituras sob RLS restritivo | `SUPABASE_SERVICE_KEY` |

⚠️ **`service_role` contorna o RLS.** Em qualquer rota que o use, a checagem de
posse no código é a ÚNICA proteção — sempre `.eq("user_id", user_id)`. Coberto
por `tests/test_lgpd_delete_ownership.py`.

A busca semântica usa a RPC `buscar_sonhos_semanticos` com pgvector.
Threshold de **recorrência:** 0.75 | Threshold de **busca manual:** 0.60–0.65.

Embeddings: `generate_embedding()` → Gemini `embedding-001` → 768 dimensões.
Em falha retorna **`None`**, nunca vetor de zeros — `None` sinaliza ausência de
indexação, e um vetor zero poluiria a busca por similaridade.

## Análise de Recorrência (Background Task)
Após enviar a resposta ao cliente, o backend roda `_background_save_and_recurrence()`:
- Busca sonhos similares do mesmo usuário (threshold 0.75, max 3)
- Se ≥ 2 similares: chama `analyze_recurring_pattern()` e adiciona `analise_recorrencia` ao objeto
- Salva o sonho no Supabase com embedding

## Tela de Resultado (AnalysisResultScreen)
Seções renderizadas na ordem:
1. Aviso ético
2. Sonho relatado
3. Essência
4. Mito espelho
5. Análise de recorrência (se houver)
6. Dimensões psíquicas
7. Arquétipos
8. Duas colunas (Sombra / Luz)
9. Símbolos
10. Jornada do Herói (`HeroJourneyWidget`)
11. Pergunta de reflexão

## Variáveis de Ambiente (backend/.env)

```env
GEMINI_API_KEY=...              # Transcrição de voz + embeddings + fallback
ANTHROPIC_API_KEY=...           # Análise principal de sonhos
XAI_API_KEY=...                 # Fallback final (Grok)

SUPABASE_URL=...
SUPABASE_KEY=...                # anon
SUPABASE_SERVICE_KEY=...        # service_role — escritas sob RLS restritivo
SUPABASE_JWT_SECRET=...         # só para tokens HS256 legados

ELEVENLABS_API_KEY=...          # narração premium
ELEVENLABS_VOICE_ID=...         # sem default no código — obrigatória

# Opcionais, com default no código:
# ALLOWED_ORIGINS=...           # lista separada por vírgula (campo str, ver nota)
# AI_TIMEOUT_SECONDS=120        # teto por tentativa de provider de IA
# TADEU_APPS_URL=...            # default aponta para TESTE
# TADEU_LICENSE_ENFORCED=false  # hoje desligado por decisão de produto
```

✅ **As chaves do Supabase NÃO estão hardcoded no app.** `SupabaseConfig`
(`frontend/lib/src/core/supabase_config.dart`) as lê via `String.fromEnvironment`
sem default, e `assertConfigured()` falha explicitamente antes do `runApp` se
faltarem. Sempre construir com `--dart-define-from-file=dart_define.json`.

⚠️ `ALLOWED_ORIGINS` é tipada como **`str`**, não `list`, de propósito: para
tipos complexos o `pydantic-settings` tenta `json.loads` no valor da env var
antes de qualquer validator, e um valor natural como
`"https://a.com,https://b.com"` derrubava o boot com `SettingsError`. A divisão
fica em `settings.allowed_origins_list`.

## Retry Automático (Dio — Cold Start do Render)
O `ApiService` em `api_service.dart` tem retry automático para timeouts e erros 5xx:
- Máximo 2 tentativas adicionais
- Backoff: 3s na 1ª, 6s na 2ª
- Coberto por: `receiveTimeout`, `connectionTimeout`, `sendTimeout`, e status >= 500
- Isso é necessário porque o Render free tier pode demorar ~30s para "acordar"

**Não remover essa lógica.** Se o backend migrar para um tier pago, pode-se reduzir o timeout.

## Padrões de Código

### Backend (Python)
- Sempre `async def` nos routers e services
- Novas rotas: criar router dedicado em `app/routers/`, registrar em `main.py`
- Novos modelos Pydantic: criar em `app/models/`
- Lógica de IA: apenas em `app/services/ai_service.py`
- Usar `BackgroundTasks` para operações pesadas pós-resposta (padrão já estabelecido em `dreams.py`)

### Frontend (Flutter/Dart)
- HTTP: sempre via `ApiService.client` (Dio com auth interceptor) — nunca instanciar Dio diretamente
- Novas URLs: adicionar em `AionConfig` em `constants.dart`
- Estado global: Riverpod — novos providers em `src/features/<feature>/`
- Cache local: Hive — box `'dreams'` já aberta no `main.dart`
- Tema: usar cores de `AionTheme` (ex: `AionTheme.darkVoid`, `AionTheme.gold`)
- Fundo animado: usar `CinematicBackground` widget nas telas principais

## Comandos Úteis

### Backend
```bash
cd backend
python -m venv venv
venv/Scripts/activate          # Windows
pip install -r requirements.txt
uvicorn app.main:app --reload  # dev local

# Testes — 131 no total; o CI roda `pytest --ignore=tests/test_api.py`
pytest tests/

# Build Docker
docker build -t aion-backend .
docker-compose up
```

### Frontend
```bash
cd frontend
flutter pub get

# Criar o arquivo de variáveis (apenas na primeira vez):
cp ../dart_define.example.json ../dart_define.json
# Editar dart_define.json com os valores reais (NÃO commitar este arquivo)

flutter run -d chrome --dart-define-from-file=../dart_define.json   # web
flutter run --dart-define-from-file=../dart_define.json             # mobile
flutter build web --dart-define-from-file=../dart_define.json       # build web
# Build de DISTRIBUIÇÃO — sempre local, nunca o artefato do CI (ver abaixo)
flutter build apk --release --dart-define-from-file=../dart_define.json
flutter build apk --release --split-per-abi --dart-define-from-file=../dart_define.json

sh build.sh                                                          # script completo

# Gerar código Riverpod/Hive
dart run build_runner build
```

### Scripts utilitários (raiz)
```bash
python cadastrar_episodio.py   # Inserir episódio no Canal
python check_build.py
python test_voice.py           # Testar endpoint de voz
```

## Erros Conhecidos e Soluções
- **Backend retorna 502/timeout:** Cold start do Render — o Dio retenta automaticamente; se persistir, verificar logs no Render
- **Embedding não gerado:** `GEMINI_API_KEY` ausente ou inválida — `generate_embedding()` retorna **`None`** (nunca vetor de zeros). O sonho é salvo sem indexação, e a busca semântica não o encontra
- **`Target file "..." not found.` no build do APK:** algum secret usado em `--dart-define` contém espaço. Os argumentos são montados em array no `build-apk.yml` justamente para isso não quebrar — se voltar a aparecer, conferir o valor do secret
- **APK do CI não instala por cima do release:** o keystore não existe no runner, então o `build.gradle.kts` cai silenciosamente na assinatura de **debug**. Para distribuição, buildar localmente
- **`keytool` diz "não é um arquivo jar assinado":** falso alarme — ele só entende assinatura v1 (JAR) e o APK usa v2. Verificar com `apksigner verify --print-certs`
- **Perguntas da entrevista com jargão:** o prompt proíbe, e `violacoes_de_jargao()` verifica a saída, regenera uma vez e cai para o fallback. Termos ambíguos (`sombra`, `complexo`, `anima`) ficam fora do filtro automático de propósito — barrá-los rejeitaria perguntas legítimas
- **Análise retorna erro de modelo:** Modelo Claude não disponível para a chave — a cadeia de fallback tenta os próximos; verificar `ANTHROPIC_API_KEY` e disponibilidade de créditos
- **Busca semântica vazia:** Verificar se o índice ivfflat do pgvector foi criado **após** inserção dos embeddings
- **build_runner falhando:** Rodar `dart run build_runner clean` antes de `build`

## O que NÃO fazer
- Não fazer chamadas HTTP diretamente com `Dio()` no Flutter — sempre `ApiService.client`
- Não remover modelos do array `AI_MODELS` sem confirmar disponibilidade do próximo
- Não mover lógica de IA para fora de `ai_service.py`
- Não adicionar URLs de API hardcodadas fora de `constants.dart`
- Não bloquear a thread principal do Flutter com operações pesadas — usar `async/await`
- Não commitar o `backend/.env`
- Não commitar `dart_define.json` (contém credenciais reais; está no .gitignore)
- Não colocar a anonKey ou SUPABASE_URL literalmente em nenhum arquivo .dart
- Para CI/CD: injetar `SUPABASE_URL` e `SUPABASE_ANON_KEY` como GitHub Secrets e passar via `--dart-define` em `.github/workflows/build-apk.yml`
- **Não distribuir o APK gerado pelo CI.** O keystore não existe no runner, então o `build.gradle.kts` cai silenciosamente na assinatura de **debug** — o artefato não instala por cima de um release nem serve para a Play Store. Serve só para QA em aparelho limpo. Build de distribuição é local
- **Não usar `get_supabase()` (anon) em rota de escrita.** As políticas de escrita exigem role `authenticated` ou `service_role`; o anon é negado pelo RLS e a falha aparece só em produção
- **Não confiar só no prompt para regras de saída da IA.** Prompt é controle probabilístico. A regra de zero jargão tem verificação determinística em `violacoes_de_jargao()` — se criar outra regra desse tipo, verificar a saída também
- **Não deixar chamada de LLM sem `timeout=`.** O SDK da Anthropic usa 600s por default; três modelos em série pendurariam o worker do Render por meia hora. Usar `AI_TIMEOUT_SECONDS`
- **Não aceitar teste que só passa.** Quebrar o código de propósito e confirmar que o teste reprova — foi assim que os bugs de posse e de `ALLOWED_ORIGINS` apareceram

---

*Revisado em 05/09/2026 após a auditoria completa. O relatório com achados,
correções e o roteiro de teste manual está em `docs/auditoria-2026-09-04.md`.*
