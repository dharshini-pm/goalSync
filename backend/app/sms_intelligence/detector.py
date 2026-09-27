"""Deterministic SMS classifier for financial and transaction detection.

Purely deterministic: relies on compiled regex, keyword combinations, and priority rules.
Does NOT invoke any LLM.
"""

from __future__ import annotations

import re
from typing import List, Optional, Tuple
from .models import SMSClassification
from .patterns import (
    OTP_PATTERNS,
    NON_FINANCIAL_PATTERNS,
    BILL_DUE_PATTERNS,
    BALANCE_ONLY_PATTERNS,
    DEBIT_VERBS,
    CREDIT_VERBS,
    TRANSACTION_AMOUNT_PATTERNS,
    GENERAL_AMOUNT_PATTERN,
)


class SMSDetector:
    """Classifies incoming SMS into financial transactions, non-transactions, or non-financial."""

    @classmethod
    def classify(
        cls,
        text: str,
        sender: Optional[str] = None,
    ) -> Tuple[SMSClassification, List[str]]:
        """Classifies the SMS text and returns (classification, reasons)."""
        reasons: List[str] = []

        if not text or not text.strip():
            return SMSClassification.UNKNOWN, ["Empty or whitespace-only message"]

        cleaned = text.strip()

        # -------------------------------------------------------------------
        # Rule 1: OTP / Verification codes have HIGHEST precedence
        # Even if message says "Your OTP for transaction of Rs.500 is 123456"
        # -------------------------------------------------------------------
        for pattern in OTP_PATTERNS:
            if pattern.search(cleaned):
                reasons.append("Security/OTP code pattern detected")
                return SMSClassification.NON_FINANCIAL, reasons

        # -------------------------------------------------------------------
        # Rule 2: Delivery, social, promotional notifications
        # -------------------------------------------------------------------
        is_promo_or_delivery = False
        for pattern in NON_FINANCIAL_PATTERNS:
            if pattern.search(cleaned):
                is_promo_or_delivery = True
                break

        # -------------------------------------------------------------------
        # Rule 3: Detect transaction verbs
        # -------------------------------------------------------------------
        has_debit_verb = any(p.search(cleaned) for p in DEBIT_VERBS)
        has_credit_verb = any(p.search(cleaned) for p in CREDIT_VERBS)
        has_transaction_verb = has_debit_verb or has_credit_verb

        # Detect specific transaction amount pattern
        has_tx_amount_pattern = any(p.search(cleaned) for p in TRANSACTION_AMOUNT_PATTERNS)

        # Detect general currency / amount
        has_currency_amount = bool(GENERAL_AMOUNT_PATTERN.search(cleaned))

        # Detect banking/account context
        has_account_signal = bool(
            re.search(
                r"\b(?:a/c|acct|account|card|upi|vpa|bank|atm|imps|neft)\b",
                cleaned,
                re.IGNORECASE,
            )
        )

        # Detect completed payment / transaction confirmation
        has_completion_signal = bool(
            re.search(
                r"\b(?:successful|completed|approved|done)\b",
                cleaned,
                re.IGNORECASE,
            )
        )

        # -------------------------------------------------------------------
        # Rule 4: Financial Non-Transaction (Bill due, EMI reminders)
        # -------------------------------------------------------------------
        for pattern in BILL_DUE_PATTERNS:
            if pattern.search(cleaned):
                # If it's a bill due or EMI reminder without a debit/credit completion
                if not (has_debit_verb and ("debited" in cleaned.lower() or "paid" in cleaned.lower() and has_completion_signal)):
                    reasons.append("Bill, EMI, or statement due reminder detected")
                    return SMSClassification.FINANCIAL_NON_TRANSACTION, reasons

        # -------------------------------------------------------------------
        # Rule 5: Balance enquiry only (no transaction verb)
        # -------------------------------------------------------------------
        has_balance_only = any(p.search(cleaned) for p in BALANCE_ONLY_PATTERNS)
        if has_balance_only and not has_transaction_verb:
            reasons.append("Account balance notification without transaction verb")
            return SMSClassification.FINANCIAL_NON_TRANSACTION, reasons

        # Check for phrase "balance is Rs..." without transaction verbs
        if (
            re.search(r"\b(?:balance\s+is|acct\s+bal\s+is|your\s+balance)\b", cleaned, re.IGNORECASE)
            and not has_transaction_verb
        ):
            reasons.append("Balance enquiry notification without transaction")
            return SMSClassification.FINANCIAL_NON_TRANSACTION, reasons

        # -------------------------------------------------------------------
        # Rule 6: Transaction classification requires COMBINATION of signals
        # -------------------------------------------------------------------
        # Case A: Explicit transaction verb + transaction amount pattern
        if has_tx_amount_pattern:
            if has_debit_verb:
                reasons.append("Debit transaction verb with associated transaction amount")
            elif has_credit_verb:
                reasons.append("Credit transaction verb with associated transaction amount")
            else:
                reasons.append("Transaction payment pattern with amount")
            return SMSClassification.FINANCIAL_TRANSACTION, reasons

        # Case B: Transaction verb + general amount + account/banking context
        if has_transaction_verb and (has_currency_amount or has_tx_amount_pattern) and (has_account_signal or has_completion_signal):
            reasons.append("Transaction verb with currency amount and banking/account context")
            return SMSClassification.FINANCIAL_TRANSACTION, reasons

        # Case C: Transaction verb + amount without account context (e.g. "Rs 450 debited")
        if has_transaction_verb and has_currency_amount:
            reasons.append("Transaction verb with currency amount")
            return SMSClassification.FINANCIAL_TRANSACTION, reasons

        # -------------------------------------------------------------------
        # Rule 7: Fallback checks
        # -------------------------------------------------------------------
        if is_promo_or_delivery:
            reasons.append("Delivery, telecom, or promotional notification")
            return SMSClassification.NON_FINANCIAL, reasons

        # Has banking context or currency without transaction action
        if has_account_signal or has_currency_amount:
            reasons.append("Financial or banking terms present but no completed transaction action detected")
            return SMSClassification.FINANCIAL_NON_TRANSACTION, reasons

        # Completely non-financial
        reasons.append("No financial indicators detected")
        return SMSClassification.NON_FINANCIAL, reasons
