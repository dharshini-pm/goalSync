"""Data models and enums for the GoalSync SMS Intelligence layer."""

from __future__ import annotations

import hashlib
from enum import Enum
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


class SMSClassification(str, Enum):
    """Broad classification of an incoming SMS message."""
    FINANCIAL_TRANSACTION = "FINANCIAL_TRANSACTION"
    FINANCIAL_NON_TRANSACTION = "FINANCIAL_NON_TRANSACTION"
    NON_FINANCIAL = "NON_FINANCIAL"
    UNKNOWN = "UNKNOWN"


class TransactionType(str, Enum):
    """Direction of money movement."""
    DEBIT = "DEBIT"
    CREDIT = "CREDIT"
    UNKNOWN = "UNKNOWN"


class PaymentMethod(str, Enum):
    """Payment channel detected in the SMS."""
    UPI = "UPI"
    CARD = "CARD"
    ATM = "ATM"
    IMPS = "IMPS"
    NEFT = "NEFT"
    BANK_TRANSFER = "BANK_TRANSFER"
    UNKNOWN = "UNKNOWN"


class ConfidenceLevel(str, Enum):
    """Confidence level of the deterministic extraction."""
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"


class ParsedFinancialSMS(BaseModel):
    """Structured result of deterministic SMS parsing.

    Contains no raw SMS text to protect user privacy.
    """
    classification: SMSClassification
    is_financial: bool = False
    is_transaction: bool = False
    amount: Optional[float] = None
    transaction_type: TransactionType = TransactionType.UNKNOWN
    merchant: Optional[str] = None
    payment_method: PaymentMethod = PaymentMethod.UNKNOWN
    transaction_date: Optional[str] = None
    available_balance: Optional[float] = None
    account_reference: Optional[str] = None
    sender: Optional[str] = None
    confidence: ConfidenceLevel = ConfidenceLevel.LOW
    reasons: List[str] = Field(default_factory=list)
    fingerprint: Optional[str] = None

    def to_dict(self) -> Dict[str, Any]:
        """Serializes the parsed SMS to a dictionary."""
        return {
            "classification": self.classification.value,
            "is_financial": self.is_financial,
            "is_transaction": self.is_transaction,
            "amount": self.amount,
            "transaction_type": self.transaction_type.value,
            "merchant": self.merchant,
            "payment_method": self.payment_method.value,
            "transaction_date": self.transaction_date,
            "available_balance": self.available_balance,
            "account_reference": self.account_reference,
            "sender": self.sender,
            "confidence": self.confidence.value,
            "reasons": list(self.reasons),
            "fingerprint": self.fingerprint,
        }
