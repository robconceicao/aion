-- 006_rls_policies.sql
--
-- Versiona as políticas de RLS que já existiam APENAS no painel do Supabase.
--
-- Contexto: até esta migration, as únicas políticas versionadas eram as de
-- `feedback` (001) e `narracao_cache` (005). As de `dreams`, `episodes` e do
-- bucket de Storage viviam só no painel — não revisáveis em code review, não
-- reproduzíveis num projeto novo, e impossíveis de auditar sem acesso ao
-- console.
--
-- Este arquivo é uma TRANSCRIÇÃO do estado real levantado em 2026-09-04 via
-- pg_policies, não uma proposta de como as políticas deveriam ser. Qualquer
-- endurecimento futuro deve vir em migration própria, para que a mudança de
-- comportamento fique separada do registro do que já existia.
--
-- Idempotente: pode ser aplicado sobre um banco que já tem as políticas.
--
-- Envolvido em transação: cada política é recriada com DROP + CREATE, e entre
-- os dois há um instante sem política. Num arquivo de segurança esse instante
-- não pode ficar exposto — BEGIN/COMMIT garante que ninguém observe o estado
-- intermediário, e que uma falha no meio não deixe tabela sem proteção.

BEGIN;

-- ─────────────────────────────────────────────────────────────────────────
-- public.dreams — cada usuário só enxerga e altera os próprios sonhos
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.dreams ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS dreams_select ON public.dreams;
CREATE POLICY dreams_select ON public.dreams AS PERMISSIVE FOR SELECT TO public
    USING ((auth.uid() = user_id));

DROP POLICY IF EXISTS dreams_insert ON public.dreams;
CREATE POLICY dreams_insert ON public.dreams AS PERMISSIVE FOR INSERT TO public
    WITH CHECK ((auth.uid() = user_id));

DROP POLICY IF EXISTS dreams_update ON public.dreams;
CREATE POLICY dreams_update ON public.dreams AS PERMISSIVE FOR UPDATE TO public
    USING ((auth.uid() = user_id));

DROP POLICY IF EXISTS dreams_delete ON public.dreams;
CREATE POLICY dreams_delete ON public.dreams AS PERMISSIVE FOR DELETE TO public
    USING ((auth.uid() = user_id));

-- Nota (não alterado aqui, de propósito): estas políticas são `TO public`, que
-- no Supabase inclui o role `anon`. Não há brecha — para o anon `auth.uid()` é
-- NULL e `NULL = user_id` nunca é verdadeiro, o que foi confirmado por sonda
-- com a anon key (Content-Range: */0). Ainda assim `TO authenticated` seria
-- mais apertado e expressaria melhor a intenção. Mudança de comportamento →
-- migration própria.

-- ─────────────────────────────────────────────────────────────────────────
-- public.episodes — leitura pública; escrita apenas para administradores
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.episodes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Permitir leitura pública de episódios" ON public.episodes;
CREATE POLICY "Permitir leitura pública de episódios" ON public.episodes AS PERMISSIVE FOR SELECT TO public
    USING (true);

DROP POLICY IF EXISTS "Permitir inserção apenas para administradores" ON public.episodes;
CREATE POLICY "Permitir inserção apenas para administradores" ON public.episodes AS PERMISSIVE FOR INSERT TO authenticated
    WITH CHECK ((COALESCE((((auth.jwt() -> 'app_metadata'::text) ->> 'is_admin'::text))::boolean, false) = true));

DROP POLICY IF EXISTS "Permitir atualização apenas para administradores" ON public.episodes;
CREATE POLICY "Permitir atualização apenas para administradores" ON public.episodes AS PERMISSIVE FOR UPDATE TO authenticated
    USING ((COALESCE((((auth.jwt() -> 'app_metadata'::text) ->> 'is_admin'::text))::boolean, false) = true))
    WITH CHECK ((COALESCE((((auth.jwt() -> 'app_metadata'::text) ->> 'is_admin'::text))::boolean, false) = true));

DROP POLICY IF EXISTS "Permitir deleção apenas para administradores" ON public.episodes;
CREATE POLICY "Permitir deleção apenas para administradores" ON public.episodes AS PERMISSIVE FOR DELETE TO authenticated
    USING ((COALESCE((((auth.jwt() -> 'app_metadata'::text) ->> 'is_admin'::text))::boolean, false) = true));

-- A checagem de admin lê `app_metadata.is_admin` do JWT — o mesmo claim que
-- get_current_admin() usa em app/routers/auth.py. O claim não é editável pelo
-- usuário (ao contrário de user_metadata), então a barreira é real.
--
-- Atenção ao promover admin: o valor precisa ser castável para boolean pelo
-- Postgres. `true`, `'true'`, `'1'` e `'yes'` funcionam; um valor como `'sim'`
-- faria o CAST levantar erro DENTRO da policy — a escrita falharia com erro de
-- banco em vez de simplesmente negar. Preferir o booleano JSON puro:
--   UPDATE auth.users
--   SET raw_app_meta_data = raw_app_meta_data || '{"is_admin": true}'::jsonb
--   WHERE email = '...';

-- ─────────────────────────────────────────────────────────────────────────
-- public.feedback — já versionado em 001, repetido aqui só por completude
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.feedback ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "usuarios gerenciam seu proprio feedback" ON public.feedback;
CREATE POLICY "usuarios gerenciam seu proprio feedback" ON public.feedback AS PERMISSIVE FOR ALL TO public
    USING ((auth.uid() = user_id))
    WITH CHECK ((auth.uid() = user_id));

-- ─────────────────────────────────────────────────────────────────────────
-- public.narracao_cache — leitura própria; escrita só via service_role
-- ─────────────────────────────────────────────────────────────────────────
ALTER TABLE public.narracao_cache ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS narracao_cache_select_own ON public.narracao_cache;
CREATE POLICY narracao_cache_select_own ON public.narracao_cache AS PERMISSIVE FOR SELECT TO public
    USING ((auth.uid() = user_id));

-- Ausência de políticas de INSERT/UPDATE/DELETE aqui é INTENCIONAL, não
-- lacuna: o backend escreve com service_role, que contorna RLS. Sem política,
-- nenhum cliente anon/authenticated consegue escrever — que é o desejado.

-- ─────────────────────────────────────────────────────────────────────────
-- storage.objects — bucket `interpretacoes-audio` (privado)
-- ─────────────────────────────────────────────────────────────────────────
-- O bucket foi confirmado como `public = false`. Só o service_role acessa os
-- objetos; o cliente recebe signed URLs, que funcionam pela assinatura e não
-- dependem destas políticas.
--
-- A migration 004 descrevia isto apenas em comentário, nunca como SQL
-- executável. Aqui vira DDL de verdade.

DROP POLICY IF EXISTS audio_select_service_role ON storage.objects;
CREATE POLICY audio_select_service_role ON storage.objects AS PERMISSIVE FOR SELECT TO service_role
    USING ((bucket_id = 'interpretacoes-audio'::text));

DROP POLICY IF EXISTS audio_insert_service_role ON storage.objects;
CREATE POLICY audio_insert_service_role ON storage.objects AS PERMISSIVE FOR INSERT TO service_role
    WITH CHECK ((bucket_id = 'interpretacoes-audio'::text));

DROP POLICY IF EXISTS audio_update_service_role ON storage.objects;
CREATE POLICY audio_update_service_role ON storage.objects AS PERMISSIVE FOR UPDATE TO service_role
    USING ((bucket_id = 'interpretacoes-audio'::text))
    WITH CHECK ((bucket_id = 'interpretacoes-audio'::text));

DROP POLICY IF EXISTS audio_delete_service_role ON storage.objects;
CREATE POLICY audio_delete_service_role ON storage.objects AS PERMISSIVE FOR DELETE TO service_role
    USING ((bucket_id = 'interpretacoes-audio'::text));

COMMIT;
