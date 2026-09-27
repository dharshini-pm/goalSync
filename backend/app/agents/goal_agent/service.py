"""Service layer for orchestrating the GoalSync Goal Agent."""

from typing import Any, Dict, List, Optional
from .models import GoalAgentInput, GoalAgentResult
from .agent import GoalAgent
from .llm_client import OllamaClient
from app.agents.transaction_agent.service import OllamaUnavailableError


class GoalAgentService:
    """High-level orchestration service for goal interpretation via GoalAgent."""

    def __init__(self, agent: Optional[GoalAgent] = None):
        self.agent = agent or GoalAgent()

    def analyze(self, snapshot: GoalAgentInput) -> GoalAgentResult:
        """Analyzes a deterministic goal feasibility snapshot using the Goal Agent.

        Flow:
        1. Validate input contract (Pydantic)
        2. Verify local Ollama readiness
        3. Execute GoalAgent reasoning
        4. Return validated GoalAgentResult
        """
        if not isinstance(snapshot, GoalAgentInput):
            raise ValueError(f"Expected GoalAgentInput, got {type(snapshot).__name__}")

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
        goal_name: str,
        target_amount: float,
        current_amount: float,
        remaining_amount: float,
        required_monthly_contribution: float,
        available_monthly_amount: float,
        feasibility_status: str,
        feasibility_score: float = 0.0,
        goal_category: Optional[str] = None,
        priority: Optional[str] = None,
        target_date: Optional[str] = None,
        months_remaining: int = 0,
        days_remaining: int = 0,
        monthly_shortfall: float = 0.0,
        surplus_coverage_ratio: float = 0.0,
        is_achievable_without_savings: bool = False,
        is_achievable_with_savings: bool = False,
        current_savings: float = 0.0,
        monthly_surplus: float = 0.0,
        feasibility_reason: Optional[str] = None,
        metadata: Optional[Dict[str, Any]] = None,
    ) -> GoalAgentResult:
        """Convenience method constructing GoalAgentInput from individual deterministic values."""
        snapshot = GoalAgentInput(
            goal_name=goal_name,
            goal_category=goal_category,
            priority=priority,
            target_amount=target_amount,
            current_amount=current_amount,
            remaining_amount=remaining_amount,
            target_date=target_date,
            months_remaining=months_remaining,
            days_remaining=days_remaining,
            required_monthly_contribution=required_monthly_contribution,
            available_monthly_amount=available_monthly_amount,
            monthly_shortfall=monthly_shortfall,
            surplus_coverage_ratio=surplus_coverage_ratio,
            feasibility_status=feasibility_status,
            feasibility_score=feasibility_score,
            feasibility_reason=feasibility_reason,
            is_achievable_without_savings=is_achievable_without_savings,
            is_achievable_with_savings=is_achievable_with_savings,
            current_savings=current_savings,
            monthly_surplus=monthly_surplus,
            metadata=metadata,
        )
        return self.analyze(snapshot)

    def analyze_multiple(self, snapshots: List[GoalAgentInput]) -> List[GoalAgentResult]:
        """Analyzes multiple goal snapshots sequentially, returning one result per goal."""
        return [self.analyze(snapshot) for snapshot in snapshots]

    @classmethod
    def create_default(
        cls,
        ollama_base_url: Optional[str] = None,
        ollama_model: Optional[str] = None,
    ) -> "GoalAgentService":
        """Factory method to construct a fully initialized GoalAgentService."""
        client = OllamaClient(base_url=ollama_base_url, model=ollama_model)
        agent = GoalAgent(llm_client=client)
        return cls(agent=agent)
