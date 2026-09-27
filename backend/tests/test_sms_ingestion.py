"""Tests for GoalSync Real-Time Android SMS Ingestion and n8n Webhook layer.

Covers all 20 required verification points:
1. Financial SMS is accepted
2. OTP is rejected
3. Promotional SMS is rejected
4. Delivery SMS is rejected
5. Balance-only SMS is rejected
6. EMI reminder is rejected
7. Structured transaction payload is correct
8. Fingerprint is preserved
9. Duplicate event is handled
10. Missing webhook configuration handled
11. Webhook timeout handled
12. Webhook failure handled
13. Retry is bounded
14. HMAC signature generated correctly
15. Wrong secret/signature rejected
16. No secrets logged
17. No raw SMS sent in structured production payload
18. Permission denied handled safely
19. Offline event handling works
20. Development simulation works
"""

from __future__ import annotations

import json
import logging
from unittest.mock import MagicMock, patch
import pytest
import requests

from app.ingestion import (
    IngestionResult,
    N8nWebhookClient,
    SMSIngestionService,
    StructuredTransactionEvent,
    compute_hmac_signature,
    verify_hmac_signature,
)


@pytest.fixture
def mock_session():
    session = MagicMock(spec=requests.Session)
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    mock_resp.json.return_value = {"status": "ok"}
    session.post.return_value = mock_resp
    return session


@pytest.fixture
def ingestion_service(mock_session):
    client = N8nWebhookClient(
        webhook_url="https://n8n.example.com/webhook/goalsync/transaction",
        webhook_secret="test-secret-key-123",
        timeout=5,
        max_retries=3,
        session=mock_session,
    )
    return SMSIngestionService(webhook_client=client)


# ---------------------------------------------------------------------------
# Test 1: Financial SMS is accepted
# ---------------------------------------------------------------------------
def test_1_financial_sms_accepted(ingestion_service: SMSIngestionService):
    msg = "Your A/c XX1234 is debited by Rs.450.00 at SWIGGY. Avl Bal Rs.12,450.00"
    res = ingestion_service.ingest_sms(msg, sender="VM-HDFCBK")

    assert res.status == "delivered"
    assert res.is_transaction is True
    assert res.event is not None
    assert res.event.amount == 450.0
    assert res.event.merchant == "SWIGGY"


# ---------------------------------------------------------------------------
# Test 2: OTP is rejected
# ---------------------------------------------------------------------------
def test_2_otp_rejected(ingestion_service: SMSIngestionService):
    msg = "Your OTP for UPI transaction of Rs.500 is 123456. Do not share it."
    res = ingestion_service.ingest_sms(msg)

    assert res.status == "rejected"
    assert res.is_transaction is False
    assert res.event is None


# ---------------------------------------------------------------------------
# Test 3: Promotional SMS is rejected
# ---------------------------------------------------------------------------
def test_3_promotional_sms_rejected(ingestion_service: SMSIngestionService):
    msg = "Flat 50% off on all items! Use code SAVE50 on your order."
    res = ingestion_service.ingest_sms(msg)

    assert res.status == "rejected"
    assert res.is_transaction is False


# ---------------------------------------------------------------------------
# Test 4: Delivery SMS is rejected
# ---------------------------------------------------------------------------
def test_4_delivery_sms_rejected(ingestion_service: SMSIngestionService):
    msg = "Your package with tracking ID 987654 has been delivered."
    res = ingestion_service.ingest_sms(msg)

    assert res.status == "rejected"
    assert res.is_transaction is False


# ---------------------------------------------------------------------------
# Test 5: Balance-only SMS is rejected
# ---------------------------------------------------------------------------
def test_5_balance_only_sms_rejected(ingestion_service: SMSIngestionService):
    msg = "Your account balance is Rs.12,450."
    res = ingestion_service.ingest_sms(msg)

    assert res.status == "rejected"
    assert res.is_transaction is False


# ---------------------------------------------------------------------------
# Test 6: EMI reminder is rejected
# ---------------------------------------------------------------------------
def test_6_emi_reminder_rejected(ingestion_service: SMSIngestionService):
    msg = "Your credit card bill payment of Rs. 4,500 is due on 28 Sep."
    res = ingestion_service.ingest_sms(msg)

    assert res.status == "rejected"
    assert res.is_transaction is False


# ---------------------------------------------------------------------------
# Test 7: Structured transaction payload is correct
# ---------------------------------------------------------------------------
def test_7_structured_transaction_payload_correct(ingestion_service: SMSIngestionService):
    msg = "Dear Customer, your A/c XX5678 is debited by Rs.350.00 on 26-09-2026 at ZOMATO. Avl Bal Rs.8,000.00"
    res = ingestion_service.ingest_sms(
        msg,
        user_id="user_test_999",
        device_id="dev_pixel_01",
    )

    assert res.event is not None
    payload = res.event.to_n8n_payload()

    assert payload["event_type"] == "financial_transaction"
    assert payload["source"] == "android_sms"
    assert payload["amount"] == 350.0
    assert payload["transaction_type"] == "DEBIT"
    assert payload["merchant"] == "ZOMATO"
    assert payload["available_balance"] == 8000.0
    assert payload["account_reference"] == "XX5678"
    assert payload["transaction_date"] == "2026-09-26"
    assert payload["confidence"] == "HIGH"
    assert payload["user_id"] == "user_test_999"
    assert payload["device_id"] == "dev_pixel_01"


# ---------------------------------------------------------------------------
# Test 8: Fingerprint is preserved
# ---------------------------------------------------------------------------
def test_8_fingerprint_preserved(ingestion_service: SMSIngestionService):
    msg = "Your A/c XX1234 is debited by Rs.100 at STORE."
    res = ingestion_service.ingest_sms(msg)

    assert res.event is not None
    assert len(res.event.fingerprint) == 64
    assert res.event.to_n8n_payload()["fingerprint"] == res.event.fingerprint


# ---------------------------------------------------------------------------
# Test 9: Duplicate event is handled
# ---------------------------------------------------------------------------
def test_9_duplicate_event_handled(ingestion_service: SMSIngestionService):
    msg = "Your A/c XX1234 is debited by Rs.200 at CAFE."

    res1 = ingestion_service.ingest_sms(msg)
    assert res1.status == "delivered"

    # Second delivery of the identical SMS
    res2 = ingestion_service.ingest_sms(msg)
    assert res2.status == "duplicate"
    assert "Duplicate transaction event skipped" in res2.reasons


# ---------------------------------------------------------------------------
# Test 10: Missing webhook configuration handled
# ---------------------------------------------------------------------------
def test_10_missing_webhook_configuration_handled():
    client = N8nWebhookClient(webhook_url=None)
    service = SMSIngestionService(webhook_client=client)

    msg = "Your A/c XX1234 is debited by Rs.450 at SWIGGY."
    res = service.ingest_sms(msg)

    assert res.status == "queued"
    assert "Missing GOALSYNC_N8N_WEBHOOK_URL" in res.reasons[0]


# ---------------------------------------------------------------------------
# Test 11: Webhook timeout handled
# ---------------------------------------------------------------------------
def test_11_webhook_timeout_handled():
    session = MagicMock()
    session.post.side_effect = requests.Timeout("Connection timed out")

    client = N8nWebhookClient(
        webhook_url="https://n8n.example.com/webhook",
        timeout=1,
        max_retries=2,
        session=session,
    )
    service = SMSIngestionService(webhook_client=client)

    msg = "Your A/c XX1234 is debited by Rs.450 at SWIGGY."
    res = service.ingest_sms(msg)

    assert res.status == "queued"
    assert "timed out" in res.reasons[0].lower()


# ---------------------------------------------------------------------------
# Test 12: Webhook failure handled (e.g. 500 error)
# ---------------------------------------------------------------------------
def test_12_webhook_failure_handled():
    session = MagicMock()
    mock_resp = MagicMock()
    mock_resp.status_code = 500
    session.post.return_value = mock_resp

    client = N8nWebhookClient(
        webhook_url="https://n8n.example.com/webhook",
        max_retries=2,
        session=session,
    )
    service = SMSIngestionService(webhook_client=client)

    msg = "Your A/c XX1234 is debited by Rs.450 at SWIGGY."
    res = service.ingest_sms(msg)

    assert res.status == "queued"
    assert len(service.offline_queue) == 1


# ---------------------------------------------------------------------------
# Test 13: Retry is bounded
# ---------------------------------------------------------------------------
def test_13_retry_is_bounded():
    session = MagicMock()
    session.post.side_effect = requests.ConnectionError("Connection refused")

    client = N8nWebhookClient(
        webhook_url="https://n8n.example.com/webhook",
        max_retries=3,
        session=session,
    )

    event = StructuredTransactionEvent(
        fingerprint="abc",
        amount=100.0,
    )
    success, _, _, _ = client.send_event(event)

    assert success is False
    assert session.post.call_count == 3  # Exactly 3 retries, no infinite loop


# ---------------------------------------------------------------------------
# Test 14: HMAC signature generated correctly
# ---------------------------------------------------------------------------
def test_14_hmac_signature_generated_correctly():
    payload = json.dumps({"test": "data"})
    secret = "secret-key-456"

    sig = compute_hmac_signature(payload, secret)
    assert len(sig) == 64
    assert verify_hmac_signature(payload, secret, sig) is True


# ---------------------------------------------------------------------------
# Test 15: Wrong secret/signature rejected
# ---------------------------------------------------------------------------
def test_15_wrong_secret_signature_rejected():
    payload = json.dumps({"test": "data"})
    sig = compute_hmac_signature(payload, "secret-key-456")

    assert verify_hmac_signature(payload, "wrong-secret", sig) is False
    assert verify_hmac_signature(payload, "secret-key-456", "invalid_signature") is False


# ---------------------------------------------------------------------------
# Test 16: No secrets logged
# ---------------------------------------------------------------------------
def test_16_no_secrets_logged(caplog, ingestion_service: SMSIngestionService):
    secret = "test-secret-key-123"
    msg = "Your A/c XX1234 is debited by Rs.450 at SWIGGY."

    with caplog.at_level(logging.DEBUG):
        ingestion_service.ingest_sms(msg)

    for record in caplog.records:
        assert secret not in record.message


# ---------------------------------------------------------------------------
# Test 17: No raw SMS sent in structured production payload
# ---------------------------------------------------------------------------
def test_17_no_raw_sms_in_structured_payload(ingestion_service: SMSIngestionService):
    msg = "Secret text: Your A/c XX1234 is debited by Rs.450 at SWIGGY. Avl Bal Rs.12,450.00"
    res = ingestion_service.ingest_sms(msg)

    assert res.event is not None
    payload = res.event.to_n8n_payload()

    assert "raw_content" not in payload
    assert "raw_sms" not in payload
    assert "body" not in payload
    assert "Secret text" not in str(payload)


# ---------------------------------------------------------------------------
# Test 18: Permission denied handled safely
# ---------------------------------------------------------------------------
def test_18_permission_denied_handled_safely():
    # If permission is denied on Android, no message is broadcasted or empty text passed
    service = SMSIngestionService()
    res = service.ingest_sms("")

    assert res.status == "rejected"
    assert res.is_transaction is False


# ---------------------------------------------------------------------------
# Test 19: Offline event handling works
# ---------------------------------------------------------------------------
def test_19_offline_event_handling_works():
    session = MagicMock()
    # Initially offline
    session.post.side_effect = requests.ConnectionError("Offline")

    client = N8nWebhookClient(
        webhook_url="https://n8n.example.com/webhook",
        max_retries=1,
        session=session,
    )
    service = SMSIngestionService(webhook_client=client)

    msg = "Your A/c XX1234 is debited by Rs.450 at SWIGGY."
    res = service.ingest_sms(msg)

    assert res.status == "queued"
    assert len(service.offline_queue) == 1

    # Network restored
    mock_resp = MagicMock()
    mock_resp.status_code = 200
    session.post.side_effect = None
    session.post.return_value = mock_resp

    flushed = service.flush_offline_queue()
    assert flushed == 1
    assert len(service.offline_queue) == 0


# ---------------------------------------------------------------------------
# Test 20: Development simulation works
# ---------------------------------------------------------------------------
def test_20_development_simulation_works(ingestion_service: SMSIngestionService):
    msg = "Your A/c XX1234 is debited by Rs.450.00 at SWIGGY. Avl Bal Rs.12,450.00"
    res = ingestion_service.simulate_sms(msg)

    assert res.status == "delivered"
    assert res.is_transaction is True
    assert res.event is not None
    assert res.event.user_id == "test-user-sim"
    assert res.event.device_id == "dev-sim-001"
    assert res.event.merchant == "SWIGGY"
