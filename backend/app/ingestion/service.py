"""Service layer for SMS ingestion, validation, and downstream n8n dispatching."""

from __future__ import annotations

from typing import List, Optional, Set
from app.sms_intelligence.service import SMSIntelligenceService
from .models import IngestionResult, StructuredTransactionEvent
from .webhook_client import N8nWebhookClient


class SMSIngestionService:
    """Orchestrates incoming SMS handling, deterministic parsing, and secure n8n dispatch.

    Architecture:
        Incoming SMS
             ↓
        SMSIntelligenceService (100% deterministic parsing)
             ↓
        If NOT a transaction → STOP (returns 'rejected')
             ↓
        If transaction:
             - Check duplicate fingerprint (returns 'duplicate' if seen)
             - Build StructuredTransactionEvent (strictly NO raw SMS)
             - Deliver to n8n webhook with HMAC-SHA256 signature
             - If webhook unreachable: enqueue in offline buffer
    """

    def __init__(
        self,
        sms_service: Optional[SMSIntelligenceService] = None,
        webhook_client: Optional[N8nWebhookClient] = None,
    ) -> None:
        self.sms_service = sms_service or SMSIntelligenceService()
        self.webhook_client = webhook_client or N8nWebhookClient()
        self.seen_fingerprints: Set[str] = set()
        self.offline_queue: List[StructuredTransactionEvent] = []

    def ingest_sms(
        self,
        text: str,
        sender: Optional[str] = None,
        timestamp: Optional[str] = None,
        user_id: Optional[str] = None,
        device_id: Optional[str] = None,
    ) -> IngestionResult:
        """Processes an incoming SMS and dispatches qualifying transactions to n8n."""
        # Step 1: Deterministic classification and extraction via SMSIntelligenceService
        parsed = self.sms_service.parse_sms(
            text=text,
            sender=sender,
            timestamp=timestamp,
        )

        # Step 2: Privacy filter — STOP if not a completed transaction
        if not parsed.is_transaction:
            return IngestionResult(
                status="rejected",
                is_transaction=False,
                reasons=[
                    f"SMS is not a completed financial transaction: {parsed.classification.value}"
                ] + parsed.reasons,
            )

        # Step 3: Duplicate detection check
        fingerprint = parsed.fingerprint or ""
        if fingerprint in self.seen_fingerprints:
            return IngestionResult(
                status="duplicate",
                is_transaction=True,
                reasons=["Duplicate transaction event skipped"],
            )

        # Step 4: Build StructuredTransactionEvent (contains NO raw SMS text)
        event = StructuredTransactionEvent(
            event_type="financial_transaction",
            source="android_sms",
            fingerprint=fingerprint,
            amount=parsed.amount,
            transaction_type=parsed.transaction_type.value,
            merchant=parsed.merchant,
            payment_method=parsed.payment_method.value,
            transaction_date=parsed.transaction_date,
            available_balance=parsed.available_balance,
            account_reference=parsed.account_reference,
            confidence=parsed.confidence.value,
            user_id=user_id,
            device_id=device_id,
        )

        # Step 5: Webhook delivery
        success, status_code, message, signature = self.webhook_client.send_event(event)

        if success:
            if fingerprint:
                self.seen_fingerprints.add(fingerprint)
            return IngestionResult(
                status="delivered",
                is_transaction=True,
                event=event,
                signature=signature,
                status_code=status_code,
                reasons=[message],
            )

        # Step 6: Offline buffering if webhook failed or is unreachable
        self.offline_queue.append(event)
        return IngestionResult(
            status="queued",
            is_transaction=True,
            event=event,
            signature=signature,
            status_code=status_code,
            reasons=[message],
        )

    def flush_offline_queue(self) -> int:
        """Attempts to flush queued events to the n8n webhook."""
        if not self.offline_queue:
            return 0

        delivered_count = 0
        remaining: List[StructuredTransactionEvent] = []

        for event in self.offline_queue:
            success, _, _, _ = self.webhook_client.send_event(event)
            if success:
                if event.fingerprint:
                    self.seen_fingerprints.add(event.fingerprint)
                delivered_count += 1
            else:
                remaining.append(event)

        self.offline_queue = remaining
        return delivered_count

    def simulate_sms(
        self,
        text: str,
        sender: Optional[str] = "SIM-BANK",
        timestamp: Optional[str] = None,
        user_id: Optional[str] = "test-user-sim",
        device_id: Optional[str] = "dev-sim-001",
    ) -> IngestionResult:
        """Simulates an incoming SMS for development testing without live hardware."""
        return self.ingest_sms(
            text=text,
            sender=sender,
            timestamp=timestamp,
            user_id=user_id,
            device_id=device_id,
        )

    def clear_state(self) -> None:
        """Clears memory state (for testing)."""
        self.seen_fingerprints.clear()
        self.offline_queue.clear()
