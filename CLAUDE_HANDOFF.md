# AION — Documento de Handoff Técnico para Claude

> **Objetivo:** Este documento descreve a arquitetura completa do app Aion para que o Claude possa propor e implementar uma nova feature de forma integrada, seguindo os padrões já estabelecidos no projeto.

---

## 1. Visão Geral do Projeto

**Aion — Mito & Psique** é uma plataforma de análise junguiana de sonhos. O usuário relata seu sonho (por texto ou voz), e a IA (Claude da Anthropic) realiza uma amplificação simbólica profunda, retornando arquétipos, símbolos, fase da Jornada do Herói, mito espelho e pergunta de reflexão.

### Stack Tecnológica

| Camada | Tecnologia |
|---|---|
| Frontend | Flutter (Dart) — Web/Mobile |
| Backend | Python 3.11 + FastAPI |
| Banco de Dados | Supabase (PostgreSQL) |
| IA — Análise de Sonhos | Anthropic Claude (claude-sonnet-4-6 e fallbacks) |
| IA — Transcrição de Voz | Google Gemini (gemini-2.0-flash) |
| Deploy Frontend | Vercel (Firebase Hosting também configurado) |
| Deploy Backend | Render.com |
| CI/CD | GitHub Actions |

---

## 2. Arquitetura do Backend (FastAPI)

**URL de produção:** `https://aion-vvx7.onrender.com`

### Estrutura de Diretórios

```
backend/
├── app/
│   ├── main.py              # FastAPI app + CORS + routers
│   ├── database.py          # Supabase client
│   ├── core/
│   │   └── config.py        # Settings (lê .env)
│   ├── models/
│   │   ├── dream.py         # DreamModel, DreamCreate, DreamAnalysis
│   │   ├── episode.py       # EpisodeModel
│   │   ├── feedback.py      # FeedbackModel
│   │   └── user.py          # UserModel
│   ├── routers/
│   │   ├── auth.py          # POST /auth/login, /auth/register
│   │   ├── dreams.py        # POST /dreams/, GET /dreams/, GET /dreams/{id}
│   │   ├── voice.py         # POST /voice/transcribe
│   │   ├── episodes.py      # GET /episodes/
│   │   ├── feedback.py      # POST /feedback/
│   │   └── analytics.py     # GET /admin/...
│   └── services/
│       ├── ai_service.py    # analyze_dream() → JSON de análise via Claude
│       └── voice_service.py # transcribe_audio() → texto via Gemini
├── requirements.txt
├── Dockerfile
└── Procfile
```

### Endpoints Relevantes

#### `POST /dreams/`
- **Input:** `{ "text": "string", "emotion": "string?", "tags": ["string"]?, "is_recurrent": bool? }`
- **Output (JSON):** Análise completa do sonho
```json
{
  "aviso": "Esta análise é uma reflexão simbólica...",
  "essencia": "O coração do sonho...",
  "arquetipos": [
    { "nome": "Herói", "simbolo": "⚔", "descricao": "..." }
  ],
  "funcao_compensatoria": "...",
  "simbolos_chave": [
    { "elemento": "Floresta", "significado": "..." }
  ],
  "fase_jornada": { "nome": "Travessia", "descricao": "..." },
  "prospeccao": "...",
  "pergunta_para_reflexao": "...",
  "mito_espelho": { "titulo": "Orfeu", "paralelo": "..." },
  "intensidade_sombra": 7,
  "intensidade_heroi": 6,
  "intensidade_transformacao": 8
}
```

#### `POST /voice/transcribe`
- **Input:** `multipart/form-data` com campo `file` (áudio .m4a / .mp3 / .wav / .ogg / .aac / .webm / .flac)
- **Output:** `{ "text": "transcrição do áudio" }`

#### `GET /episodes/`
- **Output:** Lista de episódios do podcast Mito & Psique

---

## 3. Arquitetura do Frontend (Flutter)

**URL de produção:** Hospedado no Vercel via Firebase Hosting

### Estrutura de Diretórios

```
frontend/lib/src/
├── core/
│   ├── constants.dart       # AionConfig (URLs da API)
│   ├── theme.dart           # AionTheme (Design System completo)
│   └── widgets/
│       └── cinematic_background.dart
├── features/
│   ├── auth/
│   │   └── presentation/
│   │       └── auth_screen.dart
│   ├── onboarding/
│   │   └── presentation/
│   │       └── onboarding_screen.dart
│   ├── dashboard/
│   │   └── presentation/
│   │       └── dashboard_screen.dart
│   ├── dream/
│   │   ├── models/
│   │   └── presentation/
│   │       ├── dream_diary_screen.dart     # Tela inicial / Dashboard
│   │       ├── record_dream_screen.dart    # Tela de registro de sonho
│   │       ├── analysis_result_screen.dart # Tela de resultado da análise
│   │       ├── archetypes_screen.dart      # Galeria de arquétipos
│   │       ├── canal_screen.dart           # Canal / Episódios do podcast
│   │       ├── audio_recorder.dart         # Interface abstrata
│   │       ├── audio_recorder_platform.dart # Plataform dispatcher
│   │       ├── audio_recorder_native.dart  # Implementação mobile
│   │       ├── audio_recorder_web.dart     # Implementação web
│   │       └── widgets/
│   │           ├── mandala_spinner.dart    # Loading spinner com logo girando
│   │           └── aion_logo.dart         # Logo animado
│   └── profile/
│       └── presentation/
│           └── profile_screen.dart
```

### Design System (AionTheme)

```dart
// Paleta de cores — SEMPRE usar estas constantes:
AionTheme.darkVoid   = Color(0xFF070810)  // Fundo principal
AionTheme.darkDeep   = Color(0xFF0D0C18)  // Fundo cards secundário
AionTheme.darkAbyss  = Color(0xFF121120)  // Fundo cards principais
AionTheme.shadow     = Color(0xFF1A1830)  // Borda padrão
AionTheme.veil       = Color(0xFF252340)  // Borda destaque
AionTheme.gold       = Color(0xFFC8A84A)  // Cor primária / CTA
AionTheme.amber      = Color(0xFFE8C46A)  // Dourado claro / valores
AionTheme.silver     = Color(0xFF9898B8)  // Texto secundário
AionTheme.ghost      = Color(0xFFCCCCE0)  // Texto principal dos cards
AionTheme.crimson    = Color(0xFFA83030)  // Alerta / Sombra
AionTheme.teal       = Color(0xFF2A8070)  // Transformação

// Tipografia — SEMPRE usar Google Fonts:
// PT Serif → corpo de texto, citações, labels
// Cormorant Garamond → títulos grandes
// Inter → textos funcionais / UI

// Padrão de letras espaçadas para labels:
// letterSpacing: 2 a 5, uppercase, fontSize: 9 a 12
```

### URL API — `constants.dart`

```dart
class AionConfig {
  static const String apiBaseUrl = 'https://aion-vvx7.onrender.com';
  static const String transcribeUrl = '$apiBaseUrl/voice/transcribe';
  static const String analyzeUrl = '$apiBaseUrl/dreams/';
  static const String episodesUrl = '$apiBaseUrl/episodes/';
}
```

### Navegação atual

```
DreamDiaryScreen (home)
  ├── → RecordDreamScreen    (ao pressionar "REGISTRAR SONHO")
  │       └── → AnalysisResultScreen  (após análise da IA)
  ├── → ArchetypesScreen     (ao pressionar "ARQUÉTIPOS")
  ├── → CanalScreen          (ao pressionar "CANAL")
  └── → ProfileScreen        (ao pressionar "editar perfil")
```

---

## 4. Padrões de Código — Regras Obrigatórias

### Flutter (Dart)
1. **Todas as telas são `StatefulWidget` ou `StatelessWidget`** — preferir `StatefulWidget` se houver estado local.
2. **`ConstrainedBox(maxWidth: 820)`** — todas as telas usam este container central para layout responsivo.
3. **`SafeArea` + `Scaffold(backgroundColor: AionTheme.darkVoid)`** — padrão de todas as telas.
4. **HTTP via `Dio`** — sempre usar o pacote `dio` para requisições. Não usar `http`.
5. **Loading State** — durante processamento, usar `MandalaSpinner(message: '...')` como substituto da tela inteira.
6. **Sem `BuildContext` após `await`** — sempre checar `if (mounted)` antes de usar `context` após operações assíncronas.
7. **Navegação** — usar `Navigator.push` / `Navigator.pushReplacement` com `MaterialPageRoute`.
8. **Botões primários** — `ElevatedButton` com `backgroundColor: AionTheme.gold`, `foregroundColor: AionTheme.darkVoid`, `shape: RoundedRectangleBorder()` (sem radius).
9. **Fontes** — sempre importar via `google_fonts` package.
10. **Labels de seção** — texto em uppercase com letterSpacing de 2~5, fontSize de 9~12, cor `AionTheme.silver` ou `AionTheme.gold`.

### Python (FastAPI)
1. **Router pattern** — cada domínio tem seu próprio arquivo em `routers/`, incluído em `main.py`.
2. **Models Pydantic** — todos os inputs/outputs são tipados com Pydantic em `models/`.
3. **Services** — lógica de negócio (chamadas IA, processamento) fica em `services/`, não nos routers.
4. **Async** — endpoints que chamam IA ou I/O pesado devem ser `async def`.
5. **Error handling** — usar `HTTPException` com status codes semânticos.
6. **Supabase** — acessado via `get_supabase()` de `app/database.py`.

---

## 5. Fluxo Principal — Como o App Funciona

```
[Usuário] → Tela "Registrar Sonho"
    ↓ digita ou grava voz
    ↓ (se voz) POST /voice/transcribe → texto transcrito
    ↓ preenche campos: emoção, contexto de vida, tags, recorrente, análise profunda
    ↓ pressiona "BUSCAR O SIGNIFICADO"
    ↓ POST /dreams/ { text, emotion, tags, is_recurrent }
    ↓ Backend: Claude analisa → salva no Supabase
    ↓ Retorna JSON de análise
[Usuário] ← Tela "Resultado da Análise" com:
    - Aviso ético
    - Essência do sonho
    - Dimensões (Sombra/Herói/Transformação em barras)
    - Arquétipos presentes (grid com cards)
    - Função Compensatória + Prospecção (2 colunas)
    - Símbolos & Ampliação (tabela)
    - Jornada do Herói com barra de progresso
    - Mito Espelho
    - Pergunta para Reflexão
    - Episódios Recomendados do podcast
```

---

## 6. Variáveis de Ambiente (Backend)

```env
# .env (não commitado)
ANTHROPIC_API_KEY=sk-ant-...
GOOGLE_API_KEY=AIza...
SUPABASE_URL=https://xxx.supabase.co
SUPABASE_KEY=eyJ...
PROJECT_NAME=Aion
```

---

## 7. Como Rodar Localmente

### Backend
```bash
cd backend
python -m venv venv
venv\Scripts\activate  # Windows
pip install -r requirements.txt
uvicorn app.main:app --reload --port 8000
# API disponível em http://localhost:8000
```

### Frontend
```bash
cd frontend
flutter pub get
flutter run -d chrome  # Para web
# ou
flutter run            # Para mobile conectado
```

> **Atenção:** Para testar localmente, troque `apiBaseUrl` em `constants.dart` para `http://localhost:8000`.

---

## 8. Banco de Dados (Supabase)

**Tabela principal:** `sonhos`

| Coluna | Tipo | Descrição |
|---|---|---|
| id | uuid | PK |
| relato | text | Texto do sonho |
| interpretacao | jsonb | JSON completo da análise |
| created_at | timestamptz | Timestamp automático |

> **Nota:** A autenticação de usuário está parcialmente implementada — atualmente o backend usa um UUID fixo `00000000-0000-0000-0000-000000000000` para usuário convidado. A integração com Supabase Auth é um próximo passo planejado.

---

## 9. Estado Atual e O Que Falta

### ✅ Implementado e Funcionando
- [x] Registro de sonho por texto + gravação de voz
- [x] Análise completa via Claude (Anthropic)
- [x] Tela de resultado com todos os componentes visuais
- [x] Galeria de arquétipos junguianos
- [x] Canal de episódios do podcast
- [x] Deploy no Render (backend) + Vercel/Firebase (frontend)
- [x] CI/CD via GitHub Actions

### 🔧 Próximos Desenvolvimentos Planejados
- [ ] Autenticação real com Supabase Auth (login/registro de usuário)
- [ ] Diário de sonhos — listar histórico de sonhos do usuário logado
- [ ] Favoritar sonhos
- [ ] Estatísticas dinâmicas (substituir os valores fixos na `DreamDiaryScreen`)
- [ ] Envio de feedback sobre a análise (endpoint `/feedback/` existe mas UI não usa)
- [ ] Modo de análise aprofundada (campo `deepMode` já existe na UI mas não é enviado ao backend)

---

## 10. Instrução para o Claude

Ao receber este documento, o Claude deve:

1. **Ler e entender a arquitetura completa** antes de propor qualquer código.
2. **Respeitar o design system** — usar `AionTheme.*` para todas as cores e estilos.
3. **Seguir os padrões de código** descritos na Seção 4.
4. **Propor código completo e funcional** — não usar `// TODO` ou `// implementar aqui`.
5. **Para mudanças no backend**, entregar o arquivo Python completo do router/service modificado.
6. **Para mudanças no frontend**, entregar o arquivo Dart completo da tela/widget modificado.
7. **Indicar claramente** quais arquivos existentes precisam ser modificados e quais são novos.
8. **Não quebrar o fluxo existente** — qualquer nova tela deve ser navegável a partir das telas já existentes.

---

*Gerado automaticamente pelo Antigravity em 2026-04-27. Projeto: robconceicao/aion*
