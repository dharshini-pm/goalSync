"""GoalSync Goal Agent Module."""

from .models import (
    GoalAgentInput,
    GoalAgentResult,
    GoalStatus,
    GoalFeasibility,
    AgentConfidence,
)
from .prompts import GOAL_AGENT_SYSTEM_PROMPT, build_goal_user_prompt
from .llm_client import OllamaClient
from .agent import GoalAgent
from .service import GoalAgentService

__all__ = [
    "GoalAgentInput",
    "GoalAgentResult",
    "GoalStatus",
    "GoalFeasibility",
    "AgentConfidence",
    "GOAL_AGENT_SYSTEM_PROMPT",
    "build_goal_user_prompt",
    "OllamaClient",
    "GoalAgent",
    "GoalAgentService",
]
