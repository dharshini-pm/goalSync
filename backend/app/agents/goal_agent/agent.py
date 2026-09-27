"""Core Goal Agent implementation using local LLM reasoning."""

from typing import Optional
from .models import GoalAgentInput, GoalAgentResult, GoalStatus, GoalFeasibility
from .prompts import GOAL_AGENT_SYSTEM_PROMPT, build_goal_user_prompt
from .llm_client import OllamaClient


class GoalAgent:
    """Agent that reasons over a deterministic goal feasibility snapshot using local LLM inference."""

    def __init__(self, llm_client: Optional[OllamaClient] = None):
        self.llm_client = llm_client or OllamaClient()

    def run(self, snapshot: GoalAgentInput) -> GoalAgentResult:
        """Executes the goal reasoning workflow on the deterministic feasibility snapshot.

        Args:
            snapshot: Validated GoalAgentInput containing deterministic goal facts.

        Returns:
            GoalAgentResult strictly validated against the required Pydantic schema.

        Raises:
            ValueError: If input validation or output schema validation fails.
            OllamaError: If LLM invocation or response decoding fails.
        """
        if not isinstance(snapshot, GoalAgentInput):
            raise ValueError(
                f"Expected GoalAgentInput, got {type(snapshot).__name__}"
            )

        # 1. Build prompt context with deterministic ground-truth signals
        user_prompt = build_goal_user_prompt(snapshot)

        # 2. Query local Ollama model for structured JSON
        raw_output = self.llm_client.generate_json(
            system_prompt=GOAL_AGENT_SYSTEM_PROMPT,
            user_prompt=user_prompt,
            temperature=0.0,
        )

        # 3. Parse and strictly validate using Pydantic
        result = GoalAgentResult.model_validate(raw_output)

        # 4. Deterministic Guardrails — engine classifications are authoritative
        expected_status = snapshot.deterministic_goal_status
        expected_feasibility = snapshot.deterministic_feasibility

        # Override LLM if it contradicts deterministic goal_status
        if result.goal_status != expected_status:
            result.goal_status = expected_status

        # Override LLM if it contradicts deterministic feasibility
        if result.feasibility != expected_feasibility:
            result.feasibility = expected_feasibility

        # Completed/achieved goals must never report OFF_TRACK or AT_RISK
        if snapshot.remaining_amount <= 0 and result.goal_status not in (
            GoalStatus.COMPLETED, GoalStatus.ON_TRACK
        ):
            result.goal_status = GoalStatus.COMPLETED
            result.feasibility = GoalFeasibility.ACHIEVED

        # Ensure goal_name matches input (prevent LLM hallucination)
        result.goal_name = snapshot.goal_name

        return result
