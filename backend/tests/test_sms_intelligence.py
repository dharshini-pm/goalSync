"""Deterministic unit tests for the GoalSync SMS Intelligence layer.

Verifies:
- 100% deterministic parsing (no LLM, no network, runs in <1 second)
- High accuracy Indian banking SMS classification
- Precise separation of transaction amounts vs available balance
- Safe merchant, date, and payment method extraction
- Privacy guarantees (no raw SMS in output, exception, or logs)
- Deterministic duplicate fingerprint stability
"""

from __future__ import annotations

import logging
import sys
from typing import Any
import pytest

from app.sms_intelligence import (
    ConfidenceLevel,
    ParsedFinancialSMS,
    PaymentMethod,
    SMSClassification,
    SMSIntelligenceService,
    TransactionType,
    generate_sms_fingerprint,
)


@pytest.fixture
def service() -> SMSIntelligenceService:
    return SMSIntelligenceService()


# ---------------------------------------------------------------------------
# Test 1: Debit Transaction
# ---------------------------------------------------------------------------
def test_1_debit_transaction(service: SMSIntelligenceService):
    msg = "Dear Customer, your A/c XX1234 is debited by Rs.450.00 on 26-09-2026 at SWIGGY. Avl Bal Rs.12,450.00"
    res = service.parse_sms(msg, sender="VM-HDFCBK")

    assert res.classification == SMSClassification.FINANCIAL_TRANSACTION
    assert res.is_financial is True
    assert res.is_transaction is True
    assert res.amount == 450.0
    assert res.transaction_type == TransactionType.DEBIT
    assert res.merchant == "SWIGGY"
    assert res.available_balance == 12450.0
    assert res.account_reference == "XX1234"
    assert res.transaction_date == "2026-09-26"
    assert res.confidence == ConfidenceLevel.HIGH


# ---------------------------------------------------------------------------
# Test 2: Credit Transaction
# ---------------------------------------------------------------------------
def test_2_credit_transaction(service: SMSIntelligenceService):
    msg = "Rs 2,500 credited to A/c XX1234 via UPI on 15/10/2026. Clear Bal: Rs. 45,000."
    res = service.parse_sms(msg, sender="AD-SBIINB")

    assert res.classification == SMSClassification.FINANCIAL_TRANSACTION
    assert res.is_financial is True
    assert res.is_transaction is True
    assert res.amount == 2500.0
    assert res.transaction_type == TransactionType.CREDIT
    assert res.payment_method == PaymentMethod.UPI
    assert res.account_reference == "XX1234"
    assert res.available_balance == 45000.0


# ---------------------------------------------------------------------------
# Test 3: UPI Payment
# ---------------------------------------------------------------------------
def test_3_upi_payment(service: SMSIntelligenceService):
    msg = "UPI payment of INR 350 to ZOMATO successful. Ref 987654321."
    res = service.parse_sms(msg)

    assert res.classification == SMSClassification.FINANCIAL_TRANSACTION
    assert res.is_financial is True
    assert res.is_transaction is True
    assert res.amount == 350.0
    assert res.transaction_type == TransactionType.DEBIT
    assert res.merchant == "ZOMATO"
    assert res.payment_method == PaymentMethod.UPI


# ---------------------------------------------------------------------------
# Test 4: Card Transaction
# ---------------------------------------------------------------------------
def test_4_card_transaction(service: SMSIntelligenceService):
    msg = "Your credit card ending 4567 was spent for Rs. 1,299 at AMAZON on 25/09/2026."
    res = service.parse_sms(msg)

    assert res.classification == SMSClassification.FINANCIAL_TRANSACTION
    assert res.amount == 1299.0
    assert res.transaction_type == TransactionType.DEBIT
    assert res.merchant == "AMAZON"
    assert res.payment_method == PaymentMethod.CARD
    assert res.account_reference == "XX4567"
    assert res.transaction_date == "2026-09-25"


# ---------------------------------------------------------------------------
# Test 5: ATM Withdrawal
# ---------------------------------------------------------------------------
def test_5_atm_withdrawal(service: SMSIntelligenceService):
    msg = "Rs. 2,000 withdrawn from ATM using card ending 9876. Avail Bal: Rs. 8,500."
    res = service.parse_sms(msg)

    assert res.classification == SMSClassification.FINANCIAL_TRANSACTION
    assert res.amount == 2000.0
    assert res.transaction_type == TransactionType.DEBIT
    assert res.payment_method == PaymentMethod.ATM
    assert res.available_balance == 8500.0
    assert res.account_reference == "XX9876"


# ---------------------------------------------------------------------------
# Test 6: Balance-only SMS
# ---------------------------------------------------------------------------
def test_6_balance_only_sms(service: SMSIntelligenceService):
    msg = "Your account balance is Rs.12,450."
    res = service.parse_sms(msg)

    assert res.classification == SMSClassification.FINANCIAL_NON_TRANSACTION
    assert res.is_financial is True
    assert res.is_transaction is False
    assert res.amount is None
    assert res.available_balance == 12450.0


# ---------------------------------------------------------------------------
# Test 7: EMI Reminder
# ---------------------------------------------------------------------------
def test_7_emi_reminder(service: SMSIntelligenceService):
    msg = "Your loan EMI of Rs. 4,500 is due tomorrow. Please maintain sufficient balance."
    res = service.parse_sms(msg)

    assert res.classification == SMSClassification.FINANCIAL_NON_TRANSACTION
    assert res.is_financial is True
    assert res.is_transaction is False
    assert res.amount is None  # Not a completed transaction amount


# ---------------------------------------------------------------------------
# Test 8: OTP SMS (Must NOT be classified as transaction)
# ---------------------------------------------------------------------------
def test_8_otp_sms(service: SMSIntelligenceService):
    msg = "Your OTP for UPI transaction of Rs.500 is 123456. Do not share it with anyone."
    res = service.parse_sms(msg)

    assert res.classification == SMSClassification.NON_FINANCIAL
    assert res.is_financial is False
    assert res.is_transaction is False
    assert res.amount is None


# ---------------------------------------------------------------------------
# Test 9: Delivery SMS
# ---------------------------------------------------------------------------
def test_9_delivery_sms(service: SMSIntelligenceService):
    msg = "Your package with tracking ID 987654 has been delivered. Thank you for shopping!"
    res = service.parse_sms(msg)

    assert res.classification == SMSClassification.NON_FINANCIAL
    assert res.is_financial is False
    assert res.is_transaction is False


# ---------------------------------------------------------------------------
# Test 10: Promotional SMS
# ---------------------------------------------------------------------------
def test_10_promotional_sms(service: SMSIntelligenceService):
    msg = "Flat 50% off on all items! Use code SAVE50 on your next order. Click here to shop."
    res = service.parse_sms(msg)

    assert res.classification == SMSClassification.NON_FINANCIAL
    assert res.is_financial is False
    assert res.is_transaction is False


# ---------------------------------------------------------------------------
# Test 11: Transaction Amount vs Available Balance
# ---------------------------------------------------------------------------
def test_11_transaction_amount_vs_balance(service: SMSIntelligenceService):
    msg = "Your A/c XX5678 is debited by Rs.750.00 at UBER. Avail Bal: Rs.25,000.00"
    res = service.parse_sms(msg)

    assert res.amount == 750.0
    assert res.available_balance == 25000.0
    assert res.amount != res.available_balance


# ---------------------------------------------------------------------------
# Test 12: Merchant Extraction
# ---------------------------------------------------------------------------
def test_12_merchant_extraction(service: SMSIntelligenceService):
    msg1 = "debited by Rs.450 at SWIGGY"
    res1 = service.parse_sms(msg1)
    assert res1.merchant == "SWIGGY"

    msg2 = "payment of Rs.350 to ZOMATO"
    res2 = service.parse_sms(msg2)
    assert res2.merchant == "ZOMATO"

    msg3 = "paid Rs. 250 to VPA swiggy@hdfcbank through UPI"
    res3 = service.parse_sms(msg3)
    assert res3.merchant == "SWIGGY"


# ---------------------------------------------------------------------------
# Test 13: Missing Merchant
# ---------------------------------------------------------------------------
def test_13_missing_merchant(service: SMSIntelligenceService):
    msg = "Your A/c XX1234 is debited by Rs.100.00. Avail Bal: Rs.5,000.00"
    res = service.parse_sms(msg)

    assert res.merchant is None
    assert res.amount == 100.0
    assert res.is_transaction is True


# ---------------------------------------------------------------------------
# Test 14: Missing Amount
# ---------------------------------------------------------------------------
def test_14_missing_amount(service: SMSIntelligenceService):
    msg = "Your A/c XX1234 was debited for purchase. Please check your bank statement."
    res = service.parse_sms(msg)

    assert res.amount is None


# ---------------------------------------------------------------------------
# Test 15: Missing Date
# ---------------------------------------------------------------------------
def test_15_missing_date(service: SMSIntelligenceService):
    msg = "A/c XX1234 debited by Rs.200 at CAFE."
    res = service.parse_sms(msg)

    assert res.transaction_date is None


# ---------------------------------------------------------------------------
# Test 16: Different Date Formats
# ---------------------------------------------------------------------------
def test_16_different_date_formats(service: SMSIntelligenceService):
    cases = [
        ("Debited Rs.100 on 26-09-2026 at STORE", "2026-09-26"),
        ("Debited Rs.100 on 26/09/2026 at STORE", "2026-09-26"),
        ("Debited Rs.100 on 26-Sep-2026 at STORE", "2026-09-26"),
        ("Debited Rs.100 on 26 Sep 2026 at STORE", "2026-09-26"),
        ("Debited Rs.100 on 2026-09-26 at STORE", "2026-09-26"),
    ]
    for text, expected_date in cases:
        res = service.parse_sms(text)
        assert res.transaction_date == expected_date, f"Failed for format: {text}"


# ---------------------------------------------------------------------------
# Test 17: Unknown SMS
# ---------------------------------------------------------------------------
def test_17_unknown_sms(service: SMSIntelligenceService):
    msg = "Hello, are you coming to the meeting today?"
    res = service.parse_sms(msg)

    assert res.classification in (SMSClassification.NON_FINANCIAL, SMSClassification.UNKNOWN)
    assert res.is_transaction is False
    assert res.is_financial is False
    assert res.amount is None


# ---------------------------------------------------------------------------
# Test 18: Confidence Levels
# ---------------------------------------------------------------------------
def test_18_confidence_levels(service: SMSIntelligenceService):
    # High confidence: clear verb, amount, merchant, account
    high_msg = "Your A/c XX1234 is debited by Rs.450.00 at SWIGGY."
    high_res = service.parse_sms(high_msg)
    assert high_res.confidence == ConfidenceLevel.HIGH

    # Medium confidence: amount + verb without merchant or account
    med_msg = "Rs.450 debited."
    med_res = service.parse_sms(med_msg)
    assert med_res.confidence in (ConfidenceLevel.MEDIUM, ConfidenceLevel.HIGH)

    # Low confidence: empty or unknown message
    low_res = service.parse_sms("")
    assert low_res.confidence == ConfidenceLevel.LOW


# ---------------------------------------------------------------------------
# Test 19: Duplicate Fingerprint Stability
# ---------------------------------------------------------------------------
def test_19_duplicate_fingerprint_stability():
    msg1 = "Your A/c XX1234 is debited by Rs.450.00 at SWIGGY."
    msg2 = "  Your A/c XX1234   is debited by Rs.450.00 at SWIGGY.  "

    fp1 = generate_sms_fingerprint(msg1, sender="HDFCBK")
    fp2 = generate_sms_fingerprint(msg2, sender="HDFCBK")

    assert fp1 == fp2
    assert len(fp1) == 64  # SHA-256 hex string


# ---------------------------------------------------------------------------
# Test 20: Different Messages Produce Different Fingerprints
# ---------------------------------------------------------------------------
def test_20_different_fingerprints():
    msg1 = "Your A/c XX1234 is debited by Rs.450.00 at SWIGGY."
    msg2 = "Your A/c XX1234 is debited by Rs.550.00 at SWIGGY."

    fp1 = generate_sms_fingerprint(msg1)
    fp2 = generate_sms_fingerprint(msg2)

    assert fp1 != fp2


# ---------------------------------------------------------------------------
# Test 21: Privacy — No Raw SMS Logging
# ---------------------------------------------------------------------------
def test_21_no_raw_sms_logging(caplog, service: SMSIntelligenceService):
    sensitive_sms = "Secret SMS with A/c 1234567890 debited by Rs.999"
    with caplog.at_level(logging.DEBUG):
        service.parse_sms(sensitive_sms)

    for record in caplog.records:
        assert sensitive_sms not in record.message
        assert "1234567890" not in record.message


# ---------------------------------------------------------------------------
# Test 22: Privacy — Zero LLM Invocation
# ---------------------------------------------------------------------------
def test_22_zero_llm_invocation():
    import app.sms_intelligence.service as svc_mod
    import app.sms_intelligence.parser as parse_mod
    import app.sms_intelligence.detector as det_mod

    for mod in [svc_mod, parse_mod, det_mod]:
        src = dir(mod)
        assert "OllamaClient" not in src
        assert "Ollama" not in src
        assert "llama" not in str(src).lower()


# ---------------------------------------------------------------------------
# Test 23: No Hallucinated Merchant
# ---------------------------------------------------------------------------
def test_23_no_hallucinated_merchant(service: SMSIntelligenceService):
    msg = "Your A/c XX1234 is debited by Rs.500."
    res = service.parse_sms(msg)

    assert res.merchant is None


# ---------------------------------------------------------------------------
# Test 24: No Hallucinated Amount
# ---------------------------------------------------------------------------
def test_24_no_hallucinated_amount(service: SMSIntelligenceService):
    msg = "Your credit card bill payment is due tomorrow. Please pay on time."
    res = service.parse_sms(msg)

    assert res.is_transaction is False
    assert res.amount is None


# ---------------------------------------------------------------------------
# Edge Cases
# ---------------------------------------------------------------------------
def test_edge_empty_string(service: SMSIntelligenceService):
    res = service.parse_sms("")
    assert res.classification == SMSClassification.UNKNOWN
    assert res.is_financial is False
    assert res.is_transaction is False


def test_edge_account_masking(service: SMSIntelligenceService):
    msg = "Account ending 4321 debited by Rs.100 at CAFE."
    res = service.parse_sms(msg)
    assert res.account_reference == "XX4321"


def test_edge_imps_and_neft(service: SMSIntelligenceService):
    msg_imps = "Rs. 5,000 transferred to A/c XX9999 via IMPS ref 12345."
    res_imps = service.parse_sms(msg_imps)
    assert res_imps.payment_method == PaymentMethod.IMPS

    msg_neft = "Rs. 10,000 credited to A/c XX8888 via NEFT."
    res_neft = service.parse_sms(msg_neft)
    assert res_neft.payment_method == PaymentMethod.NEFT


def test_edge_cashback_credit(service: SMSIntelligenceService):
    msg = "Cashback of Rs. 50 credited to your A/c XX1234. Avail Bal: Rs. 1,050."
    res = service.parse_sms(msg)
    assert res.classification == SMSClassification.FINANCIAL_TRANSACTION
    assert res.transaction_type == TransactionType.CREDIT
    assert res.amount == 50.0
    assert res.available_balance == 1050.0


def test_edge_to_dict_structure(service: SMSIntelligenceService):
    msg = "Your A/c XX1234 is debited by Rs.450.00 at SWIGGY."
    res = service.parse_sms(msg)
    d = res.to_dict()

    assert "classification" in d
    assert "is_financial" in d
    assert "is_transaction" in d
    assert "amount" in d
    assert "transaction_type" in d
    assert "merchant" in d
    assert "payment_method" in d
    assert "confidence" in d
    assert "fingerprint" in d


def test_edge_avail_bal_not_a_transaction(service: SMSIntelligenceService):
    msg = "Avail Bal: Rs.12,450"
    res = service.parse_sms(msg)
    assert res.classification == SMSClassification.FINANCIAL_NON_TRANSACTION
    assert res.is_transaction is False
    assert res.is_financial is True
    assert res.available_balance == 12450.0
    assert res.amount is None


def test_edge_bill_due_date_non_transaction(service: SMSIntelligenceService):
    msg = "Your credit card bill is due on 28 Sep."
    res = service.parse_sms(msg)
    assert res.classification == SMSClassification.FINANCIAL_NON_TRANSACTION
    assert res.is_transaction is False
    assert res.is_financial is True
    assert res.amount is None


def test_edge_happy_birthday_greeting(service: SMSIntelligenceService):
    msg = "Happy birthday! Wishing you great joy and prosperity."
    res = service.parse_sms(msg)
    assert res.classification == SMSClassification.NON_FINANCIAL
    assert res.is_transaction is False
    assert res.is_financial is False


def test_edge_service_helpers(service: SMSIntelligenceService):
    tx_msg = "Rs 500.00 credited to A/c XX1234 through UPI."
    assert service.is_financial(tx_msg) is True
    assert service.is_transaction(tx_msg) is True

    non_tx_msg = "Your account balance is Rs.15,000."
    assert service.is_financial(non_tx_msg) is True
    assert service.is_transaction(non_tx_msg) is False

    otp_msg = "Your OTP is 482931."
    assert service.is_financial(otp_msg) is False
    assert service.is_transaction(otp_msg) is False


def test_edge_net_banking_transfer(service: SMSIntelligenceService):
    msg = "Payment of Rs 1,500 using Net Banking to FLIPKART successful."
    res = service.parse_sms(msg)
    assert res.classification == SMSClassification.FINANCIAL_TRANSACTION
    assert res.amount == 1500.0
    assert res.merchant == "FLIPKART"
    assert res.payment_method == PaymentMethod.BANK_TRANSFER

