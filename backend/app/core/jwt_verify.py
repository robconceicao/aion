"""
Validação local de JWT Supabase (TD-01).

Supabase Auth atual emite access tokens ES256 assinados com chaves
assimétricas publicadas em:
  {SUPABASE_URL}/auth/v1/.well-known/jwks.json

Tokens legados HS256 (JWT secret) ainda são aceitos quando
SUPABASE_JWT_SECRET estiver configurado.
"""
from __future__ import annotations

import time
from typing import Any

import httpx
from jose import JWTError, jwt

from app.core.config import settings

# Cache em processo: JWKS raramente muda (rotação de chave).
_JWKS_CACHE: dict[str, Any] = {"data": None, "fetched_at": 0.0}
_JWKS_TTL_SECONDS = 3600.0


def _jwks_url() -> str:
    base = (settings.SUPABASE_URL or "").rstrip("/")
    if not base:
        raise JWTError("SUPABASE_URL não configurada — impossível buscar JWKS")
    return f"{base}/auth/v1/.well-known/jwks.json"


async def get_jwks(*, force_refresh: bool = False) -> dict[str, Any]:
    """Busca e cacheia o JWKS do projeto Supabase."""
    now = time.time()
    cached = _JWKS_CACHE["data"]
    if (
        not force_refresh
        and cached is not None
        and (now - float(_JWKS_CACHE["fetched_at"])) < _JWKS_TTL_SECONDS
    ):
        return cached

    url = _jwks_url()
    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.get(url)
        if response.status_code != 200:
            raise JWTError(
                f"Falha ao obter JWKS ({response.status_code}): {response.text[:200]}"
            )
        data = response.json()

    if not isinstance(data, dict) or not data.get("keys"):
        raise JWTError("JWKS inválido: sem chaves")

    _JWKS_CACHE["data"] = data
    _JWKS_CACHE["fetched_at"] = now
    return data


def clear_jwks_cache() -> None:
    """Utilitário de teste."""
    _JWKS_CACHE["data"] = None
    _JWKS_CACHE["fetched_at"] = 0.0


def _select_jwk(jwks: dict[str, Any], kid: str | None) -> dict[str, Any]:
    keys = jwks.get("keys") or []
    if not keys:
        raise JWTError("JWKS sem chaves")
    if kid:
        for key in keys:
            if key.get("kid") == kid:
                return key
        raise JWTError(f"Nenhuma JWK com kid={kid}")
    if len(keys) == 1:
        return keys[0]
    raise JWTError("Token sem kid e JWKS com múltiplas chaves")


def decode_with_jwk(token: str, jwk_dict: dict[str, Any], algorithms: list[str]) -> dict:
    """Decodifica e verifica assinatura com uma chave JWK (dict)."""
    return jwt.decode(
        token,
        jwk_dict,
        algorithms=algorithms,
        options={"verify_aud": False},
    )


def decode_hs256(token: str, secret: str) -> dict:
    return jwt.decode(
        token,
        secret,
        algorithms=["HS256"],
        options={"verify_aud": False},
    )


async def verify_supabase_jwt(token: str) -> dict:
    """
    Verifica o access token localmente.

    Ordem:
      1. ES256/RS* via JWKS (alg do header)
      2. HS256 via SUPABASE_JWT_SECRET (legado)
    Em falha de kid (rotação), tenta um refresh forçado do JWKS uma vez.

    Levanta JWTError se a validação local falhar por completo.
    """
    try:
        header = jwt.get_unverified_header(token)
    except Exception as e:
        raise JWTError(f"Header JWT inválido: {e}") from e

    alg = header.get("alg") or ""
    kid = header.get("kid")

    # 1) Assinatura assimétrica (ES256 atual do Supabase; RS256 em alguns setups)
    if alg.startswith("ES") or alg.startswith("RS"):
        last_err: Exception | None = None
        for force in (False, True):
            try:
                jwks = await get_jwks(force_refresh=force)
                jwk_dict = _select_jwk(jwks, kid)
                payload = decode_with_jwk(token, jwk_dict, algorithms=[alg])
                if payload.get("sub"):
                    return payload
                raise JWTError("Token sem claim sub")
            except JWTError as e:
                last_err = e
                # Segunda passagem com force_refresh só se kid não bateu
                if force or "kid" not in str(e).lower():
                    break
                continue
        raise JWTError(f"Validação JWKS falhou: {last_err}")

    # 2) HS256 legado
    if alg == "HS256":
        secret = (settings.SUPABASE_JWT_SECRET or "").strip()
        if not secret:
            raise JWTError("Token HS256 mas SUPABASE_JWT_SECRET ausente")
        payload = decode_hs256(token, secret)
        if payload.get("sub"):
            return payload
        raise JWTError("Token HS256 sem claim sub")

    raise JWTError(f"Algoritmo JWT não suportado localmente: {alg}")
