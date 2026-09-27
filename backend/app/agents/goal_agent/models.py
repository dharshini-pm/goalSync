"""Pydantic data models and schemas for the GoalSync Goal Agent."""

from enum import Enum
from typing import Any, ClassVar, Dict, List, Optional
from pydantic import BaseModel, ConfigDict, Field, field_validator


class GoalStatus(str, Enum):
    ON_TRACK = "ON_TRACK"
    AT_RISK = "AT_RISK"
    OFF_TRACK = "OFF_TRACK"
    COMPLETED = "COMPLETED"
    OVERDUE = "OVERDUE"


class GoalFeasibility(str, Enum):
    COMFORTABLE = "COMFORTABLE"
    FEASIBLE = "FEASIBLE"
    TIGHT = "TIGHT"
    INFEASIBLE = "INFEASIBLE"
    ACHIEVED = "ACHIEVED"
    OVERDUE = "OVERDUE"


class AgentConfidence(str, Enum):
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"


class GoalAgentInput(BaseModel):
    """Structured deterministic goal snapshot consumed by the Goal Agent.

    All numerical values are pre-calculated by the deterministic GoalFeasibilityEngine.
    The Goal Agent must NEVER recalculate these values — it only interprets them.
    """

    # Goal identity
    goal_name: str = Field(..., min_length=1, description="Name of the goal")
    goal_category: Optional[str] = Field(default=None, description="Category (e.g. Emergency Fund, Vacation, Education)")
    priority: Optional[str] = Field(default=None, description="Goal priority: high, medium, low")

    # Financial targets (from Goal Feasibility Engine — immutable facts)
    target_amount: float = Field(..., ge=0.0, description="Target amount to achieve")
    current_amount: float = Field(default=0.0, ge=0.0, description="Amount accumulated so far")
    remaining_amount: float = Field(default=0.0, ge=0.0, description="Amount still needed (pre-calculated)")
    target_date: Optional[str] = Field(default=None, description="Target date string (ISO 8601 or human-readable)")

    # Time horizon (from Goal Feasibility Engine)
    months_remaining: int = Field(default=0, ge=0, description="Months remaining until target date")
    days_remaining: int = Field(default=0, description="Calendar days remaining until target date")

    # Contribution analysis (from Goal Feasibility Engine)
    required_monthly_contribution: float = Field(default=0.0, ge=0.0, description="Required monthly contribution to meet goal")
    available_monthly_amount: float = Field(default=0.0, ge=0.0, description="Available monthly capacity from financial state")
    monthly_shortfall: float = Field(default=0.0, ge=0.0, description="Shortfall = required - available (0 if feasible)")
    surplus_coverage_ratio: float = Field(default=0.0, ge=0.0, description="available_surplus / required_monthly (>1 = feasible)")

    # Feasibility engine outputs
    feasibility_status: str = Field(..., description="Deterministic feasibility status from engine")
    feasibility_score: float = Field(default=0.0, ge=0.0, le=100.0, description="Score 0–100 from feasibility engine")
    feasibility_reason: Optional[str] = Field(default=None, description="Reason string from GoalFeasibilityEngine")

    # Supplementary context
    is_achievable_without_savings: bool = Field(default=False)
    is_achievable_with_savings: bool = Field(default=False)
    current_savings: float = Field(default=0.0, ge=0.0, description="User's total liquid savings for cushion calculation")
    monthly_surplus: float = Field(default=0.0, description="Monthly surplus from Financial State Engine")
    metadata: Optional[Dict[str, Any]] = Field(default=None, description="Additional context from engine")

    model_config = ConfigDict(extra="forbid")

    @property
    def deterministic_goal_status(self) -> GoalStatus:
        """Classifies the goal status deterministically from engine output fields."""
        status_lower = self.feasibility_status.lower()

        # Achieved / completed
        if status_lower in ("achieved", "completed") or self.remaining_amount <= 0:
            return GoalStatus.COMPLETED

        # Overdue
        if status_lower == "overdue" or self.days_remaining < 0:
            return GoalStatus.OVERDUE

        # Comfortable or standard feasible
        if status_lower in ("comfortable", "feasible") and self.is_achievable_without_savings:
            return GoalStatus.ON_TRACK

        # Tight — achievable but only with savings cushion
        if status_lower == "tight" and self.is_achievable_with_savings:
            return GoalStatus.AT_RISK

        return GoalStatus.OFF_TRACK

    @property
    def deterministic_feasibility(self) -> GoalFeasibility:
        """Maps raw engine feasibility status to GoalFeasibility enum."""
        status_lower = self.feasibility_status.lower()
        mapping = {
            "comfortable": GoalFeasibility.COMFORTABLE,
            "feasible": GoalFeasibility.FEASIBLE,
            "tight": GoalFeasibility.TIGHT,
            "unfeasible": GoalFeasibility.INFEASIBLE,
            "infeasible": GoalFeasibility.INFEASIBLE,
            "achieved": GoalFeasibility.ACHIEVED,
            "overdue": GoalFeasibility.OVERDUE,
        }
        return mapping.get(status_lower, GoalFeasibility.INFEASIBLE)


class GoalAgentResult(BaseModel):
    """Strict structured result returned by the Goal Agent."""

    goal_name: str = Field(..., description="Goal name (must match input)")
    goal_status: GoalStatus = Field(..., description="ON_TRACK | AT_RISK | OFF_TRACK | COMPLETED | OVERDUE")
    feasibility: GoalFeasibility = Field(..., description="COMFORTABLE | FEASIBLE | TIGHT | INFEASIBLE | ACHIEVED | OVERDUE")
    summary: str = Field(..., min_length=1, description="Factual interpretation of the goal's current state")
    key_signals: List[str] = Field(default_factory=list, description="Notable deterministic facts about the goal")
    concerns: List[str] = Field(default_factory=list, description="Factual concerns or risks about the goal")
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
        "you ought to borrow",
        "open an account",
        "purchase insurance",
        "sell your",
    ]

    model_config = ConfigDict(extra="ignore")

    @field_validator("summary")
    @classmethod
    def validate_summary_no_advice(cls, v: str) -> str:
        text_lower = v.lower()
        for phrase in cls.FORBIDDEN_PHRASES:
            if phrase in text_lower:
                raise ValueError(
                    f"Goal Agent summary violated safety policy: forbidden phrase '{phrase}' detected"
                )
        return v

    @field_validator("concerns", "key_signals")
    @classmethod
    def validate_lists_no_advice(cls, v: List[str]) -> List[str]:
        for item in v:
            item_lower = item.lower()
            for phrase in GoalAgentResult.FORBIDDEN_PHRASES:
                if phrase in item_lower:
                    raise ValueError(
                        f"Goal Agent item violated safety policy: forbidden phrase '{phrase}' detected"
                    )
        return v
