"""Core Scenario Agent — generates transparent what-if scenarios using local LLM."""

from typing import Optional

from .models import (
    ScenarioAgentInput,
    ScenarioAgentResult,
    ScenarioRecord,
    ProjectedGoalStatus,
)
from .prompts import SCENARIO_AGENT_SYSTEM_PROMPT, build_scenario_user_prompt
from .llm_client import OllamaClient
from .deterministic_engine import build_deterministic_scenarios


class ScenarioAgent:
    """Agent that generates transparent what-if financial scenarios.

    Workflow:
    1. No-conflict fast path: return scenario_required=False immediately.
    2. Deterministic scenario engine: compute all scenario numbers (no LLM).
    3. LLM call: enrich with human-readable descriptions.
    4. Pydantic validation of structured JSON output.
    5. Deterministic guardrails: overwrite any LLM-altered numbers with engine values.
    """

    def __init__(self, llm_client: Optional[OllamaClient] = None):
        self.llm_client = llm_client or OllamaClient()

    def run(self, snapshot: ScenarioAgentInput) -> ScenarioAgentResult:
        """Execute the scenario generation workflow.

        Args:
            snapshot: Validated ScenarioAgentInput with financial state,
                      goals, and conflict data.

        Returns:
            ScenarioAgentResult strictly validated against the Pydantic schema.
        """
        if not isinstance(snapshot, ScenarioAgentInput):
            raise ValueError(f"Expected ScenarioAgentInput, got {type(snapshot).__name__}")

        # ------------------------------------------------------------------
        # 1. No-conflict fast path
        # ------------------------------------------------------------------
        if not snapshot.conflict_detected:
            return ScenarioAgentResult(
                scenario_required=False,
                scenario_count=0,
                scenarios=[],
                summary="No detected conflict requires scenario analysis.",
                confidence="high",
                needs_clarification=False,
            )

        # ------------------------------------------------------------------
        # 2. Build deterministic scenarios (engine is authoritative)
        # ------------------------------------------------------------------
        det_scenarios = build_deterministic_scenarios(snapshot)

        if not det_scenarios:
            return ScenarioAgentResult(
                scenario_required=True,
                scenario_count=0,
                scenarios=[],
                summary=(
                    "A conflict was detected, but no applicable scenarios could be "
                    "generated from the current goal configuration."
                ),
                confidence="medium",
                needs_clarification=True,
            )

        # ------------------------------------------------------------------
        # 3. Build prompt and call local Ollama
        # ------------------------------------------------------------------
        user_prompt = build_scenario_user_prompt(snapshot, det_scenarios)
        raw_output = self.llm_client.generate_json(
            system_prompt=SCENARIO_AGENT_SYSTEM_PROMPT,
            user_prompt=user_prompt,
            temperature=0.0,
        )

        # ------------------------------------------------------------------
        # 4. Parse and validate with Pydantic
        # ------------------------------------------------------------------
        result = ScenarioAgentResult.model_validate(raw_output)

        # ------------------------------------------------------------------
        # 5. Deterministic guardrails
        # ------------------------------------------------------------------

        # 5a. scenario_required must match conflict_detected
        result.scenario_required = snapshot.conflict_detected

        # 5b. Overwrite scenario records with deterministic values
        #     (LLM cannot alter numbers — only descriptions/titles are accepted from LLM)
        det_map = {s.scenario_id: s for s in det_scenarios}

        # Rebuild scenarios: use LLM descriptions/titles but enforce deterministic numbers
        guarded_scenarios: list[ScenarioRecord] = []
        for det in det_scenarios:
            # Find matching LLM record by scenario_id
            llm_record = next(
                (s for s in result.scenarios if s.scenario_id == det.scenario_id),
                None,
            )
            if llm_record is not None:
                # Accept LLM title, description, assumptions but overwrite all numbers
                guarded_scenarios.append(ScenarioRecord(
                    scenario_id=det.scenario_id,
                    scenario_type=det.scenario_type,
                    title=llm_record.title if llm_record.title else det.title,
                    assumptions=llm_record.assumptions if llm_record.assumptions else det.assumptions,
                    affected_goals=det.affected_goals,  # authoritative
                    original_monthly_requirement=det.original_monthly_requirement,
                    scenario_monthly_requirement=det.scenario_monthly_requirement,
                    monthly_capacity=det.monthly_capacity,
                    capacity_gap=det.capacity_gap,
                    projected_goal_status=det.projected_goal_status,
                    description=(
                        llm_record.description if llm_record.description else det.description
                    ),
                ))
            else:
                # LLM dropped this scenario — use the full deterministic record
                guarded_scenarios.append(det)

        result.scenarios = guarded_scenarios
        result.scenario_count = len(guarded_scenarios)
        return result
