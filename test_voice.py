import httpx
import asyncio

async def test():
    async with httpx.AsyncClient(timeout=30) as client:
        files = {'file': ('test.m4a', b'1234567890', 'audio/mp4')}
        try:
            response = await client.post('https://aion-vvx7.onrender.com/voice/transcribe', files=files)
            print("Status:", response.status_code)
            print("Response:", response.text)
        except Exception as e:
            print("Error:", e)

asyncio.run(test())
