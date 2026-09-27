"""Unit tests for the GoalSync Conflict Agent (Mocked Ollama Client).

Covers all 16 required test cases plus edge cases specified in the task.
"""

import pytest
from unittest.mock import MagicMock

from app.agents.conflict_agent.models import (
    ConflictAgentInput,
    ConflictAgentResult,
    ConflictRecord,
    GoalConflictSnapshot,
    ConflictType,
    ConflictSeverity,
    OverallStatus,
    AgentConfidence,
)
from app.agents.conflict_agent.llm_client import OllamaClient, OllamaResponseError
from app.agents.conflict_agent.agent import ConflictAgent


# ===========================================================================
# Shared helpers
# ===========================================================================

def _goal(
    name: str,
    required: float,
    status: str = "ON_TRACK",
    feasibility: str = "FEASIBLE",
    priority: str = "medium",
    target: float = 100000.0,
    current: float = 0.0,
    remaining: float = 100000.0,
    is_active: bool = True,
) -> GoalConflictSnapshot:
    return GoalConflictSnapshot(
        goal_name=name,
        goal_category="General",
        priority=priority,
        target_amount=target,
        current_amount=current,
        remaining_amount=remaining,
        required_monthly_contribution=required,
        goal_status=status,
        feasibility=feasibility,
        is_active=is_active,
    )

def _no_conflict_llm():
    return {
        "conflict_detected": False,
        "conflict_count": 0,
        "overall_status": "NO_CONFLICT",
        "conflicts": [],
        "summary": "All active goals are within the available monthly financial capacity.",
        "confidence": "high",
        "needs_clarification": False,
    }

def _capacity_conflict_llm(required, available, gap, goals):
    return {
        "conflict_detected": True,
        "conflict_count": 1,
        "overall_status": "CONFLICT",
        "conflicts": [
            {
                "conflict_type": "CAPACITY_CONFLICT",
                "severity": "HIGH",
                "title": "Goal contributions exceed monthly capacity",
                "description": f"Total required {required}/mo exceeds available {available}/mo by {gap}.",
                "affected_goals": goals,
                "deterministic_required_amount": required,
                "deterministic_available_amount": available,
                "deterministic_gap": gap,
            }
        ],
        "summary": f"Combined goals require {required}/mo but only {available}/mo is available.",
        "confidence": "high",
        "needs_clarification": False,
    }


# ===========================================================================
# Test 1: No conflict
# ===========================================================================

def test_1_no_conflict():
    """Test 1: No conflict when total required < available."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = _no_conflict_llm()

    snapshot = ConflictAgentInput(
        monthly_income=50000,
        monthly_expenses=30000,
        monthly_surplus=20000,
        available_monthly_amount=20000,
        goals=[
            _goal("Emergency Fund", required=5000),
            _goal("Vacation Fund", required=4000),
            _goal("Laptop", required=3000),
        ],
    )

    agent = ConflictAgent(llm_client=mock_client)
    result = agent.run(snapshot)

    assert isinstance(result, ConflictAgentResult)
    assert result.conflict_detected is False
    assert result.overall_status == OverallStatus.NO_CONFLICT
    assert result.conflicts == []
    assert result.conflict_count == 0


# ===========================================================================
# Test 2: Single capacity conflict
# ===========================================================================

def test_2_single_capacity_conflict():
    """Test 2: CAPACITY_CONFLICT when one goal exceeds available capacity."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = _capacity_conflict_llm(
        required=18000, available=15000, gap=3000, goals=["Emergency Fund", "Travel"]
    )

    snapshot = ConflictAgentInput(
        monthly_income=50000,
        monthly_expenses=35000,
        monthly_surplus=15000,
        available_monthly_amount=15000,
        goals=[
            _goal("Emergency Fund", required=10000, priority="high"),
            _goal("Travel", required=8000, priority="low"),
        ],
    )

    agent = ConflictAgent(llm_client=mock_client)
    result = agent.run(snapshot)

    assert result.conflict_detected is True
    assert result.overall_status == OverallStatus.CONFLICT
    assert len(result.conflicts) == 1
    cap_conflict = result.conflicts[0]
    assert cap_conflict.conflict_type == ConflictType.CAPACITY_CONFLICT
    assert cap_conflict.deterministic_required_amount == 18000.0
    assert cap_conflict.deterministic_available_amount == 15000.0
    assert cap_conflict.deterministic_gap == 3000.0


# ===========================================================================
# Test 3: Multiple-goal capacity conflict
# ===========================================================================

def test_3_multiple_goal_capacity_conflict():
    """Test 3: Multiple goals creating combined capacity conflict."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = {
        "conflict_detected": True,
        "conflict_count": 1,
        "overall_status": "CONFLICT",
        "conflicts": [
            {
                "conflict_type": "CAPACITY_CONFLICT",
                "severity": "HIGH",
                "title": "Three goals exceed monthly capacity",
                "description": "Three active goals collectively require 19000/mo but 15000 is available.",
                "affected_goals": ["Goal A", "Goal B", "Goal C"],
                "deterministic_required_amount": 19000.0,
                "deterministic_available_amount": 15000.0,
                "deterministic_gap": 4000.0,
            }
        ],
        "summary": "Three goals collectively exceed available capacity by 4000/mo.",
        "confidence": "high",
        "needs_clarification": False,
    }

    snapshot = ConflictAgentInput(
        monthly_income=50000,
        monthly_expenses=35000,
        monthly_surplus=15000,
        available_monthly_amount=15000,
        goals=[
            _goal("Goal A", required=8000, priority="essential"),
            _goal("Goal B", required=6000, priority="medium"),
            _goal("Goal C", required=5000, priority="flexible"),
        ],
    )

    agent = ConflictAgent(llm_client=mock_client)
    result = agent.run(snapshot)

    assert result.conflict_detected is True
    assert snapshot.total_required_monthly_contribution == 19000.0
    assert snapshot.monthly_capacity_gap == 4000.0
    assert len(result.conflicts) >= 1


# ===========================================================================
# Test 4: Goal feasibility conflict
# ===========================================================================

def test_4_goal_feasibility_conflict():
    """Test 4: GOAL_FEASIBILITY_CONFLICT when one goal is OFF_TRACK/INFEASIBLE."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = {
        "conflict_detected": True,
        "conflict_count": 1,
        "overall_status": "CONFLICT",
        "conflicts": [
            {
                "conflict_type": "GOAL_FEASIBILITY_CONFLICT",
                "severity": "HIGH",
                "title": "Car Purchase goal is infeasible",
                "description": "The Car Purchase goal is off-track and cannot be met under current conditions.",
                "affected_goals": ["Car Purchase"],
                "deterministic_required_amount": None,
                "deterministic_available_amount": None,
                "deterministic_gap": None,
            }
        ],
        "summary": "One goal in the portfolio is individually infeasible.",
        "confidence": "high",
        "needs_clarification": False,
    }

    snapshot = ConflictAgentInput(
        monthly_income=50000,
        monthly_expenses=30000,
        monthly_surplus=20000,
        available_monthly_amount=20000,
        goals=[
            _goal("Emergency Fund", required=5000, status="ON_TRACK", feasibility="FEASIBLE"),
            _goal("Car Purchase", required=40000, status="OFF_TRACK", feasibility="INFEASIBLE"),
        ],
    )

    agent = ConflictAgent(llm_client=mock_client)
    result = agent.run(snapshot)

    assert result.conflict_detected is True
    assert any(c.conflict_type == ConflictType.GOAL_FEASIBILITY_CONFLICT for c in result.conflicts)


# ===========================================================================
# Test 5: Financial state conflict
# ===========================================================================

def test_5_financial_state_conflict():
    """Test 5: FINANCIAL_STATE_CONFLICT when monthly_surplus < 0 with active goals."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = {
        "conflict_detected": True,
        "conflict_count": 1,
        "overall_status": "CONFLICT",
        "conflicts": [
            {
                "conflict_type": "FINANCIAL_STATE_CONFLICT",
                "severity": "CRITICAL",
                "title": "Negative monthly surplus with active goal obligations",
                "description": "Monthly expenses exceed income. Active goals cannot be funded from current cash flow.",
                "affected_goals": ["Emergency Fund"],
                "deterministic_required_amount": 5000.0,
                "deterministic_available_amount": 0.0,
                "deterministic_gap": 5000.0,
            }
        ],
        "summary": "Monthly deficit prevents any goal contributions from being made.",
        "confidence": "high",
        "needs_clarification": False,
    }

    snapshot = ConflictAgentInput(
        monthly_income=25000,
        monthly_expenses=30000,
        monthly_surplus=-5000,
        available_monthly_amount=0.0,
        goals=[
            _goal("Emergency Fund", required=5000),
        ],
    )

    agent = ConflictAgent(llm_client=mock_client)
    result = agent.run(snapshot)

    assert result.conflict_detected is True
    assert snapshot.has_financial_state_conflict is True


# ===========================================================================
# Test 6: Priority conflict
# ===========================================================================

def test_6_priority_conflict():
    """Test 6: PRIORITY_CONFLICT when mixed-priority goals compete for limited capacity."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = {
        "conflict_detected": True,
        "conflict_count": 1,
        "overall_status": "CONFLICT",
        "conflicts": [
            {
                "conflict_type": "PRIORITY_CONFLICT",
                "severity": "MEDIUM",
                "title": "Essential and flexible goals competing for limited capacity",
                "description": "An essential goal and a flexible goal are both requiring more than the available monthly capacity.",
                "affected_goals": ["Emergency Fund", "Entertainment"],
                "deterministic_required_amount": 18000.0,
                "deterministic_available_amount": 12000.0,
                "deterministic_gap": 6000.0,
            }
        ],
        "summary": "Goals with different priorities are competing for a limited monthly budget.",
        "confidence": "high",
        "needs_clarification": False,
    }

    snapshot = ConflictAgentInput(
        monthly_income=40000,
        monthly_expenses=28000,
        monthly_surplus=12000,
        available_monthly_amount=12000,
        goals=[
            _goal("Emergency Fund", required=10000, priority="essential"),
            _goal("Entertainment", required=8000, priority="flexible"),
        ],
    )

    agent = ConflictAgent(llm_client=mock_client)
    result = agent.run(snapshot)

    assert result.conflict_detected is True
    assert snapshot.has_priority_conflict is True


# ===========================================================================
# Test 7: Multiple simultaneous conflicts
# ===========================================================================

def test_7_multiple_simultaneous_conflicts():
    """Test 7: Multiple conflict types detected simultaneously."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = {
        "conflict_detected": True,
        "conflict_count": 2,
        "overall_status": "CONFLICT",
        "conflicts": [
            {
                "conflict_type": "CAPACITY_CONFLICT",
                "severity": "HIGH",
                "title": "Goals exceed capacity",
                "description": "Total required exceeds available monthly capacity.",
                "affected_goals": ["Emergency Fund", "Car"],
                "deterministic_required_amount": 45000.0,
                "deterministic_available_amount": 0.0,
                "deterministic_gap": 45000.0,
            },
            {
                "conflict_type": "FINANCIAL_STATE_CONFLICT",
                "severity": "CRITICAL",
                "title": "Negative surplus",
                "description": "Monthly expenses exceed income.",
                "affected_goals": ["Emergency Fund", "Car"],
                "deterministic_required_amount": None,
                "deterministic_available_amount": None,
                "deterministic_gap": None,
            },
        ],
        "summary": "Negative monthly surplus combined with excessive goal requirements creates multiple conflicts.",
        "confidence": "high",
        "needs_clarification": False,
    }

    snapshot = ConflictAgentInput(
        monthly_income=25000,
        monthly_expenses=30000,
        monthly_surplus=-5000,
        available_monthly_amount=0.0,
        goals=[
            _goal("Emergency Fund", required=20000, status="OFF_TRACK", feasibility="INFEASIBLE"),
            _goal("Car", required=25000, status="OFF_TRACK", feasibility="INFEASIBLE"),
        ],
    )

    agent = ConflictAgent(llm_client=mock_client)
    result = agent.run(snapshot)

    assert result.conflict_detected is True
    assert result.conflict_count >= 1
    assert snapshot.has_financial_state_conflict is True
    assert snapshot.has_feasibility_conflict is True


# ===========================================================================
# Test 8: Missing required input
# ===========================================================================

def test_8_missing_required_input():
    """Test 8: ConflictAgentInput raises ValidationError for missing required fields."""
    from pydantic import ValidationError

    with pytest.raises(ValidationError):
        ConflictAgentInput(
            # missing monthly_income
            monthly_expenses=30000,
            monthly_surplus=20000,
            available_monthly_amount=20000,
        )


# ===========================================================================
# Test 9: Invalid numerical input
# ===========================================================================

def test_9_invalid_numerical_input():
    """Test 9: ConflictAgentInput rejects negative non-negative fields."""
    from pydantic import ValidationError

    with pytest.raises(ValidationError):
        ConflictAgentInput(
            monthly_income=-1000.0,  # must be >= 0
            monthly_expenses=30000,
            monthly_surplus=-5000,
            available_monthly_amount=0.0,
        )

    with pytest.raises(ValidationError):
        ConflictAgentInput(
            monthly_income=50000,
            monthly_expenses=30000,
            monthly_surplus=20000,
            available_monthly_amount=-500.0,  # must be >= 0
        )


# ===========================================================================
# Test 10: Invalid LLM JSON
# ===========================================================================

def test_10_invalid_llm_json():
    """Test 10: OllamaResponseError propagated when LLM returns malformed JSON."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.side_effect = OllamaResponseError("Malformed JSON")

    snapshot = ConflictAgentInput(
        monthly_income=50000, monthly_expenses=30000,
        monthly_surplus=20000, available_monthly_amount=20000,
        goals=[_goal("Emergency Fund", required=5000)],
    )
    agent = ConflictAgent(llm_client=mock_client)

    with pytest.raises(OllamaResponseError):
        agent.run(snapshot)


# ===========================================================================
# Test 11: LLM schema validation
# ===========================================================================

def test_11_llm_schema_validation():
    """Test 11: Invalid enum in LLM JSON raises Pydantic ValidationError."""
    from pydantic import ValidationError

    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = {
        "conflict_detected": True,
        "conflict_count": 1,
        "overall_status": "VERY_BAD",  # invalid enum
        "conflicts": [],
        "summary": "Something happened.",
        "confidence": "high",
        "needs_clarification": False,
    }

    snapshot = ConflictAgentInput(
        monthly_income=50000, monthly_expenses=35000,
        monthly_surplus=15000, available_monthly_amount=15000,
        goals=[_goal("A", required=20000)],
    )
    agent = ConflictAgent(llm_client=mock_client)

    with pytest.raises(ValidationError):
        agent.run(snapshot)


# ===========================================================================
# Test 12: LLM cannot override deterministic conflict
# ===========================================================================

def test_12_llm_cannot_override_deterministic_conflict():
    """Test 12: Guardrail enforces conflict_detected=True when deterministic says CONFLICT."""
    mock_client = MagicMock(spec=OllamaClient)
    # LLM incorrectly says no conflict
    mock_client.generate_json.return_value = _no_conflict_llm()

    snapshot = ConflictAgentInput(
        monthly_income=50000,
        monthly_expenses=35000,
        monthly_surplus=15000,
        available_monthly_amount=15000,
        goals=[
            _goal("Goal A", required=10000),
            _goal("Goal B", required=8000),
        ],
    )

    agent = ConflictAgent(llm_client=mock_client)
    result = agent.run(snapshot)

    # Guardrail must override LLM denial
    assert result.conflict_detected is True
    assert result.overall_status == OverallStatus.CONFLICT
    assert len(result.conflicts) >= 1


# ===========================================================================
# Test 13: Deterministic gap calculation
# ===========================================================================

def test_13_deterministic_gap_calculation():
    """Test 13: monthly_capacity_gap is calculated correctly from inputs."""
    snapshot = ConflictAgentInput(
        monthly_income=50000, monthly_expenses=35000,
        monthly_surplus=15000, available_monthly_amount=15000,
        goals=[
            _goal("A", required=10000),
            _goal("B", required=8000),
        ],
    )
    assert snapshot.total_required_monthly_contribution == 18000.0
    assert snapshot.monthly_capacity_gap == 3000.0
    assert snapshot.has_capacity_conflict is True

    # Exact boundary — no conflict
    snap_equal = ConflictAgentInput(
        monthly_income=50000, monthly_expenses=30000,
        monthly_surplus=20000, available_monthly_amount=10000,
        goals=[_goal("A", required=10000)],
    )
    assert snap_equal.monthly_capacity_gap == 0.0
    assert snap_equal.has_capacity_conflict is False

    # Tiny over boundary — conflict
    snap_over = ConflictAgentInput(
        monthly_income=50000, monthly_expenses=30000,
        monthly_surplus=20000, available_monthly_amount=10000,
        goals=[_goal("A", required=10000.01)],
    )
    assert snap_over.has_capacity_conflict is True
    assert round(snap_over.monthly_capacity_gap, 2) == 0.01


# ===========================================================================
# Test 14: Affected goals are preserved
# ===========================================================================

def test_14_affected_goals_preserved():
    """Test 14: Guardrail overwrites affected_goals for CAPACITY_CONFLICT with active goal names."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = {
        "conflict_detected": True,
        "conflict_count": 1,
        "overall_status": "CONFLICT",
        "conflicts": [
            {
                "conflict_type": "CAPACITY_CONFLICT",
                "severity": "HIGH",
                "title": "Capacity exceeded",
                "description": "Goals exceed capacity.",
                "affected_goals": [],  # LLM left it empty
                "deterministic_required_amount": 18000.0,
                "deterministic_available_amount": 15000.0,
                "deterministic_gap": 3000.0,
            }
        ],
        "summary": "Conflict detected.",
        "confidence": "high",
        "needs_clarification": False,
    }

    snapshot = ConflictAgentInput(
        monthly_income=50000, monthly_expenses=35000,
        monthly_surplus=15000, available_monthly_amount=15000,
        goals=[
            _goal("Emergency Fund", required=10000),
            _goal("Travel", required=8000),
        ],
    )

    agent = ConflictAgent(llm_client=mock_client)
    result = agent.run(snapshot)

    cap = next(c for c in result.conflicts if c.conflict_type == ConflictType.CAPACITY_CONFLICT)
    # Guardrail must have populated affected_goals
    assert len(cap.affected_goals) == 2
    assert "Emergency Fund" in cap.affected_goals
    assert "Travel" in cap.affected_goals


# ===========================================================================
# Test 15: Forbidden financial advice rejected
# ===========================================================================

def test_15_forbidden_financial_advice_rejected():
    """Test 15: Summary containing financial advice raises Pydantic ValidationError."""
    from pydantic import ValidationError

    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = {
        "conflict_detected": True,
        "conflict_count": 1,
        "overall_status": "CONFLICT",
        "conflicts": [
            {
                "conflict_type": "CAPACITY_CONFLICT",
                "severity": "HIGH",
                "title": "Capacity conflict",
                "description": "Goals exceed capacity.",
                "affected_goals": ["A"],
                "deterministic_required_amount": 18000.0,
                "deterministic_available_amount": 15000.0,
                "deterministic_gap": 3000.0,
            }
        ],
        "summary": "You should cut your spending to resolve this conflict.",  # forbidden
        "confidence": "high",
        "needs_clarification": False,
    }

    snapshot = ConflictAgentInput(
        monthly_income=50000, monthly_expenses=35000,
        monthly_surplus=15000, available_monthly_amount=15000,
        goals=[_goal("A", required=18000)],
    )
    agent = ConflictAgent(llm_client=mock_client)

    with pytest.raises(ValidationError, match="safety policy"):
        agent.run(snapshot)


# ===========================================================================
# Test 16: needs_clarification behavior
# ===========================================================================

def test_16_needs_clarification_behavior():
    """Test 16: needs_clarification=True is preserved when LLM signals incomplete data."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = {
        "conflict_detected": False,
        "conflict_count": 0,
        "overall_status": "NO_CONFLICT",
        "conflicts": [],
        "summary": "Goal data is incomplete; further information is required to assess conflicts.",
        "confidence": "low",
        "needs_clarification": True,
    }

    snapshot = ConflictAgentInput(
        monthly_income=50000, monthly_expenses=30000,
        monthly_surplus=20000, available_monthly_amount=20000,
        goals=[],
    )
    agent = ConflictAgent(llm_client=mock_client)
    result = agent.run(snapshot)

    assert result.needs_clarification is True
    assert result.confidence == AgentConfidence.LOW


# ===========================================================================
# Edge Cases (A–G from task spec)
# ===========================================================================

def test_edge_a_available_zero_required_nonzero():
    """Edge A: available=0, required=5000 → CONFLICT."""
    snapshot = ConflictAgentInput(
        monthly_income=20000, monthly_expenses=20000,
        monthly_surplus=0.0, available_monthly_amount=0.0,
        goals=[_goal("X", required=5000)],
    )
    assert snapshot.has_capacity_conflict is True
    assert snapshot.monthly_capacity_gap == 5000.0


def test_edge_b_available_equals_required():
    """Edge B: available=10000, required=10000 → NO capacity conflict."""
    snapshot = ConflictAgentInput(
        monthly_income=50000, monthly_expenses=30000,
        monthly_surplus=20000, available_monthly_amount=10000,
        goals=[_goal("X", required=10000)],
    )
    assert snapshot.has_capacity_conflict is False
    assert snapshot.monthly_capacity_gap == 0.0


def test_edge_c_tiny_over_boundary():
    """Edge C: available=10000, required=10000.01 → CONFLICT."""
    snapshot = ConflictAgentInput(
        monthly_income=50000, monthly_expenses=30000,
        monthly_surplus=20000, available_monthly_amount=10000,
        goals=[_goal("X", required=10000.01)],
    )
    assert snapshot.has_capacity_conflict is True


def test_edge_d_no_active_goals():
    """Edge D: No goals → deterministic_conflict_detected=False."""
    snapshot = ConflictAgentInput(
        monthly_income=50000, monthly_expenses=30000,
        monthly_surplus=20000, available_monthly_amount=20000,
        goals=[],
    )
    assert snapshot.deterministic_conflict_detected is False
    assert snapshot.active_goals == []


def test_edge_e_all_goals_completed():
    """Edge E: All goals completed → NO_CONFLICT."""
    snapshot = ConflictAgentInput(
        monthly_income=50000, monthly_expenses=30000,
        monthly_surplus=20000, available_monthly_amount=20000,
        goals=[
            _goal("Fund A", required=0, status="COMPLETED", feasibility="ACHIEVED",
                  current=100000, remaining=0),
            _goal("Fund B", required=0, status="COMPLETED", feasibility="ACHIEVED",
                  current=50000, remaining=0),
        ],
    )
    assert snapshot.deterministic_conflict_detected is False
    assert len(snapshot.active_goals) == 0


def test_edge_f_negative_surplus_with_active_goals():
    """Edge F: Negative monthly surplus with active goals → FINANCIAL_STATE_CONFLICT."""
    snapshot = ConflictAgentInput(
        monthly_income=20000, monthly_expenses=25000,
        monthly_surplus=-5000, available_monthly_amount=0,
        goals=[_goal("Emergency Fund", required=5000)],
    )
    assert snapshot.has_financial_state_conflict is True
    assert snapshot.deterministic_conflict_detected is True


def test_edge_g_only_one_infeasible():
    """Edge G: Mixed portfolio with one infeasible goal → GOAL_FEASIBILITY_CONFLICT only."""
    snapshot = ConflictAgentInput(
        monthly_income=50000, monthly_expenses=30000,
        monthly_surplus=20000, available_monthly_amount=20000,
        goals=[
            _goal("Emergency Fund", required=5000, status="ON_TRACK", feasibility="FEASIBLE"),
            _goal("Car", required=40000, status="OFF_TRACK", feasibility="INFEASIBLE"),
        ],
    )
    # No capacity conflict (5000+40000>20000 → actually there IS one here, let's check)
    # Actually 5000+40000 = 45000 > 20000 → capacity conflict also
    # For pure feasibility test, use a completed goal with high required but active=False
    snapshot2 = ConflictAgentInput(
        monthly_income=50000, monthly_expenses=30000,
        monthly_surplus=20000, available_monthly_amount=20000,
        goals=[
            _goal("Emergency Fund", required=5000, status="ON_TRACK", feasibility="FEASIBLE"),
            _goal("Car", required=8000, status="OFF_TRACK", feasibility="INFEASIBLE"),
        ],
    )
    # total = 13000 < 20000 → no capacity conflict
    assert snapshot2.has_capacity_conflict is False
    # But feasibility conflict exists
    assert snapshot2.has_feasibility_conflict is True
    assert snapshot2.deterministic_conflict_detected is True


def test_active_goals_excludes_completed():
    """Additional: active_goals excludes COMPLETED goals."""
    snapshot = ConflictAgentInput(
        monthly_income=50000, monthly_expenses=30000,
        monthly_surplus=20000, available_monthly_amount=20000,
        goals=[
            _goal("Fund A", required=5000, status="ON_TRACK", feasibility="FEASIBLE"),
            _goal("Fund B", required=0, status="COMPLETED", feasibility="ACHIEVED",
                  current=100000, remaining=0),
        ],
    )
    active = snapshot.active_goals
    assert len(active) == 1
    assert active[0].goal_name == "Fund A"
