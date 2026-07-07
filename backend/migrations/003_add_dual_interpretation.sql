-- Migration 003 -- Interpretação dual (analise_completa + interpretacao_narrativa + áudio)
-- Aplicada em: 2026-07-07
-- Referência: SPEC §5.3 (persistência atômica) e §6.1 (schema de síntese)
--
-- INVARIANTE DE NEGÓCIO:
--   Os campos analise_completa, interpretacao_narrativa e pergunta_reflexao
--   são SEMPRE gravados juntos, na mesma transação, pelo backend.
--   O banco NÃO garante isso sozinho — os defaults vazios existem apenas
--   para compatibilidade com linhas legadas (interpretações anteriores a esta migration).
--   A garantia é por construção em synthesize_dual() + _background_save_and_recurrence().
--
-- TRATAMENTO DE LEGADO:
--   Linhas anteriores ficam com analise_completa='{}' e interpretacao_narrativa=''.
--   O cliente Flutter detecta analise_completa={} e exibe modo somente-narrativa
--   (lê de interpretacao.narrative como antes). Re-síntese retroativa é P2.

ALTER TABLE dreams
    ADD COLUMN IF NOT EXISTS analise_completa        JSONB        NOT NULL DEFAULT '{}'::jsonb,
    ADD COLUMN IF NOT EXISTS interpretacao_narrativa TEXT         NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS pergunta_reflexao        TEXT         NOT NULL DEFAULT '',
    ADD COLUMN IF NOT EXISTS audio_path              TEXT         NULL,
    ADD COLUMN IF NOT EXISTS audio_gerado_em         TIMESTAMPTZ  NULL;
