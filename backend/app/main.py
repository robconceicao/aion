from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.core.config import settings
from app.routers import dreams, auth, analytics, feedback, voice, episodes

app = FastAPI(title=settings.PROJECT_NAME)

# CORS setup
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Routes
app.include_router(auth.router, prefix="/auth", tags=["Authentication"])
app.include_router(dreams.router, prefix="/dreams", tags=["Dreams"])
app.include_router(analytics.router, prefix="/admin", tags=["Analytics"])
app.include_router(feedback.router, prefix="/feedback", tags=["Feedback"])
app.include_router(voice.router, prefix="/voice", tags=["Voice"])
app.include_router(episodes.router, prefix="/episodes", tags=["Canal"])

@app.get("/")
async def root():
    return {"message": f"Welcome to {settings.PROJECT_NAME} API - Aion está ativo."}
