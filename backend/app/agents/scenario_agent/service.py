"""Service layer for orchestrating the GoalSync Scenario Agent."""

from typing import Any, Dict, List, Optional

from .models import ScenarioAgentInput, ScenarioAgentResult, GoalScenarioSnapshot, ConflictSummary
from .agent import ScenarioAgent
from .llm_client import OllamaClient
from app.agents.transaction_agent.service import OllamaUnavailableError


class ScenarioAgentService:
    """High-level orchestration service for scenario generation via ScenarioAgent."""

    def __init__(self, agent: Optional[ScenarioAgent] = None):
        self.agent = agent or ScenarioAgent()

    def generate(self, snapshot: ScenarioAgentInput) -> ScenarioAgentResult:
        """Generates what-if scenarios from a financial state + goals + conflict snapshot.

        Flow:
        1. Validate input contract (Pydantic)
        2. Verify local Ollama readiness
        3. Execute ScenarioAgent reasoning
        4. Return validated ScenarioAgentResult
        """
        if not isinstance(snapshot, ScenarioAgentInput):
            raise ValueError(f"Expected ScenarioAgentInput, got {type(snapshot).__name__}")

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

    def generate_from_values(
        self,
        monthly_income: float,
        monthly_expenses: float,
        monthly_surplus: float,
        available_monthly_amount: float,
        goals: List[Dict[str, Any]],
        conflict_detected: bool = False,
        conflict_count: int = 0,
        overall_status: str = "NO_CONFLICT",
        conflicts: Optional[List[Dict[str, Any]]] = None,
        current_savings: float = 0.0,
        total_emi: float = 0.0,
        savings_rate: float = 0.0,
    ) -> ScenarioAgentResult:
        """Convenience method constructing ScenarioAgentInput from primitive values."""
        goal_snapshots = [GoalScenarioSnapshot(**g) for g in goals]
        conflict_snapshots = [ConflictSummary(**c) for c in (conflicts or [])]
        snapshot = ScenarioAgentInput(
            monthly_income=monthly_income,
            monthly_expenses=monthly_expenses,
            monthly_surplus=monthly_surplus,
            available_monthly_amount=available_monthly_amount,
            current_savings=current_savings,
            total_emi=total_emi,
            savings_rate=savings_rate,
            goals=goal_snapshots,
            conflict_detected=conflict_detected,
            conflict_count=conflict_count,
            overall_status=overall_status,
            conflicts=conflict_snapshots,
        )
        return self.generate(snapshot)

    @classmethod
    def create_default(
        cls,
        ollama_base_url: Optional[str] = None,
        ollama_model: Optional[str] = None,
        timeout: int = 120,
    ) -> "ScenarioAgentService":
        """Factory method to construct a fully initialized ScenarioAgentService."""
        client = OllamaClient(
            base_url=ollama_base_url,
            model=ollama_model,
            timeout=timeout,
        )
        agent = ScenarioAgent(llm_client=client)
        return cls(agent=agent)
