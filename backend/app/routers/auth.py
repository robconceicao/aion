from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import JWTError, jwt
from app.core.config import settings
from app.database import get_supabase

router = APIRouter()
security = HTTPBearer()

async def get_current_user(token: HTTPAuthorizationCredentials = Depends(security)):
    """
    Dependency to verify the Supabase JWT and return the user payload.
    """
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    
    # 1. Tenta decodificar localmente se SUPABASE_JWT_SECRET estiver configurado
    if settings.SUPABASE_JWT_SECRET:
        try:
            payload = jwt.decode(
                token.credentials, 
                settings.SUPABASE_JWT_SECRET, 
                algorithms=["HS256"],
                options={"verify_aud": False}
            )
            user_id: str = payload.get("sub")
            if user_id is not None:
                return payload
        except JWTError as e:
            print(f"Local JWT Error: {e}. Tentando fallback via API do Supabase...")

    # 2. Fallback: Consulta a API do Supabase GoTrue diretamente para validar o token
    print("[AUTH] Usando verificação via API do Supabase como fallback.")
    try:
        import httpx
        headers = {
            "apikey": settings.SUPABASE_KEY,
            "Authorization": f"Bearer {token.credentials}"
        }
        async with httpx.AsyncClient() as client:
            response = await client.get(f"{settings.SUPABASE_URL}/auth/v1/user", headers=headers, timeout=10.0)
            if response.status_code == 200:
                user_data = response.json()
                mapped_payload = {
                    "sub": user_data.get("id"),
                    "email": user_data.get("email"),
                    "app_metadata": user_data.get("app_metadata", {}),
                    "user_metadata": user_data.get("user_metadata", {}),
                }
                return mapped_payload
            else:
                print(f"[AUTH] Falha na validação via API: HTTP {response.status_code} - {response.text}")
    except Exception as e:
        print(f"[AUTH] Erro ao consultar a API do Supabase: {e}")
        
    raise credentials_exception

async def get_current_admin(current_user: dict = Depends(get_current_user)):
    """
    Dependency to check if the current user is an admin.
    """
    app_metadata = current_user.get("app_metadata", {})
    user_metadata = current_user.get("user_metadata", {})
    
    # Check admin flags in JWT payload (from Supabase auth app/user metadata)
    is_admin = (
        app_metadata.get("is_admin", False) or 
        user_metadata.get("is_admin", False) or 
        current_user.get("is_admin", False) or
        # Fallback admin email
        current_user.get("email") == "admin@aion.app"
    )
    if not is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="User does not have admin privileges"
        )
    return current_user

@router.get("/me")
async def read_users_me(current_user: dict = Depends(get_current_user)):
    return current_user

# Note: /login and /register are typically handled by the Supabase Frontend SDK
# but we can add proxy endpoints here if needed for specific logic.
