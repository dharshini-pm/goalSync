"""GoalSync Conflict Agent Module."""

from .models import (
    ConflictAgentInput,
    ConflictAgentResult,
    ConflictRecord,
    GoalConflictSnapshot,
    ConflictType,
    ConflictSeverity,
    OverallStatus,
    AgentConfidence,
)
from .prompts import CONFLICT_AGENT_SYSTEM_PROMPT, build_conflict_user_prompt
from .llm_client import OllamaClient
from .agent import ConflictAgent
from .service import ConflictAgentService

__all__ = [
    "ConflictAgentInput",
    "ConflictAgentResult",
    "ConflictRecord",
    "GoalConflictSnapshot",
    "ConflictType",
    "ConflictSeverity",
    "OverallStatus",
    "AgentConfidence",
    "CONFLICT_AGENT_SYSTEM_PROMPT",
    "build_conflict_user_prompt",
    "OllamaClient",
    "ConflictAgent",
    "ConflictAgentService",
]
