"""GoalSyncGraphService — public API for the LangGraph orchestration layer.

Usage:
    service = GoalSyncGraphService()
    result = service.run(
        transaction_input={...},
        financial_state_snapshot={...},
        goal_input=[...],
        user_id="user123",
        metadata={},
    )
    print(result.completed_stages)
    print(result.explanation_result)
"""

from __future__ import annotations

import uuid
from typing import Any, Dict, List, Optional

from .state import GoalSyncState, GraphResult
from .graph import build_graph
from .nodes import NodeExecutionError


class GoalSyncGraphService:
    """High-level service that drives the LangGraph multi-agent pipeline.

    This is the ONLY entry point external code should call.
    It:
    1. Generates a unique request_id (UUID4)
    2. Builds the initial GoalSyncState
    3. Invokes the compiled LangGraph
    4. Returns a structured GraphResult

    It does NOT perform any financial calculations itself.
    """

    def __init__(self) -> None:
        self._graph = build_graph()

    def run(
        self,
        transaction_input: Dict[str, Any],
        financial_state_snapshot: Dict[str, Any],
        goal_input: List[Dict[str, Any]],
        user_id: str = "",
        metadata: Optional[Dict[str, Any]] = None,
        request_id: Optional[str] = None,
    ) -> GraphResult:
        """Execute the full six-agent pipeline for a single financial event.

        Parameters
        ----------
        transaction_input:
            Raw transaction data (merchant, amount, transaction_type, …).
        financial_state_snapshot:
            Deterministic financial snapshot computed by the FinancialStateEngine.
            This is the authoritative source of truth; no agent may overwrite it.
        goal_input:
            List of goal dicts pre-calculated by GoalFeasibilityEngine.
        user_id:
            Optional user identifier for tracing.
        metadata:
            Optional arbitrary key-value pairs for contextual metadata.
        request_id:
            Optional caller-supplied UUID; auto-generated if omitted.

        Returns
        -------
        GraphResult
            Structured final result with all six agent outputs + trace.
        """
        rid = request_id or str(uuid.uuid4())

        initial_state = GoalSyncState(
            request_id=rid,
            user_id=user_id,
            transaction_input=transaction_input,
            financial_state_snapshot=financial_state_snapshot,
            goal_input=goal_input,
            metadata=metadata or {},
        )

        try:
            raw = self._graph.invoke(initial_state)
            # LangGraph 1.x returns a dict when invoked with a dataclass state.
            # Reconstruct the dataclass from the dict so we get attribute access.
            if isinstance(raw, dict):
                final_state = _state_from_dict(initial_state, raw)
            else:
                # Older behaviour: returned the dataclass directly
                final_state = raw  # type: ignore[assignment]
        except NodeExecutionError:
            # Graph stopped at a critical node — return whatever was mutated
            # into initial_state by the node that failed
            final_state = initial_state
        except Exception as exc:
            from .state import ErrorRecord
            final_state = initial_state
            final_state.errors.append(
                ErrorRecord(
                    stage="graph_invoke",
                    error_type=type(exc).__name__,
                    message=str(exc),
                )
            )

        success = (
            len(final_state.errors) == 0
            and final_state.explanation_result is not None
        )

        return GraphResult(
            request_id=final_state.request_id,
            current_stage=final_state.current_stage,
            completed_stages=final_state.completed_stages,
            transaction_result=final_state.transaction_result,
            financial_state_result=final_state.financial_state_result,
            goal_result=final_state.goal_result,
            conflict_result=final_state.conflict_result,
            scenario_result=final_state.scenario_result,
            explanation_result=final_state.explanation_result,
            errors=final_state.errors,
            execution_trace=final_state.execution_trace,
            success=success,
        )


def _state_from_dict(base: GoalSyncState, d: dict) -> GoalSyncState:
    """Merge a LangGraph-returned dict back into a GoalSyncState dataclass.

    LangGraph may return only the *updated* keys.  We start from the base
    state so that any unmodified fields are preserved.
    """
    import dataclasses

    # Collect valid field names for GoalSyncState
    field_names = {f.name for f in dataclasses.fields(GoalSyncState)}

    for key, value in d.items():
        if key in field_names:
            object.__setattr__(base, key, value)

    return base
