from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from app.core.config import settings
from app.routers import dreams, auth, analytics, feedback, voice, episodes, interpretacoes
from app.services.tadeu_metering import check_tadeu_quota, consume_tadeu_usage

app = FastAPI(title=settings.PROJECT_NAME)

# CORS setup
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.allowed_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _metered_feature(request: Request) -> str | None:
    if request.method.upper() != "POST":
        return None

    path = request.url.path.rstrip("/")
    if path == "/dreams":
        return "ai_analyses_monthly"

    parts = [part for part in path.split("/") if part]
    if len(parts) == 3 and parts[0] == "interpretacoes" and parts[2] == "narracao":
        return "premium_narrations_monthly"

    return None


def _http_exception_response(exc: HTTPException) -> JSONResponse:
    return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})


@app.middleware("http")
async def tadeu_usage_metering(request: Request, call_next):
    """Pré-checa a cota e registra uso apenas quando o endpoint termina em 2xx.

    A transcrição possui integração dentro do próprio router porque precisa
    validar o arquivo antes da pré-checagem. Aqui ficam apenas a síntese final
    do sonho e a narração Premium.
    """
    feature = _metered_feature(request)
    if feature is None:
        return await call_next(request)

    token = request.headers.get("X-Tadeu-Token")
    idempotency_key = request.headers.get("X-Tadeu-Idempotency-Key")

    try:
        await check_tadeu_quota(token=token, feature=feature)
    except HTTPException as exc:
        return _http_exception_response(exc)

    response = await call_next(request)
    if not 200 <= response.status_code < 300:
        return response

    try:
        await consume_tadeu_usage(
            token=token,
            feature=feature,
            amount=1,
            idempotency_key=idempotency_key,
        )
    except HTTPException as exc:
        return _http_exception_response(exc)

    return response


# Routes
app.include_router(auth.router, prefix="/auth", tags=["Authentication"])
app.include_router(dreams.router, prefix="/dreams", tags=["Dreams"])
app.include_router(feedback.router, prefix="/dreams", tags=["Feedback"])
app.include_router(analytics.router, prefix="/admin", tags=["Analytics"])
app.include_router(voice.router, prefix="/voice", tags=["Voice"])
app.include_router(episodes.router, prefix="/episodes", tags=["Canal"])
app.include_router(interpretacoes.router, prefix="/interpretacoes", tags=["Interpretacoes"])


@app.get("/")
async def root():
    return {"message": f"Welcome to {settings.PROJECT_NAME} API - Aion está ativo."}
