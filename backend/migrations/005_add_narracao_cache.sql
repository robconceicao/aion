-- Migration 005 -- Cache de narração multi-provider (ElevenLabs)
-- Referência: task "Aion: narração da interpretação via ElevenLabs" (Fase 2)
--
-- POR QUE UMA TABELA NOVA (e não reaproveitar dreams.audio_path):
--   dreams.audio_path é 1:1 com o sonho e assume um único provider (Edge TTS).
--   ElevenLabs precisa coexistir com o Edge TTS existente, e o mesmo sonho pode
--   ter múltiplos áudios cacheados (um por combinação de voice_id/model_id/
--   voice_settings — mudar a voz não deve invalidar o cache de outra voz).
--   Por isso o cache é chaveado por hash, não por dream_id.
--
-- CHAVE DE CACHE (calculada em app/services/tts_service.py):
--   sha256(texto_sanitizado + voice_id + model_id + serialização_ordenada_das_voice_settings)
--
-- GUARDA DE CUSTO (Fase 2):
--   Cada linha nesta tabela representa uma geração REAL (cache miss) cobrada
--   pela ElevenLabs. Cache hits não inserem linha nova, então não contam
--   contra o limite diário por usuário — a contagem é COUNT(*) desta tabela
--   filtrado por user_id e created_at >= início do dia.

CREATE TABLE IF NOT EXISTS narracao_cache (
    id                UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    dream_id          UUID         NOT NULL REFERENCES dreams(id) ON DELETE CASCADE,
    user_id           UUID         NOT NULL,
    provider          TEXT         NOT NULL,
    cache_key         TEXT         NOT NULL UNIQUE,
    storage_path      TEXT         NOT NULL,
    voice_id          TEXT         NOT NULL,
    model_id          TEXT         NOT NULL,
    duracao_segundos  NUMERIC      NULL,
    created_at        TIMESTAMPTZ  NOT NULL DEFAULT now()
);

-- Guarda de custo diário: filtra por user_id + janela de tempo.
CREATE INDEX IF NOT EXISTS idx_narracao_cache_user_created
    ON narracao_cache (user_id, created_at);

-- Lookup do cache é sempre por cache_key (já é UNIQUE, mas o índice explícito
-- documenta a intenção e cobre o caso de o UNIQUE constraint ser removido no futuro).
CREATE INDEX IF NOT EXISTS idx_narracao_cache_key
    ON narracao_cache (cache_key);

ALTER TABLE narracao_cache ENABLE ROW LEVEL SECURITY;

-- Mesmo padrão de dreams: usuário só enxerga as próprias linhas.
-- O backend usa service_role (bypassa RLS) e filtra .eq("user_id", user_id)
-- manualmente, igual ao endpoint /interpretacoes/{id}/audio existente.
CREATE POLICY "narracao_cache_select_own" ON narracao_cache
    FOR SELECT
    USING (auth.uid() = user_id);
