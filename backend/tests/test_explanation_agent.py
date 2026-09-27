"""Unit tests for the GoalSync Explanation Agent (Mocked Ollama Client).

Covers all 20 required test cases + edge cases.
"""

import pytest
from unittest.mock import MagicMock

from app.agents.explanation_agent.models import (
    ExplanationAgentInput,
    ExplanationAgentResult,
    GoalExplanationSnapshot,
    ConflictExplanationSnapshot,
    ScenarioExplanationSnapshot,
    GoalImpactExplanation,
    ConflictExplanationOutput,
    ScenarioExplanationOutput,
)
from app.agents.explanation_agent.llm_client import OllamaClient, OllamaResponseError
from app.agents.explanation_agent.agent import ExplanationAgent


# ===========================================================================
# Shared helpers
# ===========================================================================

def _goal(name, required=5000.0, status="ON_TRACK", feasibility="FEASIBLE",
          remaining=50000.0, target=100000.0, current=50000.0,
          target_date="2027-01-01", priority="medium", completed=False):
    if completed:
        remaining, status, feasibility = 0.0, "completed", "achieved"
    return GoalExplanationSnapshot(
        goal_name=name, goal_category="General", priority=priority,
        target_amount=target, current_amount=current, target_date=target_date,
        required_monthly_contribution=required, remaining_amount=remaining,
        goal_status=status, feasibility=feasibility,
    )


def _conflict(ctype="CAPACITY_CONFLICT", severity="HIGH", title="Conflict",
              affected=None, req=18000.0, avail=15000.0, gap=3000.0):
    return ConflictExplanationSnapshot(
        conflict_type=ctype, severity=severity, title=title,
        description="Deterministic conflict.", affected_goals=affected or ["Goal A"],
        deterministic_required_amount=req, deterministic_available_amount=avail,
        deterministic_gap=gap,
    )


def _scenario(sid="S1", stype="TIMELINE_ADJUSTMENT", title="Extend timeline",
              orig=15000.0, sc_req=6000.0, cap=13000.0, gap=0.0,
              status="ON_TRACK", affected=None):
    return ScenarioExplanationSnapshot(
        scenario_id=sid, scenario_type=stype, title=title,
        assumptions=["Target date extended by 6 months."],
        affected_goals=affected or ["Goal A"],
        original_monthly_requirement=orig, scenario_monthly_requirement=sc_req,
        monthly_capacity=cap, capacity_gap=gap, projected_goal_status=status,
        description="Under this scenario...",
    )


def _snapshot(goals=None, conflicts=None, scenarios=None, conflict=False,
              available=15000.0, income=50000.0):
    return ExplanationAgentInput(
        monthly_income=income,
        monthly_expenses=income - available - 5000.0,
        monthly_surplus=available + 5000.0,
        available_monthly_amount=available,
        current_savings=50000.0,
        total_emi=5000.0,
        savings_rate=30.0,
        financial_status="STABLE",
        cash_flow_status="POSITIVE",
        key_signals=["Stable income"],
        concerns=[] if not conflict else ["Capacity shortfall"],
        goals=goals or [],
        conflict_detected=conflict,
        conflict_count=len(conflicts) if conflicts else 0,
        overall_conflict_status="CONFLICT" if conflict else "NO_CONFLICT",
        conflicts=conflicts or [],
        scenario_required=conflict,
        scenario_count=len(scenarios) if scenarios else 0,
        scenarios=scenarios or [],
    )


def _llm_result(headline="Financial summary.", summary="Details here.",
                key_points=None, goal_impacts=None, conflict_exp=None,
                scenario_exps=None, assumptions=None,
                conflict=False, needs_clarif=False):
    return {
        "headline": headline,
        "summary": summary,
        "key_points": key_points or ["Point A.", "Point B."],
        "goal_impacts": goal_impacts or [],
        "conflict_explanation": conflict_exp or {
            "detected": conflict,
            "explanation": "No conflict detected." if not conflict
                           else "Capacity conflict exists.",
        },
        "scenario_explanations": scenario_exps or [],
        "assumptions": assumptions or [],
        "confidence": "high",
        "needs_clarification": needs_clarif,
    }


def _mock(return_value: dict) -> MagicMock:
    m = MagicMock(spec=OllamaClient)
    m.generate_json.return_value = return_value
    return m


# ===========================================================================
# Test 1: Conflict explanation
# ===========================================================================

def test_1_conflict_explanation():
    """Test 1: conflict_detected=True → conflict_explanation.detected=True."""
    snap = _snapshot(
        goals=[_goal("A", required=18000.0)],
        conflicts=[_conflict()],
        scenarios=[_scenario()],
        conflict=True, available=15000.0,
    )
    mock = _mock(_llm_result(
        conflict=True,
        goal_impacts=[{"goal_name": "A", "explanation": "Requires 18000.", "status": "ON_TRACK"}],
        scenario_exps=[{"scenario_id": "S1", "explanation": "Under S1..."}],
    ))
    result = ExplanationAgent(llm_client=mock).run(snap)
    assert result.conflict_explanation.detected is True
    assert isinstance(result, ExplanationAgentResult)


# ===========================================================================
# Test 2: No-conflict explanation
# ===========================================================================

def test_2_no_conflict_explanation():
    """Test 2: conflict_detected=False → conflict_explanation.detected=False."""
    snap = _snapshot(goals=[_goal("A", required=5000.0)], conflict=False, available=15000.0)
    mock = _mock(_llm_result(conflict=False))
    result = ExplanationAgent(llm_client=mock).run(snap)
    assert result.conflict_explanation.detected is False
    assert result.scenario_explanations == []


# ===========================================================================
# Test 3: Goal explanation
# ===========================================================================

def test_3_goal_explanation():
    """Test 3: goal_impacts contain all goal names from input."""
    snap = _snapshot(
        goals=[_goal("Emergency Fund", required=10000.0, status="AT_RISK")],
        conflict=False, available=15000.0,
    )
    mock = _mock(_llm_result(
        goal_impacts=[{"goal_name": "Emergency Fund",
                       "explanation": "Requires 10000.", "status": "AT_RISK"}],
    ))
    result = ExplanationAgent(llm_client=mock).run(snap)
    names = [i.goal_name for i in result.goal_impacts]
    assert "Emergency Fund" in names


# ===========================================================================
# Test 4: Multiple goals
# ===========================================================================

def test_4_multiple_goals():
    """Test 4: All goals appear in goal_impacts after guardrail."""
    snap = _snapshot(
        goals=[_goal("A"), _goal("B")],
        conflict=False, available=15000.0,
    )
    mock = _mock(_llm_result(
        goal_impacts=[
            {"goal_name": "A", "explanation": "Goal A ok.", "status": "ON_TRACK"},
            {"goal_name": "B", "explanation": "Goal B ok.", "status": "ON_TRACK"},
        ],
    ))
    result = ExplanationAgent(llm_client=mock).run(snap)
    names = {i.goal_name for i in result.goal_impacts}
    assert "A" in names and "B" in names


# ===========================================================================
# Test 5: Multiple conflicts
# ===========================================================================

def test_5_multiple_conflicts():
    """Test 5: Multiple conflict records in input → conflict detected."""
    snap = _snapshot(
        goals=[_goal("A"), _goal("B")],
        conflicts=[_conflict("CAPACITY_CONFLICT"), _conflict("PRIORITY_CONFLICT",
                   title="Priority conflict", req=None, avail=None, gap=None)],
        scenarios=[_scenario()],
        conflict=True, available=15000.0,
    )
    mock = _mock(_llm_result(
        conflict=True,
        goal_impacts=[
            {"goal_name": "A", "explanation": "A affected.", "status": "ON_TRACK"},
            {"goal_name": "B", "explanation": "B affected.", "status": "ON_TRACK"},
        ],
        scenario_exps=[{"scenario_id": "S1", "explanation": "Under S1..."}],
    ))
    result = ExplanationAgent(llm_client=mock).run(snap)
    assert result.conflict_explanation.detected is True
    assert snap.conflict_count == 2


# ===========================================================================
# Test 6: Scenario explanation
# ===========================================================================

def test_6_scenario_explanation():
    """Test 6: Scenarios are explained in output."""
    snap = _snapshot(
        goals=[_goal("A", required=15000.0)],
        conflicts=[_conflict()],
        scenarios=[_scenario("S1")],
        conflict=True, available=13000.0,
    )
    mock = _mock(_llm_result(
        conflict=True,
        goal_impacts=[{"goal_name": "A", "explanation": "At risk.", "status": "AT_RISK"}],
        scenario_exps=[{"scenario_id": "S1", "explanation": "Under S1 contribution drops."}],
    ))
    result = ExplanationAgent(llm_client=mock).run(snap)
    ids = [s.scenario_id for s in result.scenario_explanations]
    assert "S1" in ids


# ===========================================================================
# Test 7: Multiple scenarios explained
# ===========================================================================

def test_7_multiple_scenarios():
    """Test 7: All scenario IDs appear in output."""
    snap = _snapshot(
        goals=[_goal("A", required=15000.0)],
        conflicts=[_conflict()],
        scenarios=[_scenario("S1"), _scenario("S2", orig=15000.0, sc_req=3750.0)],
        conflict=True, available=13000.0,
    )
    mock = _mock(_llm_result(
        conflict=True,
        goal_impacts=[{"goal_name": "A", "explanation": "At risk.", "status": "AT_RISK"}],
        scenario_exps=[
            {"scenario_id": "S1", "explanation": "S1 extends 6 months."},
            {"scenario_id": "S2", "explanation": "S2 extends 12 months."},
        ],
    ))
    result = ExplanationAgent(llm_client=mock).run(snap)
    ids = {s.scenario_id for s in result.scenario_explanations}
    assert "S1" in ids and "S2" in ids


# ===========================================================================
# Test 8: Deterministic numerical values preserved
# ===========================================================================

def test_8_deterministic_values_in_prompt():
    """Test 8: Snapshot properties compute correct totals."""
    snap = _snapshot(
        goals=[_goal("A", required=10000.0), _goal("B", required=8000.0)],
        conflict=True, available=15000.0,
    )
    assert snap.total_required_monthly == 18000.0
    assert snap.capacity_gap == 3000.0


# ===========================================================================
# Test 9: LLM numerical hallucination corrected (goal status)
# ===========================================================================

def test_9_llm_goal_status_corrected():
    """Test 9: If LLM changes goal status from AT_RISK to ON_TRACK, guardrail restores it."""
    snap = _snapshot(
        goals=[_goal("A", status="AT_RISK")],
        conflict=False, available=15000.0,
    )
    mock = _mock(_llm_result(
        goal_impacts=[{"goal_name": "A", "explanation": "All good.",
                       "status": "ON_TRACK"}],  # LLM incorrectly says ON_TRACK
    ))
    result = ExplanationAgent(llm_client=mock).run(snap)
    a_impact = next(i for i in result.goal_impacts if i.goal_name == "A")
    assert a_impact.status == "AT_RISK"   # guardrail must restore


# ===========================================================================
# Test 10: Invalid LLM JSON triggers error
# ===========================================================================

def test_10_invalid_llm_json():
    """Test 10: OllamaResponseError propagates when LLM returns invalid JSON."""
    snap = _snapshot(goals=[_goal("A")], conflict=False)
    mock = MagicMock(spec=OllamaClient)
    mock.generate_json.side_effect = OllamaResponseError("bad json")
    with pytest.raises(OllamaResponseError):
        ExplanationAgent(llm_client=mock).run(snap)


# ===========================================================================
# Test 11: Pydantic validation rejects malformed output
# ===========================================================================

def test_11_pydantic_validation():
    """Test 11: Missing required fields raise ValidationError."""
    from pydantic import ValidationError
    with pytest.raises(ValidationError):
        ExplanationAgentResult.model_validate({
            # Missing headline, summary, conflict_explanation
            "key_points": [],
        })


# ===========================================================================
# Test 12: Missing information → needs_clarification
# ===========================================================================

def test_12_missing_info_needs_clarification():
    """Test 12: LLM signals needs_clarification=True when info is missing."""
    snap = _snapshot(goals=[_goal("A", target_date=None)], conflict=False)
    mock = _mock({**_llm_result(), "needs_clarification": True})
    result = ExplanationAgent(llm_client=mock).run(snap)
    assert result.needs_clarification is True


# ===========================================================================
# Test 13: needs_clarification=False by default
# ===========================================================================

def test_13_needs_clarification_default_false():
    """Test 13: needs_clarification defaults to False for a complete input."""
    snap = _snapshot(goals=[_goal("A")], conflict=False)
    mock = _mock(_llm_result())
    result = ExplanationAgent(llm_client=mock).run(snap)
    assert result.needs_clarification is False


# ===========================================================================
# Test 14: Forbidden advice rejected in summary
# ===========================================================================

def test_14_forbidden_advice_rejected():
    """Test 14: Summary with forbidden phrase raises ValidationError."""
    from pydantic import ValidationError
    with pytest.raises(ValidationError):
        ExplanationAgentResult.model_validate({
            "headline": "Summary.",
            "summary": "You should invest in mutual funds.",
            "key_points": [],
            "goal_impacts": [],
            "conflict_explanation": {"detected": False, "explanation": "None."},
            "scenario_explanations": [],
            "assumptions": [],
            "confidence": "high",
            "needs_clarification": False,
        })


# ===========================================================================
# Test 15: Scenario ranking language rejected
# ===========================================================================

def test_15_scenario_ranking_rejected():
    """Test 15: Headline with 'best scenario' raises ValidationError."""
    from pydantic import ValidationError
    with pytest.raises(ValidationError):
        ExplanationAgentResult.model_validate({
            "headline": "The best scenario is S1.",
            "summary": "S1 is clearly better.",
            "key_points": [],
            "goal_impacts": [],
            "conflict_explanation": {"detected": False, "explanation": "None."},
            "scenario_explanations": [],
            "assumptions": [],
            "confidence": "high",
            "needs_clarification": False,
        })


# ===========================================================================
# Test 16: Recommendation language rejected
# ===========================================================================

def test_16_recommendation_language_rejected():
    """Test 16: 'I recommend' in key_points raises ValidationError."""
    from pydantic import ValidationError
    with pytest.raises(ValidationError):
        ExplanationAgentResult.model_validate({
            "headline": "Summary.",
            "summary": "Overview here.",
            "key_points": ["I recommend extending Goal A's timeline."],
            "goal_impacts": [],
            "conflict_explanation": {"detected": False, "explanation": "None."},
            "scenario_explanations": [],
            "assumptions": [],
            "confidence": "high",
            "needs_clarification": False,
        })


# ===========================================================================
# Test 17: Assumptions preserved
# ===========================================================================

def test_17_assumptions_preserved():
    """Test 17: Scenario assumptions appear in result.assumptions."""
    snap = _snapshot(
        goals=[_goal("A", required=15000.0)],
        conflicts=[_conflict()],
        scenarios=[_scenario("S1")],
        conflict=True, available=13000.0,
    )
    mock = _mock(_llm_result(
        conflict=True,
        assumptions=["Target date extended by 6 months."],
        goal_impacts=[{"goal_name": "A", "explanation": "At risk.", "status": "AT_RISK"}],
        scenario_exps=[{"scenario_id": "S1", "explanation": "Under S1..."}],
    ))
    result = ExplanationAgent(llm_client=mock).run(snap)
    assert len(result.assumptions) >= 1


# ===========================================================================
# Test 18: Facts vs interpretation — conflict_explanation.detected is fact
# ===========================================================================

def test_18_fact_conflict_detected_is_preserved():
    """Test 18: conflict_explanation.detected always matches input conflict_detected."""
    for conflict_flag in (True, False):
        snap = _snapshot(
            goals=[_goal("A")],
            conflicts=[_conflict()] if conflict_flag else [],
            scenarios=[_scenario()] if conflict_flag else [],
            conflict=conflict_flag, available=15000.0,
        )
        mock = _mock(_llm_result(
            conflict=not conflict_flag,   # LLM deliberately flips the flag
            scenario_exps=[{"scenario_id": "S1", "explanation": "S1."}] if conflict_flag else [],
            goal_impacts=[{"goal_name": "A", "explanation": "A.", "status": "ON_TRACK"}],
        ))
        result = ExplanationAgent(llm_client=mock).run(snap)
        assert result.conflict_explanation.detected is conflict_flag


# ===========================================================================
# Test 19: Completed goal explained as completed
# ===========================================================================

def test_19_completed_goal():
    """Test 19: Completed goal has is_completed=True and status preserved."""
    snap = _snapshot(
        goals=[_goal("Completed Goal", completed=True)],
        conflict=False, available=15000.0,
    )
    assert snap.goals[0].is_completed is True
    assert snap.active_goals == []
    mock = _mock(_llm_result(
        goal_impacts=[{"goal_name": "Completed Goal",
                       "explanation": "Goal has been completed.", "status": "completed"}],
    ))
    result = ExplanationAgent(llm_client=mock).run(snap)
    assert any("Completed Goal" in i.goal_name for i in result.goal_impacts)


# ===========================================================================
# Test 20: Empty scenarios → no scenario_explanations
# ===========================================================================

def test_20_empty_scenarios():
    """Test 20: When scenario_required=False, scenario_explanations is empty."""
    snap = _snapshot(goals=[_goal("A")], conflict=False, available=15000.0)
    mock = _mock(_llm_result(scenario_exps=[]))
    result = ExplanationAgent(llm_client=mock).run(snap)
    assert result.scenario_explanations == []


# ===========================================================================
# Edge case A: No goals → do not invent goals
# ===========================================================================

def test_edge_a_no_goals():
    """Edge A: No goals supplied → goal_impacts empty."""
    snap = _snapshot(goals=[], conflict=False)
    mock = _mock(_llm_result(goal_impacts=[]))
    result = ExplanationAgent(llm_client=mock).run(snap)
    assert result.goal_impacts == []


# ===========================================================================
# Edge case B: LLM drops a scenario → guardrail adds fallback
# ===========================================================================

def test_edge_b_llm_drops_scenario():
    """Edge B: If LLM omits a scenario, guardrail adds a deterministic fallback."""
    snap = _snapshot(
        goals=[_goal("A", required=15000.0)],
        conflicts=[_conflict()],
        scenarios=[_scenario("S1"), _scenario("S2")],
        conflict=True, available=13000.0,
    )
    mock = _mock(_llm_result(
        conflict=True,
        goal_impacts=[{"goal_name": "A", "explanation": "At risk.", "status": "AT_RISK"}],
        scenario_exps=[{"scenario_id": "S1", "explanation": "S1 extends timeline."}],
        # S2 is omitted by LLM
    ))
    result = ExplanationAgent(llm_client=mock).run(snap)
    ids = {s.scenario_id for s in result.scenario_explanations}
    assert "S1" in ids
    assert "S2" in ids   # guardrail must add it


# ===========================================================================
# Edge case C: LLM drops a goal → guardrail adds fallback
# ===========================================================================

def test_edge_c_llm_drops_goal():
    """Edge C: If LLM omits a goal, guardrail adds a deterministic fallback."""
    snap = _snapshot(goals=[_goal("A"), _goal("B")], conflict=False)
    mock = _mock(_llm_result(
        goal_impacts=[{"goal_name": "A", "explanation": "A ok.", "status": "ON_TRACK"}],
        # B is omitted
    ))
    result = ExplanationAgent(llm_client=mock).run(snap)
    names = {i.goal_name for i in result.goal_impacts}
    assert "A" in names
    assert "B" in names   # guardrail must add it
