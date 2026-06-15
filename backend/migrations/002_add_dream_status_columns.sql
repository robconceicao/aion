-- Migration 002 -- Adiciona colunas de status a tabela dreams
-- Aplicada em: 2026-06-14
-- Referencia: A-02 (embedding_status) e A-03 (interpretation_status)
-- Default 'ok' garante que registros existentes nao quebrem queries de status.

ALTER TABLE dreams
    ADD COLUMN IF NOT EXISTS interpretation_status text NOT NULL DEFAULT 'ok',
    ADD COLUMN IF NOT EXISTS embedding_status      text NOT NULL DEFAULT 'ok';
