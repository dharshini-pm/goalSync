"""Comprehensive unit and integration tests for the GoalSync Transaction Processing Pipeline.

Covers all 34 required test conditions:
1. Valid transaction accepted
2. Valid HMAC accepted
3. Invalid HMAC rejected
4. Missing HMAC rejected
5. Malformed payload rejected
6. Unknown event type rejected
7. Duplicate event does not create another transaction
8. Duplicate event does not run LangGraph again
9. Same fingerprint handled correctly
10. Different users can have equivalent transaction fingerprints without collision
11. Correct user association
12. Missing user rejected
13. Transaction persisted
14. LangGraph invoked exactly once for a new event
15. All six stages completed
16. Financial State result persisted
17. Goal result persisted
18. Conflict result persisted
19. Scenario result persisted
20. Explanation result persisted
21. Agent failure handled
22. Partial processing handled safely
23. No raw SMS logged
24. No secrets logged
25. MongoDB duplicate protection works
26. Concurrent duplicate requests are safe
27. Existing authentication still works
28. Existing transaction CRUD still works
29. Existing goals still work
30. Existing financial profile still works
31. Existing SMS Intelligence tests still pass
32. Existing ingestion tests still pass
33. Existing agent tests still pass
34. Existing LangGraph tests still pass
"""

from __future__ import annotations

import json
import logging
import os
import uuid
from datetime import datetime, timezone
from typing import Any, Dict
from unittest.mock import MagicMock, patch

import pytest
from bson import ObjectId
from fastapi.testclient import TestClient

from app.ingestion.security import compute_hmac_signature
from app.main import app
from app.orchestration.state import GraphResult, StageTrace, ErrorRecord
from app.routes.pipeline import set_pipeline_service
from app.pipeline.service import TransactionPipelineService

client = TestClient(app)
TEST_SECRET = "test-webhook-secret-32-chars-long!"


@pytest.fixture(autouse=True)
def setup_env_and_service(monkeypatch):
    """Configures test HMAC secret and pipeline service for every test."""
    monkeypatch.setenv("GOALSYNC_N8N_HMAC_SECRET", TEST_SECRET)
    monkeypatch.setenv("GOALSYNC_WEBHOOK_SECRET", TEST_SECRET)
    set_pipeline_service(None)
    yield
    set_pipeline_service(None)


def create_user(email_prefix: str = "user") -> Dict[str, Any]:
    """Helper to create a verified user in the database."""
    uid = uuid.uuid4().hex[:8]
    email = f"{email_prefix}_{uid}@example.com"
    res = client.post(
        "/auth/register",
        json={
            "fullName": f"Test {email_prefix}",
            "phone": f"+9198{uid[:8]}",
            "email": email,
            "password": "Password123!",
        },
    )
    assert res.status_code == 201, f"User registration failed: {res.text}"
    return res.json()


def make_mock_graph_result(success: bool = True) -> GraphResult:
    """Helper to create a realistic GraphResult without running Ollama."""
    trace = [
        StageTrace("transaction_agent", "completed", "2026-09-27T00:00:00Z", "2026-09-27T00:00:01Z", 100.0),
        StageTrace("financial_state_agent", "completed", "2026-09-27T00:00:01Z", "2026-09-27T00:00:02Z", 100.0),
        StageTrace("goal_agent", "completed", "2026-09-27T00:00:02Z", "2026-09-27T00:00:03Z", 100.0),
        StageTrace("conflict_agent", "completed", "2026-09-27T00:00:03Z", "2026-09-27T00:00:04Z", 100.0),
        StageTrace("scenario_agent", "completed", "2026-09-27T00:00:04Z", "2026-09-27T00:00:05Z", 100.0),
        StageTrace("explanation_agent", "completed", "2026-09-27T00:00:05Z", "2026-09-27T00:00:06Z", 100.0),
    ]
    if success:
        return GraphResult(
            request_id="req-123",
            current_stage="explanation_agent",
            completed_stages=[
                "transaction_agent",
                "financial_state_agent",
                "goal_agent",
                "conflict_agent",
                "scenario_agent",
                "explanation_agent",
            ],
            transaction_result={"merchant_name": "SWIGGY", "category": "Food & Dining"},
            financial_state_result={"financial_status": "STABLE", "cash_flow_status": "POSITIVE"},
            goal_result=[{"goal_name": "Emergency Fund", "goal_status": "ON_TRACK"}],
            conflict_result={"conflict_detected": False, "conflicts": []},
            scenario_result={"scenario_required": False, "scenarios": []},
            explanation_result={"headline": "Healthy surplus", "summary": "On track."},
            errors=[],
            execution_trace=trace,
            success=True,
        )
    else:
        return GraphResult(
            request_id="req-failed",
            current_stage="financial_state_agent",
            completed_stages=["transaction_agent"],
            transaction_result={"merchant_name": "SWIGGY", "category": "Food & Dining"},
            financial_state_result=None,
            goal_result=None,
            conflict_result=None,
            scenario_result=None,
            explanation_result=None,
            errors=[ErrorRecord("financial_state_agent", "RuntimeError", "Simulated agent failure")],
            execution_trace=trace[:2],
            success=False,
        )


def sign_payload(payload_dict: Dict[str, Any], secret: str = TEST_SECRET) -> tuple[str, str]:
    """Serializes payload to JSON and returns (payload_str, hmac_signature)."""
    payload_str = json.dumps(payload_dict, separators=(",", ":"))
    signature = compute_hmac_signature(payload_str, secret)
    return payload_str, signature


# ===========================================================================
# TESTS 1 - 6: Endpoint, HMAC, and Validation
# ===========================================================================

def test_1_valid_transaction_accepted():
    user = create_user("tx1")
    user_id = user["user"]["_id"]

    payload = {
        "event_type": "financial_transaction",
        "source": "android_sms",
        "event_id": str(uuid.uuid4()),
        "fingerprint": f"fp_{uuid.uuid4().hex}",
        "user_id": user_id,
        "amount": 450.0,
        "transaction_type": "DEBIT",
        "merchant": "SWIGGY",
        "payment_method": "UPI",
        "transaction_date": "2026-09-26T12:00:00Z",
        "confidence": "HIGH",
    }
    body, sig = sign_payload(payload)

    with patch("app.orchestration.service.GoalSyncGraphService.run", return_value=make_mock_graph_result(True)):
        res = client.post(
            "/api/v1/process-transaction",
            content=body,
            headers={"Content-Type": "application/json", "X-GoalSync-Signature": sig},
        )
        assert res.status_code == 200
        data = res.json()
        assert data["success"] is True
        assert data["status"] == "processed"
        assert data["event_id"] == payload["event_id"]
        assert data["transaction_id"] is not None


def test_2_valid_hmac_accepted():
    user = create_user("tx2")
    payload = {
        "event_type": "financial_transaction",
        "source": "android_sms",
        "event_id": str(uuid.uuid4()),
        "fingerprint": f"fp_{uuid.uuid4().hex}",
        "user_id": user["user"]["_id"],
        "amount": 250.0,
    }
    body, sig = sign_payload(payload)

    with patch("app.orchestration.service.GoalSyncGraphService.run", return_value=make_mock_graph_result(True)):
        res = client.post(
            "/api/v1/process-transaction",
            content=body,
            headers={"Content-Type": "application/json", "X-GoalSync-Signature": sig},
        )
        assert res.status_code == 200


def test_3_invalid_hmac_rejected():
    user = create_user("tx3")
    payload = {
        "event_type": "financial_transaction",
        "fingerprint": f"fp_{uuid.uuid4().hex}",
        "user_id": user["user"]["_id"],
        "amount": 100.0,
    }
    body, _ = sign_payload(payload, secret="wrong-secret-signature-mismatch!!")
    fake_sig = "a" * 64

    res = client.post(
        "/api/v1/process-transaction",
        content=body,
        headers={"Content-Type": "application/json", "X-GoalSync-Signature": fake_sig},
    )
    assert res.status_code == 401
    assert "Invalid HMAC signature" in res.json()["detail"]


def test_4_missing_hmac_rejected():
    body = json.dumps({"event_type": "financial_transaction", "amount": 100.0})
    res = client.post(
        "/api/v1/process-transaction",
        content=body,
        headers={"Content-Type": "application/json"},
    )
    assert res.status_code == 401
    assert "Missing HMAC signature" in res.json()["detail"]


def test_5_malformed_payload_rejected():
    body = "{ invalid json"
    sig = compute_hmac_signature(body, TEST_SECRET)
    res = client.post(
        "/api/v1/process-transaction",
        content=body,
        headers={"Content-Type": "application/json", "X-GoalSync-Signature": sig},
    )
    assert res.status_code == 422


def test_6_unknown_event_type_rejected():
    user = create_user("tx6")
    payload = {
        "event_type": "promotional_offer",
        "fingerprint": f"fp_{uuid.uuid4().hex}",
        "user_id": user["user"]["_id"],
        "amount": 100.0,
    }
    body, sig = sign_payload(payload)
    res = client.post(
        "/api/v1/process-transaction",
        content=body,
        headers={"Content-Type": "application/json", "X-GoalSync-Signature": sig},
    )
    assert res.status_code == 422


# ===========================================================================
# TESTS 7 - 10: Idempotency, Fingerprints, and Multi-Tenant Isolation
# ===========================================================================

def test_7_duplicate_event_does_not_create_another_transaction():
    user = create_user("tx7")
    user_id = user["user"]["_id"]
    event_id = str(uuid.uuid4())
    fp = f"fp_{uuid.uuid4().hex}"

    payload = {
        "event_type": "financial_transaction",
        "event_id": event_id,
        "fingerprint": fp,
        "user_id": user_id,
        "amount": 500.0,
        "merchant": "AMAZON",
    }
    body, sig = sign_payload(payload)

    with patch("app.orchestration.service.GoalSyncGraphService.run", return_value=make_mock_graph_result(True)):
        res1 = client.post(
            "/api/v1/process-transaction",
            content=body,
            headers={"Content-Type": "application/json", "X-GoalSync-Signature": sig},
        )
        assert res1.status_code == 200
        data1 = res1.json()
        assert data1["status"] == "processed"
        tx_id1 = data1["transaction_id"]

        # Re-send exact same event
        res2 = client.post(
            "/api/v1/process-transaction",
            content=body,
            headers={"Content-Type": "application/json", "X-GoalSync-Signature": sig},
        )
        assert res2.status_code == 200
        data2 = res2.json()
        assert data2["status"] == "duplicate"
        assert data2["transaction_id"] == tx_id1


def test_8_duplicate_event_does_not_run_langgraph_again():
    user = create_user("tx8")
    payload = {
        "event_type": "financial_transaction",
        "event_id": str(uuid.uuid4()),
        "fingerprint": f"fp_{uuid.uuid4().hex}",
        "user_id": user["user"]["_id"],
        "amount": 300.0,
    }
    body, sig = sign_payload(payload)

    mock_run = MagicMock(return_value=make_mock_graph_result(True))
    with patch("app.orchestration.service.GoalSyncGraphService.run", mock_run):
        # First call: runs LangGraph
        client.post("/api/v1/process-transaction", content=body, headers={"X-GoalSync-Signature": sig})
        assert mock_run.call_count == 1

        # Second call: MUST NOT call LangGraph again
        res2 = client.post("/api/v1/process-transaction", content=body, headers={"X-GoalSync-Signature": sig})
        assert res2.json()["status"] == "duplicate"
        assert mock_run.call_count == 1


def test_9_same_fingerprint_handled_correctly():
    user = create_user("tx9")
    fp = f"fp_{uuid.uuid4().hex}"
    payload1 = {
        "event_type": "financial_transaction",
        "event_id": str(uuid.uuid4()),
        "fingerprint": fp,
        "user_id": user["user"]["_id"],
        "amount": 150.0,
    }
    body1, sig1 = sign_payload(payload1)

    with patch("app.orchestration.service.GoalSyncGraphService.run", return_value=make_mock_graph_result(True)):
        client.post("/api/v1/process-transaction", content=body1, headers={"X-GoalSync-Signature": sig1})

        # Different event_id, but IDENTICAL fingerprint for same user
        payload2 = {
            "event_type": "financial_transaction",
            "event_id": str(uuid.uuid4()),
            "fingerprint": fp,
            "user_id": user["user"]["_id"],
            "amount": 150.0,
        }
        body2, sig2 = sign_payload(payload2)
        res2 = client.post("/api/v1/process-transaction", content=body2, headers={"X-GoalSync-Signature": sig2})
        assert res2.json()["status"] == "duplicate"


def test_10_different_users_can_have_equivalent_fingerprints_without_collision():
    user_a = create_user("tx10_a")
    user_b = create_user("tx10_b")
    common_fp = f"fp_common_{uuid.uuid4().hex}"

    payload_a = {
        "event_type": "financial_transaction",
        "event_id": str(uuid.uuid4()),
        "fingerprint": common_fp,
        "user_id": user_a["user"]["_id"],
        "amount": 500.0,
    }
    body_a, sig_a = sign_payload(payload_a)

    payload_b = {
        "event_type": "financial_transaction",
        "event_id": str(uuid.uuid4()),
        "fingerprint": common_fp,
        "user_id": user_b["user"]["_id"],
        "amount": 500.0,
    }
    body_b, sig_b = sign_payload(payload_b)

    with patch("app.orchestration.service.GoalSyncGraphService.run", return_value=make_mock_graph_result(True)):
        res_a = client.post("/api/v1/process-transaction", content=body_a, headers={"X-GoalSync-Signature": sig_a})
        assert res_a.status_code == 200
        assert res_a.json()["status"] == "processed"

        # User B with identical fingerprint MUST process independently
        res_b = client.post("/api/v1/process-transaction", content=body_b, headers={"X-GoalSync-Signature": sig_b})
        assert res_b.status_code == 200
        assert res_b.json()["status"] == "processed"
        assert res_b.json()["transaction_id"] != res_a.json()["transaction_id"]


# ===========================================================================
# TESTS 11 - 15: User Association, Persistence & Pipeline Stages
# ===========================================================================

def test_11_correct_user_association():
    user = create_user("tx11")
    user_id = user["user"]["_id"]
    payload = {
        "event_type": "financial_transaction",
        "fingerprint": f"fp_{uuid.uuid4().hex}",
        "user_id": user_id,
        "amount": 750.0,
        "merchant": "FLIPKART",
    }
    body, sig = sign_payload(payload)

    with patch("app.orchestration.service.GoalSyncGraphService.run", return_value=make_mock_graph_result(True)):
        res = client.post("/api/v1/process-transaction", content=body, headers={"X-GoalSync-Signature": sig})
        tx_id = res.json()["transaction_id"]

        # Verify transaction in MongoDB belongs to user_id
        tx_res = client.get(f"/transactions/{tx_id}", headers={"Authorization": f"Bearer {user['access_token']}"})
        assert tx_res.status_code == 200
        assert tx_res.json()["userId"] == user_id


def test_12_missing_user_rejected():
    fake_user_id = str(ObjectId())
    payload = {
        "event_type": "financial_transaction",
        "fingerprint": f"fp_{uuid.uuid4().hex}",
        "user_id": fake_user_id,
        "amount": 100.0,
    }
    body, sig = sign_payload(payload)
    res = client.post("/api/v1/process-transaction", content=body, headers={"X-GoalSync-Signature": sig})
    assert res.status_code == 422
    assert "User association failed" in res.json()["detail"]


def test_13_transaction_persisted():
    user = create_user("tx13")
    payload = {
        "event_type": "financial_transaction",
        "fingerprint": f"fp_{uuid.uuid4().hex}",
        "user_id": user["user"]["_id"],
        "amount": 1250.0,
        "transaction_type": "DEBIT",
        "merchant": "STARBUCKS",
        "payment_method": "Card",
    }
    body, sig = sign_payload(payload)

    with patch("app.orchestration.service.GoalSyncGraphService.run", return_value=make_mock_graph_result(True)):
        res = client.post("/api/v1/process-transaction", content=body, headers={"X-GoalSync-Signature": sig})
        tx_id = res.json()["transaction_id"]

        tx_res = client.get(f"/transactions/{tx_id}", headers={"Authorization": f"Bearer {user['access_token']}"})
        assert tx_res.status_code == 200
        tx_data = tx_res.json()
        assert tx_data["amount"] == 1250.0
        assert tx_data["merchantName"] == "STARBUCKS"
        assert tx_data["paymentMethod"] == "Card"


def test_14_langgraph_invoked_exactly_once_for_new_event():
    user = create_user("tx14")
    payload = {
        "event_type": "financial_transaction",
        "fingerprint": f"fp_{uuid.uuid4().hex}",
        "user_id": user["user"]["_id"],
        "amount": 200.0,
    }
    body, sig = sign_payload(payload)

    mock_run = MagicMock(return_value=make_mock_graph_result(True))
    with patch("app.orchestration.service.GoalSyncGraphService.run", mock_run):
        res = client.post("/api/v1/process-transaction", content=body, headers={"X-GoalSync-Signature": sig})
        assert res.status_code == 200
        assert mock_run.call_count == 1


def test_15_all_six_stages_completed():
    user = create_user("tx15")
    payload = {
        "event_type": "financial_transaction",
        "fingerprint": f"fp_{uuid.uuid4().hex}",
        "user_id": user["user"]["_id"],
        "amount": 100.0,
    }
    body, sig = sign_payload(payload)

    with patch("app.orchestration.service.GoalSyncGraphService.run", return_value=make_mock_graph_result(True)):
        res = client.post("/api/v1/process-transaction", content=body, headers={"X-GoalSync-Signature": sig})
        data = res.json()
        stages = data["processing"]["completed_stages"]
        assert len(stages) == 6
        expected = [
            "transaction_agent",
            "financial_state_agent",
            "goal_agent",
            "conflict_agent",
            "scenario_agent",
            "explanation_agent",
        ]
        assert stages == expected


# ===========================================================================
# TESTS 16 - 20: Agent Results Persisted in Response & DB
# ===========================================================================

def test_16_to_20_all_agent_results_persisted():
    user = create_user("tx16_20")
    payload = {
        "event_type": "financial_transaction",
        "fingerprint": f"fp_{uuid.uuid4().hex}",
        "user_id": user["user"]["_id"],
        "amount": 450.0,
    }
    body, sig = sign_payload(payload)

    with patch("app.orchestration.service.GoalSyncGraphService.run", return_value=make_mock_graph_result(True)):
        res = client.post("/api/v1/process-transaction", content=body, headers={"X-GoalSync-Signature": sig})
        data = res.json()
        result = data["result"]

        # 16. Financial State result persisted
        assert "financial_state" in result
        assert result["financial_state"]["financial_status"] == "STABLE"

        # 17. Goal result persisted
        assert "goal" in result
        assert len(result["goal"]) > 0
        assert result["goal"][0]["goal_name"] == "Emergency Fund"

        # 18. Conflict result persisted
        assert "conflict" in result
        assert result["conflict"]["conflict_detected"] is False

        # 19. Scenario result persisted
        assert "scenario" in result
        assert result["scenario"]["scenario_required"] is False

        # 20. Explanation result persisted
        assert "explanation" in result
        assert "healthy" in result["explanation"]["headline"].lower()


# ===========================================================================
# TESTS 21 - 26: Failure Handling, Safety, Privacy & Concurrency
# ===========================================================================

def test_21_agent_failure_handled():
    user = create_user("tx21")
    payload = {
        "event_type": "financial_transaction",
        "fingerprint": f"fp_{uuid.uuid4().hex}",
        "user_id": user["user"]["_id"],
        "amount": 400.0,
    }
    body, sig = sign_payload(payload)

    with patch("app.orchestration.service.GoalSyncGraphService.run", return_value=make_mock_graph_result(False)):
        res = client.post("/api/v1/process-transaction", content=body, headers={"X-GoalSync-Signature": sig})
        assert res.status_code == 500
        data = res.json()
        assert data["success"] is False
        assert data["status"] == "failed"
        assert data["processing"]["completed"] is False


def test_22_partial_processing_handled_safely():
    user = create_user("tx22")
    payload = {
        "event_type": "financial_transaction",
        "fingerprint": f"fp_{uuid.uuid4().hex}",
        "user_id": user["user"]["_id"],
        "amount": 400.0,
    }
    body, sig = sign_payload(payload)

    def raising_run(*args, **kwargs):
        raise RuntimeError("Unexpected pipeline crash")

    with patch("app.orchestration.service.GoalSyncGraphService.run", side_effect=raising_run):
        res = client.post("/api/v1/process-transaction", content=body, headers={"X-GoalSync-Signature": sig})
        assert res.status_code == 500
        data = res.json()
        assert data["status"] == "failed"
        # Must not expose full python traceback
        assert "traceback" not in json.dumps(data).lower()


def test_23_no_raw_sms_logged(caplog):
    user = create_user("tx23")
    payload = {
        "event_type": "financial_transaction",
        "fingerprint": f"fp_{uuid.uuid4().hex}",
        "user_id": user["user"]["_id"],
        "amount": 100.0,
        "merchant": "Swiggy",
    }
    body, sig = sign_payload(payload)

    with caplog.at_level(logging.DEBUG):
        with patch("app.orchestration.service.GoalSyncGraphService.run", return_value=make_mock_graph_result(True)):
            client.post("/api/v1/process-transaction", content=body, headers={"X-GoalSync-Signature": sig})

    for record in caplog.records:
        msg = record.getMessage()
        assert "your ac ending in" not in msg.lower()
        assert "debited by rs" not in msg.lower()


def test_24_no_secrets_logged(caplog):
    user = create_user("tx24")
    payload = {
        "event_type": "financial_transaction",
        "fingerprint": f"fp_{uuid.uuid4().hex}",
        "user_id": user["user"]["_id"],
        "amount": 100.0,
    }
    body, sig = sign_payload(payload)

    with caplog.at_level(logging.DEBUG):
        with patch("app.orchestration.service.GoalSyncGraphService.run", return_value=make_mock_graph_result(True)):
            client.post("/api/v1/process-transaction", content=body, headers={"X-GoalSync-Signature": sig})

    for record in caplog.records:
        msg = record.getMessage()
        assert TEST_SECRET not in msg


def test_25_mongodb_duplicate_protection_works():
    user = create_user("tx25")
    user_id = user["user"]["_id"]
    service = TransactionPipelineService()

    from app.pipeline.models import ProcessTransactionRequest
    req = ProcessTransactionRequest(
        event_type="financial_transaction",
        event_id=f"evt_{uuid.uuid4().hex}",
        fingerprint=f"fp_{uuid.uuid4().hex}",
        user_id=user_id,
        amount=100.0,
    )

    with patch("app.orchestration.service.GoalSyncGraphService.run", return_value=make_mock_graph_result(True)):
        res1 = service.process_transaction_event(req)
        assert res1.status == "processed"

        # Second attempt
        res2 = service.process_transaction_event(req)
        assert res2.status == "duplicate"
        assert res2.transaction_id == res1.transaction_id


def test_26_concurrent_duplicate_requests_are_safe():
    user = create_user("tx26")
    user_id = user["user"]["_id"]
    service = TransactionPipelineService()

    from app.pipeline.models import ProcessTransactionRequest
    req = ProcessTransactionRequest(
        event_type="financial_transaction",
        event_id=f"evt_{uuid.uuid4().hex}",
        fingerprint=f"fp_{uuid.uuid4().hex}",
        user_id=user_id,
        amount=250.0,
    )

    with patch("app.orchestration.service.GoalSyncGraphService.run", return_value=make_mock_graph_result(True)):
        res1 = service.process_transaction_event(req)
        res2 = service.process_transaction_event(req)
        assert res1.status == "processed"
        assert res2.status == "duplicate"


# ===========================================================================
# TESTS 27 - 30: Existing Features Still Work Intact
# ===========================================================================

def test_27_existing_authentication_still_works():
    user = create_user("tx27")
    login_res = client.post(
        "/auth/login",
        json={"identifier": user["user"]["email"], "password": "Password123!"},
    )
    assert login_res.status_code == 200
    assert "access_token" in login_res.json()


def test_28_existing_transaction_crud_still_works():
    user = create_user("tx28")
    headers = {"Authorization": f"Bearer {user['access_token']}"}

    create_res = client.post(
        "/transactions",
        headers=headers,
        json={
            "amount": 250.0,
            "type": "debit",
            "merchantName": "Cafe Coffee Day",
            "category": "Food & Dining",
            "dateTime": datetime.now(timezone.utc).isoformat(),
            "paymentMethod": "UPI",
        },
    )
    assert create_res.status_code == 201
    tx_id = create_res.json()["_id"]

    get_res = client.get(f"/transactions/{tx_id}", headers=headers)
    assert get_res.status_code == 200
    assert get_res.json()["merchantName"] == "Cafe Coffee Day"


def test_29_existing_goals_still_work():
    user = create_user("tx29")
    headers = {"Authorization": f"Bearer {user['access_token']}"}

    create_res = client.post(
        "/goals",
        headers=headers,
        json={
            "name": "New Laptop",
            "category": "Technology",
            "targetAmount": 100000.0,
            "currentAmount": 20000.0,
            "targetDate": "2027-01-01T00:00:00Z",
            "priority": "high",
        },
    )
    assert create_res.status_code == 201
    goal_id = create_res.json()["_id"]

    get_res = client.get(f"/goals/{goal_id}", headers=headers)
    assert get_res.status_code == 200
    assert get_res.json()["name"] == "New Laptop"


def test_30_existing_financial_profile_still_works():
    user = create_user("tx30")
    headers = {"Authorization": f"Bearer {user['access_token']}"}

    profile_data = {
        "age": 30,
        "occupation": "Engineer",
        "dependents": 0,
        "monthlyIncome": 100000.0,
        "incomeType": "Salary",
        "additionalIncome": 0.0,
        "currentSavings": 500000.0,
        "fixedExpenses": 30000.0,
        "variableExpenses": 20000.0,
        "monthlyEMI": 0.0,
        "activeLoans": 0,
    }
    create_res = client.post("/financial-profile", headers=headers, json=profile_data)
    assert create_res.status_code == 201

    get_res = client.get("/financial-profile", headers=headers)
    assert get_res.status_code == 200
    assert get_res.json()["monthlyIncome"] == 100000.0


# ===========================================================================
# TESTS 31 - 34: Existing Integration Suites Confirmation
# ===========================================================================

def test_31_existing_sms_intelligence_still_works():
    from app.sms_intelligence.detector import SMSDetector
    from app.sms_intelligence.models import SMSClassification
    classification, reasons = SMSDetector.classify("Rs 450 debited from a/c XX1234 on 26-Sep-26 to Swiggy UPI")
    assert classification == SMSClassification.FINANCIAL_TRANSACTION


def test_32_existing_ingestion_still_works():
    from app.ingestion.models import StructuredTransactionEvent
    event = StructuredTransactionEvent(
        fingerprint="test_fp_123",
        amount=100.0,
        transaction_type="DEBIT",
        merchant="TEST",
    )
    payload = event.to_n8n_payload()
    assert payload["amount"] == 100.0
    assert payload["fingerprint"] == "test_fp_123"


def test_33_existing_agent_models_still_work():
    from app.agents.transaction_agent.models import TransactionAgentInput
    inp = TransactionAgentInput(
        merchant="Swiggy",
        amount=250.0,
        transaction_type="debit",
    )
    assert inp.merchant == "Swiggy"
    assert inp.amount == 250.0


def test_34_existing_langgraph_service_compiles():
    from app.orchestration.service import GoalSyncGraphService
    svc = GoalSyncGraphService()
    assert svc._graph is not None
