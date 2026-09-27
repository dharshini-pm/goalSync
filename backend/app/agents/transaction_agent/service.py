"""Service layer for executing the GoalSync Transaction Agent pipeline."""

from typing import Optional
from .models import TransactionAgentInput, TransactionAgentResult
from .agent import TransactionAgent
from .llm_client import OllamaClient, OllamaConnectionError, OllamaTimeoutError, OllamaError
from app.rag.service import MerchantHybridResolutionService


class OllamaUnavailableError(OllamaError):
    """Raised when Ollama is required but not reachable or model is missing."""
    pass


class TransactionAgentService:
    """High-level orchestration service for transaction analysis via TransactionAgent."""

    def __init__(
        self,
        agent: Optional[TransactionAgent] = None,
        rag_service: Optional[MerchantHybridResolutionService] = None,
    ):
        self.agent = agent or TransactionAgent()
        self.rag_service = rag_service

    def analyze(self, input_data: TransactionAgentInput) -> TransactionAgentResult:
        """Analyzes a structured transaction input using the agent.

        Flow:
        1. Validate input contract
        2. Verify Ollama availability (fails fast with OllamaUnavailableError if offline)
        3. Execute Agent reasoning
        4. Return validated TransactionAgentResult
        """
        if not isinstance(input_data, TransactionAgentInput):
            raise ValueError(f"Expected TransactionAgentInput, got {type(input_data).__name__}")

        # Check local Ollama readiness without fabricating AI results
        if not self.agent.llm_client.is_available():
            raise OllamaUnavailableError(
                f"Local Ollama server is not accessible at {self.agent.llm_client.base_url}. "
                "Ensure Ollama is installed, running ('ollama serve'), and accessible locally."
            )

        if not self.agent.llm_client.is_model_available():
            raise OllamaUnavailableError(
                f"Configured model '{self.agent.llm_client.model}' is not installed in local Ollama. "
                f"Run 'ollama pull {self.agent.llm_client.model}' to download the model."
            )

        return self.agent.run(input_data)

    def analyze_raw_transaction(
        self,
        merchant: str,
        amount: float,
        transaction_type: str = "debit",
        payment_method: Optional[str] = None,
        date: Optional[str] = None,
    ) -> TransactionAgentResult:
        """Convenience method that enriches a transaction via the RAG layer before invoking the agent.

        Pipeline:
        Raw Transaction -> RAG Layer (Exact/Alias/Semantic) -> Enriched Context -> Transaction Agent
        """
        det_cat: Optional[str] = None
        rag_result: Optional[str] = None
        rag_conf: Optional[str] = None

        if self.rag_service is not None:
            resolution = self.rag_service.resolve(merchant)
            if resolution.matched:
                rag_result = resolution.merchant_name
                det_cat = resolution.category
                rag_conf = resolution.confidence.value

        input_data = TransactionAgentInput(
            merchant=merchant,
            amount=amount,
            transaction_type=transaction_type,
            payment_method=payment_method,
            date=date,
            deterministic_category=det_cat,
            merchant_rag_result=rag_result,
            merchant_rag_confidence=rag_conf,
        )

        return self.analyze(input_data)

    @classmethod
    def create_default(
        cls,
        ollama_base_url: Optional[str] = None,
        ollama_model: Optional[str] = None,
        include_rag: bool = True,
    ) -> "TransactionAgentService":
        """Factory method to construct a fully initialized TransactionAgentService."""
        client = OllamaClient(base_url=ollama_base_url, model=ollama_model)
        agent = TransactionAgent(llm_client=client)

        rag_service = None
        if include_rag:
            try:
                rag_service = MerchantHybridResolutionService.create_default()
            except Exception:
                rag_service = None

        return cls(agent=agent, rag_service=rag_service)
