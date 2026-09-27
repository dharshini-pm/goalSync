"""Regex patterns and keyword constants for Indian banking and financial SMS detection."""

import re

# ---------------------------------------------------------------------------
# OTP & Security Tokens (Highest precedence non-financial signals)
# ---------------------------------------------------------------------------
OTP_PATTERNS = [
    re.compile(r"\b(?:otp|one\s*time\s*password)\b", re.IGNORECASE),
    re.compile(r"\b(?:verification|security|secret|authorization|mfa)\s*code\b", re.IGNORECASE),
    re.compile(r"\bis\s+your\s+(?:login\s+|verification\s+|one\s*time\s*)?(?:otp|password|code)\b", re.IGNORECASE),
    re.compile(r"\bdo\s+not\s+share\s+(?:your\s+)?(?:otp|password|code|mpin|pin)\b", re.IGNORECASE),
    re.compile(r"\buse\s+(?:code|otp)\s+\d{4,8}\b", re.IGNORECASE),
]

# ---------------------------------------------------------------------------
# Non-financial Notifications (Delivery, Greetings, Telecom Promos)
# ---------------------------------------------------------------------------
NON_FINANCIAL_PATTERNS = [
    re.compile(r"\b(?:delivered|out\s+for\s+delivery|shipment|dispatched|package|tracking\s+id)\b", re.IGNORECASE),
    re.compile(r"\b(?:happy\s+birthday|anniversary|greetings|congratulations)\b", re.IGNORECASE),
    re.compile(r"\b(?:recharge\s+successful\s+for\s+(?:your\s+)?mobile|talktime|data\s+pack|gb/day|unlimited\s+calls)\b", re.IGNORECASE),
    re.compile(r"\b(?:flat\s+\d+%\s+off|special\s+discount|mega\s+sale|exclusive\s+offer|cashback\s+offer)\b", re.IGNORECASE),
]

# ---------------------------------------------------------------------------
# Financial Non-Transaction (Reminders, Statements, Due Dates, Balance Check)
# ---------------------------------------------------------------------------
BILL_DUE_PATTERNS = [
    re.compile(r"\b(?:bill\s+due|payment\s+due|due\s+date|due\s+on)\b", re.IGNORECASE),
    re.compile(r"\b(?:minimum\s+amount\s+due|total\s+amount\s+due)\b", re.IGNORECASE),
    re.compile(r"\b(?:emi\s+is\s+due|emi\s+due|loan\s+emi|reminder:?\s+your\s+emi)\b", re.IGNORECASE),
    re.compile(r"\b(?:statement\s+(?:for\s+your|generated|is\s+ready))\b", re.IGNORECASE),
]

BALANCE_ONLY_PATTERNS = [
    re.compile(r"\b(?:your\s+)?(?:account\s+balance|acct\s+bal|a/c\s+balance)\s*(?:is|:)\b", re.IGNORECASE),
    re.compile(r"\b(?:avail(?:able)?\s*bal(?:ance)?|avl\s*bal)\s*(?:is|:)?\s*(?:Rs\.?|INR|₹)?\s*[\d,]+(?:\.\d{1,2})?\s*$", re.IGNORECASE),
    re.compile(r"^.*?(?:balance\s+enquiry|clear\s+balance).*$", re.IGNORECASE),
]

# ---------------------------------------------------------------------------
# Transaction Indicators (Verbs & Directions)
# ---------------------------------------------------------------------------
DEBIT_VERBS = [
    re.compile(r"\bdebited\b", re.IGNORECASE),
    re.compile(r"\bdebit\b(?!\s*card)", re.IGNORECASE),
    re.compile(r"\bpaid\b", re.IGNORECASE),
    re.compile(r"\bpayment\s+(?:of|to|for|successful)\b", re.IGNORECASE),
    re.compile(r"\bspent\b", re.IGNORECASE),
    re.compile(r"\bwithdrawn\b", re.IGNORECASE),
    re.compile(r"\bdeducted\b", re.IGNORECASE),
    re.compile(r"\bpurchase(?:\s+at|\s+of)?\b", re.IGNORECASE),
    re.compile(r"\btransferred\s+to\b", re.IGNORECASE),
    re.compile(r"\bsent\s+to\b", re.IGNORECASE),
]

CREDIT_VERBS = [
    re.compile(r"\bcredited\b", re.IGNORECASE),
    re.compile(r"\bcredit\b(?!\s*card)", re.IGNORECASE),
    re.compile(r"\breceived\b", re.IGNORECASE),
    re.compile(r"\bdeposited\b", re.IGNORECASE),
    re.compile(r"\brefunded\b", re.IGNORECASE),
    re.compile(r"\breversal\b", re.IGNORECASE),
    re.compile(r"\bcashback\s+of\b", re.IGNORECASE),
]

# ---------------------------------------------------------------------------
# Currency & Amount Regexes
# ---------------------------------------------------------------------------
# Clean amount pattern
CURRENCY_PREFIX = r"(?:Rs\.?|INR|₹)\s*"
AMOUNT_PATTERN = r"([\d,]+(?:\.\d{1,2})?)"

# Balance extraction regex (specifically targeted at the available balance sentence)
BALANCE_EXTRACT_PATTERNS = [
    re.compile(
        r"(?:Avail(?:able)?\s*Bal(?:ance)?|Avl\s*Bal|A/c\s*Bal(?:ance)?|Balance|Bal)\s*(?:is|:|\.)?\s*"
        + CURRENCY_PREFIX + AMOUNT_PATTERN,
        re.IGNORECASE,
    ),
    re.compile(
        CURRENCY_PREFIX + AMOUNT_PATTERN
        + r"\s*(?:is\s+your\s+)?(?:avail(?:able)?\s*bal(?:ance)?|avl\s*bal)",
        re.IGNORECASE,
    ),
]

# Transaction amount extraction patterns associated with transaction verbs
TRANSACTION_AMOUNT_PATTERNS = [
    # "debited by Rs.450.00" / "credited with INR 2,500" / "withdrawn Rs. 500"
    re.compile(
        r"(?:debited\s*(?:by|with)?|credited\s*(?:by|with)?|paid|payment\s*of|spent|transferred\s*(?:of)?|withdrawn\s*(?:of)?|purchase\s*of|cashback\s*of|deducted\s*(?:by)?)\s*"
        + CURRENCY_PREFIX + AMOUNT_PATTERN,
        re.IGNORECASE,
    ),
    # "Rs.450.00 debited" / "INR 2500 credited" / "Rs 350 paid"
    re.compile(
        CURRENCY_PREFIX + AMOUNT_PATTERN
        + r"\s*(?:is|has\s+been|was)?\s*(?:debited|credited|paid|transferred|withdrawn|deducted|spent)",
        re.IGNORECASE,
    ),
    # "UPI payment of Rs.350"
    re.compile(
        r"(?:UPI\s+payment\s+of|card\s+payment\s+of|transaction\s+of)\s*"
        + CURRENCY_PREFIX + AMOUNT_PATTERN,
        re.IGNORECASE,
    ),
    # "sent Rs.350 to"
    re.compile(
        r"(?:sent|transferred)\s*" + CURRENCY_PREFIX + AMOUNT_PATTERN + r"\s*(?:to|towards)",
        re.IGNORECASE,
    ),
]

# General standalone currency amount (fallback when verb isn't immediately adjacent)
GENERAL_AMOUNT_PATTERN = re.compile(
    CURRENCY_PREFIX + AMOUNT_PATTERN,
    re.IGNORECASE,
)

# ---------------------------------------------------------------------------
# Account Reference Extraction
# ---------------------------------------------------------------------------
ACCOUNT_REF_PATTERNS = [
    # "A/c XX1234", "Acct no. *1234", "Account ending 1234"
    re.compile(r"(?:A/c|Acct|Account|Card)\s*(?:no\.?|ending|number)?\s*[:\s]*([X*x#\d]{2,16}\d{3,4})", re.IGNORECASE),
    re.compile(r"\b([X*x#]{2,12}\d{3,4})\b"),
    re.compile(r"\bending\s+(?:with\s+)?(\d{3,4})\b", re.IGNORECASE),
]

# ---------------------------------------------------------------------------
# Payment Method Patterns
# ---------------------------------------------------------------------------
PAYMENT_METHOD_PATTERNS = [
    (re.compile(r"\b(?:upi|vpa|gpay|google\s*pay|phonepe|paytm|bhim)\b", re.IGNORECASE), "UPI"),
    (re.compile(r"\b(?:atm|cash\s*withdrawal|at\s+atm)\b", re.IGNORECASE), "ATM"),
    (re.compile(r"\b(?:debit\s*card|credit\s*card|visa|mastercard|rupay|card\s+ending)\b", re.IGNORECASE), "CARD"),
    (re.compile(r"\b(?:imps)\b", re.IGNORECASE), "IMPS"),
    (re.compile(r"\b(?:neft)\b", re.IGNORECASE), "NEFT"),
    (re.compile(r"\b(?:net\s*banking|bank\s*transfer|rtgs)\b", re.IGNORECASE), "BANK_TRANSFER"),
]

# ---------------------------------------------------------------------------
# Date Extraction Patterns
# ---------------------------------------------------------------------------
MONTH_NAME_MAP = {
    "jan": "01", "january": "01",
    "feb": "02", "february": "02",
    "mar": "03", "march": "03",
    "apr": "04", "april": "04",
    "may": "05",
    "jun": "06", "june": "06",
    "jul": "07", "july": "07",
    "aug": "08", "august": "08",
    "sep": "09", "september": "09",
    "oct": "10", "october": "10",
    "nov": "11", "november": "11",
    "dec": "12", "december": "12",
}

DATE_PATTERNS = [
    # YYYY-MM-DD
    re.compile(r"\b(20\d{2})[-/.](0[1-9]|1[0-2])[-/.](0[1-9]|[12]\d|3[01])\b"),
    # DD-MM-YYYY or DD/MM/YYYY or DD.MM.YYYY
    re.compile(r"\b(0[1-9]|[12]\d|3[01])[-/.](0[1-9]|1[0-2])[-/.](20\d{2}|\d{2})\b"),
    # DD-Mon-YYYY or DD Mon YYYY (e.g., 26-Sep-2026, 26 Sep 2026)
    re.compile(
        r"\b(0[1-9]|[12]\d|3[01])[-/\s]([A-Za-z]{3,9})[-/\s](20\d{2}|\d{2})\b",
        re.IGNORECASE,
    ),
]

# ---------------------------------------------------------------------------
# Merchant Extraction Patterns
# ---------------------------------------------------------------------------
MERCHANT_STOP_WORDS = {
    "your", "the", "an", "a", "account", "acct", "a/c", "rs", "inr", "upi",
    "avl", "avail", "bal", "balance", "on", "dated", "ref", "txn", "txnid",
    "info", "trf", "via", "through", "using", "successful", "completed",
    "bank", "card", "vpa", "atm", "branch", "sms", "not", "call", "help",
    "customer", "care", "dear", "user", "is", "at", "to", "for", "towards",
}

MERCHANT_PATTERNS = [
    # "debited by Rs.450.00 at SWIGGY" / "paid to ZOMATO" / "towards LIC"
    re.compile(
        r"\b(?:at|to|towards)\s+([A-Za-z0-9&.\-_]+(?:\s+[A-Za-z0-9&.\-_]+){0,2})",
        re.IGNORECASE,
    ),
    # "VPA swiggy@hdfcbank" / "to VPA zomato@icici"
    re.compile(r"\b(?:VPA|vpa)\s+([a-zA-Z0-9.\-_]+@[a-zA-Z0-9]+)", re.IGNORECASE),
    # "info: SWIGGY" / "trf to SWIGGY"
    re.compile(r"\b(?:info[:\s]+|trf\s+to\s+)([A-Za-z0-9&.\-_]+)", re.IGNORECASE),
    # "for <MERCHANT>" when not followed by currency or digits (e.g. not "for Rs. 500")
    re.compile(
        r"\bfor\s+(?!(?:Rs\.?|INR|₹|\d))\s*([A-Za-z0-9&.\-_]+(?:\s+[A-Za-z0-9&.\-_]+){0,2})",
        re.IGNORECASE,
    ),
]
