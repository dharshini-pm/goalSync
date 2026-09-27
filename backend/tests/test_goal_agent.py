"""Unit tests for the GoalSync Goal Agent (Mocked Ollama Client)."""

import pytest
from unittest.mock import MagicMock

from app.agents.goal_agent.models import (
    GoalAgentInput,
    GoalAgentResult,
    GoalStatus,
    GoalFeasibility,
    AgentConfidence,
)
from app.agents.goal_agent.prompts import (
    GOAL_AGENT_SYSTEM_PROMPT,
    build_goal_user_prompt,
)
from app.agents.goal_agent.llm_client import OllamaClient, OllamaResponseError
from app.agents.goal_agent.agent import GoalAgent
from app.agents.goal_agent.service import GoalAgentService
from app.agents.transaction_agent.service import OllamaUnavailableError


# ---------------------------------------------------------------------------
# Helpers: minimal valid snapshots
# ---------------------------------------------------------------------------

def _feasible_snapshot(**overrides) -> GoalAgentInput:
    defaults = dict(
        goal_name="Emergency Fund",
        goal_category="Emergency",
        priority="high",
        target_amount=100000.0,
        current_amount=30000.0,
        remaining_amount=70000.0,
        months_remaining=12,
        days_remaining=365,
        required_monthly_contribution=5834.0,
        available_monthly_amount=15000.0,
        monthly_shortfall=0.0,
        surplus_coverage_ratio=2.57,
        feasibility_status="feasible",
        feasibility_score=75.0,
        feasibility_reason="Achievable with current cash flow.",
        is_achievable_without_savings=True,
        is_achievable_with_savings=True,
        current_savings=50000.0,
        monthly_surplus=20000.0,
    )
    defaults.update(overrides)
    return GoalAgentInput(**defaults)

def _tight_snapshot(**overrides) -> GoalAgentInput:
    defaults = dict(
        goal_name="Vacation Fund",
        goal_category="Vacation",
        priority="medium",
        target_amount=60000.0,
        current_amount=5000.0,
        remaining_amount=55000.0,
        months_remaining=8,
        days_remaining=244,
        required_monthly_contribution=6875.0,
        available_monthly_amount=5000.0,
        monthly_shortfall=1875.0,
        surplus_coverage_ratio=0.73,
        feasibility_status="tight",
        feasibility_score=50.0,
        feasibility_reason="Achievable by utilizing existing savings buffer.",
        is_achievable_without_savings=False,
        is_achievable_with_savings=True,
        current_savings=20000.0,
        monthly_surplus=5000.0,
    )
    defaults.update(overrides)
    return GoalAgentInput(**defaults)

def _infeasible_snapshot(**overrides) -> GoalAgentInput:
    defaults = dict(
        goal_name="Car Purchase",
        goal_category="Vehicle",
        priority="low",
        target_amount=500000.0,
        current_amount=10000.0,
        remaining_amount=490000.0,
        months_remaining=12,
        days_remaining=365,
        required_monthly_contribution=40833.0,
        available_monthly_amount=5000.0,
        monthly_shortfall=35833.0,
        surplus_coverage_ratio=0.12,
        feasibility_status="unfeasible",
        feasibility_score=5.0,
        feasibility_reason="Unfeasible under current surplus.",
        is_achievable_without_savings=False,
        is_achievable_with_savings=False,
        current_savings=8000.0,
        monthly_surplus=5000.0,
    )
    defaults.update(overrides)
    return GoalAgentInput(**defaults)

def _completed_snapshot(**overrides) -> GoalAgentInput:
    defaults = dict(
        goal_name="Laptop Purchase",
        goal_category="Electronics",
        priority="high",
        target_amount=50000.0,
        current_amount=50000.0,
        remaining_amount=0.0,
        months_remaining=0,
        days_remaining=0,
        required_monthly_contribution=0.0,
        available_monthly_amount=15000.0,
        monthly_shortfall=0.0,
        surplus_coverage_ratio=1.0,
        feasibility_status="achieved",
        feasibility_score=100.0,
        feasibility_reason="Goal target amount has been fully reached.",
        is_achievable_without_savings=True,
        is_achievable_with_savings=True,
        current_savings=60000.0,
        monthly_surplus=20000.0,
    )
    defaults.update(overrides)
    return GoalAgentInput(**defaults)


# ---------------------------------------------------------------------------
# Test 1: Feasible goal
# ---------------------------------------------------------------------------

def test_1_feasible_goal():
    """Test 1: Feasible goal produces ON_TRACK status with high confidence."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = {
        "goal_name": "Emergency Fund",
        "goal_status": "ON_TRACK",
        "feasibility": "FEASIBLE",
        "summary": "Goal is on track with sufficient monthly capacity.",
        "key_signals": ["Required: 5834/mo", "Available: 15000/mo"],
        "concerns": [],
        "confidence": "high",
        "needs_clarification": False,
    }

    agent = GoalAgent(llm_client=mock_client)
    result = agent.run(_feasible_snapshot())

    assert isinstance(result, GoalAgentResult)
    assert result.goal_name == "Emergency Fund"
    assert result.goal_status == GoalStatus.ON_TRACK
    assert result.feasibility in (GoalFeasibility.FEASIBLE, GoalFeasibility.COMFORTABLE)
    assert result.confidence == AgentConfidence.HIGH
    assert result.needs_clarification is False


# ---------------------------------------------------------------------------
# Test 2: Tight goal
# ---------------------------------------------------------------------------

def test_2_tight_goal():
    """Test 2: Tight goal produces AT_RISK status and concerns."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = {
        "goal_name": "Vacation Fund",
        "goal_status": "AT_RISK",
        "feasibility": "TIGHT",
        "summary": "Monthly capacity is insufficient; savings cushion needed.",
        "key_signals": ["Shortfall: 1875/mo", "Coverage ratio: 0.73"],
        "concerns": ["Monthly surplus does not fully cover required contribution."],
        "confidence": "medium",
        "needs_clarification": False,
    }

    agent = GoalAgent(llm_client=mock_client)
    result = agent.run(_tight_snapshot())

    assert result.goal_status == GoalStatus.AT_RISK
    assert result.feasibility == GoalFeasibility.TIGHT
    assert len(result.concerns) > 0


# ---------------------------------------------------------------------------
# Test 3: Infeasible goal
# ---------------------------------------------------------------------------

def test_3_infeasible_goal():
    """Test 3: Infeasible goal produces OFF_TRACK status and INFEASIBLE feasibility."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = {
        "goal_name": "Car Purchase",
        "goal_status": "OFF_TRACK",
        "feasibility": "INFEASIBLE",
        "summary": "Monthly capacity is far below required contribution.",
        "key_signals": ["Shortfall: 35833/mo", "Coverage ratio: 0.12"],
        "concerns": ["Goal cannot be met within timeframe under current financial conditions."],
        "confidence": "high",
        "needs_clarification": False,
    }

    agent = GoalAgent(llm_client=mock_client)
    result = agent.run(_infeasible_snapshot())

    assert result.goal_status == GoalStatus.OFF_TRACK
    assert result.feasibility == GoalFeasibility.INFEASIBLE
    assert len(result.concerns) > 0


# ---------------------------------------------------------------------------
# Test 4: Completed goal
# ---------------------------------------------------------------------------

def test_4_completed_goal():
    """Test 4: Achieved goal is marked COMPLETED with ACHIEVED feasibility."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = {
        "goal_name": "Laptop Purchase",
        "goal_status": "COMPLETED",
        "feasibility": "ACHIEVED",
        "summary": "Goal has been fully funded and achieved.",
        "key_signals": ["100% funded", "Remaining: 0"],
        "concerns": [],
        "confidence": "high",
        "needs_clarification": False,
    }

    agent = GoalAgent(llm_client=mock_client)
    result = agent.run(_completed_snapshot())

    assert result.goal_status == GoalStatus.COMPLETED
    assert result.feasibility == GoalFeasibility.ACHIEVED
    assert result.needs_clarification is False


# ---------------------------------------------------------------------------
# Test 5: Missing required input field
# ---------------------------------------------------------------------------

def test_5_missing_required_input_field():
    """Test 5: GoalAgentInput raises ValidationError when required fields are missing."""
    from pydantic import ValidationError

    with pytest.raises(ValidationError):
        GoalAgentInput(
            # missing goal_name
            target_amount=100000.0,
            current_amount=30000.0,
            remaining_amount=70000.0,
            feasibility_status="feasible",
        )

    with pytest.raises(ValidationError):
        GoalAgentInput(
            goal_name="Test Goal",
            # missing target_amount
            current_amount=30000.0,
            remaining_amount=70000.0,
            feasibility_status="feasible",
        )


# ---------------------------------------------------------------------------
# Test 6: Invalid numerical values
# ---------------------------------------------------------------------------

def test_6_invalid_numerical_values():
    """Test 6: GoalAgentInput rejects negative non-negative fields."""
    from pydantic import ValidationError

    with pytest.raises(ValidationError):
        GoalAgentInput(
            goal_name="Test Goal",
            target_amount=-5000.0,  # negative — invalid
            current_amount=0.0,
            remaining_amount=0.0,
            feasibility_status="feasible",
        )

    with pytest.raises(ValidationError):
        GoalAgentInput(
            goal_name="Test Goal",
            target_amount=50000.0,
            current_amount=-100.0,  # negative — invalid
            remaining_amount=50000.0,
            feasibility_status="feasible",
        )


# ---------------------------------------------------------------------------
# Test 7: Invalid LLM JSON output
# ---------------------------------------------------------------------------

def test_7_invalid_llm_json_output():
    """Test 7: OllamaResponseError propagated when LLM returns unparseable JSON."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.side_effect = OllamaResponseError("Malformed JSON")

    agent = GoalAgent(llm_client=mock_client)
    with pytest.raises(OllamaResponseError):
        agent.run(_feasible_snapshot())


# ---------------------------------------------------------------------------
# Test 8: LLM schema validation
# ---------------------------------------------------------------------------

def test_8_llm_schema_validation():
    """Test 8: Invalid enum in LLM JSON raises Pydantic ValidationError."""
    from pydantic import ValidationError

    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = {
        "goal_name": "Emergency Fund",
        "goal_status": "EXCELLENT_SUPER",  # invalid enum
        "feasibility": "FEASIBLE",
        "summary": "All good",
        "key_signals": [],
        "concerns": [],
        "confidence": "high",
        "needs_clarification": False,
    }

    agent = GoalAgent(llm_client=mock_client)
    with pytest.raises(ValidationError):
        agent.run(_feasible_snapshot())


# ---------------------------------------------------------------------------
# Test 9: LLM cannot override deterministic values
# ---------------------------------------------------------------------------

def test_9_llm_cannot_override_deterministic_values():
    """Test 9: Deterministic guardrails override incorrect LLM goal_status and feasibility."""
    mock_client = MagicMock(spec=OllamaClient)
    # LLM incorrectly claims goal is ON_TRACK despite infeasible engine output
    mock_client.generate_json.return_value = {
        "goal_name": "Car Purchase",
        "goal_status": "ON_TRACK",     # wrong — should be OFF_TRACK
        "feasibility": "FEASIBLE",     # wrong — should be INFEASIBLE
        "summary": "Looking great",
        "key_signals": [],
        "concerns": [],
        "confidence": "high",
        "needs_clarification": False,
    }

    agent = GoalAgent(llm_client=mock_client)
    result = agent.run(_infeasible_snapshot())

    # Guardrails must correct to deterministic engine outputs
    assert result.goal_status == GoalStatus.OFF_TRACK
    assert result.feasibility == GoalFeasibility.INFEASIBLE


# ---------------------------------------------------------------------------
# Test 10: Forbidden financial advice rejected
# ---------------------------------------------------------------------------

def test_10_forbidden_financial_advice_rejected():
    """Test 10: GoalAgentResult rejects LLM output containing financial recommendations."""
    from pydantic import ValidationError

    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = {
        "goal_name": "Emergency Fund",
        "goal_status": "AT_RISK",
        "feasibility": "TIGHT",
        "summary": "Goal is tight. You should invest in mutual funds to close the gap.",  # forbidden
        "key_signals": [],
        "concerns": [],
        "confidence": "medium",
        "needs_clarification": False,
    }

    agent = GoalAgent(llm_client=mock_client)
    with pytest.raises(ValidationError, match="safety policy"):
        agent.run(_tight_snapshot())


# ---------------------------------------------------------------------------
# Test 11: needs_clarification behavior
# ---------------------------------------------------------------------------

def test_11_needs_clarification_behavior():
    """Test 11: needs_clarification is correctly parsed (True when missing data)."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = {
        "goal_name": "Mystery Goal",
        "goal_status": "AT_RISK",
        "feasibility": "TIGHT",
        "summary": "Goal details are incomplete.",
        "key_signals": [],
        "concerns": ["Insufficient data to fully evaluate."],
        "confidence": "low",
        "needs_clarification": True,
    }

    snap = _tight_snapshot(goal_name="Mystery Goal")
    agent = GoalAgent(llm_client=mock_client)
    result = agent.run(snap)

    assert result.needs_clarification is True
    assert result.confidence == AgentConfidence.LOW


# ---------------------------------------------------------------------------
# Additional: Deterministic property tests
# ---------------------------------------------------------------------------

def test_deterministic_goal_status_completed():
    """Additional: Remaining amount zero → COMPLETED status."""
    snap = _completed_snapshot()
    assert snap.deterministic_goal_status == GoalStatus.COMPLETED


def test_deterministic_goal_status_on_track():
    """Additional: Feasible, achievable without savings → ON_TRACK."""
    snap = _feasible_snapshot()
    assert snap.deterministic_goal_status == GoalStatus.ON_TRACK


def test_deterministic_goal_status_at_risk():
    """Additional: Tight but achievable with savings → AT_RISK."""
    snap = _tight_snapshot()
    assert snap.deterministic_goal_status == GoalStatus.AT_RISK


def test_deterministic_goal_status_off_track():
    """Additional: Infeasible even with savings → OFF_TRACK."""
    snap = _infeasible_snapshot()
    assert snap.deterministic_goal_status == GoalStatus.OFF_TRACK


def test_rag_evidence_included_in_prompt():
    """Additional: User prompt correctly includes key deterministic facts."""
    snap = _feasible_snapshot()
    prompt = build_goal_user_prompt(snap)
    assert "Emergency Fund" in prompt
    assert "5834" in prompt
    assert "15000" in prompt
    assert "feasible" in prompt.lower()


def test_goal_name_is_preserved_by_guardrail():
    """Additional: Agent guardrail ensures goal_name always matches input regardless of LLM output."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = {
        "goal_name": "Some Other Goal Name",   # LLM hallucinated a different name
        "goal_status": "ON_TRACK",
        "feasibility": "FEASIBLE",
        "summary": "Goal is on track.",
        "key_signals": [],
        "concerns": [],
        "confidence": "high",
        "needs_clarification": False,
    }

    agent = GoalAgent(llm_client=mock_client)
    result = agent.run(_feasible_snapshot())
    assert result.goal_name == "Emergency Fund"
