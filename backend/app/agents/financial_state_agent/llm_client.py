"""Ollama client configuration for the Financial State Agent.

Reuses the core OllamaClient abstraction from the transaction_agent module to avoid duplicate code.
"""

from app.agents.transaction_agent.llm_client import (
    OllamaClient,
    OllamaError,
    OllamaConnectionError,
    OllamaTimeoutError,
    OllamaResponseError,
    DEFAULT_OLLAMA_BASE_URL,
    DEFAULT_OLLAMA_MODEL,
)

__all__ = [
    "OllamaClient",
    "OllamaError",
    "OllamaConnectionError",
    "OllamaTimeoutError",
    "OllamaResponseError",
    "DEFAULT_OLLAMA_BASE_URL",
    "DEFAULT_OLLAMA_MODEL",
]
