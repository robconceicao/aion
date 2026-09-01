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


def _missing_token() -> None:
    if TADEU_LICENSE_ENFORCED:
        raise HTTPException(
            status_code=403,
            detail={
                "error": "tadeu_license_required",
                "message": "Ative sua licença Tadeu Apps para continuar.",
            },
        )
    logger.warning("[TADEU] token ausente; validação ignorada em modo de transição")


def _handle_auth_or_quota(response: httpx.Response, feature: str, data: dict) -> None:
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


async def check_tadeu_quota(*, token: Optional[str], feature: str) -> dict | None:
    """Consulta a cota sem consumir nada, antes de chamar IA/voz."""
    if not token:
        _missing_token()
        return None

    try:
        async with httpx.AsyncClient(timeout=15.0) as client:
            response = await client.get(
                f"{TADEU_APPS_URL}/api/apps/aion/usage",
                headers={"Authorization": f"Bearer {token}"},
                params={"feature": feature},
            )
    except httpx.HTTPError as exc:
        logger.error("[TADEU][ERROR] quota indisponível: %s", exc)
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

    _handle_auth_or_quota(response, feature, data)

    if response.status_code >= 400:
        logger.error("[TADEU][ERROR] quota API HTTP %s: %s", response.status_code, data)
        if TADEU_LICENSE_ENFORCED:
            raise HTTPException(
                status_code=503,
                detail={
                    "error": "tadeu_metering_failed",
                    "message": "Não foi possível consultar sua cota. Tente novamente.",
                },
            )
        return None

    limit = data.get("limit")
    remaining = data.get("remaining")
    if limit is not None and remaining is not None and int(remaining) <= 0:
        raise HTTPException(
            status_code=429,
            detail={
                "error": "monthly_limit_exceeded",
                "feature": feature,
                "used": data.get("used"),
                "limit": limit,
                "remaining": remaining,
                "message": "Você atingiu o limite mensal do seu plano.",
            },
        )

    return data


async def consume_tadeu_usage(
    *,
    token: Optional[str],
    feature: str,
    amount: int = 1,
    idempotency_key: Optional[str] = None,
) -> dict | None:
    """Registra uso somente depois de a operação do AION concluir com sucesso."""
    if not token:
        _missing_token()
        return None

    payload = {"feature": feature, "amount": amount}
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

    _handle_auth_or_quota(response, feature, data)

    if response.status_code >= 400:
        logger.error("[TADEU][ERROR] usage API HTTP %s: %s", response.status_code, data)
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
