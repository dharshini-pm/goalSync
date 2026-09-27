"""Real Ollama + llama3.2 Integration Test for GoalSync Financial State Agent.

This test connects to a live local Ollama instance running llama3.2.
If Ollama is offline or llama3.2 is not installed, it gracefully skips without
fabricating an AI response.
"""

import pytest

from app.agents.financial_state_agent.models import (
    FinancialStateAgentInput,
    FinancialStateAgentResult,
    FinancialStatus,
    CashFlowStatus,
)
from app.agents.financial_state_agent.llm_client import OllamaClient
from app.agents.financial_state_agent.agent import FinancialStateAgent


def test_real_ollama_financial_state_agent_integration():
    """Executes a real financial state interpretation using local Ollama and llama3.2."""
    client = OllamaClient()

    # 1. Check Ollama server availability
    if not client.is_available():
        pytest.skip("Skipped: Ollama server not reachable on localhost:11434")

    # 2. Check llama3.2 model availability
    if not client.is_model_available("llama3.2"):
        pytest.skip("Skipped: llama3.2 model not installed in local Ollama")

    # 3. Build a realistic stable financial snapshot
    snapshot = FinancialStateAgentInput(
        monthly_income=50000.0,
        monthly_expenses=30000.0,
        monthly_surplus=20000.0,
        savings_rate=40.0,
        total_emi=5000.0,
        available_monthly_amount=15000.0,
        current_savings=100000.0,
        transaction_inflow=52000.0,
        transaction_outflow=28000.0,
        debt_to_income_ratio=0.10,
        emergency_fund_months=3.3,
    )

    # 4. Execute reasoning through FinancialStateAgent
    agent = FinancialStateAgent(llm_client=client)
    result = agent.run(snapshot)

    # 5. Print result
    print("\n--- REAL OLLAMA LLAMA3.2 FINANCIAL STATE AGENT RESULT ---")
    print(f"Financial Status: {result.financial_status.value}")
    print(f"Cash Flow Status: {result.cash_flow_status.value}")
    print(f"Confidence:       {result.confidence.value}")
    print(f"Summary:          {result.summary}")
    print(f"Key Signals:")
    for sig in result.key_signals:
        print(f"  - {sig}")
    print(f"Concerns:")
    for c in result.concerns:
        print(f"  - {c}")
    print("---------------------------------------------------------\n")

    # 6. Assertions
    assert isinstance(result, FinancialStateAgentResult)
    assert result.financial_status in [FinancialStatus.STABLE, FinancialStatus.TIGHT]
    assert result.cash_flow_status == CashFlowStatus.POSITIVE
    assert result.confidence in ["high", "medium", "low"]
    assert len(result.summary) > 0
    assert isinstance(result.key_signals, list)
    assert isinstance(result.concerns, list)
    assert result.needs_clarification is False
