"""Unit tests for the GoalSync Scenario Agent (Mocked Ollama Client).

Covers all 20 required test cases specified in the task.
"""

import pytest
from datetime import date, timedelta
from unittest.mock import MagicMock

from app.agents.scenario_agent.models import (
    ScenarioAgentInput,
    ScenarioAgentResult,
    ScenarioRecord,
    GoalScenarioSnapshot,
    ConflictSummary,
    ScenarioType,
    ProjectedGoalStatus,
    AgentConfidence,
)
from app.agents.scenario_agent.llm_client import OllamaClient, OllamaResponseError
from app.agents.scenario_agent.agent import ScenarioAgent
from app.agents.scenario_agent.deterministic_engine import (
    build_deterministic_scenarios,
    compute_timeline_adjustment,
    compute_contribution_reallocation,
    compute_capacity_change,
    compute_single_goal_focus,
)


# ===========================================================================
# Shared helpers
# ===========================================================================

def _future_date(months: int = 12) -> str:
    ref = date.today()
    y = ref.year + (ref.month + months - 1) // 12
    m = (ref.month + months - 1) % 12 + 1
    return f"{y:04d}-{m:02d}-01"


def _goal(
    name: str,
    required: float,
    target: float = 100000.0,
    current: float = 0.0,
    remaining: float = 100000.0,
    status: str = "ON_TRACK",
    feasibility: str = "FEASIBLE",
    priority: str = "medium",
    target_date: str = None,
) -> GoalScenarioSnapshot:
    return GoalScenarioSnapshot(
        goal_name=name,
        goal_category="General",
        priority=priority,
        target_amount=target,
        current_amount=current,
        remaining_amount=remaining,
        required_monthly_contribution=required,
        goal_status=status,
        feasibility=feasibility,
        target_date=target_date or _future_date(12),
    )


def _conflict_snapshot(
    goals,
    available: float = 15000.0,
    income: float = 50000.0,
    conflict: bool = True,
) -> ScenarioAgentInput:
    return ScenarioAgentInput(
        monthly_income=income,
        monthly_expenses=income - 15000.0,
        monthly_surplus=15000.0,
        available_monthly_amount=available,
        current_savings=50000.0,
        total_emi=5000.0,
        savings_rate=30.0,
        goals=goals,
        conflict_detected=conflict,
        conflict_count=1 if conflict else 0,
        overall_status="CONFLICT" if conflict else "NO_CONFLICT",
        conflicts=[
            ConflictSummary(
                conflict_type="CAPACITY_CONFLICT",
                severity="HIGH",
                title="Capacity conflict",
                description="Total required exceeds available.",
                affected_goals=[g.goal_name for g in goals],
                deterministic_required_amount=sum(g.required_monthly_contribution for g in goals),
                deterministic_available_amount=available,
                deterministic_gap=max(0.0, sum(g.required_monthly_contribution for g in goals) - available),
            )
        ] if conflict else [],
    )


def _mock_llm(scenarios: list, summary: str = "Scenario analysis complete.") -> MagicMock:
    """Build a MagicMock OllamaClient that returns valid scenario JSON."""
    mock = MagicMock(spec=OllamaClient)
    mock.generate_json.return_value = {
        "scenario_required": True,
        "scenario_count": len(scenarios),
        "scenarios": scenarios,
        "summary": summary,
        "confidence": "high",
        "needs_clarification": False,
    }
    return mock


def _scenario_dict(s: ScenarioRecord) -> dict:
    return {
        "scenario_id": s.scenario_id,
        "scenario_type": s.scenario_type.value,
        "title": s.title,
        "assumptions": list(s.assumptions),
        "affected_goals": list(s.affected_goals),
        "original_monthly_requirement": s.original_monthly_requirement,
        "scenario_monthly_requirement": s.scenario_monthly_requirement,
        "monthly_capacity": s.monthly_capacity,
        "capacity_gap": s.capacity_gap,
        "projected_goal_status": s.projected_goal_status.value,
        "description": s.description,
    }


# ===========================================================================
# Test 1: No conflict returns scenario_required=False
# ===========================================================================

def test_1_no_conflict_returns_no_scenarios():
    """Test 1: conflict_detected=False → no scenarios, scenario_required=False."""
    mock = MagicMock(spec=OllamaClient)
    snapshot = _conflict_snapshot(
        goals=[_goal("Emergency Fund", 5000.0)],
        available=15000.0,
        conflict=False,
    )
    agent = ScenarioAgent(llm_client=mock)
    result = agent.run(snapshot)

    assert result.scenario_required is False
    assert result.scenario_count == 0
    assert result.scenarios == []
    mock.generate_json.assert_not_called()


# ===========================================================================
# Test 2: Conflict generates scenarios
# ===========================================================================

def test_2_conflict_generates_scenarios():
    """Test 2: conflict_detected=True → scenario_required=True and scenarios populated."""
    goals = [
        _goal("Goal A", required=10000.0),
        _goal("Goal B", required=8000.0),
    ]
    snapshot = _conflict_snapshot(goals=goals, available=15000.0, conflict=True)
    det = build_deterministic_scenarios(snapshot)
    mock = _mock_llm([_scenario_dict(s) for s in det])

    agent = ScenarioAgent(llm_client=mock)
    result = agent.run(snapshot)

    assert result.scenario_required is True
    assert result.scenario_count >= 1
    assert len(result.scenarios) >= 1
    assert isinstance(result.scenarios[0], ScenarioRecord)


# ===========================================================================
# Test 3: Timeline adjustment deterministic calculation
# ===========================================================================

def test_3_timeline_adjustment_deterministic():
    """Test 3: Extending timeline reduces contribution deterministically."""
    goal = _goal("Travel", required=10000.0, remaining=60000.0, target_date=_future_date(6))
    orig_req, sc_req, gap, status, assumptions = compute_timeline_adjustment(
        goal=goal, extend_months=6, available_monthly_amount=15000.0
    )
    # Original: 60000 / 6 months = 10000
    assert orig_req == 10000.0
    # Scenario: 60000 / 12 months = 5000
    assert sc_req == 5000.0
    assert gap == 0.0  # 5000 < 15000 — no shortfall
    assert status == ProjectedGoalStatus.ON_TRACK


# ===========================================================================
# Test 4: Contribution reallocation
# ===========================================================================

def test_4_contribution_reallocation():
    """Test 4: Reallocation total equals available capacity exactly."""
    goals = [
        _goal("A", required=10000.0),
        _goal("B", required=8000.0),
    ]
    orig_req, sc_req, gap, status, assumptions, affected = compute_contribution_reallocation(
        active_goals=goals, available_monthly_amount=15000.0
    )
    assert abs(sc_req - 15000.0) < 0.1  # Total allocation == capacity
    assert gap == 0.0
    assert set(affected) == {"A", "B"}


# ===========================================================================
# Test 5: Single goal focus
# ===========================================================================

def test_5_single_goal_focus():
    """Test 5: All capacity directed to one goal."""
    goals = [
        _goal("Emergency Fund", required=10000.0),
        _goal("Travel", required=8000.0),
    ]
    focused = goals[0]
    orig_req, sc_req, gap, status, assumptions, affected = compute_single_goal_focus(
        focused_goal=focused,
        all_active_goals=goals,
        available_monthly_amount=15000.0,
    )
    assert sc_req == 10000.0  # Only focused goal's requirement
    assert gap == 0.0         # 10000 < 15000
    assert "Emergency Fund" in affected
    assert "Travel" in affected


# ===========================================================================
# Test 6: Capacity change
# ===========================================================================

def test_6_capacity_change():
    """Test 6: Capacity change scenario uses new_capacity in gap calculation."""
    goals = [_goal("A", required=10000.0), _goal("B", required=8000.0)]
    orig_req, sc_req, gap, status, assumptions = compute_capacity_change(
        active_goals=goals, original_capacity=15000.0, new_capacity=18000.0
    )
    assert orig_req == 18000.0  # 10000 + 8000
    assert sc_req == 18000.0   # requirements unchanged
    assert gap == 0.0           # 18000 == 18000 — no shortfall
    assert "increased" in assumptions[0]


# ===========================================================================
# Test 7: Multiple goals generate multiple scenario types
# ===========================================================================

def test_7_multiple_goals_multiple_scenario_types():
    """Test 7: Multiple active goals → multiple scenario records."""
    goals = [
        _goal("Emergency Fund", required=10000.0),
        _goal("Travel", required=8000.0),
    ]
    snapshot = _conflict_snapshot(goals=goals, available=15000.0, conflict=True)
    det = build_deterministic_scenarios(snapshot)
    types = {s.scenario_type for s in det}
    assert ScenarioType.TIMELINE_ADJUSTMENT in types
    assert ScenarioType.CONTRIBUTION_REALLOCATION in types
    assert ScenarioType.SINGLE_GOAL_FOCUS in types
    assert ScenarioType.CAPACITY_CHANGE in types


# ===========================================================================
# Test 8: Completed goal is excluded
# ===========================================================================

def test_8_completed_goal_excluded():
    """Test 8: Completed goals are excluded from active scenarios."""
    goals = [
        _goal("Emergency Fund", required=10000.0),
        _goal("Completed Goal", required=0.0, remaining=0.0, status="completed"),
    ]
    snapshot = _conflict_snapshot(goals=goals, available=5000.0, conflict=True)
    assert len(snapshot.active_goals) == 1
    assert snapshot.active_goals[0].goal_name == "Emergency Fund"


# ===========================================================================
# Test 9: Invalid target date handled gracefully
# ===========================================================================

def test_9_invalid_target_date():
    """Test 9: Invalid target_date returns None from months_remaining_from."""
    goal = _goal("A", required=5000.0)
    # Override target_date with bad string using model_copy
    bad_goal = GoalScenarioSnapshot(
        goal_name="A",
        target_amount=100000.0,
        remaining_amount=60000.0,
        required_monthly_contribution=5000.0,
        target_date="not-a-date",
    )
    months = bad_goal.months_remaining_from()
    assert months is None


# ===========================================================================
# Test 10: Zero remaining amount
# ===========================================================================

def test_10_zero_remaining_amount():
    """Test 10: Zero remaining_amount → contribution = 0.0."""
    goal = GoalScenarioSnapshot(
        goal_name="Done",
        target_amount=50000.0,
        remaining_amount=0.0,
        required_monthly_contribution=0.0,
    )
    assert goal.deterministic_contribution_for_months(12) == 0.0
    assert goal.is_completed is True


# ===========================================================================
# Test 11: Deterministic monthly contribution calculation
# ===========================================================================

def test_11_deterministic_monthly_contribution():
    """Test 11: remaining / months = correct contribution."""
    goal = GoalScenarioSnapshot(
        goal_name="Car",
        target_amount=120000.0,
        remaining_amount=60000.0,
        required_monthly_contribution=5000.0,
    )
    assert goal.deterministic_contribution_for_months(12) == 5000.0
    assert goal.deterministic_contribution_for_months(6) == 10000.0
    assert goal.deterministic_contribution_for_months(0) == 0.0


# ===========================================================================
# Test 12: Deterministic capacity gap calculation
# ===========================================================================

def test_12_deterministic_capacity_gap():
    """Test 12: monthly_capacity_gap = max(0, total_required - available)."""
    goals = [_goal("A", required=10000.0), _goal("B", required=8000.0)]
    snapshot = _conflict_snapshot(goals=goals, available=15000.0)
    assert snapshot.total_required_monthly_contribution == 18000.0
    assert snapshot.monthly_capacity_gap == 3000.0
    assert snapshot.has_capacity_shortfall is True


# ===========================================================================
# Test 13: Invalid LLM JSON triggers error
# ===========================================================================

def test_13_invalid_llm_json():
    """Test 13: OllamaResponseError raised when LLM returns invalid JSON."""
    from app.agents.scenario_agent.llm_client import OllamaResponseError
    goals = [_goal("A", required=10000.0), _goal("B", required=8000.0)]
    snapshot = _conflict_snapshot(goals=goals, available=5000.0, conflict=True)
    mock = MagicMock(spec=OllamaClient)
    mock.generate_json.side_effect = OllamaResponseError("invalid JSON")
    agent = ScenarioAgent(llm_client=mock)
    with pytest.raises(OllamaResponseError):
        agent.run(snapshot)


# ===========================================================================
# Test 14: LLM schema validation
# ===========================================================================

def test_14_llm_schema_validation():
    """Test 14: Missing required field raises ValidationError."""
    from pydantic import ValidationError
    with pytest.raises(ValidationError):
        ScenarioAgentResult.model_validate({
            # Missing 'scenario_required', 'summary'
            "scenarios": [],
        })


# ===========================================================================
# Test 15: LLM cannot override deterministic values
# ===========================================================================

def test_15_llm_cannot_override_deterministic_values():
    """Test 15: Agent guardrail restores deterministic numbers even if LLM changes them."""
    goals = [_goal("A", required=10000.0), _goal("B", required=8000.0)]
    snapshot = _conflict_snapshot(goals=goals, available=15000.0, conflict=True)
    det = build_deterministic_scenarios(snapshot)
    assert det, "Expected at least one deterministic scenario"

    # LLM deliberately returns wrong numbers for S1
    first = det[0]
    tampered = {
        "scenario_id": first.scenario_id,
        "scenario_type": first.scenario_type.value,
        "title": first.title,
        "assumptions": first.assumptions,
        "affected_goals": first.affected_goals,
        "original_monthly_requirement": 999999.0,   # wrong
        "scenario_monthly_requirement": 888888.0,   # wrong
        "monthly_capacity": 777777.0,               # wrong
        "capacity_gap": 111111.0,                   # wrong
        "projected_goal_status": "OFF_TRACK",
        "description": "Tampered by LLM.",
    }
    mock = MagicMock(spec=OllamaClient)
    mock.generate_json.return_value = {
        "scenario_required": True,
        "scenario_count": 1,
        "scenarios": [tampered],
        "summary": "Scenario analysis.",
        "confidence": "high",
        "needs_clarification": False,
    }
    agent = ScenarioAgent(llm_client=mock)
    result = agent.run(snapshot)

    # Guardrail must restore deterministic values for S1
    guarded = next(s for s in result.scenarios if s.scenario_id == first.scenario_id)
    assert guarded.original_monthly_requirement == first.original_monthly_requirement
    assert guarded.scenario_monthly_requirement == first.scenario_monthly_requirement
    assert guarded.monthly_capacity == first.monthly_capacity
    assert guarded.capacity_gap == first.capacity_gap


# ===========================================================================
# Test 16: Invalid mathematical allocation rejected
# ===========================================================================

def test_16_invalid_allocation_exceeds_capacity():
    """Test 16: Reallocation total never exceeds capacity (deterministic guarantee)."""
    goals = [_goal("A", required=10000.0), _goal("B", required=8000.0)]
    orig_req, sc_req, gap, status, assumptions, affected = compute_contribution_reallocation(
        active_goals=goals, available_monthly_amount=15000.0
    )
    # Scenario total must NOT exceed capacity
    assert sc_req <= 15000.0 + 0.01  # small float tolerance


# ===========================================================================
# Test 17: Forbidden financial advice rejected
# ===========================================================================

def test_17_forbidden_financial_advice_rejected():
    """Test 17: Summary with forbidden phrase raises ValidationError."""
    from pydantic import ValidationError
    with pytest.raises(ValidationError):
        ScenarioAgentResult.model_validate({
            "scenario_required": True,
            "scenarios": [],
            "summary": "You should invest the surplus in mutual funds.",
            "confidence": "high",
            "needs_clarification": False,
        })


# ===========================================================================
# Test 18: needs_clarification behavior
# ===========================================================================

def test_18_needs_clarification_behavior():
    """Test 18: needs_clarification can be True when LLM signals uncertainty."""
    goals = [_goal("A", required=10000.0), _goal("B", required=8000.0)]
    snapshot = _conflict_snapshot(goals=goals, available=15000.0, conflict=True)
    det = build_deterministic_scenarios(snapshot)
    mock = MagicMock(spec=OllamaClient)
    mock.generate_json.return_value = {
        "scenario_required": True,
        "scenario_count": len(det),
        "scenarios": [_scenario_dict(s) for s in det],
        "summary": "Scenarios were generated but additional information may help.",
        "confidence": "medium",
        "needs_clarification": True,
    }
    agent = ScenarioAgent(llm_client=mock)
    result = agent.run(snapshot)
    assert result.needs_clarification is True


# ===========================================================================
# Test 19: Scenario assumptions preserved
# ===========================================================================

def test_19_scenario_assumptions_preserved():
    """Test 19: Assumptions from deterministic engine are present in output."""
    goal = _goal("Travel", required=10000.0, remaining=60000.0, target_date=_future_date(6))
    _, _, _, _, assumptions = compute_timeline_adjustment(
        goal=goal, extend_months=6, available_monthly_amount=15000.0
    )
    assert any("extended" in a.lower() or "target date" in a.lower() for a in assumptions)
    assert any("remaining amount" in a.lower() for a in assumptions)


# ===========================================================================
# Test 20: Scenario numerical values preserved through guardrail
# ===========================================================================

def test_20_scenario_numerical_values_preserved():
    """Test 20: All deterministic numerical values survive the agent guardrail."""
    goals = [_goal("A", required=10000.0), _goal("B", required=8000.0)]
    snapshot = _conflict_snapshot(goals=goals, available=15000.0, conflict=True)
    det = build_deterministic_scenarios(snapshot)
    mock = _mock_llm([_scenario_dict(s) for s in det])
    agent = ScenarioAgent(llm_client=mock)
    result = agent.run(snapshot)

    for det_s in det:
        out_s = next((s for s in result.scenarios if s.scenario_id == det_s.scenario_id), None)
        assert out_s is not None, f"Scenario {det_s.scenario_id} missing from output"
        assert out_s.original_monthly_requirement == det_s.original_monthly_requirement
        assert out_s.scenario_monthly_requirement == det_s.scenario_monthly_requirement
        assert out_s.monthly_capacity == det_s.monthly_capacity
        assert out_s.capacity_gap == det_s.capacity_gap
        assert out_s.projected_goal_status == det_s.projected_goal_status


# ===========================================================================
# Edge case A: No active goals — engine returns empty list
# ===========================================================================

def test_edge_a_no_active_goals():
    """Edge A: When all goals are completed, no scenarios are generated."""
    goals = [
        _goal("Done", required=0.0, remaining=0.0, status="completed"),
    ]
    snapshot = _conflict_snapshot(goals=goals, available=15000.0, conflict=True)
    det = build_deterministic_scenarios(snapshot)
    assert det == []


# ===========================================================================
# Edge case B: Only one active goal
# ===========================================================================

def test_edge_b_single_active_goal():
    """Edge B: Single active goal generates timeline + capacity scenarios."""
    goals = [_goal("Emergency Fund", required=12000.0)]
    snapshot = _conflict_snapshot(goals=goals, available=10000.0, conflict=True)
    det = build_deterministic_scenarios(snapshot)
    types = {s.scenario_type for s in det}
    assert ScenarioType.TIMELINE_ADJUSTMENT in types
    assert ScenarioType.CAPACITY_CHANGE in types
    # No reallocation or single-focus needed for single goal
    assert ScenarioType.CONTRIBUTION_REALLOCATION not in types
    assert ScenarioType.SINGLE_GOAL_FOCUS not in types


# ===========================================================================
# Edge case C: Available capacity = 0
# ===========================================================================

def test_edge_c_zero_capacity():
    """Edge C: Zero available capacity — no division by zero errors."""
    goals = [_goal("A", required=10000.0), _goal("B", required=5000.0)]
    snapshot = _conflict_snapshot(goals=goals, available=0.0, conflict=True)
    det = build_deterministic_scenarios(snapshot)
    # Engine must run without raising exceptions
    for s in det:
        assert s.capacity_gap >= 0.0


# ===========================================================================
# Edge case D: Past target date
# ===========================================================================

def test_edge_d_past_target_date():
    """Edge D: Past target date → months_remaining_from returns 0."""
    goal = _goal("Old Goal", required=5000.0, target_date="2020-01-01")
    months = goal.months_remaining_from()
    assert months == 0


# ===========================================================================
# Edge case E: scenario_required must match conflict_detected (guardrail)
# ===========================================================================

def test_edge_e_guardrail_scenario_required():
    """Edge E: Guardrail forces scenario_required to match conflict_detected."""
    goals = [_goal("A", required=10000.0), _goal("B", required=8000.0)]
    snapshot = _conflict_snapshot(goals=goals, available=15000.0, conflict=True)
    det = build_deterministic_scenarios(snapshot)
    mock = MagicMock(spec=OllamaClient)
    mock.generate_json.return_value = {
        "scenario_required": False,  # LLM incorrectly says False
        "scenario_count": 0,
        "scenarios": [_scenario_dict(s) for s in det],
        "summary": "No scenarios needed.",
        "confidence": "high",
        "needs_clarification": False,
    }
    agent = ScenarioAgent(llm_client=mock)
    result = agent.run(snapshot)
    assert result.scenario_required is True  # Guardrail corrects it
