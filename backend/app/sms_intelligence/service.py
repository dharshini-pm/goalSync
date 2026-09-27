"""Service layer for the GoalSync SMS Intelligence module.

Provides a clean, high-level interface for deterministic SMS classification,
information extraction, and fingerprinting without calling any LLM.
"""

from __future__ import annotations

from typing import Any, Dict, Optional
from .models import (
    ConfidenceLevel,
    ParsedFinancialSMS,
    PaymentMethod,
    SMSClassification,
    TransactionType,
)
from .parser import SMSParser, generate_sms_fingerprint


class SMSIntelligenceService:
    """Service facade for deterministic financial SMS parsing."""

    def __init__(self) -> None:
        pass

    def parse_sms(
        self,
        text: str,
        sender: Optional[str] = None,
        timestamp: Optional[str] = None,
    ) -> ParsedFinancialSMS:
        """Parses an SMS message into structured financial data.

        Guarantees privacy:
        - Never logs raw SMS content
        - Never includes raw SMS in exception messages
        - Never calls an external LLM
        """
        try:
            return SMSParser.parse(text=text, sender=sender, timestamp=timestamp)
        except Exception as exc:
            # Privacy guarantee: do NOT include raw SMS text in the exception
            err_type = type(exc).__name__
            return ParsedFinancialSMS(
                classification=SMSClassification.UNKNOWN,
                is_financial=False,
                is_transaction=False,
                confidence=ConfidenceLevel.LOW,
                reasons=[f"Internal parsing error: {err_type}"],
                fingerprint=generate_sms_fingerprint(text, sender=sender, timestamp=timestamp) if text else None,
            )

    def is_financial(self, text: str, sender: Optional[str] = None) -> bool:
        """Quick check whether an SMS is financial-related."""
        parsed = self.parse_sms(text, sender=sender)
        return parsed.is_financial

    def is_transaction(self, text: str, sender: Optional[str] = None) -> bool:
        """Quick check whether an SMS represents a completed financial transaction."""
        parsed = self.parse_sms(text, sender=sender)
        return parsed.is_transaction

    def extract_structured_event(
        self,
        text: str,
        sender: Optional[str] = None,
        timestamp: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Convenience method returning a JSON-serializable dictionary."""
        return self.parse_sms(text, sender=sender, timestamp=timestamp).to_dict()

    @staticmethod
    def create_fingerprint(
        text: str,
        sender: Optional[str] = None,
        timestamp: Optional[str] = None,
    ) -> str:
        """Generates a stable deterministic fingerprint for an SMS."""
        return generate_sms_fingerprint(text, sender=sender, timestamp=timestamp)
