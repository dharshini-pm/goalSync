import secrets
from datetime import datetime, timezone
from sqlalchemy.orm import declarative_base

Base = declarative_base()


def generate_id() -> str:
    """Generates a 24-character hexadecimal ID string (consistent with 24-char hex format)."""
    return secrets.token_hex(12)


def utc_now() -> datetime:
    """Returns current UTC datetime with timezone awareness."""
    return datetime.now(timezone.utc)
