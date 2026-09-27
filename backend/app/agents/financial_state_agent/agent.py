"""Core Financial State Agent implementation using local LLM reasoning."""

from typing import Optional
from .models import (
    FinancialStateAgentInput,
    FinancialStateAgentResult,
    FinancialStatus,
    CashFlowStatus,
)
from .prompts import (
    FINANCIAL_STATE_AGENT_SYSTEM_PROMPT,
    build_financial_state_user_prompt,
)
from .llm_client import OllamaClient


class FinancialStateAgent:
    """Agent that reasons over a deterministic financial snapshot using local LLM inference."""

    def __init__(self, llm_client: Optional[OllamaClient] = None):
        self.llm_client = llm_client or OllamaClient()

    def run(self, snapshot: FinancialStateAgentInput) -> FinancialStateAgentResult:
        """Executes the financial state reasoning workflow on the deterministic snapshot.

        Args:
            snapshot: Validated FinancialStateAgentInput containing deterministic facts.

        Returns:
            FinancialStateAgentResult strictly validated against the required Pydantic schema.

        Raises:
            ValueError: If input validation or schema validation fails.
            OllamaError: If LLM invocation or response decoding fails.
        """
        if not isinstance(snapshot, FinancialStateAgentInput):
            raise ValueError(
                f"Expected FinancialStateAgentInput, got {type(snapshot).__name__}"
            )

        # 1. Build prompt context with deterministic ground-truth signals
        user_prompt = build_financial_state_user_prompt(snapshot)

        # 2. Query local Ollama model for structured JSON
        raw_output = self.llm_client.generate_json(
            system_prompt=FINANCIAL_STATE_AGENT_SYSTEM_PROMPT,
            user_prompt=user_prompt,
            temperature=0.0,
        )

        # 3. Parse and strictly validate the structured result using Pydantic
        result = FinancialStateAgentResult.model_validate(raw_output)

        # 4. Deterministic Guardrails:
        # The deterministic Financial State Engine is the absolute source of truth.
        # If the LLM deviated from deterministic cash flow or deficit status,
        # enforce ground truth.
        expected_cash_flow = snapshot.deterministic_cash_flow_status
        if result.cash_flow_status != expected_cash_flow:
            result.cash_flow_status = expected_cash_flow

        # If deterministic surplus is negative, financial status cannot be STABLE or TIGHT
        if snapshot.monthly_surplus < 0 and result.financial_status != FinancialStatus.NEGATIVE:
            result.financial_status = FinancialStatus.NEGATIVE

        return result
