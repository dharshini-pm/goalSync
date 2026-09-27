"""Service layer for orchestrating the GoalSync Explanation Agent."""

from typing import Any, Dict, List, Optional

from .models import (
    ExplanationAgentInput,
    ExplanationAgentResult,
    GoalExplanationSnapshot,
    ConflictExplanationSnapshot,
    ScenarioExplanationSnapshot,
)
from .agent import ExplanationAgent
from .llm_client import OllamaClient
from app.agents.transaction_agent.service import OllamaUnavailableError


class ExplanationAgentService:
    """High-level orchestration service for the Explanation Agent."""

    def __init__(self, agent: Optional[ExplanationAgent] = None):
        self.agent = agent or ExplanationAgent()

    def explain(self, snapshot: ExplanationAgentInput) -> ExplanationAgentResult:
        """Generate a structured explanation from a full intelligence snapshot.

        Flow:
        1. Validate input contract (Pydantic).
        2. Verify local Ollama readiness.
        3. Execute ExplanationAgent.
        4. Return validated ExplanationAgentResult.
        """
        if not isinstance(snapshot, ExplanationAgentInput):
            raise ValueError(
                f"Expected ExplanationAgentInput, got {type(snapshot).__name__}"
            )

        if not self.agent.llm_client.is_available():
            raise OllamaUnavailableError(
                f"Local Ollama server is not accessible at "
                f"{self.agent.llm_client.base_url}. "
                "Ensure Ollama is running ('ollama serve') locally."
            )

        if not self.agent.llm_client.is_model_available():
            raise OllamaUnavailableError(
                f"Model '{self.agent.llm_client.model}' is not installed. "
                f"Run 'ollama pull {self.agent.llm_client.model}' to download it."
            )

        return self.agent.run(snapshot)

    @classmethod
    def create_default(
        cls,
        ollama_base_url: Optional[str] = None,
        ollama_model: Optional[str] = None,
        timeout: int = 180,
    ) -> "ExplanationAgentService":
        """Factory method to construct a fully initialized ExplanationAgentService."""
        client = OllamaClient(
            base_url=ollama_base_url,
            model=ollama_model,
            timeout=timeout,
        )
        agent = ExplanationAgent(llm_client=client)
        return cls(agent=agent)
