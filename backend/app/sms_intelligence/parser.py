"""Deterministic parsing and extraction for Indian financial SMS messages.

Extracts amounts, balances, merchants, payment methods, dates, and masked account references.
Ensures zero LLM invocation and strict privacy (no raw SMS in outputs or errors).
"""

from __future__ import annotations

import hashlib
import re
from typing import Any, Dict, List, Optional, Tuple

from .models import (
    ConfidenceLevel,
    ParsedFinancialSMS,
    PaymentMethod,
    SMSClassification,
    TransactionType,
)
from .patterns import (
    ACCOUNT_REF_PATTERNS,
    BALANCE_EXTRACT_PATTERNS,
    DATE_PATTERNS,
    DEBIT_VERBS,
    CREDIT_VERBS,
    GENERAL_AMOUNT_PATTERN,
    MERCHANT_PATTERNS,
    MERCHANT_STOP_WORDS,
    MONTH_NAME_MAP,
    PAYMENT_METHOD_PATTERNS,
    TRANSACTION_AMOUNT_PATTERNS,
)


def _clean_amount(amt_str: str) -> Optional[float]:
    """Converts a regex-captured amount string to float."""
    try:
        clean = amt_str.replace(",", "").strip()
        val = float(clean)
        return val if val >= 0 else None
    except Exception:
        return None


def extract_amounts(
    text: str,
    classification: SMSClassification,
) -> Tuple[Optional[float], Optional[float]]:
    """Separates transaction amount from available balance.

    Returns:
        (transaction_amount, available_balance)
    """
    cleaned = text.strip()
    available_balance: Optional[float] = None
    balance_span: Optional[Tuple[int, int]] = None

    # Step 1: Detect available balance specifically
    for pattern in BALANCE_EXTRACT_PATTERNS:
        match = pattern.search(cleaned)
        if match:
            # Group 1 is the amount
            val = _clean_amount(match.group(1))
            if val is not None:
                available_balance = val
                balance_span = match.span()
                break

    # If it is a non-transaction message (e.g., balance check), there is no transaction amount
    if classification == SMSClassification.FINANCIAL_NON_TRANSACTION:
        return None, available_balance

    # If non-financial or unknown, return None for both
    if classification in (SMSClassification.NON_FINANCIAL, SMSClassification.UNKNOWN):
        return None, None

    # Step 2: Extract transaction amount tied to verbs
    transaction_amount: Optional[float] = None

    for pattern in TRANSACTION_AMOUNT_PATTERNS:
        for match in pattern.finditer(cleaned):
            # Ensure this match does not overlap with the balance span
            m_start, m_end = match.span()
            if balance_span:
                b_start, b_end = balance_span
                # Check for overlap
                if not (m_end <= b_start or m_start >= b_end):
                    continue
            val = _clean_amount(match.group(1))
            if val is not None:
                transaction_amount = val
                break
        if transaction_amount is not None:
            break

    # Step 3: Fallback if transaction verb exists but amount wasn't immediately adjacent
    if transaction_amount is None:
        for match in GENERAL_AMOUNT_PATTERN.finditer(cleaned):
            m_start, m_end = match.span()
            if balance_span:
                b_start, b_end = balance_span
                if not (m_end <= b_start or m_start >= b_end):
                    continue
            val = _clean_amount(match.group(1))
            if val is not None:
                transaction_amount = val
                break

    return transaction_amount, available_balance


def extract_transaction_type(text: str) -> TransactionType:
    """Determines if the transaction is DEBIT or CREDIT."""
    has_debit = any(p.search(text) for p in DEBIT_VERBS)
    has_credit = any(p.search(text) for p in CREDIT_VERBS)

    if has_debit and not has_credit:
        return TransactionType.DEBIT
    if has_credit and not has_debit:
        return TransactionType.CREDIT
    if has_debit and has_credit:
        # Check order of appearance to determine primary action
        first_debit_idx = min((m.start() for p in DEBIT_VERBS for m in [p.search(text)] if m), default=9999)
        first_credit_idx = min((m.start() for p in CREDIT_VERBS for m in [p.search(text)] if m), default=9999)
        return TransactionType.DEBIT if first_debit_idx < first_credit_idx else TransactionType.CREDIT

    return TransactionType.UNKNOWN


def extract_payment_method(text: str) -> PaymentMethod:
    """Extracts the explicit payment method from the SMS."""
    for pattern, method_name in PAYMENT_METHOD_PATTERNS:
        if pattern.search(text):
            return PaymentMethod(method_name)
    return PaymentMethod.UNKNOWN


def extract_date(text: str) -> Optional[str]:
    """Extracts and normalizes transaction date to YYYY-MM-DD format."""
    for pattern in DATE_PATTERNS:
        match = pattern.search(text)
        if not match:
            continue

        groups = match.groups()
        if len(groups) != 3:
            continue

        # Format 1: YYYY-MM-DD
        if len(groups[0]) == 4:
            yyyy, mm, dd = groups[0], groups[1].zfill(2), groups[2].zfill(2)
            return f"{yyyy}-{mm}-{dd}"

        # Format 2 or 3: DD-MM-YYYY or DD-Mon-YYYY
        dd = groups[0].zfill(2)
        month_part = groups[1].lower()
        year_part = groups[2]
        if len(year_part) == 2:
            year_part = f"20{year_part}"

        if month_part.isdigit():
            mm = month_part.zfill(2)
        else:
            mm = MONTH_NAME_MAP.get(month_part[:3], "01")

        return f"{year_part}-{mm}-{dd}"

    return None


def extract_account_reference(text: str) -> Optional[str]:
    """Extracts and safely masks the account reference (e.g. XX1234)."""
    for pattern in ACCOUNT_REF_PATTERNS:
        match = pattern.search(text)
        if match:
            raw = match.group(1).strip()
            # If already masked like XX1234 or *1234
            digits = re.findall(r"\d", raw)
            if len(digits) >= 3:
                last_four = "".join(digits[-4:])
                return f"XX{last_four}"
            if len(raw) >= 3:
                return f"XX{raw[-4:]}"
    return None


def extract_merchant(text: str) -> Optional[str]:
    """Extracts merchant name only when deterministic evidence exists."""
    for pattern in MERCHANT_PATTERNS:
        for match in pattern.finditer(text):
            candidate = match.group(1).strip()

            # Handle VPA handles e.g. "swiggy@hdfcbank" -> "SWIGGY"
            if "@" in candidate:
                handle = candidate.split("@")[0].strip()
                if handle and len(handle) >= 2 and handle.lower() not in MERCHANT_STOP_WORDS:
                    return handle.upper()

            # Clean trailing punctuation and noise
            candidate = re.split(
                r"[.,;:\n]|(?:\s+(?:on|dated|ref|txn|avl|bal|vpa|upi|at|to)\b)",
                candidate,
                flags=re.IGNORECASE,
            )[0].strip()

            # Strip surrounding quotes or brackets
            candidate = candidate.strip("\"'()[]{}*#-")

            # Reject stop words or invalid candidates
            tokens = candidate.split()
            if not tokens:
                continue

            clean_tokens = [t for t in tokens if t.lower() not in MERCHANT_STOP_WORDS]
            if not clean_tokens:
                continue

            final_name = " ".join(clean_tokens).strip()

            # Avoid purely numeric or single char candidates
            if len(final_name) < 2 or final_name.replace(" ", "").isdigit():
                continue

            return final_name.upper()

    return None


def calculate_confidence(
    classification: SMSClassification,
    is_transaction: bool,
    amount: Optional[float],
    transaction_type: TransactionType,
    merchant: Optional[str],
    account_reference: Optional[str],
) -> Tuple[ConfidenceLevel, List[str]]:
    """Calculates deterministic confidence level based on extracted evidence."""
    reasons: List[str] = []

    if classification == SMSClassification.FINANCIAL_TRANSACTION:
        score = 0
        if amount is not None and amount > 0:
            score += 2
            reasons.append("Valid transaction amount extracted")
        if transaction_type in (TransactionType.DEBIT, TransactionType.CREDIT):
            score += 2
            reasons.append(f"Confirmed transaction type: {transaction_type.value}")
        if merchant:
            score += 1
            reasons.append(f"Merchant identified: {merchant}")
        if account_reference:
            score += 1
            reasons.append(f"Account reference confirmed: {account_reference}")

        if score >= 4:
            return ConfidenceLevel.HIGH, reasons
        elif score >= 2:
            return ConfidenceLevel.MEDIUM, reasons
        else:
            return ConfidenceLevel.LOW, reasons

    elif classification == SMSClassification.FINANCIAL_NON_TRANSACTION:
        reasons.append("Deterministic non-transaction financial pattern")
        return ConfidenceLevel.HIGH, reasons

    elif classification == SMSClassification.NON_FINANCIAL:
        reasons.append("Deterministic non-financial pattern")
        return ConfidenceLevel.HIGH, reasons

    reasons.append("Insufficient signals for deterministic confidence")
    return ConfidenceLevel.LOW, reasons


def generate_sms_fingerprint(
    text: str,
    sender: Optional[str] = None,
    timestamp: Optional[str] = None,
) -> str:
    """Generates a stable, deterministic SHA-256 fingerprint for duplicate detection.

    Normalizes whitespace and case to prevent formatting variations from altering hash.
    """
    normalized_text = " ".join(text.strip().lower().split())
    normalized_sender = (sender or "").strip().lower()
    normalized_ts = (timestamp or "").strip()

    raw_key = f"{normalized_sender}|{normalized_text}|{normalized_ts}"
    return hashlib.sha256(raw_key.encode("utf-8")).hexdigest()


class SMSParser:
    """Combines detection and field extraction into a complete ParsedFinancialSMS model."""

    @classmethod
    def parse(
        cls,
        text: str,
        sender: Optional[str] = None,
        timestamp: Optional[str] = None,
    ) -> ParsedFinancialSMS:
        """Parses an SMS text deterministically into a structured ParsedFinancialSMS object."""
        from .detector import SMSDetector

        classification, detect_reasons = SMSDetector.classify(text, sender=sender)
        is_financial = classification in (
            SMSClassification.FINANCIAL_TRANSACTION,
            SMSClassification.FINANCIAL_NON_TRANSACTION,
        )
        is_transaction = classification == SMSClassification.FINANCIAL_TRANSACTION

        # Extract structured fields
        amount, available_balance = extract_amounts(text, classification)
        tx_type = extract_transaction_type(text) if is_transaction else TransactionType.UNKNOWN
        merchant = extract_merchant(text) if is_transaction else None
        payment_method = extract_payment_method(text) if is_financial else PaymentMethod.UNKNOWN
        date = extract_date(text) if is_financial else None
        account_ref = extract_account_reference(text) if is_financial else None

        # Calculate confidence
        confidence, conf_reasons = calculate_confidence(
            classification=classification,
            is_transaction=is_transaction,
            amount=amount,
            transaction_type=tx_type,
            merchant=merchant,
            account_reference=account_ref,
        )

        all_reasons = detect_reasons + conf_reasons

        # Deterministic fingerprint
        fingerprint = generate_sms_fingerprint(text, sender=sender, timestamp=timestamp)

        return ParsedFinancialSMS(
            classification=classification,
            is_financial=is_financial,
            is_transaction=is_transaction,
            amount=amount,
            transaction_type=tx_type,
            merchant=merchant,
            payment_method=payment_method,
            transaction_date=date,
            available_balance=available_balance,
            account_reference=account_ref,
            sender=sender,
            confidence=confidence,
            reasons=all_reasons,
            fingerprint=fingerprint,
        )
