"""Pydantic data models for the GoalSync Explanation Agent.

The Explanation Agent is a read-only interpretation layer.
It never recalculates financial values — it only explains them.
"""

from __future__ import annotations

from typing import ClassVar, Dict, List, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


# ---------------------------------------------------------------------------
# Sub-models: condensed snapshots of previous agents' outputs
# ---------------------------------------------------------------------------

class GoalExplanationSnapshot(BaseModel):
    """Single goal as received from Goal Agent output."""
    goal_name: str = Field(..., min_length=1)
    goal_category: Optional[str] = Field(default=None)
    target_amount: float = Field(default=0.0, ge=0.0)
    current_amount: float = Field(default=0.0, ge=0.0)
    target_date: Optional[str] = Field(default=None)
    priority: Optional[str] = Field(default=None)
    required_monthly_contribution: float = Field(default=0.0, ge=0.0)
    remaining_amount: float = Field(default=0.0, ge=0.0)
    goal_status: str = Field(default="ON_TRACK")
    feasibility: str = Field(default="FEASIBLE")
    model_config = ConfigDict(extra="ignore")

    @property
    def is_completed(self) -> bool:
        return (
            self.goal_status.lower() in ("completed",)
            or self.feasibility.lower() in ("achieved",)
            or self.remaining_amount <= 0
        )


class ConflictExplanationSnapshot(BaseModel):
    """Single conflict record from Conflict Agent output."""
    conflict_type: str = Field(default="CAPACITY_CONFLICT")
    severity: str = Field(default="HIGH")
    title: str = Field(default="")
    description: str = Field(default="")
    affected_goals: List[str] = Field(default_factory=list)
    deterministic_required_amount: Optional[float] = Field(default=None)
    deterministic_available_amount: Optional[float] = Field(default=None)
    deterministic_gap: Optional[float] = Field(default=None)
    model_config = ConfigDict(extra="ignore")


class ScenarioExplanationSnapshot(BaseModel):
    """Single scenario record from Scenario Agent output."""
    scenario_id: str = Field(default="S1")
    scenario_type: str = Field(default="TIMELINE_ADJUSTMENT")
    title: str = Field(default="")
    assumptions: List[str] = Field(default_factory=list)
    affected_goals: List[str] = Field(default_factory=list)
    original_monthly_requirement: float = Field(default=0.0, ge=0.0)
    scenario_monthly_requirement: float = Field(default=0.0, ge=0.0)
    monthly_capacity: float = Field(default=0.0, ge=0.0)
    capacity_gap: float = Field(default=0.0, ge=0.0)
    projected_goal_status: str = Field(default="ON_TRACK")
    description: str = Field(default="")
    model_config = ConfigDict(extra="ignore")


# ---------------------------------------------------------------------------
# Main input model
# ---------------------------------------------------------------------------

class ExplanationAgentInput(BaseModel):
    """All deterministic intelligence outputs consumed by the Explanation Agent.

    Every numerical value here is authoritative — computed by the
    FinancialStateEngine, GoalFeasibilityEngine, or a previous agent.
    The Explanation Agent must NEVER recalculate any of these values.
    """

    # Financial state (from FinancialStateAgent)
    monthly_income: float = Field(..., ge=0.0)
    monthly_expenses: float = Field(..., ge=0.0)
    monthly_surplus: float = Field(..., description="Can be negative")
    available_monthly_amount: float = Field(..., ge=0.0)
    current_savings: float = Field(default=0.0, ge=0.0)
    total_emi: float = Field(default=0.0, ge=0.0)
    savings_rate: float = Field(default=0.0)

    # Financial state interpretation (from FinancialStateAgent)
    financial_status: str = Field(default="STABLE")
    cash_flow_status: str = Field(default="POSITIVE")
    key_signals: List[str] = Field(default_factory=list)
    concerns: List[str] = Field(default_factory=list)

    # Goals (from GoalAgent)
    goals: List[GoalExplanationSnapshot] = Field(default_factory=list)

    # Conflict information (from ConflictAgent)
    conflict_detected: bool = Field(default=False)
    conflict_count: int = Field(default=0, ge=0)
    overall_conflict_status: str = Field(default="NO_CONFLICT")
    conflicts: List[ConflictExplanationSnapshot] = Field(default_factory=list)

    # Scenario information (from ScenarioAgent)
    scenario_required: bool = Field(default=False)
    scenario_count: int = Field(default=0, ge=0)
    scenarios: List[ScenarioExplanationSnapshot] = Field(default_factory=list)

    model_config = ConfigDict(extra="forbid")

    @property
    def active_goals(self) -> List[GoalExplanationSnapshot]:
        return [g for g in self.goals if not g.is_completed]

    @property
    def completed_goals(self) -> List[GoalExplanationSnapshot]:
        return [g for g in self.goals if g.is_completed]

    @property
    def total_required_monthly(self) -> float:
        return sum(g.required_monthly_contribution for g in self.active_goals)

    @property
    def capacity_gap(self) -> float:
        return max(0.0, self.total_required_monthly - self.available_monthly_amount)


# ---------------------------------------------------------------------------
# Output sub-models
# ---------------------------------------------------------------------------

class GoalImpactExplanation(BaseModel):
    """Per-goal explanation from the Explanation Agent."""
    goal_name: str = Field(..., min_length=1)
    explanation: str = Field(..., min_length=1)
    status: str = Field(default="ON_TRACK")
    model_config = ConfigDict(extra="ignore")


class ConflictExplanationOutput(BaseModel):
    """Conflict explanation block."""
    detected: bool = Field(...)
    explanation: str = Field(..., min_length=1)
    model_config = ConfigDict(extra="ignore")


class ScenarioExplanationOutput(BaseModel):
    """Per-scenario explanation."""
    scenario_id: str = Field(...)
    explanation: str = Field(..., min_length=1)
    model_config = ConfigDict(extra="ignore")


# ---------------------------------------------------------------------------
# Main output model
# ---------------------------------------------------------------------------

class ExplanationAgentResult(BaseModel):
    """Strict structured result returned by the Explanation Agent."""

    headline: str = Field(..., min_length=1, description="Single-sentence summary for the user")
    summary: str = Field(..., min_length=1)
    key_points: List[str] = Field(default_factory=list)
    goal_impacts: List[GoalImpactExplanation] = Field(default_factory=list)
    conflict_explanation: ConflictExplanationOutput = Field(...)
    scenario_explanations: List[ScenarioExplanationOutput] = Field(default_factory=list)
    assumptions: List[str] = Field(default_factory=list)
    confidence: str = Field(default="high")
    needs_clarification: bool = Field(default=False)

    FORBIDDEN_PHRASES: ClassVar[List[str]] = [
        "you should",
        "you must",
        "i recommend",
        "best option",
        "best scenario",
        "choose scenario",
        "select scenario",
        "pick scenario",
        "choose this",
        "select this",
        "i suggest",
        "take out a loan",
        "take a loan",
        "borrow money",
        "buy stocks",
        "invest in",
        "mutual fund",
        "cryptocurrency",
        "crypto",
        "financial advice",
        "financial product",
        "cancel the goal",
        "cancel goal",
        "reduce goal",
        "stop funding",
        "stop the goal",
        "cut your spending",
        "cut expenses",
        "reduce your spending",
        "sell your",
        "open an account",
        "purchase insurance",
        "this is bad",
        "wrong goal",
        "bad goal",
    ]

    model_config = ConfigDict(extra="ignore")

    def _check_text(self, text: str, context: str) -> None:
        t = text.lower()
        for phrase in self.FORBIDDEN_PHRASES:
            if phrase in t:
                raise ValueError(
                    f"Explanation Agent output violated safety policy in {context}: "
                    f"forbidden phrase '{phrase}' detected"
                )

    @field_validator("headline", "summary")
    @classmethod
    def validate_top_level_text(cls, v: str) -> str:
        v_lower = v.lower()
        for phrase in cls.FORBIDDEN_PHRASES:
            if phrase in v_lower:
                raise ValueError(
                    f"Explanation Agent output violated safety policy: "
                    f"forbidden phrase '{phrase}' detected"
                )
        return v

    @field_validator("key_points", "assumptions")
    @classmethod
    def validate_lists_no_advice(cls, v: List[str]) -> List[str]:
        for item in v:
            item_lower = item.lower()
            for phrase in cls.FORBIDDEN_PHRASES:
                if phrase in item_lower:
                    raise ValueError(
                        f"Explanation Agent output violated safety policy: "
                        f"forbidden phrase '{phrase}' detected in list item"
                    )
        return v
