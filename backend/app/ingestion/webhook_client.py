"""HTTP client for dispatching structured events to the n8n webhook."""

from __future__ import annotations

import json
import logging
import time
from typing import Any, Dict, Optional, Tuple
import requests

from .config import IngestionConfig
from .models import StructuredTransactionEvent
from .security import compute_hmac_signature

logger = logging.getLogger(__name__)


class WebhookDeliveryError(Exception):
    """Raised when an unrecoverable webhook delivery error occurs."""
    pass


class N8nWebhookClient:
    """Client for delivering structured transaction events to n8n."""

    def __init__(
        self,
        webhook_url: Optional[str] = None,
        webhook_secret: Optional[str] = None,
        timeout: Optional[int] = None,
        max_retries: Optional[int] = None,
        session: Optional[requests.Session] = None,
    ) -> None:
        self.webhook_url = webhook_url or IngestionConfig.get_webhook_url()
        self.webhook_secret = webhook_secret or IngestionConfig.get_webhook_secret()
        self.timeout = timeout or IngestionConfig.get_timeout()
        self.max_retries = max_retries or IngestionConfig.get_max_retries()
        self.session = session or requests.Session()

    def send_event(
        self,
        event: StructuredTransactionEvent,
    ) -> Tuple[bool, Optional[int], str, Optional[str]]:
        """Sends a StructuredTransactionEvent to the n8n webhook.

        Returns:
            (success, status_code, message, signature)
        """
        if not self.webhook_url:
            return False, None, "Missing GOALSYNC_N8N_WEBHOOK_URL configuration", None

        payload_dict = event.to_n8n_payload()
        payload_json = json.dumps(payload_dict, separators=(",", ":"))

        headers: Dict[str, str] = {
            "Content-Type": "application/json",
            "X-GoalSync-Source": "android_sms",
        }

        signature: Optional[str] = None
        if self.webhook_secret:
            signature = compute_hmac_signature(payload_json, self.webhook_secret)
            headers["X-GoalSync-Signature"] = signature

        attempt = 0
        last_error = ""

        while attempt < self.max_retries:
            attempt += 1
            try:
                resp = self.session.post(
                    self.webhook_url,
                    data=payload_json,
                    headers=headers,
                    timeout=self.timeout,
                )

                if 200 <= resp.status_code < 300:
                    return True, resp.status_code, "Delivered to n8n successfully", signature

                # If client error (4xx), do not retry
                if 400 <= resp.status_code < 500:
                    return (
                        False,
                        resp.status_code,
                        f"n8n webhook rejected request with HTTP {resp.status_code}",
                        signature,
                    )

                last_error = f"HTTP {resp.status_code}"

            except requests.Timeout:
                last_error = f"Request timed out after {self.timeout}s"
            except requests.ConnectionError as e:
                last_error = f"Connection error: {type(e).__name__}"
            except Exception as e:
                last_error = f"Unexpected error: {type(e).__name__}"

            # Exponential backoff between bounded retries
            if attempt < self.max_retries:
                time.sleep(0.05 * attempt)

        return (
            False,
            None,
            f"Failed to deliver to n8n after {self.max_retries} attempts: {last_error}",
            signature,
        )
