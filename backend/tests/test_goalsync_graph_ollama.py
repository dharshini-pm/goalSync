"""Real Ollama integration test for the GoalSync LangGraph pipeline.

Uses actual llama3.2 via local Ollama server.
Skips gracefully if Ollama is unavailable or llama3.2 not installed.

Run:
    python -m pytest tests/test_goalsync_graph_ollama.py -v -s

WARNING: This test calls Ollama SIX times and may take 2–10 minutes.
"""

from __future__ import annotations

import pytest
import requests


# ---------------------------------------------------------------------------
# Skip guard
# ---------------------------------------------------------------------------

def _ollama_ready() -> bool:
    try:
        r = requests.get("http://localhost:11434/api/tags", timeout=5)
        if r.status_code != 200:
            return False
        models = [m.get("name", "") for m in r.json().get("models", [])]
        return any("llama3.2" in m for m in models)
    except Exception:
        return False


OLLAMA_SKIP = pytest.mark.skipif(
    not _ollama_ready(),
    reason="Ollama not available or llama3.2 not installed",
)


# ---------------------------------------------------------------------------
# Minimal realistic fixture (small prompt to keep test fast)
# ---------------------------------------------------------------------------

TRANSACTION_INPUT = {
    "merchant": "BigBasket",
    "amount": 1200.0,
    "transaction_type": "debit",
    "payment_method": "UPI",
    "date": "2025-01-20",
}

FINANCIAL_SNAPSHOT = {
    "monthly_income": 60000.0,
    "monthly_expenses": 42000.0,
    "monthly_surplus": 18000.0,
    "savings_rate": 30.0,
    "total_emi": 3000.0,
    "available_monthly_amount": 10000.0,
    "current_savings": 30000.0,
}

# One goal that WILL produce a conflict (required > available * 2 so conflict triggers)
GOAL_INPUT = [
    {
        "goal_name": "Emergency Fund",
        "goal_category": "Emergency Fund",
        "priority": "high",
        "target_amount": 120000.0,
        "current_amount": 30000.0,
        "remaining_amount": 90000.0,
        "target_date": "2026-06-01",
        "months_remaining": 17,
        "days_remaining": 497,
        "required_monthly_contribution": 5294.0,
        "available_monthly_amount": 10000.0,
        "monthly_shortfall": 0.0,
        "surplus_coverage_ratio": 1.89,
        "feasibility_status": "feasible",
        "feasibility_score": 65.0,
        "is_achievable_without_savings": True,
        "is_achievable_with_savings": True,
        "current_savings": 30000.0,
        "monthly_surplus": 18000.0,
    }
]


# ---------------------------------------------------------------------------
# Integration test
# ---------------------------------------------------------------------------

@OLLAMA_SKIP
def test_full_pipeline_ollama():
    """Real end-to-end LangGraph run with llama3.2.

    Verifies:
    - All six agents actually execute through LangGraph
    - All six stages appear in completed_stages
    - Each agent produced a non-empty result
    - Explanation headline is present
    - No graph-level errors
    """
    from app.orchestration.service import GoalSyncGraphService

    svc = GoalSyncGraphService()
    result = svc.run(
        transaction_input=TRANSACTION_INPUT,
        financial_state_snapshot=FINANCIAL_SNAPSHOT,
        goal_input=GOAL_INPUT,
        user_id="test-ollama-user",
    )

    print("\n=== GoalSync Graph Integration Test ===")
    print(f"Request ID     : {result.request_id}")
    print(f"Success        : {result.success}")
    print(f"Completed stages: {result.completed_stages}")
    print(f"Errors         : {result.errors}")

    if result.explanation_result:
        print(f"Headline       : {result.explanation_result.get('headline')}")
        print(f"Summary        : {result.explanation_result.get('summary', '')[:120]}")

    for trace in result.execution_trace:
        print(f"  [{trace.stage}] {trace.status} in {trace.duration_ms:.0f}ms")

    # Hard assertions
    expected_stages = [
        "transaction_agent",
        "financial_state_agent",
        "goal_agent",
        "conflict_agent",
        "scenario_agent",
        "explanation_agent",
    ]
    assert result.completed_stages == expected_stages, (
        f"Stages mismatch: {result.completed_stages}"
    )

    assert len(result.errors) == 0, f"Graph errors: {result.errors}"
    assert result.transaction_result is not None
    assert result.financial_state_result is not None
    assert result.goal_result is not None and len(result.goal_result) > 0
    assert result.conflict_result is not None
    assert result.scenario_result is not None
    assert result.explanation_result is not None
    assert result.explanation_result.get("headline"), "Explanation headline is empty"
    assert result.success
