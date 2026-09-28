"""Pydantic schemas and models for the GoalSync Transaction Processing Pipeline."""

from __future__ import annotations

from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field, field_validator


class ProcessTransactionRequest(BaseModel):
    """Structured transaction event processed by GoalSync AI pipeline.

    Guarantees privacy: Contains only structured financial data.
    """
    event_type: str = Field(default="financial_transaction", description="Must be 'financial_transaction'")
    source: str = Field(default="manual_entry", description="Source of event (e.g. manual_entry)")
    event_id: Optional[str] = Field(default=None, description="Unique idempotency ID for this event")
    fingerprint: Optional[str] = Field(default=None, description="Deterministic SHA-256 fingerprint")
    user_id: Optional[str] = Field(default=None, description="Associated user ID")
    device_id: Optional[str] = Field(default=None, description="Originating device identifier")
    amount: float = Field(..., gt=0.0, description="Transaction amount in currency units")
    transaction_type: str = Field(default="DEBIT", description="DEBIT or CREDIT")
    merchant: Optional[str] = Field(default=None, description="Cleaned merchant name")
    payment_method: str = Field(default="UNKNOWN", description="UPI, Card, NetBanking, etc.")
    transaction_date: Optional[str] = Field(default=None, description="ISO-8601 or YYYY-MM-DD date")
    available_balance: Optional[float] = Field(default=None, description="Extracted account balance")
    account_reference: Optional[str] = Field(default=None, description="Masked account reference")
    confidence: str = Field(default="LOW", description="HIGH, MEDIUM, LOW")

    @field_validator("event_type")
    @classmethod
    def validate_event_type(cls, v: str) -> str:
        if v != "financial_transaction":
            raise ValueError(f"Unsupported event_type '{v}'. Expected 'financial_transaction'.")
        return v


class ProcessingStageInfo(BaseModel):
    """Information on completed pipeline stages."""
    completed: bool
    completed_stages: List[str] = Field(default_factory=list)


class ProcessTransactionResponse(BaseModel):
    """Response returned by the production POST /api/v1/process-transaction endpoint."""
    success: bool
    status: str  # "processed", "duplicate", "failed"
    event_id: str
    transaction_id: Optional[str] = None
    processing: Optional[ProcessingStageInfo] = None
    result: Optional[Dict[str, Any]] = None
    error: Optional[str] = None
