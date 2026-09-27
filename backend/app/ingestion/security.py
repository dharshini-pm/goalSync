"""Security and cryptographic signature helpers for GoalSync webhooks.

Uses HMAC-SHA256 over UTF-8 encoded JSON payloads with constant-time verification.
"""

from __future__ import annotations

import hmac
import hashlib


def compute_hmac_signature(payload: str, secret: str) -> str:
    """Computes a hexadecimal HMAC-SHA256 signature for the given payload string.

    Never logs or exposes the secret string.
    """
    if not secret:
        raise ValueError("Cannot compute signature: secret is empty")
    key_bytes = secret.encode("utf-8")
    payload_bytes = payload.encode("utf-8")
    return hmac.new(key_bytes, payload_bytes, hashlib.sha256).hexdigest()


def verify_hmac_signature(payload: str, secret: str, signature: str) -> bool:
    """Verifies a signature using constant-time comparison to prevent timing attacks."""
    if not secret or not signature:
        return False
    expected = compute_hmac_signature(payload, secret)
    return hmac.compare_digest(expected, signature.strip().lower())
