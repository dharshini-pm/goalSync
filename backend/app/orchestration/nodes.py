"""LangGraph nodes for the GoalSync multi-agent pipeline.

Each node:
  1. Reads required fields from GoalSyncState
  2. Builds the target agent's typed input model
  3. Calls the existing agent service (no agent logic lives here)
  4. Stores the result in state
  5. Updates current_stage / completed_stages / execution_trace
  6. Returns the updated state (LangGraph requires returning the whole state)

Error handling:
  - Every node wraps its call in try/except.
  - On failure an ErrorRecord is appended to state.errors.
  - Nodes raise NodeExecutionError so the graph can stop cleanly.
"""

from __future__ import annotations

import traceback
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional

from .state import GoalSyncState, StageTrace, ErrorRecord


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

class NodeExecutionError(RuntimeError):
    """Raised by a node after it has already recorded the error in state."""

    def __init__(self, stage: str, original: Exception) -> None:
        super().__init__(f"[{stage}] {type(original).__name__}: {original}")
        self.stage = stage
        self.original = original


def _now_utc() -> str:
    return datetime.now(timezone.utc).isoformat()


def _ms_between(start: str, end: str) -> float:
    fmt = "%Y-%m-%dT%H:%M:%S.%f+00:00"
    try:
        t0 = datetime.fromisoformat(start)
        t1 = datetime.fromisoformat(end)
        return round((t1 - t0).total_seconds() * 1000, 2)
    except Exception:
        return 0.0


def _record_start(state: GoalSyncState, stage: str) -> str:
    state.current_stage = stage
    return _now_utc()


def _record_success(
    state: GoalSyncState,
    stage: str,
    started_at: str,
) -> None:
    completed_at = _now_utc()
    state.completed_stages.append(stage)
    state.execution_trace.append(
        StageTrace(
            stage=stage,
            status="completed",
            started_at=started_at,
            completed_at=completed_at,
            duration_ms=_ms_between(started_at, completed_at),
        )
    )


def _record_failure(
    state: GoalSyncState,
    stage: str,
    started_at: str,
    exc: Exception,
) -> None:
    completed_at = _now_utc()
    state.errors.append(
        ErrorRecord(
            stage=stage,
            error_type=type(exc).__name__,
            message=str(exc),
        )
    )
    state.execution_trace.append(
        StageTrace(
            stage=stage,
            status="failed",
            started_at=started_at,
            completed_at=completed_at,
            duration_ms=_ms_between(started_at, completed_at),
        )
    )


def _ensure_sufficient_timeout(service: Any, min_seconds: int = 180) -> None:
    """Ensures service's LLM client has sufficient timeout for pipeline execution.

    Cold-starting local models like llama3.2 can take >30s on the first call.
    Safely adjusts the timeout on the underlying OllamaClient without modifying
    agent code or affecting mock objects in tests.
    """
    try:
        agent = getattr(service, "agent", None)
        if agent is not None:
            llm_client = getattr(agent, "llm_client", None)
            if llm_client is not None and hasattr(llm_client, "timeout"):
                current = getattr(llm_client, "timeout", None)
                if isinstance(current, (int, float)) and current < min_seconds:
                    llm_client.timeout = min_seconds
    except Exception:
        pass


# ---------------------------------------------------------------------------
# Node 1 — Transaction Agent
# ---------------------------------------------------------------------------

def transaction_node(state: GoalSyncState) -> GoalSyncState:
    """Calls TransactionAgentService with state.transaction_input."""
    stage = "transaction_agent"
    started_at = _record_start(state, stage)
    try:
        from app.agents.transaction_agent.models import TransactionAgentInput
        from app.agents.transaction_agent.service import TransactionAgentService

        raw = state.transaction_input or {}
        inp = TransactionAgentInput(
            merchant=raw.get("merchant", "Unknown"),
            amount=float(raw.get("amount", 0.0)),
            transaction_type=raw.get("transaction_type", "debit"),
            payment_method=raw.get("payment_method"),
            date=raw.get("date"),
            deterministic_category=raw.get("deterministic_category"),
            merchant_rag_result=raw.get("merchant_rag_result"),
            merchant_rag_confidence=raw.get("merchant_rag_confidence"),
        )

        service = TransactionAgentService.create_default()
        _ensure_sufficient_timeout(service, 180)
        result = service.analyze(inp)

        state.transaction_result = {
            "merchant_name": result.merchant_name,
            "category": result.category,
            "transaction_type": result.transaction_type,
            "summary": result.summary,
            "reasoning": result.reasoning,
            "confidence": result.confidence,
            "needs_clarification": result.needs_clarification,
        }
        _record_success(state, stage, started_at)

    except Exception as exc:
        _record_failure(state, stage, started_at, exc)
        raise NodeExecutionError(stage, exc) from exc

    return state


# ---------------------------------------------------------------------------
# Node 2 — Financial State Agent
# ---------------------------------------------------------------------------

def financial_state_node(state: GoalSyncState) -> GoalSyncState:
    """Calls FinancialStateAgentService with state.financial_state_snapshot."""
    stage = "financial_state_agent"
    started_at = _record_start(state, stage)
    try:
        from app.agents.financial_state_agent.models import FinancialStateAgentInput
        from app.agents.financial_state_agent.service import FinancialStateAgentService

        snap = state.financial_state_snapshot or {}
        inp = FinancialStateAgentInput(
            monthly_income=float(snap.get("monthly_income", 0.0)),
            monthly_expenses=float(snap.get("monthly_expenses", 0.0)),
            monthly_surplus=float(snap.get("monthly_surplus", 0.0)),
            savings_rate=float(snap.get("savings_rate", 0.0)),
            total_emi=float(snap.get("total_emi", 0.0)),
            available_monthly_amount=float(snap.get("available_monthly_amount", 0.0)),
            current_savings=float(snap.get("current_savings", 0.0)),
            transaction_inflow=snap.get("transaction_inflow"),
            transaction_outflow=snap.get("transaction_outflow"),
            debt_to_income_ratio=snap.get("debt_to_income_ratio"),
            expense_to_income_ratio=snap.get("expense_to_income_ratio"),
            emergency_fund_months=snap.get("emergency_fund_months"),
        )

        service = FinancialStateAgentService.create_default()
        _ensure_sufficient_timeout(service, 180)
        result = service.analyze(inp)

        state.financial_state_result = {
            "financial_status": result.financial_status.value,
            "cash_flow_status": result.cash_flow_status.value,
            "summary": result.summary,
            "key_signals": result.key_signals,
            "concerns": result.concerns,
            "confidence": result.confidence.value,
            "needs_clarification": result.needs_clarification,
        }
        _record_success(state, stage, started_at)

    except Exception as exc:
        _record_failure(state, stage, started_at, exc)
        raise NodeExecutionError(stage, exc) from exc

    return state


# ---------------------------------------------------------------------------
# Node 3 — Goal Agent
# ---------------------------------------------------------------------------

def goal_node(state: GoalSyncState) -> GoalSyncState:
    """Calls GoalAgentService for each goal in state.goal_input."""
    stage = "goal_agent"
    started_at = _record_start(state, stage)
    try:
        from app.agents.goal_agent.models import GoalAgentInput
        from app.agents.goal_agent.service import GoalAgentService

        goal_inputs = state.goal_input or []
        fin_snap = state.financial_state_snapshot or {}
        available_monthly = float(fin_snap.get("available_monthly_amount", 0.0))
        monthly_surplus = float(fin_snap.get("monthly_surplus", 0.0))
        current_savings = float(fin_snap.get("current_savings", 0.0))

        service = GoalAgentService.create_default()
        _ensure_sufficient_timeout(service, 180)
        results: List[Dict[str, Any]] = []

        for g in goal_inputs:
            inp = GoalAgentInput(
                goal_name=g.get("goal_name", "Goal"),
                goal_category=g.get("goal_category"),
                priority=g.get("priority"),
                target_amount=float(g.get("target_amount", 0.0)),
                current_amount=float(g.get("current_amount", 0.0)),
                remaining_amount=float(g.get("remaining_amount", 0.0)),
                target_date=g.get("target_date"),
                months_remaining=int(g.get("months_remaining", 0)),
                days_remaining=int(g.get("days_remaining", 0)),
                required_monthly_contribution=float(g.get("required_monthly_contribution", 0.0)),
                available_monthly_amount=g.get("available_monthly_amount", available_monthly),
                monthly_shortfall=float(g.get("monthly_shortfall", 0.0)),
                surplus_coverage_ratio=float(g.get("surplus_coverage_ratio", 0.0)),
                feasibility_status=g.get("feasibility_status", "infeasible"),
                feasibility_score=float(g.get("feasibility_score", 0.0)),
                feasibility_reason=g.get("feasibility_reason"),
                is_achievable_without_savings=bool(g.get("is_achievable_without_savings", False)),
                is_achievable_with_savings=bool(g.get("is_achievable_with_savings", False)),
                current_savings=g.get("current_savings", current_savings),
                monthly_surplus=g.get("monthly_surplus", monthly_surplus),
                metadata=g.get("metadata"),
            )
            r = service.analyze(inp)
            results.append({
                "goal_name": r.goal_name,
                "goal_status": r.goal_status.value,
                "feasibility": r.feasibility.value,
                "summary": r.summary,
                "key_signals": r.key_signals,
                "concerns": r.concerns,
                "confidence": r.confidence.value,
                "needs_clarification": r.needs_clarification,
            })

        state.goal_result = results
        _record_success(state, stage, started_at)

    except Exception as exc:
        _record_failure(state, stage, started_at, exc)
        raise NodeExecutionError(stage, exc) from exc

    return state


# ---------------------------------------------------------------------------
# Node 4 — Conflict Agent
# ---------------------------------------------------------------------------

def conflict_node(state: GoalSyncState) -> GoalSyncState:
    """Calls ConflictAgentService with financial state + goal results."""
    stage = "conflict_agent"
    started_at = _record_start(state, stage)
    try:
        from app.agents.conflict_agent.models import ConflictAgentInput, GoalConflictSnapshot
        from app.agents.conflict_agent.service import ConflictAgentService

        fin_snap = state.financial_state_snapshot or {}
        goal_results = state.goal_result or []
        goal_inputs = state.goal_input or []

        # Build GoalConflictSnapshot list from goal_input + goal_result
        goal_snapshots = []
        for i, g_in in enumerate(goal_inputs):
            g_res = goal_results[i] if i < len(goal_results) else {}
            snapshot = GoalConflictSnapshot(
                goal_name=g_in.get("goal_name", "Goal"),
                goal_category=g_in.get("goal_category"),
                priority=g_in.get("priority"),
                target_amount=float(g_in.get("target_amount", 0.0)),
                current_amount=float(g_in.get("current_amount", 0.0)),
                remaining_amount=float(g_in.get("remaining_amount", 0.0)),
                target_date=g_in.get("target_date"),
                required_monthly_contribution=float(g_in.get("required_monthly_contribution", 0.0)),
                goal_status=g_res.get("goal_status", "UNKNOWN"),
                feasibility=g_res.get("feasibility", "UNKNOWN"),
                is_active=True,
            )
            goal_snapshots.append(snapshot)

        inp = ConflictAgentInput(
            monthly_income=float(fin_snap.get("monthly_income", 0.0)),
            monthly_expenses=float(fin_snap.get("monthly_expenses", 0.0)),
            monthly_surplus=float(fin_snap.get("monthly_surplus", 0.0)),
            available_monthly_amount=float(fin_snap.get("available_monthly_amount", 0.0)),
            current_savings=float(fin_snap.get("current_savings", 0.0)),
            total_emi=float(fin_snap.get("total_emi", 0.0)),
            savings_rate=float(fin_snap.get("savings_rate", 0.0)),
            goals=goal_snapshots,
        )

        service = ConflictAgentService.create_default()
        _ensure_sufficient_timeout(service, 180)
        result = service.analyze(inp)

        state.conflict_result = {
            "conflict_detected": result.conflict_detected,
            "conflict_count": result.conflict_count,
            "overall_status": result.overall_status.value,
            "conflicts": [
                {
                    "conflict_type": c.conflict_type.value,
                    "severity": c.severity.value,
                    "title": c.title,
                    "description": c.description,
                    "affected_goals": c.affected_goals,
                    "deterministic_required_amount": c.deterministic_required_amount,
                    "deterministic_available_amount": c.deterministic_available_amount,
                    "deterministic_gap": c.deterministic_gap,
                }
                for c in result.conflicts
            ],
            "summary": result.summary,
            "confidence": result.confidence.value,
            "needs_clarification": result.needs_clarification,
        }
        _record_success(state, stage, started_at)

    except Exception as exc:
        _record_failure(state, stage, started_at, exc)
        raise NodeExecutionError(stage, exc) from exc

    return state


# ---------------------------------------------------------------------------
# Node 5 — Scenario Agent
# ---------------------------------------------------------------------------

def scenario_node(state: GoalSyncState) -> GoalSyncState:
    """Calls ScenarioAgentService with financial state + goals + conflict."""
    stage = "scenario_agent"
    started_at = _record_start(state, stage)
    try:
        from app.agents.scenario_agent.models import (
            ScenarioAgentInput, GoalScenarioSnapshot, ConflictSummary,
        )
        from app.agents.scenario_agent.service import ScenarioAgentService

        fin_snap = state.financial_state_snapshot or {}
        goal_inputs = state.goal_input or []
        goal_results = state.goal_result or []
        conflict = state.conflict_result or {}

        goal_snapshots = []
        for i, g_in in enumerate(goal_inputs):
            g_res = goal_results[i] if i < len(goal_results) else {}
            snapshot = GoalScenarioSnapshot(
                goal_name=g_in.get("goal_name", "Goal"),
                goal_category=g_in.get("goal_category"),
                target_amount=float(g_in.get("target_amount", 0.0)),
                current_amount=float(g_in.get("current_amount", 0.0)),
                target_date=g_in.get("target_date"),
                priority=g_in.get("priority"),
                required_monthly_contribution=float(g_in.get("required_monthly_contribution", 0.0)),
                remaining_amount=float(g_in.get("remaining_amount", 0.0)),
                goal_status=g_res.get("goal_status", "ON_TRACK"),
                feasibility=g_res.get("feasibility", "FEASIBLE"),
            )
            goal_snapshots.append(snapshot)

        conflict_snapshots = [
            ConflictSummary(**c)
            for c in conflict.get("conflicts", [])
        ]

        inp = ScenarioAgentInput(
            monthly_income=float(fin_snap.get("monthly_income", 0.0)),
            monthly_expenses=float(fin_snap.get("monthly_expenses", 0.0)),
            monthly_surplus=float(fin_snap.get("monthly_surplus", 0.0)),
            available_monthly_amount=float(fin_snap.get("available_monthly_amount", 0.0)),
            current_savings=float(fin_snap.get("current_savings", 0.0)),
            total_emi=float(fin_snap.get("total_emi", 0.0)),
            savings_rate=float(fin_snap.get("savings_rate", 0.0)),
            goals=goal_snapshots,
            conflict_detected=bool(conflict.get("conflict_detected", False)),
            conflict_count=int(conflict.get("conflict_count", 0)),
            overall_status=conflict.get("overall_status", "NO_CONFLICT"),
            conflicts=conflict_snapshots,
        )

        service = ScenarioAgentService.create_default()
        _ensure_sufficient_timeout(service, 180)
        result = service.generate(inp)

        state.scenario_result = {
            "scenario_required": result.scenario_required,
            "scenario_count": result.scenario_count,
            "scenarios": [
                {
                    "scenario_id": s.scenario_id,
                    "scenario_type": s.scenario_type.value,
                    "title": s.title,
                    "assumptions": s.assumptions,
                    "affected_goals": s.affected_goals,
                    "original_monthly_requirement": s.original_monthly_requirement,
                    "scenario_monthly_requirement": s.scenario_monthly_requirement,
                    "monthly_capacity": s.monthly_capacity,
                    "capacity_gap": s.capacity_gap,
                    "projected_goal_status": s.projected_goal_status.value,
                    "description": s.description,
                }
                for s in result.scenarios
            ],
            "summary": result.summary,
            "confidence": result.confidence.value,
            "needs_clarification": result.needs_clarification,
        }
        _record_success(state, stage, started_at)

    except Exception as exc:
        _record_failure(state, stage, started_at, exc)
        raise NodeExecutionError(stage, exc) from exc

    return state


# ---------------------------------------------------------------------------
# Node 6 — Explanation Agent
# ---------------------------------------------------------------------------

def explanation_node(state: GoalSyncState) -> GoalSyncState:
    """Calls ExplanationAgentService with full pipeline outputs."""
    stage = "explanation_agent"
    started_at = _record_start(state, stage)
    try:
        from app.agents.explanation_agent.models import (
            ExplanationAgentInput,
            GoalExplanationSnapshot,
            ConflictExplanationSnapshot,
            ScenarioExplanationSnapshot,
        )
        from app.agents.explanation_agent.service import ExplanationAgentService

        fin_snap = state.financial_state_snapshot or {}
        fin_result = state.financial_state_result or {}
        goal_inputs = state.goal_input or []
        goal_results = state.goal_result or []
        conflict = state.conflict_result or {}
        scenario = state.scenario_result or {}

        goal_snapshots = []
        for i, g_in in enumerate(goal_inputs):
            g_res = goal_results[i] if i < len(goal_results) else {}
            snap = GoalExplanationSnapshot(
                goal_name=g_in.get("goal_name", "Goal"),
                goal_category=g_in.get("goal_category"),
                target_amount=float(g_in.get("target_amount", 0.0)),
                current_amount=float(g_in.get("current_amount", 0.0)),
                target_date=g_in.get("target_date"),
                priority=g_in.get("priority"),
                required_monthly_contribution=float(g_in.get("required_monthly_contribution", 0.0)),
                remaining_amount=float(g_in.get("remaining_amount", 0.0)),
                goal_status=g_res.get("goal_status", "ON_TRACK"),
                feasibility=g_res.get("feasibility", "FEASIBLE"),
            )
            goal_snapshots.append(snap)

        conflict_snapshots = [
            ConflictExplanationSnapshot(**c)
            for c in conflict.get("conflicts", [])
        ]

        scenario_snapshots = [
            ScenarioExplanationSnapshot(**s)
            for s in scenario.get("scenarios", [])
        ]

        inp = ExplanationAgentInput(
            monthly_income=float(fin_snap.get("monthly_income", 0.0)),
            monthly_expenses=float(fin_snap.get("monthly_expenses", 0.0)),
            monthly_surplus=float(fin_snap.get("monthly_surplus", 0.0)),
            available_monthly_amount=float(fin_snap.get("available_monthly_amount", 0.0)),
            current_savings=float(fin_snap.get("current_savings", 0.0)),
            total_emi=float(fin_snap.get("total_emi", 0.0)),
            savings_rate=float(fin_snap.get("savings_rate", 0.0)),
            financial_status=fin_result.get("financial_status", "STABLE"),
            cash_flow_status=fin_result.get("cash_flow_status", "POSITIVE"),
            key_signals=fin_result.get("key_signals", []),
            concerns=fin_result.get("concerns", []),
            goals=goal_snapshots,
            conflict_detected=bool(conflict.get("conflict_detected", False)),
            conflict_count=int(conflict.get("conflict_count", 0)),
            overall_conflict_status=conflict.get("overall_status", "NO_CONFLICT"),
            conflicts=conflict_snapshots,
            scenario_required=bool(scenario.get("scenario_required", False)),
            scenario_count=int(scenario.get("scenario_count", 0)),
            scenarios=scenario_snapshots,
        )

        service = ExplanationAgentService.create_default()
        _ensure_sufficient_timeout(service, 180)
        result = service.explain(inp)

        state.explanation_result = {
            "headline": result.headline,
            "summary": result.summary,
            "key_points": result.key_points,
            "goal_impacts": [
                {"goal_name": gi.goal_name, "explanation": gi.explanation, "status": gi.status}
                for gi in result.goal_impacts
            ],
            "conflict_explanation": {
                "detected": result.conflict_explanation.detected,
                "explanation": result.conflict_explanation.explanation,
            },
            "scenario_explanations": [
                {"scenario_id": se.scenario_id, "explanation": se.explanation}
                for se in result.scenario_explanations
            ],
            "assumptions": result.assumptions,
            "confidence": result.confidence,
            "needs_clarification": result.needs_clarification,
        }
        _record_success(state, stage, started_at)

    except Exception as exc:
        _record_failure(state, stage, started_at, exc)
        raise NodeExecutionError(stage, exc) from exc

    return state
