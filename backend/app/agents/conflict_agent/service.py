"""Service layer for orchestrating the GoalSync Conflict Agent."""

from typing import Any, Dict, List, Optional

from .models import ConflictAgentInput, ConflictAgentResult, GoalConflictSnapshot
from .agent import ConflictAgent
from .llm_client import OllamaClient
from app.agents.transaction_agent.service import OllamaUnavailableError


class ConflictAgentService:
    """High-level orchestration service for conflict detection via ConflictAgent."""

    def __init__(self, agent: Optional[ConflictAgent] = None):
        self.agent = agent or ConflictAgent()

    def analyze(self, snapshot: ConflictAgentInput) -> ConflictAgentResult:
        """Analyzes a financial state + goals snapshot for conflicts.

        Flow:
        1. Validate input contract (Pydantic)
        2. Verify local Ollama readiness
        3. Execute ConflictAgent reasoning
        4. Return validated ConflictAgentResult
        """
        if not isinstance(snapshot, ConflictAgentInput):
            raise ValueError(f"Expected ConflictAgentInput, got {type(snapshot).__name__}")

        if not self.agent.llm_client.is_available():
            raise OllamaUnavailableError(
                f"Local Ollama server is not accessible at {self.agent.llm_client.base_url}. "
                "Ensure Ollama is running ('ollama serve') locally."
            )

        if not self.agent.llm_client.is_model_available():
            raise OllamaUnavailableError(
                f"Model '{self.agent.llm_client.model}' is not installed. "
                f"Run 'ollama pull {self.agent.llm_client.model}' to download it."
            )

        return self.agent.run(snapshot)

    def analyze_from_values(
        self,
        monthly_income: float,
        monthly_expenses: float,
        monthly_surplus: float,
        available_monthly_amount: float,
        goals: List[Dict[str, Any]],
        current_savings: float = 0.0,
        total_emi: float = 0.0,
        savings_rate: float = 0.0,
    ) -> ConflictAgentResult:
        """Convenience method constructing ConflictAgentInput from primitive values."""
        goal_snapshots = [GoalConflictSnapshot(**g) for g in goals]
        snapshot = ConflictAgentInput(
            monthly_income=monthly_income,
            monthly_expenses=monthly_expenses,
            monthly_surplus=monthly_surplus,
            available_monthly_amount=available_monthly_amount,
            current_savings=current_savings,
            total_emi=total_emi,
            savings_rate=savings_rate,
            goals=goal_snapshots,
        )
        return self.analyze(snapshot)

    @classmethod
    def create_default(
        cls,
        ollama_base_url: Optional[str] = None,
        ollama_model: Optional[str] = None,
        timeout: int = 90,
    ) -> "ConflictAgentService":
        """Factory method to construct a fully initialized ConflictAgentService."""
        client = OllamaClient(
            base_url=ollama_base_url,
            model=ollama_model,
            timeout=timeout,
        )
        agent = ConflictAgent(llm_client=client)
        return cls(agent=agent)
