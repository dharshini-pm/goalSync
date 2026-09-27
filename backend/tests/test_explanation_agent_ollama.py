"""Real Ollama + llama3.2 Integration Test for GoalSync Explanation Agent.

Uses a minimal single-goal, single-scenario input to keep the prompt short
and reliably fit within a 240-second local timeout.
"""

import sys
import pytest
from datetime import date

from app.agents.explanation_agent.models import (
    ExplanationAgentInput,
    ExplanationAgentResult,
    GoalExplanationSnapshot,
    ConflictExplanationSnapshot,
    ScenarioExplanationSnapshot,
)
from app.agents.explanation_agent.llm_client import OllamaClient
from app.agents.explanation_agent.agent import ExplanationAgent


def _safe_print(text: str) -> None:
    sys.stdout.buffer.write((text + "\n").encode("utf-8", errors="replace"))
    sys.stdout.buffer.flush()


def _future_date(months: int) -> str:
    ref = date.today()
    y = ref.year + (ref.month + months - 1) // 12
    m = (ref.month + months - 1) % 12 + 1
    return f"{y:04d}-{m:02d}-01"


def test_real_ollama_explanation_agent_integration():
    """Executes a real explanation using local Ollama and llama3.2."""
    client = OllamaClient(timeout=240)

    if not client.is_available():
        pytest.skip("Skipped: Ollama server not reachable on localhost:11434")

    if not client.is_model_available("llama3.2"):
        pytest.skip("Skipped: llama3.2 model not installed in local Ollama")

    snapshot = ExplanationAgentInput(
        monthly_income=50000.0,
        monthly_expenses=37000.0,
        monthly_surplus=13000.0,
        available_monthly_amount=13000.0,
        current_savings=40000.0,
        total_emi=4000.0,
        savings_rate=26.0,
        financial_status="STABLE",
        cash_flow_status="POSITIVE",
        key_signals=["Stable monthly income", "Positive cash flow"],
        concerns=["Goal contribution exceeds available capacity"],
        goals=[
            GoalExplanationSnapshot(
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
        overall_conflict_status="CONFLICT",
        conflicts=[
            ConflictExplanationSnapshot(
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
        scenario_required=True,
        scenario_count=2,
        scenarios=[
            ScenarioExplanationSnapshot(
                scenario_id="S1",
                scenario_type="TIMELINE_ADJUSTMENT",
                title="Extend Emergency Fund target date by 6 months",
                assumptions=["Target date extended by 6 months."],
                affected_goals=["Emergency Fund"],
                original_monthly_requirement=15000.0,
                scenario_monthly_requirement=6000.0,
                monthly_capacity=13000.0,
                capacity_gap=0.0,
                projected_goal_status="ON_TRACK",
                description="Under this scenario the monthly contribution reduces from 15000 to 6000.",
            ),
            ScenarioExplanationSnapshot(
                scenario_id="S2",
                scenario_type="CAPACITY_CHANGE",
                title="What-if: available capacity increases by 20%",
                assumptions=["Available monthly capacity is modelled at 15600."],
                affected_goals=["Emergency Fund"],
                original_monthly_requirement=15000.0,
                scenario_monthly_requirement=15000.0,
                monthly_capacity=15600.0,
                capacity_gap=0.0,
                projected_goal_status="ON_TRACK",
                description="Under this scenario capacity rises to 15600 covering the full requirement.",
            ),
        ],
    )

    agent = ExplanationAgent(llm_client=client)
    result = agent.run(snapshot)

    _safe_print("\n--- REAL OLLAMA LLAMA3.2 EXPLANATION AGENT RESULT ---")
    _safe_print(f"Headline:            {result.headline}")
    _safe_print(f"Confidence:          {result.confidence}")
    _safe_print(f"Needs Clarification: {result.needs_clarification}")
    _safe_print(f"Summary:             {result.summary[:200]}")
    _safe_print(f"Key Points:          {result.key_points}")
    _safe_print(f"Conflict Detected:   {result.conflict_explanation.detected}")
    _safe_print(f"Conflict Expl:       {result.conflict_explanation.explanation[:150]}")
    for gi in result.goal_impacts:
        _safe_print(f"  Goal [{gi.status}] {gi.goal_name}: {gi.explanation[:100]}")
    for se in result.scenario_explanations:
        _safe_print(f"  Scenario {se.scenario_id}: {se.explanation[:120]}")
    _safe_print("-----------------------------------------------------\n")

    # Assertions
    assert isinstance(result, ExplanationAgentResult)
    assert len(result.headline) > 0
    assert len(result.summary) > 0
    assert result.conflict_explanation.detected is True   # guardrail enforced
    assert result.needs_clarification is False

    # All goal names must appear
    goal_names = {i.goal_name for i in result.goal_impacts}
    assert "Emergency Fund" in goal_names

    # Goal status must be deterministic (AT_RISK, not changed by LLM)
    ef = next(i for i in result.goal_impacts if i.goal_name == "Emergency Fund")
    assert ef.status == "AT_RISK"

    # All scenario IDs must appear
    s_ids = {s.scenario_id for s in result.scenario_explanations}
    assert "S1" in s_ids
    assert "S2" in s_ids
