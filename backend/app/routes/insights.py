"""FastAPI route for GoalSync AI Pipeline Insights.

Provides the authenticated Flutter client with the latest AI pipeline result
for the current user, fetched from the `transaction_processing_records` collection.
"""

from __future__ import annotations

import logging
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel

from app.database import get_collection
from app.dependencies import get_current_user

logger = logging.getLogger("goalsync.insights")

router = APIRouter(prefix="/api/v1/insights", tags=["AI Insights"])


# ---------------------------------------------------------------------------
# Response schemas
# ---------------------------------------------------------------------------

class PipelineInsightResponse(BaseModel):
    """Latest AI pipeline result for the authenticated user."""

    available: bool
    event_id: Optional[str] = None
    transaction_id: Optional[str] = None
    source: Optional[str] = None
    processed_at: Optional[str] = None

    # Agent results
    financial_state: Optional[Dict[str, Any]] = None
    goal: Optional[List[Dict[str, Any]]] = None
    conflict: Optional[Dict[str, Any]] = None
    scenario: Optional[Dict[str, Any]] = None
    explanation: Optional[Dict[str, Any]] = None

    # Execution metadata
    completed_stages: List[str] = []


class InsightHistoryItem(BaseModel):
    """Summary of a past pipeline execution."""
    event_id: Optional[str] = None
    transaction_id: Optional[str] = None
    status: str
    source: Optional[str] = None
    processed_at: Optional[str] = None
    headline: Optional[str] = None


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _dt_to_str(value: Any) -> Optional[str]:
    """Convert a MongoDB datetime to an ISO-8601 string, or return None."""
    if value is None:
        return None
    try:
        return value.isoformat()
    except AttributeError:
        return str(value)


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.get(
    "",
    response_model=PipelineInsightResponse,
    summary="Get latest AI pipeline result for the authenticated user",
)
def get_latest_insight(current_user: dict = Depends(get_current_user)):
    """Returns the most recently processed pipeline result for the user.

    Used by the Flutter AI Copilot tab to surface real LangGraph output.
    Returns `available: false` when no processed records exist yet.
    """
    user_id = str(current_user["_id"])
    coll = get_collection("transaction_processing_records")

    # Most recent PROCESSED record
    record = coll.find_one(
        {"userId": user_id, "status": "PROCESSED"},
        sort=[("updatedAt", -1)],
    )

    if not record:
        return PipelineInsightResponse(available=False)

    goal_result = record.get("goal_result")
    if goal_result is not None and not isinstance(goal_result, list):
        goal_result = [goal_result]

    return PipelineInsightResponse(
        available=True,
        event_id=record.get("eventId"),
        transaction_id=str(record["transactionId"]) if record.get("transactionId") else None,
        source=record.get("source"),
        processed_at=_dt_to_str(record.get("updatedAt")),
        financial_state=record.get("financial_state_result"),
        goal=goal_result,
        conflict=record.get("conflict_result"),
        scenario=record.get("scenario_result"),
        explanation=record.get("explanation_result"),
        completed_stages=record.get("completed_stages", []),
    )


@router.get(
    "/history",
    response_model=List[InsightHistoryItem],
    summary="Get recent pipeline execution history for the authenticated user",
)
def get_insight_history(
    limit: int = 10,
    current_user: dict = Depends(get_current_user),
):
    """Returns recent pipeline execution summaries (up to `limit`).

    Used by the Flutter AI Copilot tab to list prior SMS-triggered analyses.
    """
    if limit < 1 or limit > 50:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="limit must be between 1 and 50",
        )

    user_id = str(current_user["_id"])
    coll = get_collection("transaction_processing_records")

    cursor = (
        coll.find({"userId": user_id})
        .sort("updatedAt", -1)
        .limit(limit)
    )

    items: List[InsightHistoryItem] = []
    for rec in cursor:
        explanation = rec.get("explanation_result") or {}
        headline = (
            explanation.get("headline")
            or explanation.get("summary")
            if isinstance(explanation, dict)
            else None
        )
        items.append(
            InsightHistoryItem(
                event_id=rec.get("eventId"),
                transaction_id=str(rec["transactionId"]) if rec.get("transactionId") else None,
                status=rec.get("status", "UNKNOWN"),
                source=rec.get("source"),
                processed_at=_dt_to_str(rec.get("updatedAt")),
                headline=headline,
            )
        )

    return items
