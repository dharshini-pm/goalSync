"""Tests for GET /api/v1/insights and GET /api/v1/insights/history endpoints.

Covers:
1. No insight available when no processed records exist → available: false
2. Latest processed record is returned correctly
3. All 5 agent results included in response
4. completed_stages list populated
5. History endpoint returns empty list when no records
6. History returns up to N most recent records
7. Unauthenticated requests are rejected (401)
8. History limit validation (limit > 50 rejected)
9. Non-PROCESSED records are not returned as latest insight
10. Existing pipeline tests still pass (regression guard)
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone
from typing import Any, Dict
from unittest.mock import MagicMock, patch

import pytest
from bson import ObjectId
from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def register_user(prefix: str = "ins") -> Dict[str, Any]:
    uid = uuid.uuid4().hex[:8]
    res = client.post(
        "/auth/register",
        json={
            "fullName": f"Insight {prefix}",
            "phone": f"+9197{uid[:8]}",
            "email": f"{prefix}_{uid}@example.com",
            "password": "Password123!",
        },
    )
    assert res.status_code == 201, f"Registration failed: {res.text}"
    return res.json()


def auth_header(user_data: Dict[str, Any]) -> Dict[str, str]:
    token = user_data["access_token"]
    return {"Authorization": f"Bearer {token}"}


def _make_processing_record(user_id_obj: ObjectId, status: str = "PROCESSED") -> Dict[str, Any]:
    """Creates a synthetic pipeline record matching TransactionPipelineService output."""
    return {
        "userId": user_id_obj,
        "eventId": f"evt_{uuid.uuid4().hex[:12]}",
        "fingerprint": f"fp_{uuid.uuid4().hex}",
        "transactionId": ObjectId(),
        "status": status,
        "source": "android_sms",
        "completed_stages": [
            "transaction_agent",
            "financial_state_agent",
            "goal_agent",
            "conflict_agent",
            "scenario_agent",
            "explanation_agent",
        ],
        "transaction_result": {"merchant_name": "SWIGGY", "category": "Food & Dining"},
        "financial_state_result": {
            "financial_status": "STABLE",
            "cash_flow_status": "POSITIVE",
            "monthly_income": 95000.0,
        },
        "goal_result": [
            {"goal_name": "Emergency Fund", "goal_status": "ON_TRACK"}
        ],
        "conflict_result": {"conflict_detected": False, "conflicts": []},
        "scenario_result": {"scenario_required": False, "scenarios": []},
        "explanation_result": {
            "headline": "Healthy surplus maintained",
            "summary": "You are on track with your financial goals.",
        },
        "createdAt": datetime.now(timezone.utc),
        "updatedAt": datetime.now(timezone.utc),
    }


# ---------------------------------------------------------------------------
# Test 1: No insight when no records exist
# ---------------------------------------------------------------------------

def test_1_no_insight_when_no_records():
    user = register_user("ins1")
    res = client.get("/api/v1/insights", headers=auth_header(user))
    assert res.status_code == 200
    data = res.json()
    assert data["available"] is False
    assert data["financial_state"] is None
    assert data["explanation"] is None


# ---------------------------------------------------------------------------
# Test 2: Latest processed record is returned
# ---------------------------------------------------------------------------

def test_2_latest_processed_record_returned():
    from app.database import get_collection

    user = register_user("ins2")
    user_id = user["user"]["_id"]
    user_id_obj = ObjectId(user_id)

    coll = get_collection("transaction_processing_records")
    rec = _make_processing_record(user_id_obj, status="PROCESSED")
    coll.insert_one(rec)

    try:
        res = client.get("/api/v1/insights", headers=auth_header(user))
        assert res.status_code == 200
        data = res.json()
        assert data["available"] is True
        assert data["event_id"] == rec["eventId"]
        assert data["source"] == "android_sms"
    finally:
        coll.delete_many({"userId": user_id_obj})


# ---------------------------------------------------------------------------
# Test 3: All 5 agent results present
# ---------------------------------------------------------------------------

def test_3_all_five_agent_results_present():
    from app.database import get_collection

    user = register_user("ins3")
    user_id_obj = ObjectId(user["user"]["_id"])
    coll = get_collection("transaction_processing_records")
    rec = _make_processing_record(user_id_obj)
    coll.insert_one(rec)

    try:
        res = client.get("/api/v1/insights", headers=auth_header(user))
        assert res.status_code == 200
        data = res.json()
        assert data["financial_state"] is not None
        assert data["goal"] is not None
        assert data["conflict"] is not None
        assert data["scenario"] is not None
        assert data["explanation"] is not None
    finally:
        coll.delete_many({"userId": user_id_obj})


# ---------------------------------------------------------------------------
# Test 4: completed_stages populated
# ---------------------------------------------------------------------------

def test_4_completed_stages_populated():
    from app.database import get_collection

    user = register_user("ins4")
    user_id_obj = ObjectId(user["user"]["_id"])
    coll = get_collection("transaction_processing_records")
    rec = _make_processing_record(user_id_obj)
    coll.insert_one(rec)

    try:
        res = client.get("/api/v1/insights", headers=auth_header(user))
        data = res.json()
        stages = data["completed_stages"]
        assert len(stages) == 6
        assert "explanation_agent" in stages
    finally:
        coll.delete_many({"userId": user_id_obj})


# ---------------------------------------------------------------------------
# Test 5: History empty when no records
# ---------------------------------------------------------------------------

def test_5_history_empty_when_no_records():
    user = register_user("ins5")
    res = client.get("/api/v1/insights/history", headers=auth_header(user))
    assert res.status_code == 200
    assert res.json() == []


# ---------------------------------------------------------------------------
# Test 6: History returns up to N records
# ---------------------------------------------------------------------------

def test_6_history_returns_up_to_n_records():
    from app.database import get_collection

    user = register_user("ins6")
    user_id_obj = ObjectId(user["user"]["_id"])
    coll = get_collection("transaction_processing_records")

    records = [_make_processing_record(user_id_obj) for _ in range(5)]
    coll.insert_many(records)

    try:
        res = client.get(
            "/api/v1/insights/history?limit=3",
            headers=auth_header(user),
        )
        assert res.status_code == 200
        assert len(res.json()) == 3
    finally:
        coll.delete_many({"userId": user_id_obj})


# ---------------------------------------------------------------------------
# Test 7: Unauthenticated requests rejected
# ---------------------------------------------------------------------------

def test_7_unauthenticated_rejected():
    res = client.get("/api/v1/insights")
    assert res.status_code in (401, 403)


def test_7b_history_unauthenticated_rejected():
    res = client.get("/api/v1/insights/history")
    assert res.status_code in (401, 403)


# ---------------------------------------------------------------------------
# Test 8: History limit > 50 rejected
# ---------------------------------------------------------------------------

def test_8_history_limit_too_large_rejected():
    user = register_user("ins8")
    res = client.get(
        "/api/v1/insights/history?limit=100",
        headers=auth_header(user),
    )
    assert res.status_code == 422


# ---------------------------------------------------------------------------
# Test 9: Non-PROCESSED records not returned as latest insight
# ---------------------------------------------------------------------------

def test_9_non_processed_records_excluded_from_latest():
    from app.database import get_collection

    user = register_user("ins9")
    user_id_obj = ObjectId(user["user"]["_id"])
    coll = get_collection("transaction_processing_records")

    # Insert a FAILED record (not PROCESSED)
    failed_rec = _make_processing_record(user_id_obj, status="FAILED")
    failed_rec["financial_state_result"] = None
    failed_rec["explanation_result"] = None
    coll.insert_one(failed_rec)

    try:
        res = client.get("/api/v1/insights", headers=auth_header(user))
        assert res.status_code == 200
        data = res.json()
        # No PROCESSED record exists → available should be False
        assert data["available"] is False
    finally:
        coll.delete_many({"userId": user_id_obj})


# ---------------------------------------------------------------------------
# Test 10: Regression — pipeline tests still pass (import check)
# ---------------------------------------------------------------------------

def test_10_pipeline_route_still_importable():
    """Regression: Ensures the existing pipeline route is not broken."""
    from app.routes.pipeline import router as pipeline_router
    assert pipeline_router is not None


def test_10b_insights_route_importable():
    """Ensures the new insights route is properly importable."""
    from app.routes.insights import router as insights_router
    assert insights_router is not None
