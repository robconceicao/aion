import logging
import os
from typing import Optional

import httpx
from fastapi import HTTPException

logger = logging.getLogger(__name__)

TADEU_APPS_URL = os.getenv(
    "TADEU_APPS_URL",
    "https://tadeu-apps-core-test2.vercel.app",
).rstrip("/")
TADEU_LICENSE_ENFORCED = os.getenv("TADEU_LICENSE_ENFORCED", "false").lower() in {
    "1",
    "true",
    "yes",
    "on",
}


async def consume_tadeu_usage(
    *,
    token: Optional[str],
    feature: str,
    amount: int = 1,
    idempotency_key: Optional[str] = None,
) -> dict | None:
    """Registra uso apenas após a operação do AION ter sido concluída.

    Durante a transição, builds antigos sem X-Tadeu-Token continuam funcionando
    enquanto TADEU_LICENSE_ENFORCED=false. Builds novos sempre enviam o token e
    passam a ser medidos imediatamente.
    """
    if not token:
        if TADEU_LICENSE_ENFORCED:
            raise HTTPException(
                status_code=403,
                detail={
                    "error": "tadeu_license_required",
                    "message": "Ative sua licença Tadeu Apps para continuar.",
                },
            )
        logger.warning("[TADEU] token ausente; metering ignorado em modo de transição")
        return None

    payload = {
        "feature": feature,
        "amount": amount,
    }
    if idempotency_key:
        payload["idempotencyKey"] = idempotency_key[:200]

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.post(
                f"{TADEU_APPS_URL}/api/apps/aion/usage",
                headers={"Authorization": f"Bearer {token}"},
                json=payload,
            )
    except httpx.HTTPError as exc:
        logger.error("[TADEU][ERROR] metering indisponível: %s", exc)
        if TADEU_LICENSE_ENFORCED:
            raise HTTPException(
                status_code=503,
                detail={
                    "error": "tadeu_metering_unavailable",
                    "message": "Não foi possível validar sua cota agora. Tente novamente.",
                },
            ) from exc
        return None

    try:
        data = response.json()
    except ValueError:
        data = {}

    if response.status_code == 429:
        raise HTTPException(
            status_code=429,
            detail={
                "error": "monthly_limit_exceeded",
                "feature": feature,
                "used": data.get("used"),
                "limit": data.get("limit"),
                "remaining": data.get("remaining"),
                "message": "Você atingiu o limite mensal do seu plano.",
            },
        )

    if response.status_code in {401, 403}:
        raise HTTPException(
            status_code=403,
            detail={
                "error": "tadeu_license_denied",
                "feature": feature,
                "message": "Sua licença Tadeu Apps não permite esta operação.",
            },
        )

    if response.status_code >= 400:
        logger.error(
            "[TADEU][ERROR] usage API HTTP %s: %s",
            response.status_code,
            data,
        )
        if TADEU_LICENSE_ENFORCED:
            raise HTTPException(
                status_code=503,
                detail={
                    "error": "tadeu_metering_failed",
                    "message": "Não foi possível registrar o uso. Tente novamente.",
                },
            )
        return None

    return data
