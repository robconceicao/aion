import google.generativeai as genai
from app.core.config import settings
import os

genai.configure(api_key=settings.GEMINI_API_KEY)

async def transcribe_audio(audio_path: str):
    """
    Transcribes audio using Gemini 1.5 Flash (Multimodal).
    The file is uploaded to Gemini and then analyzed.
    """
    try:
        # Use Gemini 3 Flash for maximum performance and multimodal accuracy
        model = genai.GenerativeModel('gemini-3-flash')
        
        # Upload the file
        sample_file = genai.upload_file(path=audio_path, display_name="Dream Record")
        
        # Generate content with prompt
        response = model.generate_content([
            "Transcreva este áudio de um sonho. Remova hesitações e foque no conteúdo literal.",
            sample_file
        ])
        
        # Cleanup file from Gemini server (optional but good practice)
        # genai.delete_file(sample_file.name) 
        
        return response.text.strip()
    except Exception as e:
        print(f"Error in transcription: {e}")
        return None
