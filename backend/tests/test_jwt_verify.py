"""Testes unitários da validação JWT local (TD-01 / JWKS)."""
import asyncio
from unittest.mock import AsyncMock, patch

import pytest
from jose import JWTError, jwt
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.backends import default_backend

from app.core import jwt_verify
from app.core.jwt_verify import (
    clear_jwks_cache,
    decode_hs256,
    _select_jwk,
    verify_supabase_jwt,
)


@pytest.fixture(autouse=True)
def _reset_jwks_cache():
    clear_jwks_cache()
    yield
    clear_jwks_cache()


def _make_ec_jwk_and_token(sub: str = "user-123", kid: str = "test-kid"):
    """Gera par EC P-256, JWK pública e access token ES256 assinado."""
    private_key = ec.generate_private_key(ec.SECP256R1(), default_backend())
    # python-jose ECKey from PEM
    pem = private_key.private_bytes(
        encoding=serialization.Encoding.PEM,
        format=serialization.PrivateFormat.PKCS8,
        encryption_algorithm=serialization.NoEncryption(),
    )
    public_numbers = private_key.public_key().public_numbers()

    def _int_to_b64u(n: int, size: int = 32) -> str:
        from jose.utils import base64url_encode

        return base64url_encode(n.to_bytes(size, "big")).decode("ascii")

    jwk_public = {
        "kty": "EC",
        "crv": "P-256",
        "x": _int_to_b64u(public_numbers.x),
        "y": _int_to_b64u(public_numbers.y),
        "kid": kid,
        "alg": "ES256",
        "use": "sig",
    }

    # Assina com a chave privada via cryptography + jose
    from jose.backends.cryptography_backend import CryptographyECKey

    signing_key = CryptographyECKey(pem, algorithm="ES256")
    token = jwt.encode(
        {"sub": sub, "email": "u@test.com", "role": "authenticated"},
        signing_key,
        algorithm="ES256",
        headers={"kid": kid},
    )
    return jwk_public, token


def test_select_jwk_by_kid():
    jwks = {"keys": [{"kid": "a"}, {"kid": "b"}]}
    assert _select_jwk(jwks, "b")["kid"] == "b"


def test_select_jwk_missing_kid_raises():
    jwks = {"keys": [{"kid": "a"}]}
    with pytest.raises(JWTError, match="kid"):
        _select_jwk(jwks, "missing")


def test_decode_hs256_roundtrip():
    secret = "test-secret-hs256-for-unit"
    token = jwt.encode({"sub": "hs-user", "role": "authenticated"}, secret, algorithm="HS256")
    payload = decode_hs256(token, secret)
    assert payload["sub"] == "hs-user"


def test_verify_es256_via_jwks():
    jwk_public, token = _make_ec_jwk_and_token()
    jwks = {"keys": [jwk_public]}

    async def _run():
        with patch.object(jwt_verify, "get_jwks", new=AsyncMock(return_value=jwks)):
            return await verify_supabase_jwt(token)

    payload = asyncio.run(_run())
    assert payload["sub"] == "user-123"
    assert payload["email"] == "u@test.com"


def test_verify_hs256_with_secret(monkeypatch):
    secret = "unit-hs256-secret"
    monkeypatch.setattr(jwt_verify.settings, "SUPABASE_JWT_SECRET", secret)
    token = jwt.encode({"sub": "legacy-user"}, secret, algorithm="HS256")
    payload = asyncio.run(verify_supabase_jwt(token))
    assert payload["sub"] == "legacy-user"


def test_verify_unsupported_alg():
    token = jwt.encode({"sub": "x"}, "s", algorithm="HS256")

    async def _run():
        with patch.object(jwt, "get_unverified_header", return_value={"alg": "none"}):
            await verify_supabase_jwt(token)

    with pytest.raises(JWTError, match="não suportado"):
        asyncio.run(_run())
