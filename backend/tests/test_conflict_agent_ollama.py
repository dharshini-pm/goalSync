"""Real Ollama + llama3.2 Integration Test for GoalSync Conflict Agent.

Connects to a live local Ollama instance. Skips gracefully if unavailable.
Follows the same pattern as test_financial_state_agent_ollama.py and test_goal_agent_ollama.py.
"""

import sys
import pytest

from app.agents.conflict_agent.models import (
    ConflictAgentInput,
    ConflictAgentResult,
    GoalConflictSnapshot,
    OverallStatus,
)
from app.agents.conflict_agent.llm_client import OllamaClient
from app.agents.conflict_agent.agent import ConflictAgent


def _safe_print(text: str) -> None:
    """UTF-8 safe print for Windows terminals that default to CP1252."""
    sys.stdout.buffer.write((text + "\n").encode("utf-8", errors="replace"))
    sys.stdout.buffer.flush()


def test_real_ollama_conflict_agent_integration():
    """Executes a real conflict analysis using local Ollama and llama3.2."""
    # Conflict prompts are long — use extended timeout
    client = OllamaClient(timeout=120)

    if not client.is_available():
        pytest.skip("Skipped: Ollama server not reachable on localhost:11434")

    if not client.is_model_available("llama3.2"):
        pytest.skip("Skipped: llama3.2 model not installed in local Ollama")

    # Realistic conflict scenario: two goals exceed available capacity
    snapshot = ConflictAgentInput(
        monthly_income=50000.0,
        monthly_expenses=35000.0,
        monthly_surplus=15000.0,
        available_monthly_amount=15000.0,
        current_savings=50000.0,
        total_emi=5000.0,
        savings_rate=30.0,
        goals=[
            GoalConflictSnapshot(
                goal_name="Emergency Fund",
                goal_category="Emergency",
                priority="high",
                target_amount=100000.0,
                current_amount=30000.0,
                remaining_amount=70000.0,
                required_monthly_contribution=10000.0,
                goal_status="ON_TRACK",
                feasibility="FEASIBLE",
                is_active=True,
            ),
            GoalConflictSnapshot(
                goal_name="International Travel",
                goal_category="Vacation",
                priority="medium",
                target_amount=80000.0,
                current_amount=5000.0,
                remaining_amount=75000.0,
                required_monthly_contribution=9000.0,
                goal_status="AT_RISK",
                feasibility="TIGHT",
                is_active=True,
            ),
        ],
    )

    agent = ConflictAgent(llm_client=client)
    result = agent.run(snapshot)

    _safe_print("\n--- REAL OLLAMA LLAMA3.2 CONFLICT AGENT RESULT ---")
    _safe_print(f"Conflict Detected:  {result.conflict_detected}")
    _safe_print(f"Overall Status:     {result.overall_status.value}")
    _safe_print(f"Conflict Count:     {result.conflict_count}")
    _safe_print(f"Confidence:         {result.confidence.value}")
    _safe_print(f"Summary:            {result.summary}")
    for i, c in enumerate(result.conflicts, 1):
        _safe_print(f"  Conflict {i}:")
        _safe_print(f"    Type:        {c.conflict_type.value}")
        _safe_print(f"    Severity:    {c.severity.value}")
        _safe_print(f"    Title:       {c.title}")
        _safe_print(f"    Description: {c.description}")
        _safe_print(f"    Affected:    {c.affected_goals}")
        _safe_print(f"    Required:    {c.deterministic_required_amount}")
        _safe_print(f"    Available:   {c.deterministic_available_amount}")
        _safe_print(f"    Gap:         {c.deterministic_gap}")
    _safe_print(f"Needs Clarification: {result.needs_clarification}")
    _safe_print("--------------------------------------------------\n")

    # Deterministic ground truth
    assert snapshot.total_required_monthly_contribution == 19000.0
    assert snapshot.monthly_capacity_gap == 4000.0
    assert snapshot.has_capacity_conflict is True

    # Assertions on result
    assert isinstance(result, ConflictAgentResult)
    assert result.conflict_detected is True
    assert result.overall_status == OverallStatus.CONFLICT
    assert result.conflict_count >= 1
    assert len(result.summary) > 0
    assert isinstance(result.conflicts, list)
    assert result.needs_clarification is False

    # Verify deterministic values were preserved in CAPACITY_CONFLICT record
    cap_conflicts = [c for c in result.conflicts if c.conflict_type.value == "CAPACITY_CONFLICT"]
    if cap_conflicts:
        cap = cap_conflicts[0]
        assert cap.deterministic_required_amount == 19000.0
        assert cap.deterministic_available_amount == 15000.0
        assert cap.deterministic_gap == 4000.0
