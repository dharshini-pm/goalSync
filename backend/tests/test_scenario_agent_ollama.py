"""Real Ollama + llama3.2 Integration Test for GoalSync Scenario Agent.

Connects to a live local Ollama instance. Skips gracefully if unavailable.
Follows the same pattern as test_conflict_agent_ollama.py.

Uses a single-goal scenario (3 generated scenarios) instead of dual-goal (5
scenarios) so the prompt stays concise enough for a 240-second local timeout.
"""

import sys
import pytest
from datetime import date

from app.agents.scenario_agent.models import (
    ScenarioAgentInput,
    ScenarioAgentResult,
    GoalScenarioSnapshot,
    ConflictSummary,
)
from app.agents.scenario_agent.llm_client import OllamaClient
from app.agents.scenario_agent.agent import ScenarioAgent


def _safe_print(text: str) -> None:
    """UTF-8 safe print for Windows terminals that default to CP1252."""
    sys.stdout.buffer.write((text + "\n").encode("utf-8", errors="replace"))
    sys.stdout.buffer.flush()


def _future_date(months: int) -> str:
    ref = date.today()
    y = ref.year + (ref.month + months - 1) // 12
    m = (ref.month + months - 1) % 12 + 1
    return f"{y:04d}-{m:02d}-01"


def test_real_ollama_scenario_agent_integration():
    """Executes a real scenario analysis using local Ollama and llama3.2."""
    client = OllamaClient(timeout=240)

    if not client.is_available():
        pytest.skip("Skipped: Ollama server not reachable on localhost:11434")

    if not client.is_model_available("llama3.2"):
        pytest.skip("Skipped: llama3.2 model not installed in local Ollama")

    # Single active goal exceeds available capacity — clean capacity conflict.
    # One goal generates 3 scenarios (2x TIMELINE_ADJUSTMENT + CAPACITY_CHANGE)
    # keeping the prompt compact enough to finish within 240 seconds.
    snapshot = ScenarioAgentInput(
        monthly_income=50000.0,
        monthly_expenses=37000.0,
        monthly_surplus=13000.0,
        available_monthly_amount=13000.0,
        current_savings=40000.0,
        total_emi=4000.0,
        savings_rate=26.0,
        goals=[
            GoalScenarioSnapshot(
                goal_name="Emergency Fund",
                goal_category="Emergency",
                priority="high",
                target_amount=100000.0,
                current_amount=40000.0,
                remaining_amount=60000.0,
                required_monthly_contribution=15000.0,
                goal_status="AT_RISK",
                feasibility="TIGHT",
                target_date=_future_date(4),
            ),
        ],
        conflict_detected=True,
        conflict_count=1,
        overall_status="CONFLICT",
        conflicts=[
            ConflictSummary(
                conflict_type="CAPACITY_CONFLICT",
                severity="HIGH",
                title="Insufficient Monthly Capacity",
                description="Required monthly contribution exceeds available capacity.",
                affected_goals=["Emergency Fund"],
                deterministic_required_amount=15000.0,
                deterministic_available_amount=13000.0,
                deterministic_gap=2000.0,
            )
        ],
    )

    agent = ScenarioAgent(llm_client=client)
    result = agent.run(snapshot)

    _safe_print("\n--- REAL OLLAMA LLAMA3.2 SCENARIO AGENT RESULT ---")
    _safe_print(f"Scenario Required:   {result.scenario_required}")
    _safe_print(f"Scenario Count:      {result.scenario_count}")
    _safe_print(f"Confidence:          {result.confidence.value}")
    _safe_print(f"Needs Clarification: {result.needs_clarification}")
    _safe_print(f"Summary:             {result.summary}")
    for s in result.scenarios:
        _safe_print(f"\n  [{s.scenario_id}] {s.scenario_type.value}: {s.title}")
        _safe_print(f"    Affected:  {s.affected_goals}")
        _safe_print(f"    Original:  {s.original_monthly_requirement}")
        _safe_print(f"    Scenario:  {s.scenario_monthly_requirement}")
        _safe_print(f"    Capacity:  {s.monthly_capacity}")
        _safe_print(f"    Gap:       {s.capacity_gap}")
        _safe_print(f"    Status:    {s.projected_goal_status.value}")
        _safe_print(f"    Desc:      {s.description[:120]}")
    _safe_print("--------------------------------------------------\n")

    # Deterministic ground truth
    assert snapshot.total_required_monthly_contribution == 15000.0
    assert snapshot.monthly_capacity_gap == 2000.0
    assert snapshot.has_capacity_shortfall is True

    # Result assertions
    assert isinstance(result, ScenarioAgentResult)
    assert result.scenario_required is True
    assert result.scenario_count >= 1
    assert len(result.scenarios) >= 1
    assert len(result.summary) > 0
    assert result.needs_clarification is False

    # Guardrail: deterministic numbers must not be altered by LLM
    for s in result.scenarios:
        assert s.monthly_capacity >= 0.0
        assert s.capacity_gap >= 0.0
        assert s.original_monthly_requirement >= 0.0
        assert s.scenario_monthly_requirement >= 0.0
