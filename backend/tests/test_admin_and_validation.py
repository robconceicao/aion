"""
Testes de segurança e validação (auditoria Quick Wins).

- C-02: get_current_admin só aceita app_metadata.is_admin
- A-02: limites de tamanho em DreamCreate / InterviewRequest
- A-07: FeedbackCreate com rating ge/le
"""
from __future__ import annotations

import asyncio
import os
import sys

import pytest
from fastapi import HTTPException
from pydantic import ValidationError

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from app.routers.auth import get_current_admin, _is_admin_flag
from app.models.dream import DreamCreate, InterviewRequest, SemanticSearchRequest, DREAM_TEXT_MAX_LEN
from app.models.feedback import FeedbackCreate


def _run(coro):
    return asyncio.run(coro)


def test_is_admin_flag_accepts_bool_and_string():
    assert _is_admin_flag(True) is True
    assert _is_admin_flag("true") is True
    assert _is_admin_flag("TRUE") is True
    assert _is_admin_flag(False) is False
    assert _is_admin_flag("false") is False
    assert _is_admin_flag(None) is False
    assert _is_admin_flag("yes") is True


def test_admin_rejects_user_metadata_and_email():
    """user_metadata.is_admin e e-mail hardcoded NÃO concedem admin."""

    async def _t():
        with pytest.raises(HTTPException) as ei:
            await get_current_admin(
                {
                    "sub": "u1",
                    "email": "admin@aion.app",
                    "user_metadata": {"is_admin": True},
                    "app_metadata": {},
                }
            )
        assert ei.value.status_code == 403

    _run(_t())


def test_admin_rejects_top_level_is_admin_claim():
    async def _t():
        with pytest.raises(HTTPException) as ei:
            await get_current_admin(
                {"sub": "u1", "email": "x@y.com", "is_admin": True, "app_metadata": {}}
            )
        assert ei.value.status_code == 403

    _run(_t())


def test_admin_accepts_app_metadata_only():
    async def _t():
        user = {
            "sub": "admin-1",
            "email": "real@example.com",
            "app_metadata": {"is_admin": True},
            "user_metadata": {},
        }
        out = await get_current_admin(user)
        assert out["sub"] == "admin-1"

    _run(_t())


def test_dream_create_rejects_too_long_text():
    with pytest.raises(ValidationError):
        DreamCreate(text="x" * (DREAM_TEXT_MAX_LEN + 1))


def test_dream_create_rejects_too_short_text():
    with pytest.raises(ValidationError):
        DreamCreate(text="ab")


def test_dream_create_accepts_normal_text():
    d = DreamCreate(text="Sonhei que voava sobre o mar à noite.")
    assert "voava" in d.text


def test_interview_request_max_length():
    with pytest.raises(ValidationError):
        InterviewRequest(text="y" * (DREAM_TEXT_MAX_LEN + 1))


def test_semantic_search_threshold_bounds():
    with pytest.raises(ValidationError):
        SemanticSearchRequest(query="água", threshold=1.5)
    ok = SemanticSearchRequest(query="água", threshold=0.7, max_results=10)
    assert ok.threshold == 0.7


def test_feedback_rating_bounds():
    with pytest.raises(ValidationError):
        FeedbackCreate(rating=0)
    with pytest.raises(ValidationError):
        FeedbackCreate(rating=6)
    ok = FeedbackCreate(rating=5, comment="bom", accurate_archetypes=False)
    assert ok.rating == 5
    assert ok.accurate_archetypes is False
