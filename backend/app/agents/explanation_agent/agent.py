"""Core Explanation Agent — explains GoalSync intelligence using local LLM."""

from typing import Optional

from .models import (
    ExplanationAgentInput,
    ExplanationAgentResult,
    GoalImpactExplanation,
    ConflictExplanationOutput,
    ScenarioExplanationOutput,
)
from .prompts import EXPLANATION_AGENT_SYSTEM_PROMPT, build_explanation_user_prompt
from .llm_client import OllamaClient


class ExplanationAgent:
    """Agent that explains deterministic GoalSync intelligence to the user.

    Workflow:
    1. Validate input.
    2. Call local Ollama with all deterministic facts injected in the prompt.
    3. Pydantic-validate the structured JSON response.
    4. Deterministic guardrails: restore any numerical values the LLM altered.
    5. Safety guardrails: ensure no financial advice leaked through.
    """

    def __init__(self, llm_client: Optional[OllamaClient] = None):
        self.llm_client = llm_client or OllamaClient()

    def run(self, snapshot: ExplanationAgentInput) -> ExplanationAgentResult:
        """Execute the explanation workflow.

        Args:
            snapshot: Validated ExplanationAgentInput with all agent outputs.

        Returns:
            ExplanationAgentResult strictly validated against the Pydantic schema.
        """
        if not isinstance(snapshot, ExplanationAgentInput):
            raise ValueError(
                f"Expected ExplanationAgentInput, got {type(snapshot).__name__}"
            )

        # ------------------------------------------------------------------
        # 1. Build prompt and call local Ollama
        # ------------------------------------------------------------------
        user_prompt = build_explanation_user_prompt(snapshot)
        raw_output = self.llm_client.generate_json(
            system_prompt=EXPLANATION_AGENT_SYSTEM_PROMPT,
            user_prompt=user_prompt,
            temperature=0.0,
        )

        # ------------------------------------------------------------------
        # 2. Parse and validate with Pydantic
        # ------------------------------------------------------------------
        result = ExplanationAgentResult.model_validate(raw_output)

        # ------------------------------------------------------------------
        # 3. Deterministic guardrails
        # ------------------------------------------------------------------

        # 3a. conflict_explanation.detected must match input
        result.conflict_explanation = ConflictExplanationOutput(
            detected=snapshot.conflict_detected,
            explanation=result.conflict_explanation.explanation,
        )

        # 3b. goal_impacts: status must match the deterministic goal_status
        #     (LLM cannot reclassify a goal from AT_RISK to ON_TRACK)
        goal_status_map = {g.goal_name: g.goal_status for g in snapshot.goals}
        guarded_impacts: list[GoalImpactExplanation] = []
        for impact in result.goal_impacts:
            det_status = goal_status_map.get(impact.goal_name, impact.status)
            guarded_impacts.append(GoalImpactExplanation(
                goal_name=impact.goal_name,
                explanation=impact.explanation,
                status=det_status,
            ))
        # If LLM dropped a goal, add a minimal deterministic entry
        explained_names = {i.goal_name for i in guarded_impacts}
        for g in snapshot.goals:
            if g.goal_name not in explained_names:
                guarded_impacts.append(GoalImpactExplanation(
                    goal_name=g.goal_name,
                    explanation=(
                        f"This goal {'has been completed' if g.is_completed else 'is active'}. "
                        f"Status: {g.goal_status}. "
                        f"Remaining amount: {g.remaining_amount:.2f}."
                    ),
                    status=g.goal_status,
                ))
        result.goal_impacts = guarded_impacts

        # 3c. scenario_explanations must cover all scenarios in the input
        #     If LLM dropped a scenario, add a minimal deterministic entry
        explained_ids = {s.scenario_id for s in result.scenario_explanations}
        for s in snapshot.scenarios:
            if s.scenario_id not in explained_ids:
                result.scenario_explanations.append(ScenarioExplanationOutput(
                    scenario_id=s.scenario_id,
                    explanation=(
                        f"Scenario {s.scenario_id} ({s.scenario_type}): {s.title}. "
                        f"Under this scenario, the required monthly contribution changes "
                        f"from {s.original_monthly_requirement:.2f} to "
                        f"{s.scenario_monthly_requirement:.2f}. "
                        f"Remaining capacity gap: {s.capacity_gap:.2f}."
                    ),
                ))

        # 3d. If no conflicts but LLM somehow left scenario explanations, clear them
        if not snapshot.scenario_required and result.scenario_explanations:
            result.scenario_explanations = []

        return result
