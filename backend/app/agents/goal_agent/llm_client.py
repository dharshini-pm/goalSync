"""Ollama client re-export for Goal Agent — avoids code duplication."""

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
