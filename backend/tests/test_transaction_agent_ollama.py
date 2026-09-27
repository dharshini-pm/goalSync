"""Real Ollama + llama3.2 Integration Test for GoalSync Transaction Agent.

This test connects to a live local Ollama instance running llama3.2.
If Ollama is offline or llama3.2 is not installed, it gracefully skips without
fabricating an AI response.
"""

import pytest

from app.agents.transaction_agent.models import (
    TransactionAgentInput,
    TransactionAgentResult,
)
from app.agents.transaction_agent.llm_client import OllamaClient
from app.agents.transaction_agent.agent import TransactionAgent
from app.agents.transaction_agent.service import TransactionAgentService


def test_real_ollama_transaction_agent_integration():
    """Executes a real transaction analysis using local Ollama and llama3.2."""
    client = OllamaClient()

    # 1. Check Ollama server availability
    if not client.is_available():
        pytest.skip("Skipped: Ollama server not reachable on localhost:11434")

    # 2. Check llama3.2 model availability
    if not client.is_model_available("llama3.2"):
        pytest.skip("Skipped: llama3.2 model not installed in local Ollama")

    # 3. Build a structured transaction input
    structured_input = TransactionAgentInput(
        merchant="SWIGGY*ORDER123",
        amount=450.0,
        transaction_type="debit",
        payment_method="UPI",
        date="2026-03-27",
        deterministic_category="Food",
        merchant_rag_result="Swiggy",
        merchant_rag_confidence="EXACT",
    )

    # 4. Execute reasoning through TransactionAgent
    agent = TransactionAgent(llm_client=client)
    result = agent.run(structured_input)

    # 5. Output and validate result
    print("\n--- REAL OLLAMA LLAMA3.2 TRANSACTION AGENT RESULT ---")
    print(f"Merchant Name:       {result.merchant_name}")
    print(f"Category:            {result.category}")
    print(f"Transaction Type:    {result.transaction_type}")
    print(f"Summary:             {result.summary}")
    print(f"Reasoning:           {result.reasoning}")
    print(f"Confidence:          {result.confidence}")
    print(f"Needs Clarification: {result.needs_clarification}")
    print("----------------------------------------------------\n")

    # 6. Schema and assertion checks
    assert isinstance(result, TransactionAgentResult)
    assert result.merchant_name == "Swiggy"
    assert result.category == "Food"
    assert result.transaction_type in ["Expense", "debit", "Debit"]
    assert result.confidence in ["high", "medium", "low"]
    assert isinstance(result.needs_clarification, bool)
    assert result.needs_clarification is False
    assert len(result.reasoning) > 0
    assert len(result.summary) > 0
