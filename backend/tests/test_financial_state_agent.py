"""Unit tests for the GoalSync Financial State Agent (Mocked Ollama Client)."""

import pytest
from unittest.mock import MagicMock, patch

from app.agents.financial_state_agent.models import (
    FinancialStateAgentInput,
    FinancialStateAgentResult,
    FinancialStatus,
    CashFlowStatus,
    AgentConfidence,
)
from app.agents.financial_state_agent.prompts import (
    FINANCIAL_STATE_AGENT_SYSTEM_PROMPT,
    build_financial_state_user_prompt,
)
from app.agents.financial_state_agent.llm_client import (
    OllamaClient,
    OllamaResponseError,
)
from app.agents.financial_state_agent.agent import FinancialStateAgent
from app.agents.financial_state_agent.service import FinancialStateAgentService
from app.agents.transaction_agent.service import OllamaUnavailableError


# ---------------------------------------------------------------------------
# Helpers: pre-built valid LLM responses
# ---------------------------------------------------------------------------

def _stable_llm_response():
    return {
        "financial_status": "STABLE",
        "cash_flow_status": "POSITIVE",
        "summary": "Monthly income exceeds expenses with a healthy surplus and strong savings rate.",
        "key_signals": [
            "Monthly surplus is 20000.00",
            "Savings rate is 40.0%",
            "Current savings is 100000.00"
        ],
        "concerns": [],
        "confidence": "high",
    }

def _negative_llm_response():
    return {
        "financial_status": "NEGATIVE",
        "cash_flow_status": "NEGATIVE",
        "summary": "Monthly expenses exceed income resulting in a monthly cash deficit.",
        "key_signals": [
            "Monthly deficit of 5000.00",
            "Savings rate is 0.0%"
        ],
        "concerns": ["Negative monthly cash flow; expenses exceed income."],
        "confidence": "high",
    }

def _tight_llm_response():
    return {
        "financial_status": "TIGHT",
        "cash_flow_status": "POSITIVE",
        "summary": "Cash flow is positive but surplus is thin with limited buffer.",
        "key_signals": [
            "Monthly surplus of 3000.00",
            "Savings rate of 10.0%"
        ],
        "concerns": ["Low savings rate indicates limited financial buffer."],
        "confidence": "medium",
    }

def _strained_llm_response():
    return {
        "financial_status": "STRAINED",
        "cash_flow_status": "POSITIVE",
        "summary": "High debt-to-income ratio is placing significant pressure on monthly cash flow.",
        "key_signals": [
            "Monthly surplus of 2000.00",
            "Debt-to-income ratio exceeds 40%"
        ],
        "concerns": ["High EMI burden relative to income."],
        "confidence": "medium",
    }


# ---------------------------------------------------------------------------
# Test 1: Valid stable financial state
# ---------------------------------------------------------------------------

def test_1_valid_stable_financial_state():
    """Test 1: Stable financial state is correctly parsed from valid LLM output."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = _stable_llm_response()

    agent = FinancialStateAgent(llm_client=mock_client)
    snapshot = FinancialStateAgentInput(
        monthly_income=50000.0,
        monthly_expenses=30000.0,
        monthly_surplus=20000.0,
        savings_rate=40.0,
        total_emi=5000.0,
        available_monthly_amount=15000.0,
        current_savings=100000.0,
    )

    result = agent.run(snapshot)

    assert isinstance(result, FinancialStateAgentResult)
    assert result.financial_status == FinancialStatus.STABLE
    assert result.cash_flow_status == CashFlowStatus.POSITIVE
    assert result.confidence == AgentConfidence.HIGH
    assert result.needs_clarification is False
    assert len(result.summary) > 0


# ---------------------------------------------------------------------------
# Test 2: Negative cash flow
# ---------------------------------------------------------------------------

def test_2_negative_cash_flow():
    """Test 2: Negative cash flow is correctly parsed and deterministic guardrail enforced."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = _negative_llm_response()

    agent = FinancialStateAgent(llm_client=mock_client)
    snapshot = FinancialStateAgentInput(
        monthly_income=25000.0,
        monthly_expenses=30000.0,
        monthly_surplus=-5000.0,
        savings_rate=0.0,
        total_emi=2000.0,
        available_monthly_amount=0.0,
        current_savings=10000.0,
    )

    result = agent.run(snapshot)

    assert result.financial_status == FinancialStatus.NEGATIVE
    assert result.cash_flow_status == CashFlowStatus.NEGATIVE
    assert len(result.concerns) > 0


# ---------------------------------------------------------------------------
# Test 3: Tight financial state
# ---------------------------------------------------------------------------

def test_3_tight_financial_state():
    """Test 3: Tight financial state is parsed with correct enums and concerns."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = _tight_llm_response()

    agent = FinancialStateAgent(llm_client=mock_client)
    snapshot = FinancialStateAgentInput(
        monthly_income=30000.0,
        monthly_expenses=27000.0,
        monthly_surplus=3000.0,
        savings_rate=10.0,
        total_emi=3000.0,
        available_monthly_amount=500.0,
        current_savings=15000.0,
    )

    result = agent.run(snapshot)

    assert result.financial_status == FinancialStatus.TIGHT
    assert result.cash_flow_status == CashFlowStatus.POSITIVE
    assert len(result.concerns) > 0


# ---------------------------------------------------------------------------
# Test 4: Strained financial state
# ---------------------------------------------------------------------------

def test_4_strained_financial_state():
    """Test 4: Strained financial state is parsed correctly."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = _strained_llm_response()

    agent = FinancialStateAgent(llm_client=mock_client)
    snapshot = FinancialStateAgentInput(
        monthly_income=20000.0,
        monthly_expenses=18000.0,
        monthly_surplus=2000.0,
        savings_rate=10.0,
        total_emi=9000.0,  # very high, >40% of income
        available_monthly_amount=500.0,
        current_savings=5000.0,
        debt_to_income_ratio=0.45,
    )

    result = agent.run(snapshot)

    assert result.financial_status == FinancialStatus.STRAINED
    assert len(result.concerns) > 0


# ---------------------------------------------------------------------------
# Test 5: Missing required input field
# ---------------------------------------------------------------------------

def test_5_missing_required_input_field():
    """Test 5: FinancialStateAgentInput raises ValidationError for missing required fields."""
    from pydantic import ValidationError

    # monthly_income, monthly_expenses, monthly_surplus, savings_rate all required
    with pytest.raises(ValidationError):
        FinancialStateAgentInput(
            monthly_income=50000.0,
            # missing monthly_expenses
            monthly_surplus=20000.0,
            savings_rate=40.0,
        )


# ---------------------------------------------------------------------------
# Test 6: Invalid numerical values
# ---------------------------------------------------------------------------

def test_6_invalid_numerical_values():
    """Test 6: FinancialStateAgentInput rejects invalid (negative) values for non-negative fields."""
    from pydantic import ValidationError

    with pytest.raises(ValidationError):
        FinancialStateAgentInput(
            monthly_income=-1000.0,  # negative income is invalid
            monthly_expenses=30000.0,
            monthly_surplus=20000.0,
            savings_rate=40.0,
        )

    with pytest.raises(ValidationError):
        FinancialStateAgentInput(
            monthly_income=50000.0,
            monthly_expenses=-500.0,  # negative expenses invalid
            monthly_surplus=20000.0,
            savings_rate=40.0,
        )


# ---------------------------------------------------------------------------
# Test 7: Invalid LLM JSON output
# ---------------------------------------------------------------------------

def test_7_invalid_llm_json_output():
    """Test 7: OllamaResponseError propagated when LLM returns unparseable JSON."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.side_effect = OllamaResponseError("Malformed JSON from model")

    agent = FinancialStateAgent(llm_client=mock_client)
    snapshot = FinancialStateAgentInput(
        monthly_income=50000.0,
        monthly_expenses=30000.0,
        monthly_surplus=20000.0,
        savings_rate=40.0,
    )

    with pytest.raises(OllamaResponseError):
        agent.run(snapshot)


# ---------------------------------------------------------------------------
# Test 8: LLM response schema validation
# ---------------------------------------------------------------------------

def test_8_llm_response_schema_validation():
    """Test 8: Invalid enum in LLM JSON output raises Pydantic ValidationError."""
    from pydantic import ValidationError

    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = {
        "financial_status": "GREAT_AMAZING",  # invalid enum
        "cash_flow_status": "POSITIVE",
        "summary": "Everything is great",
        "key_signals": [],
        "concerns": [],
        "confidence": "high",
    }

    agent = FinancialStateAgent(llm_client=mock_client)
    snapshot = FinancialStateAgentInput(
        monthly_income=50000.0,
        monthly_expenses=30000.0,
        monthly_surplus=20000.0,
        savings_rate=40.0,
    )

    with pytest.raises(ValidationError):
        agent.run(snapshot)


# ---------------------------------------------------------------------------
# Test 9: LLM cannot override deterministic values
# ---------------------------------------------------------------------------

def test_9_llm_cannot_override_deterministic_values():
    """Test 9: Deterministic guardrail overrides incorrect LLM cash_flow_status and financial_status."""
    mock_client = MagicMock(spec=OllamaClient)
    # Simulate LLM incorrectly claiming POSITIVE cash flow despite negative surplus
    mock_client.generate_json.return_value = {
        "financial_status": "STABLE",  # incorrect — should be NEGATIVE
        "cash_flow_status": "POSITIVE",  # incorrect — should be NEGATIVE
        "summary": "Everything looks fine",
        "key_signals": [],
        "concerns": [],
        "confidence": "medium",
    }

    agent = FinancialStateAgent(llm_client=mock_client)
    snapshot = FinancialStateAgentInput(
        monthly_income=20000.0,
        monthly_expenses=25000.0,
        monthly_surplus=-5000.0,  # deterministically NEGATIVE
        savings_rate=0.0,
        total_emi=3000.0,
        available_monthly_amount=0.0,
        current_savings=5000.0,
    )

    result = agent.run(snapshot)

    # Guardrails must override incorrect LLM classification
    assert result.cash_flow_status == CashFlowStatus.NEGATIVE
    assert result.financial_status == FinancialStatus.NEGATIVE


# ---------------------------------------------------------------------------
# Test 10: Forbidden financial advice is rejected
# ---------------------------------------------------------------------------

def test_10_forbidden_financial_advice_rejected():
    """Test 10: FinancialStateAgentResult rejects LLM output containing financial recommendations."""
    from pydantic import ValidationError

    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = {
        "financial_status": "TIGHT",
        "cash_flow_status": "POSITIVE",
        "summary": "Cash flow is tight. You should invest in mutual funds to improve your wealth.",  # forbidden advice
        "key_signals": [],
        "concerns": [],
        "confidence": "medium",
    }

    agent = FinancialStateAgent(llm_client=mock_client)
    snapshot = FinancialStateAgentInput(
        monthly_income=30000.0,
        monthly_expenses=27000.0,
        monthly_surplus=3000.0,
        savings_rate=10.0,
    )

    with pytest.raises(ValidationError):
        agent.run(snapshot)


# ---------------------------------------------------------------------------
# Additional: FinancialStateAgentResult has needs_clarification=False by default
# ---------------------------------------------------------------------------

def test_result_needs_clarification_default():
    """Additional: needs_clarification defaults to False when not in LLM output."""
    data = {
        "financial_status": "STABLE",
        "cash_flow_status": "POSITIVE",
        "summary": "Financial posture looks healthy.",
        "key_signals": ["Surplus is positive"],
        "concerns": [],
        "confidence": "high",
    }
    result = FinancialStateAgentResult.model_validate(data)
    assert result.needs_clarification is False


# ---------------------------------------------------------------------------
# Additional: Deterministic classification tests
# ---------------------------------------------------------------------------

def test_deterministic_cash_flow_status():
    """Additional: Deterministic cash flow status correctly classifies surplus/neutral/deficit."""
    positive_snap = FinancialStateAgentInput(
        monthly_income=50000, monthly_expenses=30000,
        monthly_surplus=20000, savings_rate=40.0,
    )
    assert positive_snap.deterministic_cash_flow_status == CashFlowStatus.POSITIVE

    negative_snap = FinancialStateAgentInput(
        monthly_income=20000, monthly_expenses=25000,
        monthly_surplus=-5000, savings_rate=0.0,
    )
    assert negative_snap.deterministic_cash_flow_status == CashFlowStatus.NEGATIVE

    neutral_snap = FinancialStateAgentInput(
        monthly_income=30000, monthly_expenses=30000,
        monthly_surplus=0.0, savings_rate=0.0,
    )
    assert neutral_snap.deterministic_cash_flow_status == CashFlowStatus.NEUTRAL


def test_deterministic_financial_status():
    """Additional: Deterministic financial status thresholds are correct."""
    stable = FinancialStateAgentInput(
        monthly_income=50000, monthly_expenses=30000,
        monthly_surplus=20000, savings_rate=40.0,
        total_emi=5000, available_monthly_amount=15000, current_savings=100000,
    )
    assert stable.deterministic_financial_status == FinancialStatus.STABLE

    negative = FinancialStateAgentInput(
        monthly_income=20000, monthly_expenses=25000,
        monthly_surplus=-5000, savings_rate=0.0,
    )
    assert negative.deterministic_financial_status == FinancialStatus.NEGATIVE
