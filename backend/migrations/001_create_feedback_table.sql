-- Migration 001 — Cria a tabela feedback
-- Aplicada em: 2026-06-14
-- Referência: B-02 (migração MongoDB → Supabase)

CREATE TABLE IF NOT EXISTS feedback (
    id                  uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    dream_id            uuid        NOT NULL REFERENCES dreams(id) ON DELETE CASCADE,
    user_id             uuid,
    rating              int         NOT NULL,
    comment             text,
    accurate_archetypes bool,
    created_at          timestamptz DEFAULT now()
);

-- RLS
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;

CREATE POLICY "usuarios gerenciam seu proprio feedback"
    ON feedback
    FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);
