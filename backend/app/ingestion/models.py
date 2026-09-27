"""Pydantic data models for SMS ingestion and downstream n8n webhook delivery."""

from __future__ import annotations

from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


class StructuredTransactionEvent(BaseModel):
    """The structured event sent to n8n downstream.

    Guarantees privacy: Contains ONLY structured, extracted financial data.
    Does NOT contain the raw SMS text.
    """
    event_type: str = "financial_transaction"
    source: str = "android_sms"
    fingerprint: str
    amount: Optional[float] = None
    transaction_type: str = "UNKNOWN"
    merchant: Optional[str] = None
    payment_method: str = "UNKNOWN"
    transaction_date: Optional[str] = None
    available_balance: Optional[float] = None
    account_reference: Optional[str] = None
    event_id: Optional[str] = None
    confidence: str = "LOW"
    user_id: Optional[str] = None
    device_id: Optional[str] = None

    def to_n8n_payload(self) -> Dict[str, Any]:
        """Returns the dictionary representation matching the n8n webhook contract."""
        payload: Dict[str, Any] = {
            "event_type": self.event_type,
            "source": self.source,
            "fingerprint": self.fingerprint,
            "amount": self.amount,
            "transaction_type": self.transaction_type,
            "merchant": self.merchant,
            "payment_method": self.payment_method,
            "transaction_date": self.transaction_date,
            "available_balance": self.available_balance,
            "account_reference": self.account_reference,
            "confidence": self.confidence,
        }
        if self.event_id is not None:
            payload["event_id"] = self.event_id
        if self.user_id is not None:
            payload["user_id"] = self.user_id
        if self.device_id is not None:
            payload["device_id"] = self.device_id
        return payload


class IngestionResult(BaseModel):
    """Result of processing an incoming SMS through the ingestion pipeline."""
    status: str  # "delivered", "duplicate", "rejected", "queued", "failed"
    is_transaction: bool = False
    event: Optional[StructuredTransactionEvent] = None
    reasons: List[str] = Field(default_factory=list)
    signature: Optional[str] = None
    status_code: Optional[int] = None
