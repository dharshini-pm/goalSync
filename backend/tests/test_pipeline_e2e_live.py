"""Live End-to-End Integration Test for GoalSync Production Transaction Pipeline.

Verifies the full pipeline:
Structured transaction event
    ↓
FastAPI (/api/v1/process-transaction)
    ↓
HMAC Validation & Idempotency
    ↓
MongoDB (Transaction & Profile)
    ↓
LangGraph (GoalSyncGraphService)
    ↓
All 6 AI Agents (Transaction -> Financial State -> Goal -> Conflict -> Scenario -> Explanation)
    ↓
MongoDB Persistence & Final Result Response

NOTE: If Ollama is offline or llama3.2 is not installed locally, this test
skips gracefully with an informative message.
"""

from __future__ import annotations

import json
import os
import uuid
import pytest
import requests
from fastapi.testclient import TestClient

from app.ingestion.security import compute_hmac_signature
from app.main import app

client = TestClient(app)
LIVE_TEST_SECRET = "live-test-secret-32-chars-goalsync!"


def _is_ollama_available() -> bool:
    """Checks if local Ollama server is running and has llama3.2."""
    try:
        r = requests.get("http://localhost:11434/api/tags", timeout=4)
        if r.status_code != 200:
            return False
        models = [m.get("name", "") for m in r.json().get("models", [])]
        return any("llama3.2" in m for m in models)
    except Exception:
        return False


OLLAMA_AVAILABLE = _is_ollama_available()


@pytest.mark.skipif(
    not OLLAMA_AVAILABLE,
    reason="Live Ollama server is offline or llama3.2 model is not installed. Skipping live AI e2e test.",
)
def test_live_pipeline_e2e_all_six_agents(monkeypatch):
    """Executes live end-to-end transaction processing through all 6 agents."""
    monkeypatch.setenv("GOALSYNC_N8N_HMAC_SECRET", LIVE_TEST_SECRET)
    monkeypatch.setenv("GOALSYNC_WEBHOOK_SECRET", LIVE_TEST_SECRET)

    # 1. Create a controlled test user
    uid = uuid.uuid4().hex[:8]
    reg_res = client.post(
        "/auth/register",
        json={
            "fullName": "E2E Test User",
            "phone": f"+9199{uid[:8]}",
            "email": f"e2e_user_{uid}@example.com",
            "password": "Password123!",
        },
    )
    assert reg_res.status_code == 201
    user_data = reg_res.json()
    user_id = user_data["user"]["_id"]
    token = user_data["access_token"]
    auth_header = {"Authorization": f"Bearer {token}"}

    # 2. Setup user's financial profile
    profile_res = client.post(
        "/financial-profile",
        headers=auth_header,
        json={
            "age": 29,
            "occupation": "Product Manager",
            "dependents": 1,
            "monthlyIncome": 95000.0,
            "incomeType": "Salary",
            "additionalIncome": 5000.0,
            "currentSavings": 150000.0,
            "fixedExpenses": 35000.0,
            "variableExpenses": 20000.0,
            "monthlyEMI": 8000.0,
            "activeLoans": 1,
        },
    )
    assert profile_res.status_code == 201

    # 3. Setup a financial goal
    goal_res = client.post(
        "/goals",
        headers=auth_header,
        json={
            "name": "House Downpayment",
            "category": "Housing",
            "targetAmount": 500000.0,
            "currentAmount": 100000.0,
            "targetDate": "2027-12-31T00:00:00Z",
            "priority": "high",
        },
    )
    assert goal_res.status_code == 201

    # 4. Construct a structured transaction event
    event_id = f"evt_live_{uuid.uuid4().hex[:12]}"
    fingerprint = f"fp_live_{uuid.uuid4().hex}"
    event_payload = {
        "event_type": "financial_transaction",
        "source": "android_sms",
        "event_id": event_id,
        "fingerprint": fingerprint,
        "user_id": user_id,
        "amount": 850.0,
        "transaction_type": "DEBIT",
        "merchant": "Swiggy",
        "payment_method": "UPI",
        "transaction_date": "2026-09-27T14:30:00Z",
        "available_balance": 87000.0,
        "confidence": "HIGH",
    }
    payload_str = json.dumps(event_payload, separators=(",", ":"))
    signature = compute_hmac_signature(payload_str, LIVE_TEST_SECRET)

    # 5. POST to /api/v1/process-transaction
    res = client.post(
        "/api/v1/process-transaction",
        content=payload_str,
        headers={
            "Content-Type": "application/json",
            "X-GoalSync-Signature": signature,
        },
    )
    assert res.status_code == 200, f"Live pipeline failed: {res.text}"
    data = res.json()

    assert data["success"] is True
    assert data["status"] == "processed"
    assert data["event_id"] == event_id
    assert data["transaction_id"] is not None

    # Verify all 6 stages completed
    completed = data["processing"]["completed_stages"]
    assert len(completed) == 6
    assert "transaction_agent" in completed
    assert "financial_state_agent" in completed
    assert "goal_agent" in completed
    assert "conflict_agent" in completed
    assert "scenario_agent" in completed
    assert "explanation_agent" in completed

    # Verify results
    result = data["result"]
    assert result["financial_state"] is not None
    assert result["goal"] is not None
    assert result["conflict"] is not None
    assert result["scenario"] is not None
    assert result["explanation"] is not None

    # 6. Verify idempotency: Resend identical event
    res_dup = client.post(
        "/api/v1/process-transaction",
        content=payload_str,
        headers={
            "Content-Type": "application/json",
            "X-GoalSync-Signature": signature,
        },
    )
    assert res_dup.status_code == 200
    assert res_dup.json()["status"] == "duplicate"
    assert res_dup.json()["transaction_id"] == data["transaction_id"]
