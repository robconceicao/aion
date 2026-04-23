import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.database import get_database

client = TestClient(app)

def test_read_root():
    response = client.get("/")
    assert response.status_code == 200
    assert "Aion" in response.json()["message"]

def test_auth_protected_route():
    # Attempt to access dreams without token
    response = client.get("/dreams/")
    assert response.status_code == 401

def test_pydantic_schema_validation():
    # Test registering with invalid email
    response = client.post("/auth/register", json={
        "email": "invalid-email",
        "password": "123",
        "full_name": "Test User"
    })
    assert response.status_code == 422 # Unprocessable Entity
