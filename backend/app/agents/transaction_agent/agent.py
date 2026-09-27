"""Core Transaction Agent implementation using local LLM reasoning."""

from typing import Optional
from .models import TransactionAgentInput, TransactionAgentResult
from .prompts import TRANSACTION_AGENT_SYSTEM_PROMPT, build_transaction_user_prompt
from .llm_client import OllamaClient


class TransactionAgent:
    """Agent that reasons over a structured transaction using local LLM inference."""

    def __init__(self, llm_client: Optional[OllamaClient] = None):
        self.llm_client = llm_client or OllamaClient()

    def run(self, input_data: TransactionAgentInput) -> TransactionAgentResult:
        """Executes the agent reasoning workflow on the structured transaction input.

        Args:
            input_data: Validated TransactionAgentInput containing transaction facts
                        and deterministic/RAG evidence.

        Returns:
            TransactionAgentResult strictly validated against the required schema.

        Raises:
            ValueError: If input validation fails or output schema validation fails.
            OllamaError: If LLM invocation or response decoding fails.
        """
        if not isinstance(input_data, TransactionAgentInput):
            raise ValueError(
                f"Expected TransactionAgentInput, got {type(input_data).__name__}"
            )

        # 1. Build prompt context
        user_prompt = build_transaction_user_prompt(input_data)

        # 2. Query local Ollama model for structured JSON
        raw_output = self.llm_client.generate_json(
            system_prompt=TRANSACTION_AGENT_SYSTEM_PROMPT,
            user_prompt=user_prompt,
            temperature=0.0,
        )

        # 3. Parse and strictly validate the structured result
        result = TransactionAgentResult.from_dict(raw_output)

        # 4. Enforce RAG Ground-Truth Guardrail:
        # If confident RAG knowledge was supplied (EXACT or ALIAS match) and the model
        # did not set the merchant_name, override or align it with verified ground truth.
        if (
            input_data.merchant_rag_result
            and input_data.merchant_rag_confidence in ["EXACT", "ALIAS"]
        ):
            # If model hallucinated or changed the merchant away from verified RAG ground truth
            if result.merchant_name.lower() != input_data.merchant_rag_result.lower():
                # Re-align with deterministic ground truth
                result.merchant_name = input_data.merchant_rag_result

            # Ensure high confidence when deterministic RAG evidence is verified
            if input_data.merchant_rag_confidence == "EXACT":
                result.confidence = "high"

        return result
