"""Pydantic data models for the GoalSync Conflict Agent."""

from enum import Enum
from typing import Any, ClassVar, Dict, List, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator


# ---------------------------------------------------------------------------
# Enums
# ---------------------------------------------------------------------------

class ConflictType(str, Enum):
    CAPACITY_CONFLICT = "CAPACITY_CONFLICT"
    GOAL_FEASIBILITY_CONFLICT = "GOAL_FEASIBILITY_CONFLICT"
    FINANCIAL_STATE_CONFLICT = "FINANCIAL_STATE_CONFLICT"
    PRIORITY_CONFLICT = "PRIORITY_CONFLICT"


class ConflictSeverity(str, Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"


class OverallStatus(str, Enum):
    NO_CONFLICT = "NO_CONFLICT"
    CONFLICT = "CONFLICT"


class AgentConfidence(str, Enum):
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"


# ---------------------------------------------------------------------------
# Goal snapshot within the conflict input
# ---------------------------------------------------------------------------

class GoalConflictSnapshot(BaseModel):
    """A single goal's deterministic snapshot as consumed by the Conflict Agent."""

    goal_name: str = Field(..., min_length=1)
    goal_category: Optional[str] = Field(default=None)
    priority: Optional[str] = Field(default=None, description="high / medium / low / essential / flexible")
    target_amount: float = Field(..., ge=0.0)
    current_amount: float = Field(default=0.0, ge=0.0)
    remaining_amount: float = Field(default=0.0, ge=0.0)
    target_date: Optional[str] = Field(default=None)
    required_monthly_contribution: float = Field(default=0.0, ge=0.0)
    goal_status: str = Field(default="UNKNOWN", description="ON_TRACK | AT_RISK | OFF_TRACK | COMPLETED | OVERDUE")
    feasibility: str = Field(default="UNKNOWN", description="COMFORTABLE | FEASIBLE | TIGHT | INFEASIBLE | ACHIEVED | OVERDUE")
    is_active: bool = Field(default=True, description="False if COMPLETED or ACHIEVED")

    model_config = ConfigDict(extra="forbid")

    @property
    def is_completed(self) -> bool:
        status_lower = self.goal_status.lower()
        feasibility_lower = self.feasibility.lower()
        return (
            status_lower in ("completed",)
            or feasibility_lower in ("achieved",)
            or self.remaining_amount <= 0
        )

    @property
    def is_off_track_or_infeasible(self) -> bool:
        status_lower = self.goal_status.lower()
        feasibility_lower = self.feasibility.lower()
        return (
            status_lower in ("off_track", "overdue")
            or feasibility_lower in ("infeasible", "unfeasible", "overdue")
        )


# ---------------------------------------------------------------------------
# Main input model
# ---------------------------------------------------------------------------

class ConflictAgentInput(BaseModel):
    """Deterministic financial state + goals snapshot consumed by the Conflict Agent.

    All numerical values must come from the GoalFeasibilityEngine and FinancialStateEngine.
    The Conflict Agent must NEVER recalculate these values — it only detects and explains conflicts.
    """

    # Financial state (from FinancialStateEngine)
    monthly_income: float = Field(..., ge=0.0)
    monthly_expenses: float = Field(..., ge=0.0)
    monthly_surplus: float = Field(..., description="Income minus expenses (can be negative)")
    available_monthly_amount: float = Field(..., ge=0.0, description="Amount available for goal contributions")
    current_savings: float = Field(default=0.0, ge=0.0)
    total_emi: float = Field(default=0.0, ge=0.0)
    savings_rate: float = Field(default=0.0, description="Savings rate as percentage")

    # Goals (from GoalFeasibilityEngine outputs)
    goals: List[GoalConflictSnapshot] = Field(default_factory=list)

    model_config = ConfigDict(extra="forbid")

    # ------------------------------------------------------------------
    # Deterministic computation properties
    # ------------------------------------------------------------------

    @property
    def active_goals(self) -> List[GoalConflictSnapshot]:
        """Goals that still require monthly contributions (not completed)."""
        return [g for g in self.goals if not g.is_completed and g.is_active]

    @property
    def total_required_monthly_contribution(self) -> float:
        """Sum of required monthly contributions across all active goals."""
        return sum(g.required_monthly_contribution for g in self.active_goals)

    @property
    def monthly_capacity_gap(self) -> float:
        """Positive gap = shortfall (conflict). Zero or negative = surplus (no conflict)."""
        return max(0.0, self.total_required_monthly_contribution - self.available_monthly_amount)

    @property
    def has_capacity_conflict(self) -> bool:
        """True when total required contributions exceed available monthly amount."""
        return self.total_required_monthly_contribution > self.available_monthly_amount

    @property
    def has_financial_state_conflict(self) -> bool:
        """True when monthly surplus is negative while active goals need contributions."""
        return self.monthly_surplus < 0 and len(self.active_goals) > 0

    @property
    def infeasible_goals(self) -> List[GoalConflictSnapshot]:
        """Goals that are individually OFF_TRACK or INFEASIBLE."""
        return [g for g in self.active_goals if g.is_off_track_or_infeasible]

    @property
    def has_feasibility_conflict(self) -> bool:
        """True when one or more active goals are infeasible."""
        return len(self.infeasible_goals) > 0

    @property
    def has_priority_conflict(self) -> bool:
        """True when capacity is exceeded and goals have mixed priorities."""
        if not self.has_capacity_conflict:
            return False
        priorities = {(g.priority or "").lower() for g in self.active_goals if g.priority}
        priority_tiers = {"essential", "high", "medium", "low", "flexible"}
        return len(priorities.intersection(priority_tiers)) >= 2

    @property
    def deterministic_conflict_detected(self) -> bool:
        return (
            self.has_capacity_conflict
            or self.has_financial_state_conflict
            or self.has_feasibility_conflict
        )

    @property
    def all_goals_completed(self) -> bool:
        if not self.goals:
            return False
        return all(g.is_completed for g in self.goals)


# ---------------------------------------------------------------------------
# Individual conflict record in output
# ---------------------------------------------------------------------------

class ConflictRecord(BaseModel):
    """A single detected conflict with its deterministic facts and LLM interpretation."""

    conflict_type: ConflictType
    severity: ConflictSeverity
    title: str = Field(..., min_length=1)
    description: str = Field(..., min_length=1)
    affected_goals: List[str] = Field(default_factory=list, description="Names of affected goals")
    deterministic_required_amount: Optional[float] = Field(default=None, ge=0.0)
    deterministic_available_amount: Optional[float] = Field(default=None, ge=0.0)
    deterministic_gap: Optional[float] = Field(default=None, ge=0.0)

    model_config = ConfigDict(extra="ignore")


# ---------------------------------------------------------------------------
# Output model
# ---------------------------------------------------------------------------

class ConflictAgentResult(BaseModel):
    """Strict structured result returned by the Conflict Agent."""

    conflict_detected: bool = Field(..., description="Whether at least one conflict was detected")
    conflict_count: int = Field(default=0, ge=0)
    overall_status: OverallStatus = Field(..., description="NO_CONFLICT | CONFLICT")
    conflicts: List[ConflictRecord] = Field(default_factory=list)
    summary: str = Field(..., min_length=1)
    confidence: AgentConfidence = Field(default=AgentConfidence.HIGH)
    needs_clarification: bool = Field(default=False)

    FORBIDDEN_PHRASES: ClassVar[List[str]] = [
        "you should invest",
        "you should buy",
        "i recommend investing",
        "take out a loan",
        "take a loan",
        "buy stocks",
        "crypto",
        "financial advice",
        "financial product",
        "cancel the goal",
        "cancel goal",
        "reduce the goal",
        "reduce goal",
        "stop funding",
        "stop the goal",
        "borrow money",
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
                    f"Conflict Agent summary violated safety policy: forbidden phrase '{phrase}' detected"
                )
        return v

    @field_validator("conflicts")
    @classmethod
    def validate_conflicts_no_advice(cls, v: List[ConflictRecord]) -> List[ConflictRecord]:
        for record in v:
            for text in [record.title, record.description]:
                text_lower = text.lower()
                for phrase in ConflictAgentResult.FORBIDDEN_PHRASES:
                    if phrase in text_lower:
                        raise ValueError(
                            f"Conflict record violated safety policy: forbidden phrase '{phrase}' detected"
                        )
        return v

    @model_validator(mode="after")
    def validate_consistency(self) -> "ConflictAgentResult":
        """Ensure conflict_count and overall_status are consistent with conflict_detected."""
        if self.conflict_detected:
            if self.overall_status == OverallStatus.NO_CONFLICT:
                self.overall_status = OverallStatus.CONFLICT
        else:
            if self.overall_status == OverallStatus.CONFLICT:
                self.overall_status = OverallStatus.NO_CONFLICT
        self.conflict_count = len(self.conflicts)
        return self
