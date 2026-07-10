# Backlog — Aion

Itens registrados durante a auditoria. Não são bugs em aberto; são features
removidas/adiadas que valem implementar com o pacote completo.

## Favoritar sonhos
Removido o contador "FAVORITOS" da dashboard (M-03) porque a coluna não existia.
Para implementar de verdade:
- Coluna `is_favorite boolean default false` em `dreams` (migration nova).
- Endpoint para marcar/desmarcar favorito (PATCH em `/dreams/{id}`).
- Botão de favoritar na UI (tela do sonho e/ou diário).
- Restaurar o contador na dashboard lendo `is_favorite`.

## Arquétipo predominante
Removido o contador "ARQUÉTIPO" da dashboard (M-03) pelo mesmo motivo.
Para implementar de verdade:
- Coluna `main_archetype text` em `dreams` (migration nova).
- No backend, extrair o arquétipo principal da interpretação e gravar em
  `main_archetype` no insert do sonho.
- Restaurar o contador agregando `main_archetype` na dashboard.

## Observações de auditoria (a investigar, não confirmados)
- `_searchResults` / `_showSearchResults` aparecem como "não usados" em
  dream_diary_screen.dart — possível UI de resultados da busca semântica
  incompleta. Confirmar ao testar a busca no app.

---

## Débito técnico

### TD-01 — Validação JWT local desatualizada (ES256 vs HS256) — P2

**Registrado:** 2026-07-10 (pós E2E dual/áudio)  
**Prioridade:** P2 — **não bloqueante**. Fallback via GoTrue funciona.  
**Status:** aberto — **não corrigir sem decisão explícita**.

**Resumo (uma frase):** o Auth do projeto emite **ES256 (JWKS)**; o backend só tenta **HS256 + JWT secret legado** → erro de `alg` em toda request → fallback GoTrue.

**Sintoma nos logs (Render):**
```
Local JWT Error: The specified alg value is not allowed.
[AUTH] Usando verificação via API do Supabase como fallback.
```

**Causa (evidência):**
- Access token real (header): `"alg": "ES256"`, com `kid` e tip `JWT`.
- JWKS do projeto: `GET {SUPABASE_URL}/auth/v1/.well-known/jwks.json` → chave EC P-256, `alg=ES256`, mesmo `kid`.
- Código: `backend/app/routers/auth.py` → `jwt.decode(..., algorithms=["HS256"])` com `settings.SUPABASE_JWT_SECRET` (modelo legado simétrico).
- Alinha à migração Supabase: JWT Secret (HS256) → Signing keys assimétricas (ES256).

**Impacto atual:**
- +1 RTT por request autenticada (`GET /auth/v1/user`).
- Dependência de GoTrue disponível.
- Ruído de log; funcionalidade OK (E2E passou com fallback).

**Opções de correção (quando priorizar):**

| Opção | Ideia | Notas |
|---|---|---|
| **A (recomendada)** | Validar com **JWKS ES256**, cache de chaves por `kid` | Alinha ao Auth atual; elimina round-trip na maioria das requests |
| **B** | Aceitar **HS256 + ES256** (secret legado e JWKS) | Útil se ainda houver tokens HS256 em circulação |
| **C** | Manter **só fallback GoTrue** | Simples; latência permanente |
| **D** | Forçar emissão HS256 de novo no projeto | Depende de settings Supabase; frágil a longo prazo |

**Recomendação:** Opção **A** — verificação local via JWKS com cache por `kid`.

**Arquivos-alvo (quando implementar):** `backend/app/routers/auth.py` (+ possivelmente helper em `core/` e env docs).  
**Não fazer agora:** nenhuma mudança de código até decisão de sprint/P2.