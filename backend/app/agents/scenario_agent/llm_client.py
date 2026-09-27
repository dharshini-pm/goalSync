"""Ollama client re-export for Scenario Agent — avoids code duplication."""

from app.agents.transaction_agent.llm_client import (
    OllamaClient,
    OllamaError,
    OllamaConnectionError,
    OllamaTimeoutError,
    OllamaResponseError,
)

__all__ = [
    "OllamaClient",
    "OllamaError",
    "OllamaConnectionError",
    "OllamaTimeoutError",
    "OllamaResponseError",
]
