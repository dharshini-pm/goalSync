"""Configuration settings for n8n webhook delivery and SMS ingestion."""

import os
from typing import Optional


class IngestionConfig:
    """Ingestion and webhook configuration loaded from environment variables."""

    @classmethod
    def get_webhook_url(cls) -> Optional[str]:
        url = os.getenv("GOALSYNC_N8N_WEBHOOK_URL", "").strip()
        return url if url else None

    @classmethod
    def get_webhook_secret(cls) -> Optional[str]:
        secret = os.getenv("GOALSYNC_WEBHOOK_SECRET", "").strip()
        return secret if secret else None

    @classmethod
    def get_timeout(cls) -> int:
        try:
            return int(os.getenv("GOALSYNC_WEBHOOK_TIMEOUT", "10"))
        except ValueError:
            return 10

    @classmethod
    def get_max_retries(cls) -> int:
        try:
            return int(os.getenv("GOALSYNC_WEBHOOK_RETRIES", "3"))
        except ValueError:
            return 3
