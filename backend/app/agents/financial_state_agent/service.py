"""Service layer for orchestrating the GoalSync Financial State Agent."""

from typing import Optional
from .models import FinancialStateAgentInput, FinancialStateAgentResult
from .agent import FinancialStateAgent
from .llm_client import OllamaClient
from app.agents.transaction_agent.service import OllamaUnavailableError


class FinancialStateAgentService:
    """High-level orchestration service for interpreting financial snapshots via FinancialStateAgent."""

    def __init__(self, agent: Optional[FinancialStateAgent] = None):
        self.agent = agent or FinancialStateAgent()

    def analyze(self, snapshot: FinancialStateAgentInput) -> FinancialStateAgentResult:
        """Analyzes and interprets a deterministic financial snapshot using the agent.

        Flow:
        1. Validate input contract (Pydantic model)
        2. Verify local Ollama readiness (fails fast with OllamaUnavailableError if offline)
        3. Execute Agent reasoning workflow
        4. Return validated FinancialStateAgentResult
        """
        if not isinstance(snapshot, FinancialStateAgentInput):
            raise ValueError(f"Expected FinancialStateAgentInput, got {type(snapshot).__name__}")

        # Check local Ollama readiness without fabricating AI results
        if not self.agent.llm_client.is_available():
            raise OllamaUnavailableError(
                f"Local Ollama server is not accessible at {self.agent.llm_client.base_url}. "
                "Ensure Ollama is running ('ollama serve') locally."
            )

        if not self.agent.llm_client.is_model_available():
            raise OllamaUnavailableError(
                f"Configured model '{self.agent.llm_client.model}' is not installed in local Ollama. "
                f"Run 'ollama pull {self.agent.llm_client.model}' to download the model."
            )

        return self.agent.run(snapshot)

    def analyze_from_values(
        self,
        monthly_income: float,
        monthly_expenses: float,
        monthly_surplus: float,
        savings_rate: float,
        total_emi: float = 0.0,
        available_monthly_amount: float = 0.0,
        current_savings: float = 0.0,
        transaction_inflow: Optional[float] = None,
        transaction_outflow: Optional[float] = None,
        debt_to_income_ratio: Optional[float] = None,
        emergency_fund_months: Optional[float] = None,
    ) -> FinancialStateAgentResult:
        """Convenience method constructing FinancialStateAgentInput from individual deterministic values."""
        snapshot = FinancialStateAgentInput(
            monthly_income=monthly_income,
            monthly_expenses=monthly_expenses,
            monthly_surplus=monthly_surplus,
            savings_rate=savings_rate,
            total_emi=total_emi,
            available_monthly_amount=available_monthly_amount,
            current_savings=current_savings,
            transaction_inflow=transaction_inflow,
            transaction_outflow=transaction_outflow,
            debt_to_income_ratio=debt_to_income_ratio,
            emergency_fund_months=emergency_fund_months,
        )
        return self.analyze(snapshot)

    @classmethod
    def create_default(
        cls,
        ollama_base_url: Optional[str] = None,
        ollama_model: Optional[str] = None,
    ) -> "FinancialStateAgentService":
        """Factory method to construct a fully initialized FinancialStateAgentService."""
        client = OllamaClient(base_url=ollama_base_url, model=ollama_model)
        agent = FinancialStateAgent(llm_client=client)
        return cls(agent=agent)
