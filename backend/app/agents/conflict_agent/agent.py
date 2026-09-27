"""Core Conflict Agent — detects and explains financial goal conflicts using local LLM."""

from typing import Optional

from .models import (
    ConflictAgentInput,
    ConflictAgentResult,
    ConflictRecord,
    ConflictType,
    ConflictSeverity,
    OverallStatus,
)
from .prompts import CONFLICT_AGENT_SYSTEM_PROMPT, build_conflict_user_prompt
from .llm_client import OllamaClient


class ConflictAgent:
    """Agent that detects and explains conflicts between financial goals and capacity.

    Workflow:
    1. Deterministic conflict detection (math — no LLM).
    2. LLM prompt with pre-computed conflict facts.
    3. Pydantic validation of structured JSON output.
    4. Deterministic guardrails override any incorrect LLM values.
    """

    def __init__(self, llm_client: Optional[OllamaClient] = None):
        self.llm_client = llm_client or OllamaClient()

    def run(self, snapshot: ConflictAgentInput) -> ConflictAgentResult:
        """Executes the conflict detection and explanation workflow.

        Args:
            snapshot: Validated ConflictAgentInput with financial state and goals.

        Returns:
            ConflictAgentResult strictly validated against the Pydantic schema.

        Raises:
            ValueError: On input or output schema validation failure.
            OllamaError: If LLM call or response decoding fails.
        """
        if not isinstance(snapshot, ConflictAgentInput):
            raise ValueError(f"Expected ConflictAgentInput, got {type(snapshot).__name__}")

        # ------------------------------------------------------------------
        # 1. Deterministic conflict detection — ground truth before LLM call
        # ------------------------------------------------------------------
        det_conflict = snapshot.deterministic_conflict_detected
        det_required = snapshot.total_required_monthly_contribution
        det_available = snapshot.available_monthly_amount
        det_gap = snapshot.monthly_capacity_gap

        # No-conflict fast path: generate a simple no-conflict result
        # We still call the LLM for the human-readable summary, but
        # guardrails will enforce conflict_detected = False.

        # ------------------------------------------------------------------
        # 2. Build prompt and call local Ollama
        # ------------------------------------------------------------------
        user_prompt = build_conflict_user_prompt(snapshot)
        raw_output = self.llm_client.generate_json(
            system_prompt=CONFLICT_AGENT_SYSTEM_PROMPT,
            user_prompt=user_prompt,
            temperature=0.0,
        )

        # ------------------------------------------------------------------
        # 3. Parse and validate with Pydantic
        # ------------------------------------------------------------------
        result = ConflictAgentResult.model_validate(raw_output)

        # ------------------------------------------------------------------
        # 4. Deterministic guardrails — engine is authoritative
        # ------------------------------------------------------------------

        # 4a. conflict_detected must match deterministic result
        result.conflict_detected = det_conflict

        # 4b. overall_status must be consistent
        result.overall_status = (
            OverallStatus.CONFLICT if det_conflict else OverallStatus.NO_CONFLICT
        )

        # 4c. If no conflict detected, clear any hallucinated conflicts
        if not det_conflict:
            result.conflicts = []
            result.conflict_count = 0
            return result

        # 4d. For each conflict record returned by LLM, overwrite deterministic
        #     amounts to prevent hallucinated numbers
        for record in result.conflicts:
            if record.conflict_type == ConflictType.CAPACITY_CONFLICT:
                record.deterministic_required_amount = round(det_required, 2)
                record.deterministic_available_amount = round(det_available, 2)
                record.deterministic_gap = round(det_gap, 2)
                # Affected goals must be the actual active goal names
                active_names = [g.goal_name for g in snapshot.active_goals]
                if not record.affected_goals:
                    record.affected_goals = active_names

        # 4e. If LLM claimed no conflicts but we detect them, build a minimal
        #     deterministic conflict record so the output is never empty
        if det_conflict and not result.conflicts:
            result.conflicts = self._build_deterministic_conflicts(snapshot)

        result.conflict_count = len(result.conflicts)
        return result

    # ------------------------------------------------------------------
    # Deterministic fallback conflict builder (when LLM returns empty)
    # ------------------------------------------------------------------

    def _build_deterministic_conflicts(
        self, snapshot: ConflictAgentInput
    ) -> list[ConflictRecord]:
        """Generates minimal deterministic ConflictRecord list as a guardrail fallback."""
        records: list[ConflictRecord] = []

        if snapshot.has_financial_state_conflict:
            records.append(ConflictRecord(
                conflict_type=ConflictType.FINANCIAL_STATE_CONFLICT,
                severity=ConflictSeverity.CRITICAL,
                title="Negative monthly surplus with active goal obligations",
                description=(
                    f"Monthly surplus is {snapshot.monthly_surplus:.2f}, which is negative. "
                    f"Active goals still require monthly contributions, creating a financial state conflict."
                ),
                affected_goals=[g.goal_name for g in snapshot.active_goals],
                deterministic_required_amount=round(snapshot.total_required_monthly_contribution, 2),
                deterministic_available_amount=round(snapshot.available_monthly_amount, 2),
                deterministic_gap=round(snapshot.monthly_capacity_gap, 2),
            ))

        if snapshot.has_capacity_conflict:
            active_names = [g.goal_name for g in snapshot.active_goals]
            severity = ConflictSeverity.HIGH
            gap_ratio = snapshot.monthly_capacity_gap / max(1.0, snapshot.available_monthly_amount)
            if gap_ratio >= 0.5:
                severity = ConflictSeverity.CRITICAL
            elif gap_ratio <= 0.15:
                severity = ConflictSeverity.MEDIUM
            records.append(ConflictRecord(
                conflict_type=ConflictType.CAPACITY_CONFLICT,
                severity=severity,
                title="Combined goal contributions exceed available monthly capacity",
                description=(
                    f"Active goals collectively require {snapshot.total_required_monthly_contribution:.2f}/month, "
                    f"but only {snapshot.available_monthly_amount:.2f} is available. "
                    f"Monthly shortfall: {snapshot.monthly_capacity_gap:.2f}."
                ),
                affected_goals=active_names,
                deterministic_required_amount=round(snapshot.total_required_monthly_contribution, 2),
                deterministic_available_amount=round(snapshot.available_monthly_amount, 2),
                deterministic_gap=round(snapshot.monthly_capacity_gap, 2),
            ))

        if snapshot.has_feasibility_conflict:
            infeasible_names = [g.goal_name for g in snapshot.infeasible_goals]
            records.append(ConflictRecord(
                conflict_type=ConflictType.GOAL_FEASIBILITY_CONFLICT,
                severity=ConflictSeverity.HIGH,
                title="One or more goals are individually infeasible",
                description=(
                    f"The following goals are off-track or infeasible under current financial conditions: "
                    f"{infeasible_names}."
                ),
                affected_goals=infeasible_names,
            ))

        return records
