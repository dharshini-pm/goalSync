"""Pydantic data models for the GoalSync Scenario Agent.

All numerical values in scenarios are produced by deterministic calculations,
not by the LLM. The LLM only adds human-readable descriptions and assumptions.
"""

from __future__ import annotations

from datetime import date, datetime
from enum import Enum
from typing import ClassVar, List, Optional

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

class ScenarioType(str, Enum):
    TIMELINE_ADJUSTMENT = "TIMELINE_ADJUSTMENT"
    CONTRIBUTION_REALLOCATION = "CONTRIBUTION_REALLOCATION"
    SINGLE_GOAL_FOCUS = "SINGLE_GOAL_FOCUS"
    CAPACITY_CHANGE = "CAPACITY_CHANGE"


class ProjectedGoalStatus(str, Enum):
    ON_TRACK = "ON_TRACK"
    AT_RISK = "AT_RISK"
    OFF_TRACK = "OFF_TRACK"
    COMPLETED = "COMPLETED"


class AgentConfidence(str, Enum):
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"


# ---------------------------------------------------------------------------
# Conflict snapshot passed from the Conflict Agent output
# ---------------------------------------------------------------------------

class ConflictSummary(BaseModel):
    """A summarised conflict record passed from the Conflict Agent output."""

    conflict_type: str = Field(default="CAPACITY_CONFLICT")
    severity: str = Field(default="HIGH")
    title: str = Field(default="")
    description: str = Field(default="")
    affected_goals: List[str] = Field(default_factory=list)
    deterministic_required_amount: Optional[float] = Field(default=None)
    deterministic_available_amount: Optional[float] = Field(default=None)
    deterministic_gap: Optional[float] = Field(default=None)

    model_config = ConfigDict(extra="ignore")


# ---------------------------------------------------------------------------
# Goal snapshot within the scenario input
# ---------------------------------------------------------------------------

class GoalScenarioSnapshot(BaseModel):
    """A single goal deterministic snapshot consumed by the Scenario Agent."""

    goal_name: str = Field(..., min_length=1)
    goal_category: Optional[str] = Field(default=None)
    target_amount: float = Field(..., ge=0.0)
    current_amount: float = Field(default=0.0, ge=0.0)
    target_date: Optional[str] = Field(
        default=None,
        description="ISO-8601 date string YYYY-MM-DD, or None if open-ended",
    )
    priority: Optional[str] = Field(default=None)
    required_monthly_contribution: float = Field(default=0.0, ge=0.0)
    remaining_amount: float = Field(default=0.0, ge=0.0)
    goal_status: str = Field(default="ON_TRACK")
    feasibility: str = Field(default="FEASIBLE")

    model_config = ConfigDict(extra="forbid")

    @property
    def is_completed(self) -> bool:
        return (
            self.goal_status.lower() in ("completed",)
            or self.feasibility.lower() in ("achieved",)
            or self.remaining_amount <= 0
        )

    @property
    def is_active(self) -> bool:
        return not self.is_completed

    def months_remaining_from(self, reference: Optional[date] = None) -> Optional[int]:
        """Return integer months remaining from reference date to target_date.

        Returns None if target_date is absent or unparseable.
        Returns 0 if target_date is in the past or today.
        Minimum 1 when future to prevent division-by-zero.
        """
        if not self.target_date:
            return None
        try:
            target = datetime.strptime(self.target_date[:10], "%Y-%m-%d").date()
        except (ValueError, TypeError):
            return None
        ref = reference or date.today()
        if target <= ref:
            return 0
        delta_months = (target.year - ref.year) * 12 + (target.month - ref.month)
        if target.day >= ref.day:
            delta_months = max(delta_months, 1)
        return max(delta_months, 1)

    def deterministic_contribution_for_months(self, months: int) -> float:
        """Compute required monthly contribution for a given number of months."""
        if months <= 0 or self.remaining_amount <= 0:
            return 0.0
        return round(self.remaining_amount / months, 2)


# ---------------------------------------------------------------------------
# Main input model
# ---------------------------------------------------------------------------

class ScenarioAgentInput(BaseModel):
    """Deterministic financial state + goals + conflict data for the Scenario Agent.

    All numerical values must originate from GoalFeasibilityEngine and FinancialStateEngine.
    The Scenario Agent must NEVER recalculate feasibility or conflict detection itself.
    """

    # Financial state (from FinancialStateEngine)
    monthly_income: float = Field(..., ge=0.0)
    monthly_expenses: float = Field(..., ge=0.0)
    monthly_surplus: float = Field(..., description="Income minus expenses (can be negative)")
    available_monthly_amount: float = Field(..., ge=0.0)
    current_savings: float = Field(default=0.0, ge=0.0)
    total_emi: float = Field(default=0.0, ge=0.0)
    savings_rate: float = Field(default=0.0)

    # Goals (from GoalFeasibilityEngine outputs)
    goals: List[GoalScenarioSnapshot] = Field(default_factory=list)

    # Conflict information (from Conflict Agent output)
    conflict_detected: bool = Field(default=False)
    conflict_count: int = Field(default=0, ge=0)
    overall_status: str = Field(default="NO_CONFLICT")
    conflicts: List[ConflictSummary] = Field(default_factory=list)

    model_config = ConfigDict(extra="forbid")

    @property
    def active_goals(self) -> List[GoalScenarioSnapshot]:
        """Goals that are not completed and still need contributions."""
        return [g for g in self.goals if g.is_active]

    @property
    def total_required_monthly_contribution(self) -> float:
        """Sum of required monthly contributions across all active goals."""
        return sum(g.required_monthly_contribution for g in self.active_goals)

    @property
    def monthly_capacity_gap(self) -> float:
        """Positive value = shortfall. Zero or negative = no shortfall."""
        return max(0.0, self.total_required_monthly_contribution - self.available_monthly_amount)

    @property
    def has_capacity_shortfall(self) -> bool:
        return self.total_required_monthly_contribution > self.available_monthly_amount

    @property
    def scenario_generation_required(self) -> bool:
        """Scenarios are only required when a conflict has been detected."""
        return self.conflict_detected


# ---------------------------------------------------------------------------
# Individual scenario record in output
# ---------------------------------------------------------------------------

class ScenarioRecord(BaseModel):
    """A single what-if scenario with its assumptions and deterministic outcomes."""

    scenario_id: str = Field(..., description="Short identifier e.g. 'S1'")
    scenario_type: ScenarioType
    title: str = Field(..., min_length=1)
    assumptions: List[str] = Field(default_factory=list)
    affected_goals: List[str] = Field(default_factory=list)

    # Deterministic financial values (LLM cannot alter these)
    original_monthly_requirement: float = Field(default=0.0, ge=0.0)
    scenario_monthly_requirement: float = Field(default=0.0, ge=0.0)
    monthly_capacity: float = Field(default=0.0, ge=0.0)
    capacity_gap: float = Field(default=0.0, ge=0.0)
    projected_goal_status: ProjectedGoalStatus = Field(default=ProjectedGoalStatus.ON_TRACK)

    # Human-readable interpretation (LLM-generated, safety-checked)
    description: str = Field(..., min_length=1)

    model_config = ConfigDict(extra="ignore")


# ---------------------------------------------------------------------------
# Output model
# ---------------------------------------------------------------------------

class ScenarioAgentResult(BaseModel):
    """Strict structured result returned by the Scenario Agent."""

    scenario_required: bool = Field(...)
    scenario_count: int = Field(default=0, ge=0)
    scenarios: List[ScenarioRecord] = Field(default_factory=list)
    summary: str = Field(..., min_length=1)
    confidence: AgentConfidence = Field(default=AgentConfidence.HIGH)
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
        "sell your",
        "open an account",
        "purchase insurance",
    ]

    model_config = ConfigDict(extra="ignore")

    @field_validator("summary")
    @classmethod
    def validate_summary_no_advice(cls, v: str) -> str:
        v_lower = v.lower()
        for phrase in cls.FORBIDDEN_PHRASES:
            if phrase in v_lower:
                raise ValueError(
                    f"Scenario Agent summary violated safety policy: "
                    f"forbidden phrase '{phrase}' detected"
                )
        return v

    @field_validator("scenarios")
    @classmethod
    def validate_scenarios_no_advice(cls, v: List[ScenarioRecord]) -> List[ScenarioRecord]:
        for record in v:
            for text in [record.title, record.description] + list(record.assumptions):
                text_lower = text.lower()
                for phrase in ScenarioAgentResult.FORBIDDEN_PHRASES:
                    if phrase in text_lower:
                        raise ValueError(
                            f"Scenario record violated safety policy: "
                            f"forbidden phrase '{phrase}' detected"
                        )
        return v

    @model_validator(mode="after")
    def sync_scenario_count(self) -> "ScenarioAgentResult":
        self.scenario_count = len(self.scenarios)
        return self
