"""Unit tests for the GoalSync Transaction Agent (Mocked Ollama Client)."""

import pytest
from unittest.mock import MagicMock

from app.agents.transaction_agent.models import (
    TransactionAgentInput,
    TransactionAgentResult,
    AgentConfidence,
)
from app.agents.transaction_agent.prompts import (
    TRANSACTION_AGENT_SYSTEM_PROMPT,
    build_transaction_user_prompt,
)
from app.agents.transaction_agent.llm_client import (
    OllamaClient,
    OllamaResponseError,
    OllamaConnectionError,
)
from app.agents.transaction_agent.agent import TransactionAgent
from app.agents.transaction_agent.service import (
    TransactionAgentService,
    OllamaUnavailableError,
)


# ---------------------------------------------------------------------------
# Test 1: TransactionAgentInput Validation
# ---------------------------------------------------------------------------

def test_1_transaction_agent_input_validation():
    """Test 1: TransactionAgentInput validates valid inputs and rejects invalid ones."""
    # Valid input
    valid_input = TransactionAgentInput(
        merchant="Swiggy",
        amount=450.0,
        transaction_type="debit",
        payment_method="UPI",
        date="2026-03-27",
    )
    assert valid_input.merchant == "Swiggy"
    assert valid_input.amount == 450.0
    assert valid_input.transaction_type == "debit"
    assert valid_input.has_rag_evidence is False

    # Invalid empty merchant
    with pytest.raises(ValueError, match="merchant"):
        TransactionAgentInput(merchant="", amount=100.0, transaction_type="debit")

    with pytest.raises(ValueError, match="merchant"):
        TransactionAgentInput(merchant="   ", amount=100.0, transaction_type="debit")

    # Invalid negative amount
    with pytest.raises(ValueError, match="amount"):
        TransactionAgentInput(merchant="Swiggy", amount=-10.0, transaction_type="debit")

    # Invalid empty transaction_type
    with pytest.raises(ValueError, match="transaction_type"):
        TransactionAgentInput(merchant="Swiggy", amount=100.0, transaction_type="")


# ---------------------------------------------------------------------------
# Test 2: Valid Structured Output Parsing
# ---------------------------------------------------------------------------

def test_2_valid_structured_output_parsing():
    """Test 2: TransactionAgentResult parses and serializes valid dictionary output."""
    raw_data = {
        "merchant_name": "Swiggy",
        "category": "Food",
        "transaction_type": "Expense",
        "summary": "Food delivery order from restaurant",
        "reasoning": "Swiggy is verified as an online food ordering platform.",
        "confidence": "high",
        "needs_clarification": False,
    }

    result = TransactionAgentResult.from_dict(raw_data)
    assert result.merchant_name == "Swiggy"
    assert result.category == "Food"
    assert result.transaction_type == "Expense"
    assert result.confidence == "high"
    assert result.needs_clarification is False

    d = result.to_dict()
    assert d["merchant_name"] == "Swiggy"
    assert d["category"] == "Food"


# ---------------------------------------------------------------------------
# Test 3: Invalid JSON Rejection
# ---------------------------------------------------------------------------

def test_3_invalid_json_rejection():
    """Test 3: LLM client raises OllamaResponseError when JSON decoding fails."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.side_effect = OllamaResponseError("Invalid JSON from LLM")

    agent = TransactionAgent(llm_client=mock_client)
    inp = TransactionAgentInput(merchant="Swiggy", amount=250.0, transaction_type="debit")

    with pytest.raises(OllamaResponseError):
        agent.run(inp)


# ---------------------------------------------------------------------------
# Test 4: Missing Required Field Rejection
# ---------------------------------------------------------------------------

def test_4_missing_required_field_rejection():
    """Test 4: TransactionAgentResult rejects raw dictionaries missing required keys."""
    incomplete_data = {
        "merchant_name": "Swiggy",
        "category": "Food",
        # missing transaction_type, summary, reasoning, confidence, needs_clarification
    }

    with pytest.raises(ValueError, match="Missing required fields"):
        TransactionAgentResult.from_dict(incomplete_data)


# ---------------------------------------------------------------------------
# Test 5: Confidence Validation
# ---------------------------------------------------------------------------

def test_5_confidence_validation():
    """Test 5: TransactionAgentResult enforces confidence is high, medium, or low."""
    data = {
        "merchant_name": "Swiggy",
        "category": "Food",
        "transaction_type": "Expense",
        "summary": "Food delivery",
        "reasoning": "RAG evidence confirms",
        "confidence": "super_high_invalid",  # invalid confidence
        "needs_clarification": False,
    }

    with pytest.raises(ValueError, match="Invalid confidence"):
        TransactionAgentResult.from_dict(data)


# ---------------------------------------------------------------------------
# Test 6: RAG Evidence is Included in Prompt Context
# ---------------------------------------------------------------------------

def test_6_rag_evidence_included_in_prompt_context():
    """Test 6: User prompt correctly injects RAG matched merchant and confidence."""
    inp = TransactionAgentInput(
        merchant="AMZN*MKTP",
        amount=1499.0,
        transaction_type="debit",
        deterministic_category="Shopping",
        merchant_rag_result="Amazon",
        merchant_rag_confidence="ALIAS",
    )

    prompt = build_transaction_user_prompt(inp)
    assert "AMZN*MKTP" in prompt
    assert "Amazon" in prompt
    assert "ALIAS" in prompt
    assert "Shopping" in prompt
    assert inp.has_rag_evidence is True


# ---------------------------------------------------------------------------
# Test 7: Deterministic Category is Passed to Agent
# ---------------------------------------------------------------------------

def test_7_deterministic_category_passed_to_agent():
    """Test 7: Deterministic category is passed and respected in the agent workflow."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = {
        "merchant_name": "Uber",
        "category": "Transport",
        "transaction_type": "Expense",
        "summary": "City taxi ride",
        "reasoning": "Deterministic category and RAG confirm Uber is transport",
        "confidence": "high",
        "needs_clarification": False,
    }

    agent = TransactionAgent(llm_client=mock_client)
    inp = TransactionAgentInput(
        merchant="UBER TRIP 123",
        amount=320.0,
        transaction_type="debit",
        deterministic_category="Transport",
        merchant_rag_result="Uber",
        merchant_rag_confidence="EXACT",
    )

    result = agent.run(inp)
    assert result.category == "Transport"
    assert result.merchant_name == "Uber"
    assert result.confidence == "high"

    # Verify that the generated prompt actually contained the deterministic category
    called_user_prompt = mock_client.generate_json.call_args[1]["user_prompt"]
    assert "Deterministic Category: Transport" in called_user_prompt


# ---------------------------------------------------------------------------
# Test 8: Unknown Merchant is Preserved as Unknown
# ---------------------------------------------------------------------------

def test_8_unknown_merchant_preserved_as_unknown():
    """Test 8: Unknown merchant produces preserved raw merchant or Unknown with needs_clarification=True."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = {
        "merchant_name": "XYZ Local Mechanical Shop",
        "category": "Other",
        "transaction_type": "Expense",
        "summary": "Payment to unknown workshop",
        "reasoning": "No RAG knowledge or recognized merchant pattern exists",
        "confidence": "low",
        "needs_clarification": True,
    }

    agent = TransactionAgent(llm_client=mock_client)
    inp = TransactionAgentInput(
        merchant="XYZ Local Mechanical Shop",
        amount=1200.0,
        transaction_type="debit",
    )

    result = agent.run(inp)
    assert result.merchant_name == "XYZ Local Mechanical Shop"
    assert result.confidence == "low"
    assert result.needs_clarification is True


# ---------------------------------------------------------------------------
# Test 9: Agent Does Not Invent Merchant Information
# ---------------------------------------------------------------------------

def test_9_agent_does_not_invent_merchant_information():
    """Test 9: Agent re-aligns with verified RAG ground truth if model tries to hallucinate."""
    mock_client = MagicMock(spec=OllamaClient)
    # Simulate LLM returning a slightly different or altered merchant name
    mock_client.generate_json.return_value = {
        "merchant_name": "Swiggy Super Mart Ltd",
        "category": "Food",
        "transaction_type": "Expense",
        "summary": "Food delivery",
        "reasoning": "Identified from transaction",
        "confidence": "medium",
        "needs_clarification": False,
    }

    agent = TransactionAgent(llm_client=mock_client)
    inp = TransactionAgentInput(
        merchant="SWIGGY*ORDER",
        amount=500.0,
        transaction_type="debit",
        merchant_rag_result="Swiggy",
        merchant_rag_confidence="EXACT",
    )

    result = agent.run(inp)
    # Guardrail ensures canonical verified merchant Swiggy is enforced
    assert result.merchant_name == "Swiggy"
    assert result.confidence == "high"


# ---------------------------------------------------------------------------
# Test 10: Agent Does Not Generate Financial Recommendations
# ---------------------------------------------------------------------------

def test_10_agent_does_not_generate_financial_recommendations():
    """Test 10: Agent rejects reasoning that contains forbidden financial advice/recommendations."""
    mock_client = MagicMock(spec=OllamaClient)
    mock_client.generate_json.return_value = {
        "merchant_name": "Netflix",
        "category": "Entertainment",
        "transaction_type": "Expense",
        "summary": "Monthly video subscription",
        "reasoning": "This is entertainment. You should save more money instead of streaming.",
        "confidence": "high",
        "needs_clarification": False,
    }

    agent = TransactionAgent(llm_client=mock_client)
    inp = TransactionAgentInput(
        merchant="Netflix",
        amount=649.0,
        transaction_type="debit",
    )

    with pytest.raises(ValueError, match="financial recommendation boundary"):
        agent.run(inp)
