"""Production transaction pipeline service for GoalSync.

Orchestrates:
n8n Webhook -> HMAC Validation -> User Resolution -> Idempotency Guard ->
MongoDB Transaction -> Deterministic Financial Context -> LangGraph Multi-Agent -> MongoDB Persistence.
"""

from __future__ import annotations

import dataclasses
import datetime
import logging
import math
import os
import uuid
from typing import Any, Dict, List, Optional, Tuple

from app.config import settings
from app.database import get_collection, DuplicateKeyError
from app.ingestion.config import IngestionConfig
from app.ingestion.security import verify_hmac_signature
from app.orchestration.service import GoalSyncGraphService
from app.rag.service import MerchantHybridResolutionService
from .models import (
    ProcessTransactionRequest,
    ProcessTransactionResponse,
    ProcessingStageInfo,
)
from .user_resolver import UserResolverService, UserResolutionError

logger = logging.getLogger("goalsync.pipeline")


class TransactionPipelineService:
    """Production service orchestrating transaction ingestion through LangGraph."""

    def __init__(
        self,
        graph_service: Optional[GoalSyncGraphService] = None,
        rag_service: Optional[MerchantHybridResolutionService] = None,
        user_resolver: Optional[UserResolverService] = None,
        db_database=None,
    ) -> None:
        self._graph_service = graph_service
        self._rag_service = rag_service
        self._user_resolver = user_resolver or UserResolverService()
        self._db = db_database

    @property
    def graph_service(self) -> GoalSyncGraphService:
        if self._graph_service is None:
            self._graph_service = GoalSyncGraphService()
        return self._graph_service

    @property
    def rag_service(self) -> Optional[MerchantHybridResolutionService]:
        if self._rag_service is None:
            try:
                self._rag_service = MerchantHybridResolutionService.create_default()
            except Exception as e:
                logger.warning("Merchant RAG service initialization failed: %s", type(e).__name__)
                self._rag_service = None
        return self._rag_service

    def get_collection(self, name: str):
        if self._db is not None:
            return self._db[name]
        return get_collection(name)

    @classmethod
    def get_configured_hmac_secret(cls) -> Optional[str]:
        """Resolves the configured HMAC secret from environment variables."""
        secret = (
            os.getenv("GOALSYNC_N8N_HMAC_SECRET", "").strip()
            or getattr(settings, "GOALSYNC_N8N_HMAC_SECRET", "").strip()
            or os.getenv("GOALSYNC_WEBHOOK_SECRET", "").strip()
            or IngestionConfig.get_webhook_secret()
            or ""
        )
        return secret if secret else None

    def verify_request_signature(
        self,
        payload_body: str,
        signature: Optional[str],
    ) -> bool:
        """Verifies the HMAC-SHA256 signature using constant-time comparison."""
        secret = self.get_configured_hmac_secret()
        if not secret or not signature:
            return False

        # Validate hex signature format (must be 64-char hex for SHA-256)
        sig_clean = signature.strip().lower()
        if len(sig_clean) != 64:
            return False
        try:
            int(sig_clean, 16)
        except ValueError:
            return False

        return verify_hmac_signature(payload_body, secret, sig_clean)

    def process_transaction_event(
        self,
        event: ProcessTransactionRequest,
    ) -> ProcessTransactionResponse:
        """Processes a validated structured transaction event through the pipeline."""
        now = datetime.datetime.now(datetime.timezone.utc)
        event_id = event.event_id or f"evt_{uuid.uuid4().hex[:16]}"

        # 1. Resolve & authenticate user
        user_doc = self._user_resolver.resolve_user(
            user_id=event.user_id,
            device_id=event.device_id,
        )
        user_id_str = str(user_doc["_id"])

        proc_coll = self.get_collection("transaction_processing_records")
        tx_coll = self.get_collection("transactions")

        # 2. Check Idempotency / Duplicate Detection
        existing_record = proc_coll.find_one({
            "userId": user_id_str,
            "$or": [
                {"eventId": event_id},
                {"fingerprint": event.fingerprint},
            ],
        })

        if existing_record and existing_record.get("status") == "PROCESSED":
            tx_id_str = str(existing_record.get("transactionId", ""))
            logger.info("Duplicate event ignored: event_id=%s, user=%s", event_id, user_id_str)
            return ProcessTransactionResponse(
                success=True,
                status="duplicate",
                event_id=event_id,
                transaction_id=tx_id_str if tx_id_str else None,
            )

        # 3. Create or resume processing record atomically
        is_retry = False
        if existing_record:
            is_retry = True
            proc_id = existing_record["_id"]
            existing_tx_id = existing_record.get("transactionId")
            tx_id_str = str(existing_tx_id) if existing_tx_id else None
            proc_coll.update_one(
                {"_id": proc_id},
                {"$set": {"status": "PROCESSING", "updatedAt": now}},
            )
        else:
            initial_proc = {
                "userId": user_id_str,
                "eventId": event_id,
                "fingerprint": event.fingerprint,
                "status": "PROCESSING",
                "source": event.source,
                "createdAt": now,
                "updatedAt": now,
            }
            try:
                proc_res = proc_coll.insert_one(initial_proc)
                proc_id = proc_res.inserted_id
                tx_id_str = None
            except DuplicateKeyError:
                # Concurrent request race condition caught by unique index
                rec = proc_coll.find_one({
                    "userId": user_id_str,
                    "$or": [
                        {"eventId": event_id},
                        {"fingerprint": event.fingerprint},
                    ],
                })
                tx_id_str = str(rec.get("transactionId", "")) if rec else ""
                return ProcessTransactionResponse(
                    success=True,
                    status="duplicate",
                    event_id=event_id,
                    transaction_id=tx_id_str if tx_id_str else None,
                )

        # 4. Resolve Merchant via RAG
        merchant_name = event.merchant or "Unknown Merchant"
        det_category = "General Expense" if event.transaction_type.upper() == "DEBIT" else "General Income"
        rag_merchant: Optional[str] = None
        rag_confidence: Optional[str] = None

        if self.rag_service is not None:
            try:
                resolution = self.rag_service.resolve(merchant_name)
                if resolution.matched:
                    rag_merchant = resolution.merchant_name
                    det_category = resolution.category
                    rag_confidence = resolution.confidence.value
            except Exception as e:
                logger.warning("RAG lookup failed: %s", type(e).__name__)

        # 5. Persist Transaction in SQLite
        if tx_id_str is None:
            # Parse transaction datetime
            tx_dt = now
            if event.transaction_date:
                try:
                    tx_dt = datetime.datetime.fromisoformat(event.transaction_date)
                    if tx_dt.tzinfo is None:
                        tx_dt = tx_dt.replace(tzinfo=datetime.timezone.utc)
                except Exception:
                    tx_dt = now

            tx_doc = {
                "userId": user_id_str,
                "amount": float(event.amount),
                "type": "debit" if event.transaction_type.upper() == "DEBIT" else "credit",
                "merchantName": merchant_name,
                "category": det_category,
                "dateTime": tx_dt,
                "paymentMethod": event.payment_method or "UNKNOWN",
                "notes": f"Processed via GoalSync AI (event {event_id})",
                "source": event.source,
                "eventId": event_id,
                "fingerprint": event.fingerprint,
                "confidence": event.confidence,
                "createdAt": now,
                "updatedAt": now,
            }

            try:
                tx_res = tx_coll.insert_one(tx_doc)
                tx_id_str = str(tx_res.inserted_id)
            except DuplicateKeyError:
                # Transaction already exists for this eventId
                existing_tx = tx_coll.find_one({"userId": user_id_str, "eventId": event_id})
                tx_id_str = str(existing_tx["_id"]) if existing_tx else None

            # Link transaction ID to processing record
            proc_coll.update_one(
                {"_id": proc_id},
                {"$set": {"transactionId": tx_id_str, "updatedAt": now}},
            )

        transaction_id_str = str(tx_id_str) if tx_id_str else ""

        # 6. Build Deterministic Financial Context for LangGraph
        fin_snapshot = self._build_financial_snapshot(user_id_str)
        goal_inputs = self._build_goal_inputs(user_id_str, fin_snapshot)

        transaction_input = {
            "merchant": merchant_name,
            "amount": float(event.amount),
            "transaction_type": "debit" if event.transaction_type.upper() == "DEBIT" else "credit",
            "payment_method": event.payment_method,
            "date": event.transaction_date,
            "deterministic_category": det_category,
            "merchant_rag_result": rag_merchant,
            "merchant_rag_confidence": rag_confidence,
        }

        # 7. Execute LangGraph Multi-Agent Pipeline
        try:
            graph_result = self.graph_service.run(
                transaction_input=transaction_input,
                financial_state_snapshot=fin_snapshot,
                goal_input=goal_inputs,
                user_id=user_id_str,
                request_id=event_id,
                metadata={
                    "event_id": event_id,
                    "fingerprint": event.fingerprint,
                    "source": event.source,
                },
            )
        except Exception as exc:
            logger.error("LangGraph pipeline threw unexpected exception: %s", type(exc).__name__)
            proc_coll.update_one(
                {"_id": proc_id},
                {
                    "$set": {
                        "status": "FAILED",
                        "error": str(exc),
                        "updatedAt": datetime.datetime.now(datetime.timezone.utc),
                    }
                },
            )
            return ProcessTransactionResponse(
                success=False,
                status="failed",
                event_id=event_id,
                transaction_id=transaction_id_str,
                error="Pipeline execution failed unexpectedly.",
            )

        # 8. Handle Pipeline Results & Persist to MongoDB
        completed_stages = graph_result.completed_stages
        trace_data = [dataclasses.asdict(t) for t in graph_result.execution_trace]

        if not graph_result.success:
            err_data = [dataclasses.asdict(e) for e in graph_result.errors]
            proc_coll.update_one(
                {"_id": proc_id},
                {
                    "$set": {
                        "status": "FAILED",
                        "completed_stages": completed_stages,
                        "errors": err_data,
                        "execution_trace": trace_data,
                        "updatedAt": datetime.datetime.now(datetime.timezone.utc),
                    }
                },
            )
            return ProcessTransactionResponse(
                success=False,
                status="failed",
                event_id=event_id,
                transaction_id=transaction_id_str,
                processing=ProcessingStageInfo(
                    completed=False,
                    completed_stages=completed_stages,
                ),
                error="Multi-agent orchestration pipeline failed to complete all required stages.",
            )

        # Successful pipeline completion
        proc_coll.update_one(
            {"_id": proc_id},
            {
                "$set": {
                    "status": "PROCESSED",
                    "completed_stages": completed_stages,
                    "transaction_result": graph_result.transaction_result,
                    "financial_state_result": graph_result.financial_state_result,
                    "goal_result": graph_result.goal_result,
                    "conflict_result": graph_result.conflict_result,
                    "scenario_result": graph_result.scenario_result,
                    "explanation_result": graph_result.explanation_result,
                    "execution_trace": trace_data,
                    "updatedAt": datetime.datetime.now(datetime.timezone.utc),
                }
            },
        )

        return ProcessTransactionResponse(
            success=True,
            status="processed",
            event_id=event_id,
            transaction_id=transaction_id_str,
            processing=ProcessingStageInfo(
                completed=True,
                completed_stages=completed_stages,
            ),
            result={
                "financial_state": graph_result.financial_state_result,
                "goal": graph_result.goal_result,
                "conflict": graph_result.conflict_result,
                "scenario": graph_result.scenario_result,
                "explanation": graph_result.explanation_result,
            },
        )

    def _build_financial_snapshot(self, user_id: str) -> Dict[str, Any]:
        """Calculates deterministic financial snapshot from user's financial profile."""
        fp_coll = self.get_collection("financial_profiles")
        profile = fp_coll.find_one({"userId": str(user_id)})

        if not profile:
            # Deterministic baseline defaults when user has not completed onboarding
            return {
                "monthly_income": 0.0,
                "monthly_expenses": 0.0,
                "monthly_surplus": 0.0,
                "savings_rate": 0.0,
                "total_emi": 0.0,
                "available_monthly_amount": 0.0,
                "current_savings": 0.0,
            }

        monthly_income = float(profile.get("monthlyIncome", 0.0)) + float(profile.get("additionalIncome", 0.0))
        fixed_expenses = float(profile.get("fixedExpenses", 0.0))
        variable_expenses = float(profile.get("variableExpenses", 0.0))
        loan_emi = float(profile.get("monthlyEMI", 0.0))
        current_savings = float(profile.get("currentSavings", 0.0))

        total_expenses = fixed_expenses + variable_expenses + loan_emi
        monthly_surplus = monthly_income - total_expenses
        savings_rate = (monthly_surplus / monthly_income * 100.0) if monthly_income > 0 and monthly_surplus > 0 else 0.0
        available_monthly = max(0.0, monthly_surplus)

        return {
            "monthly_income": monthly_income,
            "monthly_expenses": total_expenses,
            "monthly_surplus": monthly_surplus,
            "savings_rate": savings_rate,
            "total_emi": loan_emi,
            "available_monthly_amount": available_monthly,
            "current_savings": current_savings,
        }

    def _build_goal_inputs(
        self,
        user_id: str,
        fin_snapshot: Dict[str, Any],
    ) -> List[Dict[str, Any]]:
        """Constructs deterministic goal inputs for all active user goals."""
        goals_coll = self.get_collection("goals")
        cursor = goals_coll.find({"userId": str(user_id)}).sort("createdAt", 1)

        available_monthly = float(fin_snapshot.get("available_monthly_amount", 0.0))
        monthly_surplus = float(fin_snapshot.get("monthly_surplus", 0.0))
        current_savings = float(fin_snapshot.get("current_savings", 0.0))
        now = datetime.datetime.now(datetime.timezone.utc)

        goal_inputs: List[Dict[str, Any]] = []

        for g in cursor:
            target_amount = float(g.get("targetAmount", 0.0))
            current_amount = float(g.get("currentAmount", 0.0))
            remaining_amount = max(0.0, target_amount - current_amount)

            target_date_raw = g.get("targetDate")
            if isinstance(target_date_raw, datetime.datetime):
                target_dt = target_date_raw
            elif isinstance(target_date_raw, str):
                try:
                    target_dt = datetime.datetime.fromisoformat(target_date_raw)
                except Exception:
                    target_dt = now + datetime.timedelta(days=365)
            else:
                target_dt = now + datetime.timedelta(days=365)

            if target_dt.tzinfo is None:
                target_dt = target_dt.replace(tzinfo=datetime.timezone.utc)

            days_remaining = max(0, (target_dt.date() - now.date()).days)
            months_remaining = max(1, math.ceil(days_remaining / 30.4375)) if days_remaining > 0 else 0

            req_contrib = (remaining_amount / months_remaining) if months_remaining > 0 else remaining_amount
            surplus_coverage = (available_monthly / req_contrib) if req_contrib > 0 else 1.0
            shortfall = max(0.0, req_contrib - available_monthly)

            feasibility_status = "feasible" if surplus_coverage >= 1.0 else ("tight" if surplus_coverage >= 0.7 else "infeasible")
            feasibility_score = min(100.0, max(0.0, surplus_coverage * 75.0))

            goal_inputs.append({
                "goal_name": g.get("name", "Goal"),
                "goal_category": g.get("category", "General"),
                "priority": g.get("priority", "medium"),
                "target_amount": target_amount,
                "current_amount": current_amount,
                "remaining_amount": remaining_amount,
                "target_date": target_dt.isoformat(),
                "months_remaining": months_remaining,
                "days_remaining": days_remaining,
                "required_monthly_contribution": req_contrib,
                "available_monthly_amount": available_monthly,
                "monthly_shortfall": shortfall,
                "surplus_coverage_ratio": surplus_coverage,
                "feasibility_status": feasibility_status,
                "feasibility_score": feasibility_score,
                "is_achievable_without_savings": available_monthly >= req_contrib,
                "is_achievable_with_savings": (available_monthly * months_remaining + current_savings) >= remaining_amount,
                "current_savings": current_savings,
                "monthly_surplus": monthly_surplus,
            })

        return goal_inputs
