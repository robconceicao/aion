from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from app.routers.auth import get_current_user
from app.services.voice_service import transcribe_audio
import os
import shutil
import uuid

router = APIRouter()

@router.post("/transcribe")
async def transcribe_voice(
    file: UploadFile = File(...)
):
    """
    Receives an audio file, transcribes it using Gemini, and returns the text.
    The file is stored temporarily and deleted after processing.
    """
    # Verify file type (basic extension check)
    extension = os.path.splitext(file.filename)[1]
    if extension not in ['.m4a', '.mp3', '.wav', '.ogg', '.aac', '.webm', '.flac']:
         raise HTTPException(status_code=400, detail="Unsupported audio format")

    temp_filename = f"temp_{uuid.uuid4()}{extension}"
    temp_path = os.path.join("/tmp", temp_filename)
    
    # Ensure /tmp exists (inside workspace context it might be different, but let's assume /tmp/aion)
    os.makedirs("/tmp/aion", exist_ok=True)
    temp_path = os.path.join("/tmp/aion", temp_filename)

    try:
        with open(temp_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        transcription = await transcribe_audio(temp_path)
        
        if not transcription:
            raise HTTPException(status_code=500, detail="Transcription failed")
            
        return {"text": transcription}
        
    finally:
        if os.path.exists(temp_path):
            os.remove(temp_path)
