"""FastAPI Route for Real-time Transaction Processing Pipeline (FastAPI -> LangGraph)."""


from __future__ import annotations

import json
import logging
from typing import Optional
from fastapi import APIRouter, Header, HTTPException, Request, status
from fastapi.responses import JSONResponse
from pydantic import ValidationError

from app.pipeline.models import (
    ProcessTransactionRequest,
    ProcessTransactionResponse,
)
from app.pipeline.service import TransactionPipelineService
from app.pipeline.user_resolver import UserResolutionError

logger = logging.getLogger("goalsync.pipeline.route")

router = APIRouter(tags=["Transaction Pipeline"])

_pipeline_service: Optional[TransactionPipelineService] = None


def get_pipeline_service() -> TransactionPipelineService:
    global _pipeline_service
    if _pipeline_service is None:
        _pipeline_service = TransactionPipelineService()
    return _pipeline_service


def set_pipeline_service(service: Optional[TransactionPipelineService]) -> None:
    """Helper to inject mock service in tests."""
    global _pipeline_service
    _pipeline_service = service


@router.post(
    "/api/v1/process-transaction",
    response_model=ProcessTransactionResponse,
    status_code=status.HTTP_200_OK,
    summary="Process structured financial transaction",
)
async def process_transaction_endpoint(
    request: Request,
):
    """Production endpoint connecting structured transaction input to GoalSync LangGraph multi-agent pipeline."""
    raw_body_bytes = await request.body()
    try:
        raw_body_str = raw_body_bytes.decode("utf-8")
    except UnicodeDecodeError:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Payload must be valid UTF-8 encoded JSON.",
        )

    pipeline_svc = get_pipeline_service()


    # 2. Parse & Validate Payload
    try:
        payload_data = json.loads(raw_body_str)
    except json.JSONDecodeError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"Malformed JSON payload: {str(exc)}",
        )

    if not isinstance(payload_data, dict):
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Payload must be a JSON object.",
        )

    try:
        event = ProcessTransactionRequest.model_validate(payload_data)
    except ValidationError as exc:
        clean_errors = [
            {"loc": list(err["loc"]), "msg": err["msg"], "type": err["type"]}
            for err in exc.errors()
        ]
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=clean_errors,
        )

    # 3. User Resolution & Pipeline Processing
    try:
        response = pipeline_svc.process_transaction_event(event)
    except UserResolutionError as exc:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=str(exc),
        )
    except Exception as exc:
        logger.error("Unhandled pipeline exception: %s", type(exc).__name__)
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content={
                "success": False,
                "status": "failed",
                "event_id": event.event_id or event.fingerprint,
                "error": "Internal processing failure.",
            },
        )

    if not response.success and response.status == "failed":
        return JSONResponse(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            content=response.model_dump(),
        )

    return response
