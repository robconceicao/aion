"""Durable commands; identity is verified before calling this service."""
import asyncio
import hashlib
import json
import uuid
from fastapi import HTTPException


async def execute_dream_command(service, owner, command_id, payload, generate, persist, after_persist=None):
    lease = str(uuid.uuid4())
    params = {"p_user_id": owner, "p_command_id": str(command_id)}
    digest = hashlib.sha256(json.dumps(payload, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()

    async def rpc(name, arguments):
        # Retry database operations with the same lease, never the external AI.
        for attempt in range(3):
            try:
                result = await asyncio.to_thread(lambda: service.rpc(name, arguments).execute())
                return result.data
            except Exception:
                if attempt == 2:
                    raise HTTPException(503, detail={"error": "command_storage_unavailable", "message": "Não foi possível confirmar a operação. Repita a mesma solicitação."})
                await asyncio.sleep(0.1 * (attempt + 1))

    claimed = await rpc("claim_dream_command", {**params, "p_hash": digest, "p_lease": lease})
    state = claimed["state"]
    if state == "complete":
        return claimed["response"]
    if state not in ("claimed", "generated"):
        messages = {
            "running": "Sua análise ainda está em processamento. Aguarde e consulte novamente.",
            "uncertain": "O processamento foi interrompido sem confirmação. Seu rascunho foi preservado; é necessária revisão antes de gerar outra análise.",
            "conflict": "Esta solicitação já foi enviada com outras respostas. Recupere o rascunho original.",
            "gone": "O sonho desta solicitação foi excluído.",
        }
        raise HTTPException(409, detail={"error": "command_" + state, "message": messages.get(state, "Operação pendente")})
    if state == "claimed":
        try:
            dream, response = await generate()
        except HTTPException as error:
            # Explicit exhausted providers produced no valid synthesis. Unexpected
            # failures retain the reservation for safe operator reconciliation.
            if isinstance(error.detail, dict) and error.detail.get("error") == "synthesis_failed":
                await rpc("fail_dream_command", {**params, "p_lease": lease})
            raise
        await rpc("checkpoint_dream_command", {**params, "p_lease": lease, "p_dream": dream, "p_response": response})
    else:
        dream, response = claimed["dream"], claimed["response"]
    try:
        await persist(dream)
    except Exception:
        raise HTTPException(503, detail={"error": "persist_failed", "message": "A análise está preservada. Repita a solicitação para concluir o salvamento."})
    result = await rpc("complete_dream_command", params)
    if after_persist:
        after_persist(dream)
    return result
