-- Internal API commands: no direct client access.
CREATE TABLE public.dream_commands (
 user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 command_id uuid NOT NULL, payload_hash text NOT NULL, lease_id uuid NOT NULL,
 state text NOT NULL CHECK(state IN ('running','generated','complete','failed','uncertain')),
 started_at timestamptz NOT NULL DEFAULT now(), dream jsonb, response jsonb,
 PRIMARY KEY(user_id,command_id)
);
ALTER TABLE public.dream_commands ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.dream_commands FROM PUBLIC, anon, authenticated;
GRANT ALL ON public.dream_commands TO service_role;

CREATE FUNCTION public.claim_dream_command(p_user_id uuid,p_command_id uuid,p_hash text,p_lease uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE c public.dream_commands; created integer;
BEGIN
 INSERT INTO public.dream_commands(user_id,command_id,payload_hash,lease_id,state)
 VALUES(p_user_id,p_command_id,p_hash,p_lease,'running') ON CONFLICT DO NOTHING;
 GET DIAGNOSTICS created = ROW_COUNT;
 SELECT * INTO STRICT c FROM public.dream_commands
 WHERE user_id=p_user_id AND command_id=p_command_id FOR UPDATE;
 IF c.payload_hash<>p_hash THEN RETURN jsonb_build_object('state','conflict'); END IF;
 IF c.state='complete' AND NOT EXISTS(SELECT 1 FROM public.dreams WHERE id=(c.dream->>'id')::uuid AND user_id=p_user_id)
 THEN RETURN jsonb_build_object('state','gone'); END IF;
 IF c.state='failed' THEN
  UPDATE public.dream_commands SET state='running',lease_id=p_lease,started_at=now()
  WHERE user_id=p_user_id AND command_id=p_command_id;
  RETURN jsonb_build_object('state','claimed');
 END IF;
 IF c.state='running' AND c.started_at < now()-interval '10 minutes' THEN
  UPDATE public.dream_commands SET state='uncertain' WHERE user_id=p_user_id AND command_id=p_command_id;
  RETURN jsonb_build_object('state','uncertain');
 END IF;
 IF created=1 OR (c.state='running' AND c.lease_id=p_lease) THEN
  RETURN jsonb_build_object('state','claimed');
 END IF;
 RETURN jsonb_build_object('state',c.state,'dream',c.dream,'response',c.response);
END $$;

CREATE FUNCTION public.checkpoint_dream_command(p_user_id uuid,p_command_id uuid,p_lease uuid,p_dream jsonb,p_response jsonb)
RETURNS void LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE c public.dream_commands;
BEGIN
 SELECT * INTO STRICT c FROM public.dream_commands WHERE user_id=p_user_id AND command_id=p_command_id FOR UPDATE;
 IF c.lease_id<>p_lease OR p_dream->>'user_id' IS DISTINCT FROM p_user_id::text OR p_dream->>'id' IS NULL
 OR p_response->>'id' IS DISTINCT FROM p_dream->>'id' THEN RAISE EXCEPTION 'Invalid command owner or result'; END IF;
 IF c.state IN ('generated','complete') THEN
  IF c.dream<>p_dream OR c.response<>p_response THEN RAISE EXCEPTION 'Different result for command'; END IF;
  RETURN;
 END IF;
 IF c.state NOT IN ('running','uncertain') THEN RAISE EXCEPTION 'Invalid command state'; END IF;
 UPDATE public.dream_commands SET state='generated',dream=p_dream,response=p_response
 WHERE user_id=p_user_id AND command_id=p_command_id;
END $$;

CREATE FUNCTION public.fail_dream_command(p_user_id uuid,p_command_id uuid,p_lease uuid)
RETURNS void LANGUAGE sql SECURITY INVOKER SET search_path = '' AS $$
 UPDATE public.dream_commands SET state='failed'
 WHERE user_id=p_user_id AND command_id=p_command_id AND lease_id=p_lease AND state='running';
$$;

CREATE FUNCTION public.complete_dream_command(p_user_id uuid,p_command_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE c public.dream_commands;
BEGIN
 SELECT * INTO STRICT c FROM public.dream_commands WHERE user_id=p_user_id AND command_id=p_command_id FOR UPDATE;
 IF c.state NOT IN ('generated','complete') OR NOT EXISTS(
 SELECT 1 FROM public.dreams WHERE id=(c.dream->>'id')::uuid AND user_id=p_user_id)
 THEN RAISE EXCEPTION 'Dream persistence not confirmed'; END IF;
 UPDATE public.dream_commands SET state='complete' WHERE user_id=p_user_id AND command_id=p_command_id;
 RETURN c.response;
END $$;

REVOKE ALL ON FUNCTION public.claim_dream_command(uuid,uuid,text,uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.checkpoint_dream_command(uuid,uuid,uuid,jsonb,jsonb) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.fail_dream_command(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION public.complete_dream_command(uuid,uuid) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.claim_dream_command(uuid,uuid,text,uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.checkpoint_dream_command(uuid,uuid,uuid,jsonb,jsonb) TO service_role;
GRANT EXECUTE ON FUNCTION public.fail_dream_command(uuid,uuid,uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_dream_command(uuid,uuid) TO service_role;
