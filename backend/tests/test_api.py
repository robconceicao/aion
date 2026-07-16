"""
Smoke tests da API via httpx.AsyncClient + ASGITransport.

Nota: starlette 0.27 TestClient passa app= ao httpx.Client, o que quebra em
httpx 0.28+. Usamos ASGITransport async (caminho suportado).
"""
from __future__ import annotations

import asyncio
import unittest

import httpx

from app.main import app


def _run(coro):
    return asyncio.run(coro)


class TestApiSmoke(unittest.TestCase):
    def test_read_root(self):
        async def _t():
            transport = httpx.ASGITransport(app=app)
            async with httpx.AsyncClient(
                transport=transport, base_url="http://testserver"
            ) as client:
                response = await client.get("/")
                self.assertEqual(response.status_code, 200)
                self.assertIn("Aion", response.json()["message"])

        _run(_t())

    def test_history_requires_auth(self):
        """GET /dreams/history sem Bearer → 401 missing_token."""

        async def _t():
            transport = httpx.ASGITransport(app=app)
            async with httpx.AsyncClient(
                transport=transport, base_url="http://testserver"
            ) as client:
                response = await client.get("/dreams/history")
                self.assertEqual(response.status_code, 401)
                detail = response.json().get("detail")
                self.assertEqual(detail, "missing_token")

        _run(_t())

    def test_create_dream_requires_auth(self):
        """POST /dreams/ sem Bearer → 401 missing_token."""

        async def _t():
            transport = httpx.ASGITransport(app=app)
            async with httpx.AsyncClient(
                transport=transport, base_url="http://testserver"
            ) as client:
                response = await client.post(
                    "/dreams/",
                    json={"text": "Sonhei que voava sobre o mar."},
                )
                self.assertEqual(response.status_code, 401)
                self.assertEqual(response.json().get("detail"), "missing_token")

        _run(_t())

    def test_interview_requires_auth(self):
        """POST /dreams/interview sem Bearer → 401 missing_token (C-01)."""

        async def _t():
            transport = httpx.ASGITransport(app=app)
            async with httpx.AsyncClient(
                transport=transport, base_url="http://testserver"
            ) as client:
                response = await client.post(
                    "/dreams/interview",
                    json={"text": "Sonhei com um rio escuro e uma ponte."},
                )
                self.assertEqual(response.status_code, 401)
                self.assertEqual(response.json().get("detail"), "missing_token")

        _run(_t())

    def test_voice_transcribe_requires_auth(self):
        """POST /voice/transcribe sem Bearer → 401 missing_token."""

        async def _t():
            transport = httpx.ASGITransport(app=app)
            async with httpx.AsyncClient(
                transport=transport, base_url="http://testserver"
            ) as client:
                response = await client.post("/voice/transcribe")
                self.assertEqual(response.status_code, 401)
                self.assertEqual(response.json().get("detail"), "missing_token")

        _run(_t())


if __name__ == "__main__":
    unittest.main()

