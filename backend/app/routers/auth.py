from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError
from app.core.config import settings
from app.core.jwt_verify import verify_supabase_jwt
from app.database import get_supabase_service
import logging

logger = logging.getLogger(__name__)

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
            # Não logar body completo (pode conter detalhes internos).
            print(f"[AUTH FALLBACK FAILED] Status: {response.status_code}")
    except Exception as e:
        print(f"[AUTH] Erro ao consultar a API do Supabase: {type(e).__name__}")

    raise _unauthorized("invalid_token")


def _is_admin_flag(value) -> bool:
    """Aceita bool True ou strings comuns setadas via service_role no Auth."""
    if value is True:
        return True
    if isinstance(value, str) and value.strip().lower() in ("true", "1", "yes"):
        return True
    return False


async def get_current_admin(current_user: dict = Depends(get_current_user)):
    """
    Admin somente via app_metadata.is_admin (claim não controlável pelo usuário).

    NÃO confiar em user_metadata (editável via updateUser) nem em e-mail hardcoded.
    Promover admin no SQL Editor do Supabase:
      UPDATE auth.users
      SET raw_app_meta_data = raw_app_meta_data || '{"is_admin": true}'::jsonb
      WHERE email = '...';
    """
    app_metadata = current_user.get("app_metadata") or {}
    if not isinstance(app_metadata, dict):
        app_metadata = {}

    if not _is_admin_flag(app_metadata.get("is_admin")):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User does not have admin privileges",
        )
    return current_user


@router.get("/me")
async def read_users_me(current_user: dict = Depends(get_current_user)):
    return current_user


@router.delete("/account")
async def delete_account(current_user: dict = Depends(get_current_user)):
    """
    Exclui a conta do usuário autenticado e todos os seus dados (LGPD art. 18, VI —
    eliminação dos dados pessoais tratados com consentimento).

    Ordem: apaga os sonhos (Supabase) primeiro; só então remove o usuário do
    Auth do Supabase. Se a remoção do Auth falhar após os sonhos já terem sido
    apagados, o usuário é avisado para tentar de novo — os dados de sonho já
    não existem mais de qualquer forma.
    """
    user_id = current_user.get("sub")
    if not user_id:
        raise HTTPException(status_code=400, detail="Usuário inválido.")

    service = get_supabase_service()

    try:
        service.table("dreams").delete().eq("user_id", user_id).execute()
    except Exception as e:
        logger.error("[AUTH][ERROR] falha ao excluir sonhos user_id=%s: %s", user_id, e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail={"error": "delete_failed", "message": "Erro ao excluir os dados do usuário."},
        )

    try:
        service.auth.admin.delete_user(user_id)
    except Exception as e:
        logger.error("[AUTH][ERROR] falha ao excluir usuário do Auth user_id=%s: %s", user_id, e, exc_info=True)
        raise HTTPException(
            status_code=500,
            detail={
                "error": "delete_failed",
                "message": "Seus sonhos foram removidos, mas houve falha ao excluir a conta. Tente novamente ou contate o suporte.",
            },
        )

    return {"deleted": True}
