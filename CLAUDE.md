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
| DB backend | MongoDB + Supabase (PostgreSQL) | Dual DB — ver seção abaixo |
| Embeddings | Gemini embedding-001 | 768 dimensões → pgvector |
| IA análise | Claude (Anthropic) com fallback | ver cadeia abaixo |
| IA transcrição de voz | Gemini 2.5 Flash | voice_service.py |
| Áudio | record ^5.1.0 | Flutter |
| Deploy frontend | Vercel (+ Firebase configurado) | — |
| Deploy backend | Render.com | cold start ~30s no free tier |
| CI/CD | GitHub Actions | .github/workflows/deploy.yml |
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
│   │   ├── main.py              # FastAPI app, CORS, inclui todos os routers
│   │   ├── database.py          # Supabase client
│   │   ├── core/
│   │   │   ├── config.py        # Settings via pydantic-settings + .env
│   │   │   └── security.py
│   │   ├── models/
│   │   │   ├── dream.py         # DreamCreate, InterviewRequest, NarrativeRequest, SemanticSearchRequest
│   │   │   ├── episode.py
│   │   │   ├── feedback.py
│   │   │   └── user.py
│   │   ├── routers/
│   │   │   ├── auth.py          # POST /auth/login, /auth/register
│   │   │   ├── dreams.py        # POST /dreams/, GET /dreams/history, busca semântica, filtros
│   │   │   ├── voice.py         # POST /voice/transcribe
│   │   │   ├── episodes.py      # GET /episodes/ (Canal Mito & Psique)
│   │   │   ├── feedback.py      # POST /feedback/
│   │   │   └── analytics.py     # GET /admin/...
│   │   └── services/
│   │       ├── ai_service.py    # Toda a lógica de IA (Claude/Gemini/DeepSeek)
│   │       └── voice_service.py # Transcrição de áudio via Gemini
│   ├── requirements.txt
│   ├── Dockerfile
│   ├── Procfile
│   ├── analisador.py
│   ├── processador_sonhos.py
│   └── tests/
│       └── test_api.py
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
| `filterUrl` | `/dreams/filter` | POST — filtros |
| `narrativeUrl` | `/dreams/narrative` | POST — narrativa |
| `historyUrl` | `/dreams/history` | GET — histórico |
| `transcribeUrl` | `/voice/transcribe` | POST — transcrição de voz |
| `episodesUrl` | `/episodes/` | GET — canal Mito & Psique |

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
    "claude-sonnet-4-6",          # primário
    "claude-haiku-4-5-20251001",  # fallback 1
    "claude-3-5-sonnet-20241022", # fallback 2
]
# Se todos falharem → call_gemini() com gemini-2.5-flash
# Se Gemini falhar → call_deepseek()
```

**Regra:** nunca remover um modelo da lista sem confirmar disponibilidade do próximo.
Se adicionar modelos novos, inserir no início da lista `AI_MODELS`.

## Segurança — RLS (Row Level Security)

| Tabela | RLS | Políticas |
|---|---|---|
| `public.dreams` | ✅ Ativo | Usuário vê apenas seus próprios sonhos |
| `public.episodes` | ✅ Ativo | SELECT público; INSERT/UPDATE/DELETE só admin |

**Admin no Supabase:** identificado via `app_metadata.is_admin = true` no JWT.
Para promover um usuário a admin, executar no SQL Editor do Supabase:
```sql
UPDATE auth.users
SET raw_app_meta_data = raw_app_meta_data || '{"is_admin": true}'::jsonb
WHERE email = 'email_do_usuario@exemplo.com';
```

⚠️ Nunca desabilitar RLS nas tabelas acima. Nunca usar `execute_sql` via MCP sem revisar o SQL completo antes.

## Banco de Dados Duplo

O projeto usa **dois** bancos:

| Banco | Uso | Acesso |
|---|---|---|
| **MongoDB** | Dados principais do app (legado/paralelo) | `MONGODB_URL` + `DATABASE_NAME` |
| **Supabase (PostgreSQL)** | Auth, pgvector para embeddings, episódios, busca semântica | `SUPABASE_URL` + `SUPABASE_KEY` |

A busca semântica usa a RPC `buscar_sonhos_semanticos` no Supabase com pgvector.
Threshold de **recorrência:** 0.75 | Threshold de **busca manual:** 0.60–0.65.

Embeddings: gerados via `generate_embedding()` no backend → Gemini `embedding-001` → 768 dimensões.

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
MONGODB_URL=...
DATABASE_NAME=aion_db
JWT_SECRET=...
GEMINI_API_KEY=...          # Transcrição de voz + embeddings + fallback
ANTHROPIC_API_KEY=...       # Análise principal de sonhos
DEEPSEEK_API_KEY=...        # Fallback final
SUPABASE_URL=...
SUPABASE_KEY=...
SUPABASE_JWT_SECRET=...
```

⚠️ A `SUPABASE_URL` e `anonKey` do Supabase estão **hardcodadas** em `frontend/lib/main.dart`.
Isso é aceitável para a anonKey pública, mas monitorar se precisar trocar o projeto Supabase.

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

# Testes
pytest tests/

# Build Docker
docker build -t aion-backend .
docker-compose up
```

### Frontend
```bash
cd frontend
flutter pub get
flutter run -d chrome          # web
flutter run                    # mobile conectado
flutter build web              # build produção web
sh build.sh                    # script de build completo

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
- **Embedding retorna zeros:** `GEMINI_API_KEY` ausente ou inválida — `generate_embedding()` retorna `[0.0] * 768` como fallback silencioso
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
- Não alterar `SUPABASE_URL`/`anonKey` em `main.dart` sem atualizar os secrets do CI/CD em `.github/workflows/`
