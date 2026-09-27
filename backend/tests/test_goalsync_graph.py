"""Unit tests for GoalSync LangGraph orchestration.

All agent services are mocked so these tests:
- Run offline (no Ollama required)
- Execute fast (<1 second)
- Verify graph structure, state propagation, error handling
"""

from __future__ import annotations

import dataclasses
import uuid
from typing import Any, Dict, List
from unittest.mock import MagicMock, patch


# ---------------------------------------------------------------------------
# Fixtures / helpers
# ---------------------------------------------------------------------------

TRANSACTION_INPUT: Dict[str, Any] = {
    "merchant": "Swiggy",
    "amount": 350.0,
    "transaction_type": "debit",
    "payment_method": "UPI",
    "date": "2025-01-15",
}

FINANCIAL_SNAPSHOT: Dict[str, Any] = {
    "monthly_income": 80000.0,
    "monthly_expenses": 55000.0,
    "monthly_surplus": 25000.0,
    "savings_rate": 31.25,
    "total_emi": 5000.0,
    "available_monthly_amount": 15000.0,
    "current_savings": 50000.0,
}

GOAL_INPUT: List[Dict[str, Any]] = [
    {
        "goal_name": "Emergency Fund",
        "goal_category": "Emergency Fund",
        "priority": "high",
        "target_amount": 200000.0,
        "current_amount": 50000.0,
        "remaining_amount": 150000.0,
        "target_date": "2027-01-01",
        "months_remaining": 24,
        "days_remaining": 730,
        "required_monthly_contribution": 6250.0,
        "available_monthly_amount": 15000.0,
        "monthly_shortfall": 0.0,
        "surplus_coverage_ratio": 2.4,
        "feasibility_status": "feasible",
        "feasibility_score": 75.0,
        "is_achievable_without_savings": True,
        "is_achievable_with_savings": True,
        "current_savings": 50000.0,
        "monthly_surplus": 25000.0,
    }
]

MOCK_TRANSACTION_RESULT = MagicMock(
    merchant_name="Swiggy",
    category="Food & Dining",
    transaction_type="Expense",
    summary="Food order from Swiggy.",
    reasoning="Standard food delivery transaction.",
    confidence="high",
    needs_clarification=False,
)

MOCK_FINANCIAL_RESULT = MagicMock(
    financial_status=MagicMock(value="STABLE"),
    cash_flow_status=MagicMock(value="POSITIVE"),
    summary="Finances are stable.",
    key_signals=["Surplus 25000"],
    concerns=[],
    confidence=MagicMock(value="high"),
    needs_clarification=False,
)

MOCK_GOAL_RESULT = MagicMock(
    goal_name="Emergency Fund",
    goal_status=MagicMock(value="ON_TRACK"),
    feasibility=MagicMock(value="FEASIBLE"),
    summary="Goal is on track.",
    key_signals=["Adequate surplus"],
    concerns=[],
    confidence=MagicMock(value="high"),
    needs_clarification=False,
)

MOCK_CONFLICT_RESULT = MagicMock(
    conflict_detected=False,
    conflict_count=0,
    overall_status=MagicMock(value="NO_CONFLICT"),
    conflicts=[],
    summary="No conflicts detected.",
    confidence=MagicMock(value="high"),
    needs_clarification=False,
)

MOCK_SCENARIO_RESULT = MagicMock(
    scenario_required=False,
    scenario_count=0,
    scenarios=[],
    summary="No scenarios required.",
    confidence=MagicMock(value="high"),
    needs_clarification=False,
)

MOCK_EXPLANATION_RESULT = MagicMock(
    headline="Your finances are healthy.",
    summary="All goals on track, no conflicts.",
    key_points=["Surplus is sufficient."],
    goal_impacts=[MagicMock(goal_name="Emergency Fund", explanation="On track.", status="ON_TRACK")],
    conflict_explanation=MagicMock(detected=False, explanation="No conflicts."),
    scenario_explanations=[],
    assumptions=["Stable income assumed."],
    confidence="high",
    needs_clarification=False,
)


def _all_service_mocks():
    """Context managers for all six agent services.

    nodes.py uses lazy imports (inside function bodies), so we patch at the
    real service module locations — where the class objects actually live when
    nodes.py does `from app.agents.xxx.service import XxxService`.
    """
    return [
        patch(
            "app.agents.transaction_agent.service.TransactionAgentService.create_default",
            return_value=MagicMock(analyze=MagicMock(return_value=MOCK_TRANSACTION_RESULT)),
        ),
        patch(
            "app.agents.financial_state_agent.service.FinancialStateAgentService.create_default",
            return_value=MagicMock(analyze=MagicMock(return_value=MOCK_FINANCIAL_RESULT)),
        ),
        patch(
            "app.agents.goal_agent.service.GoalAgentService.create_default",
            return_value=MagicMock(analyze=MagicMock(return_value=MOCK_GOAL_RESULT)),
        ),
        patch(
            "app.agents.conflict_agent.service.ConflictAgentService.create_default",
            return_value=MagicMock(analyze=MagicMock(return_value=MOCK_CONFLICT_RESULT)),
        ),
        patch(
            "app.agents.scenario_agent.service.ScenarioAgentService.create_default",
            return_value=MagicMock(generate=MagicMock(return_value=MOCK_SCENARIO_RESULT)),
        ),
        patch(
            "app.agents.explanation_agent.service.ExplanationAgentService.create_default",
            return_value=MagicMock(explain=MagicMock(return_value=MOCK_EXPLANATION_RESULT)),
        ),
    ]


import contextlib

@contextlib.contextmanager
def all_mocked():
    patches = _all_service_mocks()
    started = []
    try:
        for p in patches:
            started.append(p.start())
        yield started
    finally:
        for p in patches:
            p.stop()


# ---------------------------------------------------------------------------
# Import targets
# ---------------------------------------------------------------------------

def _import_graph():
    from app.orchestration.graph import build_graph
    return build_graph


def _import_service():
    from app.orchestration.service import GoalSyncGraphService
    return GoalSyncGraphService


def _import_state():
    from app.orchestration.state import GoalSyncState, GraphResult
    return GoalSyncState, GraphResult


# ---------------------------------------------------------------------------
# T01 — Graph compiles
# ---------------------------------------------------------------------------

def test_graph_compiles():
    build_graph = _import_graph()
    g = build_graph()
    assert g is not None


# ---------------------------------------------------------------------------
# T02 — Service instantiates
# ---------------------------------------------------------------------------

def test_service_instantiates():
    GoalSyncGraphService = _import_service()
    svc = GoalSyncGraphService()
    assert svc is not None


# ---------------------------------------------------------------------------
# T03 — Full happy-path run: six stages complete, results present
# ---------------------------------------------------------------------------

def test_full_happy_path():
    GoalSyncGraphService = _import_service()
    with all_mocked():
        svc = GoalSyncGraphService()
        result = svc.run(
            transaction_input=TRANSACTION_INPUT,
            financial_state_snapshot=FINANCIAL_SNAPSHOT,
            goal_input=GOAL_INPUT,
            user_id="user-001",
        )

    assert result.success, f"Graph failed: {result.errors}"
    assert len(result.errors) == 0
    assert result.transaction_result is not None
    assert result.financial_state_result is not None
    assert result.goal_result is not None
    assert result.conflict_result is not None
    assert result.scenario_result is not None
    assert result.explanation_result is not None


# ---------------------------------------------------------------------------
# T04 — Correct stage order
# ---------------------------------------------------------------------------

def test_correct_stage_order():
    GoalSyncGraphService = _import_service()
    with all_mocked():
        svc = GoalSyncGraphService()
        result = svc.run(
            transaction_input=TRANSACTION_INPUT,
            financial_state_snapshot=FINANCIAL_SNAPSHOT,
            goal_input=GOAL_INPUT,
        )

    EXPECTED = [
        "transaction_agent",
        "financial_state_agent",
        "goal_agent",
        "conflict_agent",
        "scenario_agent",
        "explanation_agent",
    ]
    assert result.completed_stages == EXPECTED, (
        f"Stage order mismatch: {result.completed_stages}"
    )


# ---------------------------------------------------------------------------
# T05 — All six stages complete
# ---------------------------------------------------------------------------

def test_all_six_stages_complete():
    GoalSyncGraphService = _import_service()
    with all_mocked():
        svc = GoalSyncGraphService()
        result = svc.run(
            transaction_input=TRANSACTION_INPUT,
            financial_state_snapshot=FINANCIAL_SNAPSHOT,
            goal_input=GOAL_INPUT,
        )
    assert len(result.completed_stages) == 6


# ---------------------------------------------------------------------------
# T06 — request_id is generated
# ---------------------------------------------------------------------------

def test_request_id_generated():
    GoalSyncGraphService = _import_service()
    with all_mocked():
        svc = GoalSyncGraphService()
        result = svc.run(
            transaction_input=TRANSACTION_INPUT,
            financial_state_snapshot=FINANCIAL_SNAPSHOT,
            goal_input=GOAL_INPUT,
        )
    assert result.request_id
    # Must parse as UUID
    uuid.UUID(result.request_id)


# ---------------------------------------------------------------------------
# T07 — Caller-supplied request_id is preserved
# ---------------------------------------------------------------------------

def test_request_id_preserved():
    GoalSyncGraphService = _import_service()
    fixed_id = str(uuid.uuid4())
    with all_mocked():
        svc = GoalSyncGraphService()
        result = svc.run(
            transaction_input=TRANSACTION_INPUT,
            financial_state_snapshot=FINANCIAL_SNAPSHOT,
            goal_input=GOAL_INPUT,
            request_id=fixed_id,
        )
    assert result.request_id == fixed_id


# ---------------------------------------------------------------------------
# T08 — Execution trace has 6 entries
# ---------------------------------------------------------------------------

def test_execution_trace_six_entries():
    GoalSyncGraphService = _import_service()
    with all_mocked():
        svc = GoalSyncGraphService()
        result = svc.run(
            transaction_input=TRANSACTION_INPUT,
            financial_state_snapshot=FINANCIAL_SNAPSHOT,
            goal_input=GOAL_INPUT,
        )
    assert len(result.execution_trace) == 6


# ---------------------------------------------------------------------------
# T09 — Each trace entry has required fields and is "completed"
# ---------------------------------------------------------------------------

def test_trace_entries_structure():
    GoalSyncGraphService = _import_service()
    with all_mocked():
        svc = GoalSyncGraphService()
        result = svc.run(
            transaction_input=TRANSACTION_INPUT,
            financial_state_snapshot=FINANCIAL_SNAPSHOT,
            goal_input=GOAL_INPUT,
        )
    for trace in result.execution_trace:
        assert trace.stage
        assert trace.status == "completed"
        assert trace.started_at
        assert trace.completed_at
        assert trace.duration_ms >= 0


# ---------------------------------------------------------------------------
# T10 — Transaction node runs first
# ---------------------------------------------------------------------------

def test_transaction_node_runs_first():
    GoalSyncGraphService = _import_service()
    with all_mocked():
        svc = GoalSyncGraphService()
        result = svc.run(
            transaction_input=TRANSACTION_INPUT,
            financial_state_snapshot=FINANCIAL_SNAPSHOT,
            goal_input=GOAL_INPUT,
        )
    assert result.execution_trace[0].stage == "transaction_agent"


# ---------------------------------------------------------------------------
# T11 — Financial state node runs second
# ---------------------------------------------------------------------------

def test_financial_state_node_runs_second():
    GoalSyncGraphService = _import_service()
    with all_mocked():
        svc = GoalSyncGraphService()
        result = svc.run(
            transaction_input=TRANSACTION_INPUT,
            financial_state_snapshot=FINANCIAL_SNAPSHOT,
            goal_input=GOAL_INPUT,
        )
    assert result.execution_trace[1].stage == "financial_state_agent"


# ---------------------------------------------------------------------------
# T12 — Explanation node runs last
# ---------------------------------------------------------------------------

def test_explanation_node_runs_last():
    GoalSyncGraphService = _import_service()
    with all_mocked():
        svc = GoalSyncGraphService()
        result = svc.run(
            transaction_input=TRANSACTION_INPUT,
            financial_state_snapshot=FINANCIAL_SNAPSHOT,
            goal_input=GOAL_INPUT,
        )
    assert result.execution_trace[-1].stage == "explanation_agent"


# ---------------------------------------------------------------------------
# T13 — Transaction result key fields present
# ---------------------------------------------------------------------------

def test_transaction_result_fields():
    GoalSyncGraphService = _import_service()
    with all_mocked():
        svc = GoalSyncGraphService()
        result = svc.run(
            transaction_input=TRANSACTION_INPUT,
            financial_state_snapshot=FINANCIAL_SNAPSHOT,
            goal_input=GOAL_INPUT,
        )
    tr = result.transaction_result
    assert tr is not None
    for key in ("merchant_name", "category", "transaction_type", "summary", "confidence"):
        assert key in tr, f"Missing key: {key}"


# ---------------------------------------------------------------------------
# T14 — Financial state result key fields present
# ---------------------------------------------------------------------------

def test_financial_state_result_fields():
    GoalSyncGraphService = _import_service()
    with all_mocked():
        svc = GoalSyncGraphService()
        result = svc.run(
            transaction_input=TRANSACTION_INPUT,
            financial_state_snapshot=FINANCIAL_SNAPSHOT,
            goal_input=GOAL_INPUT,
        )
    fsr = result.financial_state_result
    assert fsr is not None
    for key in ("financial_status", "cash_flow_status", "summary"):
        assert key in fsr


# ---------------------------------------------------------------------------
# T15 — Goal result is a list
# ---------------------------------------------------------------------------

def test_goal_result_is_list():
    GoalSyncGraphService = _import_service()
    with all_mocked():
        svc = GoalSyncGraphService()
        result = svc.run(
            transaction_input=TRANSACTION_INPUT,
            financial_state_snapshot=FINANCIAL_SNAPSHOT,
            goal_input=GOAL_INPUT,
        )
    assert isinstance(result.goal_result, list)
    assert len(result.goal_result) == 1


# ---------------------------------------------------------------------------
# T16 — Conflict result fields present
# ---------------------------------------------------------------------------

def test_conflict_result_fields():
    GoalSyncGraphService = _import_service()
    with all_mocked():
        svc = GoalSyncGraphService()
        result = svc.run(
            transaction_input=TRANSACTION_INPUT,
            financial_state_snapshot=FINANCIAL_SNAPSHOT,
            goal_input=GOAL_INPUT,
        )
    cr = result.conflict_result
    assert cr is not None
    for key in ("conflict_detected", "conflict_count", "overall_status", "summary"):
        assert key in cr


# ---------------------------------------------------------------------------
# T17 — Scenario result fields present
# ---------------------------------------------------------------------------

def test_scenario_result_fields():
    GoalSyncGraphService = _import_service()
    with all_mocked():
        svc = GoalSyncGraphService()
        result = svc.run(
            transaction_input=TRANSACTION_INPUT,
            financial_state_snapshot=FINANCIAL_SNAPSHOT,
            goal_input=GOAL_INPUT,
        )
    sr = result.scenario_result
    assert sr is not None
    for key in ("scenario_required", "scenario_count", "summary"):
        assert key in sr


# ---------------------------------------------------------------------------
# T18 — Explanation result fields present
# ---------------------------------------------------------------------------

def test_explanation_result_fields():
    GoalSyncGraphService = _import_service()
    with all_mocked():
        svc = GoalSyncGraphService()
        result = svc.run(
            transaction_input=TRANSACTION_INPUT,
            financial_state_snapshot=FINANCIAL_SNAPSHOT,
            goal_input=GOAL_INPUT,
        )
    er = result.explanation_result
    assert er is not None
    for key in ("headline", "summary", "conflict_explanation"):
        assert key in er


# ---------------------------------------------------------------------------
# T19 — No-conflict flow: conflict_detected == False
# ---------------------------------------------------------------------------

def test_no_conflict_flow():
    GoalSyncGraphService = _import_service()
    with all_mocked():
        svc = GoalSyncGraphService()
        result = svc.run(
            transaction_input=TRANSACTION_INPUT,
            financial_state_snapshot=FINANCIAL_SNAPSHOT,
            goal_input=GOAL_INPUT,
        )
    assert result.conflict_result["conflict_detected"] is False
    assert result.conflict_result["overall_status"] == "NO_CONFLICT"


# ---------------------------------------------------------------------------
# T20 — Critical failure stops graph and records error
# ---------------------------------------------------------------------------

def test_critical_failure_stops_graph():
    GoalSyncGraphService = _import_service()

    failing_txn = MagicMock(
        side_effect=RuntimeError("Ollama unavailable")
    )

    with patch(
        "app.agents.transaction_agent.service.TransactionAgentService.create_default",
        return_value=MagicMock(analyze=failing_txn),
    ):
        svc = GoalSyncGraphService()
        result = svc.run(
            transaction_input=TRANSACTION_INPUT,
            financial_state_snapshot=FINANCIAL_SNAPSHOT,
            goal_input=GOAL_INPUT,
        )

    assert not result.success
    assert len(result.errors) >= 1
    assert result.errors[0].stage == "transaction_agent"
    # Downstream nodes must NOT have run
    assert result.financial_state_result is None
    assert result.explanation_result is None


# ---------------------------------------------------------------------------
# T21 — Deterministic financial_state_snapshot is never overwritten
# ---------------------------------------------------------------------------

def test_deterministic_snapshot_preserved():
    GoalSyncGraphService = _import_service()
    with all_mocked():
        svc = GoalSyncGraphService()
        result = svc.run(
            transaction_input=TRANSACTION_INPUT,
            financial_state_snapshot=FINANCIAL_SNAPSHOT,
            goal_input=GOAL_INPUT,
        )
    # financial_state_snapshot must remain exactly as supplied
    # (nodes read it but must not overwrite it)
    # We verify indirectly: the financial_state_result is a SEPARATE dict
    assert result.financial_state_result is not None
    assert "financial_status" in result.financial_state_result  # LLM interpretation
    # financial_state_snapshot values are authoritative numeric values, not LLM fields
    # (the snapshot itself is not exposed in GraphResult intentionally, but
    #  we verify the result dict does not contain engine raw keys)
    assert "monthly_income" not in result.financial_state_result  # engine value, not in result


# ---------------------------------------------------------------------------
# T22 — GraphResult.to_dict() is serialisable
# ---------------------------------------------------------------------------

def test_graph_result_to_dict():
    GoalSyncGraphService = _import_service()
    with all_mocked():
        svc = GoalSyncGraphService()
        result = svc.run(
            transaction_input=TRANSACTION_INPUT,
            financial_state_snapshot=FINANCIAL_SNAPSHOT,
            goal_input=GOAL_INPUT,
        )
    d = result.to_dict()
    assert isinstance(d, dict)
    assert "request_id" in d
    assert "completed_stages" in d


# ---------------------------------------------------------------------------
# T23 — GoalSyncState dataclass initialises cleanly
# ---------------------------------------------------------------------------

def test_state_initialises():
    GoalSyncState, GraphResult = _import_state()
    s = GoalSyncState(request_id="abc", user_id="u1")
    assert s.request_id == "abc"
    assert s.completed_stages == []
    assert s.errors == []
    assert s.execution_trace == []
    assert s.transaction_result is None


# ---------------------------------------------------------------------------
# T24 — Multiple goals produce multiple goal_results
# ---------------------------------------------------------------------------

def test_multiple_goals():
    GoalSyncGraphService = _import_service()
    multi_goal_input = GOAL_INPUT + [
        {
            **GOAL_INPUT[0],
            "goal_name": "Vacation Fund",
            "target_amount": 100000.0,
        }
    ]
    with all_mocked():
        svc = GoalSyncGraphService()
        result = svc.run(
            transaction_input=TRANSACTION_INPUT,
            financial_state_snapshot=FINANCIAL_SNAPSHOT,
            goal_input=multi_goal_input,
        )
    # GoalAgentService.analyze is mocked to return one result per call
    assert isinstance(result.goal_result, list)
    assert len(result.goal_result) == 2


# ---------------------------------------------------------------------------
# T25 — Empty goal_input is handled without crash
# ---------------------------------------------------------------------------

def test_empty_goal_input():
    GoalSyncGraphService = _import_service()
    with all_mocked():
        svc = GoalSyncGraphService()
        result = svc.run(
            transaction_input=TRANSACTION_INPUT,
            financial_state_snapshot=FINANCIAL_SNAPSHOT,
            goal_input=[],
        )
    assert result.goal_result == []
    assert result.success
