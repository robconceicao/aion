from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError
from app.core.config import settings
from app.core.jwt_verify import verify_supabase_jwt

router = APIRouter()
# auto_error=False: sem header não vira 403 genérico do HTTPBearer —
# devolvemos 401 explícito (missing_token vs invalid_token) para o app diagnosticar.
security = HTTPBearer(auto_error=False)


def _unauthorized(detail: str) -> HTTPException:
    return HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=detail,
        headers={"WWW-Authenticate": "Bearer"},
    )


async def get_current_user(
    token: HTTPAuthorizationCredentials | None = Depends(security),
):
    """
    Verifica o Supabase JWT e devolve o payload do usuário.

    Ordem (TD-01):
      1. Header Authorization obrigatório (senão 401 missing_token)
      2. Validação local — ES256/RS* via JWKS, ou HS256 via SUPABASE_JWT_SECRET
      3. Fallback GoTrue GET /auth/v1/user (rede; só se local falhar)

    Nota: HTTP 403 do FastAPI HTTPBearer (auto_error=True) significava
    "sem Bearer" — isso confundia com falha de JWT. Agora missing = 401.
    """
    if token is None or not (token.credentials or "").strip():
        print("[AUTH] Request sem Authorization Bearer — missing_token")
        raise _unauthorized("missing_token")

    raw = token.credentials.strip()

    # 1. Validação local (JWKS ES256 ou HS256 legado)
    try:
        payload = await verify_supabase_jwt(raw)
        return payload
    except JWTError as e:
        print(f"[AUTH] Validação local falhou: {e}. Tentando fallback GoTrue...")

    # 2. Fallback: API GoTrue do Supabase
    print("[AUTH] Usando verificação via API do Supabase como fallback.")
    try:
        import httpx

        headers = {
            "apikey": settings.SUPABASE_KEY,
            "Authorization": f"Bearer {raw}",
        }
        base_url = settings.SUPABASE_URL.rstrip("/")

        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{base_url}/auth/v1/user", headers=headers, timeout=10.0
            )
            if response.status_code == 200:
                user_data = response.json()
                return {
                    "sub": user_data.get("id"),
                    "email": user_data.get("email"),
                    "app_metadata": user_data.get("app_metadata", {}),
                    "user_metadata": user_data.get("user_metadata", {}),
                }
            print(f"[AUTH FALLBACK FAILED] Status: {response.status_code}")
            print(f"[AUTH FALLBACK FAILED] Body: {response.text}")
            print(f"[AUTH FALLBACK FAILED] URL Called: {base_url}/auth/v1/user")
    except Exception as e:
        print(f"[AUTH] Erro ao consultar a API do Supabase: {e}")

    raise _unauthorized("invalid_token")


async def get_current_admin(current_user: dict = Depends(get_current_user)):
    """
    Dependency to check if the current user is an admin.
    """
    app_metadata = current_user.get("app_metadata", {})
    user_metadata = current_user.get("user_metadata", {})

    is_admin = (
        app_metadata.get("is_admin", False)
        or user_metadata.get("is_admin", False)
        or current_user.get("is_admin", False)
        or current_user.get("email") == "admin@aion.app"
    )
    if not is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User does not have admin privileges",
        )
    return current_user


@router.get("/me")
async def read_users_me(current_user: dict = Depends(get_current_user)):
    return current_user
