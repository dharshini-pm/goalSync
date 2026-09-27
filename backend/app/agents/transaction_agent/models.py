"""Data models and validation contracts for the GoalSync Transaction Agent."""

from dataclasses import dataclass
from enum import Enum
from typing import Optional, Dict, Any, List, ClassVar, Set


class AgentConfidence(str, Enum):
    HIGH = "high"
    MEDIUM = "medium"
    LOW = "low"


class TransactionTypeCategory(str, Enum):
    EXPENSE = "Expense"
    INCOME = "Income"
    TRANSFER = "Transfer"
    INVESTMENT = "Investment"
    REFUND = "Refund"
    UNKNOWN = "Unknown"


@dataclass
class TransactionAgentInput:
    """Structured input contract received by the Transaction Agent.

    The agent receives already-parsed, structured data. Raw database objects
    or unparsed strings must be transformed prior to agent invocation.
    """

    merchant: str
    amount: float
    transaction_type: str
    payment_method: Optional[str] = None
    date: Optional[str] = None
    deterministic_category: Optional[str] = None
    merchant_rag_result: Optional[str] = None
    merchant_rag_confidence: Optional[str] = None

    def __post_init__(self) -> None:
        """Validates input invariants."""
        if not isinstance(self.merchant, str) or not self.merchant.strip():
            raise ValueError("TransactionAgentInput 'merchant' must be a non-empty string.")

        if not isinstance(self.amount, (int, float)) or self.amount < 0:
            raise ValueError("TransactionAgentInput 'amount' must be a non-negative number.")

        if not isinstance(self.transaction_type, str) or not self.transaction_type.strip():
            raise ValueError("TransactionAgentInput 'transaction_type' must be a non-empty string.")

    @property
    def has_rag_evidence(self) -> bool:
        """Returns True if confident RAG knowledge accompanied this input."""
        return bool(
            self.merchant_rag_result
            and self.merchant_rag_confidence
            and self.merchant_rag_confidence.upper() in ["EXACT", "ALIAS", "SEMANTIC"]
        )


@dataclass
class TransactionAgentResult:
    """Strict structured result returned by the Transaction Agent.

    Represents AI reasoning over a transaction without financial advice or
    modifying underlying financial state.
    """

    merchant_name: str
    category: str
    transaction_type: str
    summary: str
    reasoning: str
    confidence: str
    needs_clarification: bool

    REQUIRED_FIELDS: ClassVar[Set[str]] = {
        "merchant_name",
        "category",
        "transaction_type",
        "summary",
        "reasoning",
        "confidence",
        "needs_clarification",
    }

    FORBIDDEN_RECOMMENDATION_PHRASES: ClassVar[List[str]] = [
        "you should save",
        "you should cut",
        "you ought to",
        "i recommend saving",
        "financial advice",
        "budget reduction",
        "goal feasibility is",
        "your goal will fail",
        "you cannot afford",
    ]

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "TransactionAgentResult":
        """Parses and strictly validates raw dictionary output from the LLM."""
        if not isinstance(data, dict):
            raise ValueError(f"Expected dict from LLM response, got {type(data).__name__}")

        missing = cls.REQUIRED_FIELDS - set(data.keys())
        if missing:
            raise ValueError(f"Missing required fields in TransactionAgentResult: {sorted(missing)}")

        merchant_name = str(data["merchant_name"]).strip()
        category = str(data["category"]).strip()
        transaction_type = str(data["transaction_type"]).strip()
        summary = str(data["summary"]).strip()
        reasoning = str(data["reasoning"]).strip()
        confidence = str(data["confidence"]).strip().lower()
        needs_clarification_raw = data["needs_clarification"]
        if isinstance(needs_clarification_raw, bool):
            needs_clarification = needs_clarification_raw
        elif isinstance(needs_clarification_raw, str):
            val_clean = needs_clarification_raw.strip().lower()
            if val_clean in ("true", "1", "yes"):
                needs_clarification = True
            elif val_clean in ("false", "0", "no"):
                needs_clarification = False
            else:
                raise ValueError(
                    f"Cannot parse 'needs_clarification' boolean from string: '{needs_clarification_raw}'"
                )
        else:
            raise ValueError(
                f"'needs_clarification' must be a boolean, got {type(needs_clarification_raw).__name__}"
            )

        if confidence not in {"high", "medium", "low"}:
            raise ValueError(f"Invalid confidence '{confidence}'. Must be one of: 'high', 'medium', 'low'")

        if not merchant_name:
            merchant_name = "Unknown"

        if not category:
            category = "Other"

        # Check that the reasoning does not overstep into financial advice/recommendations
        combined_text = f"{summary} {reasoning}".lower()
        for phrase in cls.FORBIDDEN_RECOMMENDATION_PHRASES:
            if phrase in combined_text:
                raise ValueError(
                    f"Agent output violated financial recommendation boundary: contained forbidden phrase '{phrase}'"
                )

        return cls(
            merchant_name=merchant_name,
            category=category,
            transaction_type=transaction_type,
            summary=summary,
            reasoning=reasoning,
            confidence=confidence,
            needs_clarification=needs_clarification,
        )

    def to_dict(self) -> Dict[str, Any]:
        """Serializes result into standard dictionary format."""
        return {
            "merchant_name": self.merchant_name,
            "category": self.category,
            "transaction_type": self.transaction_type,
            "summary": self.summary,
            "reasoning": self.reasoning,
            "confidence": self.confidence,
            "needs_clarification": self.needs_clarification,
        }
