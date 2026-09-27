"""Real Ollama + llama3.2 Integration Test for GoalSync Goal Agent.

Connects to a live local Ollama instance running llama3.2.
Skips gracefully if Ollama is offline or llama3.2 is not installed.
"""

import pytest

from app.agents.goal_agent.models import (
    GoalAgentInput,
    GoalAgentResult,
    GoalStatus,
    GoalFeasibility,
)
from app.agents.goal_agent.llm_client import OllamaClient
from app.agents.goal_agent.agent import GoalAgent


def test_real_ollama_goal_agent_integration():
    """Executes a real goal interpretation using local Ollama and llama3.2."""
    # Goal prompt is longer than transaction/financial prompts — use extended timeout
    client = OllamaClient(timeout=90)

    if not client.is_available():
        pytest.skip("Skipped: Ollama server not reachable on localhost:11434")

    if not client.is_model_available("llama3.2"):
        pytest.skip("Skipped: llama3.2 model not installed in local Ollama")

    # Realistic emergency fund goal — feasible scenario
    snapshot = GoalAgentInput(
        goal_name="Emergency Fund",
        goal_category="Emergency",
        priority="high",
        target_amount=100000.0,
        current_amount=30000.0,
        remaining_amount=70000.0,
        target_date="2027-03-31",
        months_remaining=18,
        days_remaining=548,
        required_monthly_contribution=3889.0,
        available_monthly_amount=15000.0,
        monthly_shortfall=0.0,
        surplus_coverage_ratio=3.86,
        feasibility_status="comfortable",
        feasibility_score=92.0,
        feasibility_reason="Comfortably achievable. Requires ₹3889/mo (26% of monthly surplus).",
        is_achievable_without_savings=True,
        is_achievable_with_savings=True,
        current_savings=50000.0,
        monthly_surplus=15000.0,
    )

    agent = GoalAgent(llm_client=client)
    result = agent.run(snapshot)

    def safe_print(text: str) -> None:
        """UTF-8 safe print for Windows terminals that default to CP1252."""
        import sys
        sys.stdout.buffer.write((text + "\n").encode("utf-8", errors="replace"))
        sys.stdout.buffer.flush()

    safe_print("\n--- REAL OLLAMA LLAMA3.2 GOAL AGENT RESULT ---")
    safe_print(f"Goal Name:          {result.goal_name}")
    safe_print(f"Goal Status:        {result.goal_status.value}")
    safe_print(f"Feasibility:        {result.feasibility.value}")
    safe_print(f"Confidence:         {result.confidence.value}")
    safe_print(f"Summary:            {result.summary}")
    safe_print(f"Key Signals:")
    for s in result.key_signals:
        safe_print(f"  - {s}")
    safe_print(f"Concerns:")
    for c in result.concerns:
        safe_print(f"  - {c}")
    safe_print(f"Needs Clarification: {result.needs_clarification}")
    safe_print("----------------------------------------------\n")

    assert isinstance(result, GoalAgentResult)
    assert result.goal_name == "Emergency Fund"
    assert result.goal_status in [GoalStatus.ON_TRACK, GoalStatus.COMPLETED]
    assert result.feasibility in [GoalFeasibility.COMFORTABLE, GoalFeasibility.FEASIBLE, GoalFeasibility.ACHIEVED]
    assert result.confidence in ["high", "medium", "low"]
    assert len(result.summary) > 0
    assert isinstance(result.key_signals, list)
    assert isinstance(result.concerns, list)
    assert result.needs_clarification is False
