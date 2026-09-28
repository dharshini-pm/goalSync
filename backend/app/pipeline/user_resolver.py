"""User and device resolution service for GoalSync transaction ingestion.

Resolves incoming webhook events to verified GoalSync users in SQLite.
"""

from __future__ import annotations

import os
from typing import Any, Dict, Optional
from app.database import get_collection
from app.config import settings


class UserResolutionError(ValueError):
    """Raised when an incoming transaction cannot be resolved to a valid user."""
    pass


class UserResolverService:
    """Resolves and validates user identity for incoming transaction events.

    Security & Privacy Rules:
    - Never blindly trusts unverified client input.
    - Resolves user_id strictly against existing users in the SQLite database.
    - If device_id is provided, looks up registered device mappings.
    - In development/test environments, controlled user mappings can be enabled via
      explicit configuration (GOALSYNC_ALLOW_DEV_USER_MAPPING=true).
    """

    def __init__(self, users_collection=None, device_mappings_collection=None) -> None:
        self._users_collection = users_collection
        self._device_mappings_collection = device_mappings_collection

    @property
    def users_coll(self):
        if self._users_collection is None:
            self._users_collection = get_collection("users")
        return self._users_collection

    @property
    def device_mappings_coll(self):
        if self._device_mappings_collection is None:
            self._device_mappings_collection = get_collection("device_mappings")
        return self._device_mappings_collection

    def resolve_user(
        self,
        user_id: Optional[str] = None,
        device_id: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Resolves and returns the verified user document from SQLite database.

        Raises:
            UserResolutionError: If no valid user can be authenticated/found.
        """
        # 1. Direct user_id lookup if provided
        if user_id:
            user_doc = self._find_user_by_id(str(user_id).strip())
            if user_doc:
                return user_doc

        # 2. Device ID mapping lookup
        if device_id:
            mapping = self.device_mappings_coll.find_one({"deviceId": device_id})
            if mapping and "userId" in mapping:
                user_doc = self._find_user_by_id(str(mapping["userId"]))
                if user_doc:
                    return user_doc

            # Also check if user document has deviceId field
            user_doc = self.users_coll.find_one({"deviceId": device_id})
            if user_doc:
                return user_doc

        # 3. Development-only controlled fallback mapping (explicitly enabled)
        dev_mapping_allowed = getattr(settings, "GOALSYNC_ALLOW_DEV_USER_MAPPING", False) or (
            os.getenv("GOALSYNC_ALLOW_DEV_USER_MAPPING", "").lower() in ("true", "1")
        )
        if dev_mapping_allowed:
            dev_user_id = os.getenv("GOALSYNC_DEV_USER_ID", "").strip()
            if dev_user_id:
                dev_user = self._find_user_by_id(dev_user_id)
                if dev_user:
                    return dev_user

        raise UserResolutionError(
            f"User association failed: No verified GoalSync user found for "
            f"user_id='{user_id}' or device_id='{device_id}'. "
            "Ensure the user exists or device is registered."
        )

    def _find_user_by_id(self, user_id_str: str) -> Optional[Dict[str, Any]]:
        """Finds user by string ID in the users collection."""
        if not user_id_str:
            return None
        return self.users_coll.find_one({"_id": str(user_id_str).strip()})
