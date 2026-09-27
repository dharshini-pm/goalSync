"""Pydantic data models and schemas for the GoalSync Financial State Agent."""

from enum import Enum
from typing import List, Optional, ClassVar
from pydantic import BaseModel, Field, ConfigDict, field_validator


class FinancialStatus(str, Enum):
    STABLE = "STABLE"
    TIGHT = "TIGHT"
    STRAINED = "STRAINED"
    NEGATIVE = "NEGATIVE"


class CashFlowStatus(str, Enum):
    POSITIVE = "POSITIVE"
    NEUTRAL = "NEUTRAL"
    NEGATIVE = "NEGATIVE"


class AgentConfidence(str, Enum):
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"


class FinancialStateAgentInput(BaseModel):
    """Structured deterministic financial snapshot consumed by the Financial State Agent.

    Values are calculated upstream by the deterministic Financial State Engine.
    The agent receives already-calculated values and must never recalculate them.
    """

    monthly_income: float = Field(..., ge=0.0, description="Total monthly income from all sources")
    monthly_expenses: float = Field(..., ge=0.0, description="Total monthly expenses including fixed, variable, and EMI")
    monthly_surplus: float = Field(..., description="Income minus expenses; can be negative (deficit)")
    savings_rate: float = Field(..., ge=0.0, description="Percentage of income saved (0.0 if in deficit)")
    total_emi: float = Field(default=0.0, ge=0.0, description="Total monthly loan/EMI debt payments")
    available_monthly_amount: float = Field(default=0.0, ge=0.0, description="Uncommitted surplus available for goals")
    current_savings: float = Field(default=0.0, ge=0.0, description="Total accumulated liquid savings/emergency fund")
    transaction_inflow: Optional[float] = Field(default=None, ge=0.0, description="Sum of recent transaction credits")
    transaction_outflow: Optional[float] = Field(default=None, ge=0.0, description="Sum of recent transaction debits")

    # Optional pre-calculated deterministic ratios
    debt_to_income_ratio: Optional[float] = Field(default=None, ge=0.0)
    expense_to_income_ratio: Optional[float] = Field(default=None, ge=0.0)
    emergency_fund_months: Optional[float] = Field(default=None, ge=0.0)

    model_config = ConfigDict(extra="forbid")

    @property
    def deterministic_cash_flow_status(self) -> CashFlowStatus:
        """Determines cash flow status deterministically from surplus."""
        if self.monthly_surplus > 0.0001:
            return CashFlowStatus.POSITIVE
        elif self.monthly_surplus < -0.0001:
            return CashFlowStatus.NEGATIVE
        return CashFlowStatus.NEUTRAL

    @property
    def deterministic_financial_status(self) -> FinancialStatus:
        """Classifies the financial state using strict deterministic thresholds."""
        if self.monthly_surplus < 0.0:
            return FinancialStatus.NEGATIVE

        # Calculate debt to income ratio if not pre-provided
        dti = self.debt_to_income_ratio
        if dti is None:
            dti = (self.total_emi / self.monthly_income) if self.monthly_income > 0 else 0.0

        # High debt or severe lack of surplus
        if dti > 0.40 or (self.savings_rate < 10.0 and self.monthly_surplus < 5000.0):
            return FinancialStatus.STRAINED

        # Modest surplus or low savings cushion
        if self.savings_rate < 20.0 or self.available_monthly_amount < 5000.0:
            return FinancialStatus.TIGHT

        return FinancialStatus.STABLE


class FinancialStateAgentResult(BaseModel):
    """Strict structured result returned by the Financial State Agent."""

    financial_status: FinancialStatus = Field(..., description="Overall health classification: STABLE, TIGHT, STRAINED, NEGATIVE")
    cash_flow_status: CashFlowStatus = Field(..., description="Cash flow classification: POSITIVE, NEUTRAL, NEGATIVE")
    summary: str = Field(..., min_length=1, description="Factual interpretation of the financial snapshot")
    key_signals: List[str] = Field(default_factory=list, description="List of notable financial facts and indicators")
    concerns: List[str] = Field(default_factory=list, description="Identified financial risks or concerns")
    confidence: AgentConfidence = Field(default=AgentConfidence.HIGH, description="Confidence level: high, medium, low")
    needs_clarification: bool = Field(default=False, description="Whether additional clarification or data is needed")

    FORBIDDEN_RECOMMENDATION_PHRASES: ClassVar[List[str]] = [
        "you should invest",
        "you should buy",
        "you should cut",
        "i recommend investing",
        "i recommend buying",
        "buy stocks",
        "crypto",
        "take a loan",
        "financial advice",
        "financial product",
        "you ought to spend",
        "open an account",
    ]

    model_config = ConfigDict(extra="ignore")

    @field_validator("summary")
    @classmethod
    def validate_no_financial_advice(cls, v: str) -> str:
        text_lower = v.lower()
        for phrase in cls.FORBIDDEN_RECOMMENDATION_PHRASES:
            if phrase in text_lower:
                raise ValueError(
                    f"Agent summary violated safety policy: contained forbidden advice phrase '{phrase}'"
                )
        return v

    @field_validator("concerns", "key_signals")
    @classmethod
    def validate_list_no_financial_advice(cls, v: List[str]) -> List[str]:
        for item in v:
            item_lower = item.lower()
            for phrase in cls.FORBIDDEN_RECOMMENDATION_PHRASES:
                if phrase in item_lower:
                    raise ValueError(
                        f"Agent item violated safety policy: contained forbidden advice phrase '{phrase}'"
                    )
        return v
