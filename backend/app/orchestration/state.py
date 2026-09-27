"""LangGraph state definition for the GoalSync multi-agent pipeline.

GoalSyncState is the single shared mutable document that flows through
every node.  Fields become populated progressively as each agent completes.

IMPORTANT RULES:
- LLM agents must NEVER overwrite deterministic engine snapshots.
- All Optional fields start as None and are set exactly once by their node.
- The 'errors' list is append-only; nodes must never clear it.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any, Dict, List, Optional


@dataclass
class StageTrace:
    """Lightweight execution record for one pipeline stage."""

    stage: str
    status: str          # "completed" | "failed" | "skipped"
    started_at: str      # ISO-8601 UTC string
    completed_at: str    # ISO-8601 UTC string
    duration_ms: float


@dataclass
class ErrorRecord:
    """Structured error captured when a node raises an exception."""

    stage: str
    error_type: str
    message: str


@dataclass
class GoalSyncState:
    """Shared typed state for the GoalSync LangGraph graph.

    Fields are set progressively by each node.  No node may overwrite
    a field that was already set by an earlier node (deterministic values
    are immutable once written).
    """

    # ----------------------------------------------------------------
    # Identity / tracing
    # ----------------------------------------------------------------
    request_id: str = ""
    user_id: str = ""
    current_stage: str = "initialised"
    completed_stages: List[str] = field(default_factory=list)
    errors: List[ErrorRecord] = field(default_factory=list)
    execution_trace: List[StageTrace] = field(default_factory=list)
    metadata: Dict[str, Any] = field(default_factory=dict)

    # ----------------------------------------------------------------
    # Transaction node I/O
    # ----------------------------------------------------------------
    # Input supplied by the caller before graph.invoke()
    transaction_input: Optional[Dict[str, Any]] = None
    # Output set by transaction_node
    transaction_result: Optional[Dict[str, Any]] = None

    # ----------------------------------------------------------------
    # Financial State node I/O
    # ----------------------------------------------------------------
    # The deterministic snapshot (plain dict) — authoritative, never overwritten
    financial_state_snapshot: Optional[Dict[str, Any]] = None
    # Output set by financial_state_node (LLM interpretation)
    financial_state_result: Optional[Dict[str, Any]] = None

    # ----------------------------------------------------------------
    # Goal node I/O
    # ----------------------------------------------------------------
    # List of goal dicts supplied by the caller; passed through unchanged
    goal_input: Optional[List[Dict[str, Any]]] = None
    # Output set by goal_node (one result dict per goal)
    goal_result: Optional[List[Dict[str, Any]]] = None

    # ----------------------------------------------------------------
    # Conflict node I/O
    # ----------------------------------------------------------------
    conflict_result: Optional[Dict[str, Any]] = None

    # ----------------------------------------------------------------
    # Scenario node I/O
    # ----------------------------------------------------------------
    scenario_result: Optional[Dict[str, Any]] = None

    # ----------------------------------------------------------------
    # Explanation node I/O
    # ----------------------------------------------------------------
    explanation_result: Optional[Dict[str, Any]] = None


@dataclass
class GraphResult:
    """Final structured result returned by GoalSyncGraphService.run()."""

    request_id: str
    current_stage: str
    completed_stages: List[str]
    transaction_result: Optional[Dict[str, Any]]
    financial_state_result: Optional[Dict[str, Any]]
    goal_result: Optional[List[Dict[str, Any]]]
    conflict_result: Optional[Dict[str, Any]]
    scenario_result: Optional[Dict[str, Any]]
    explanation_result: Optional[Dict[str, Any]]
    errors: List[ErrorRecord]
    execution_trace: List[StageTrace]
    success: bool

    def to_dict(self) -> Dict[str, Any]:
        import dataclasses
        return dataclasses.asdict(self)
