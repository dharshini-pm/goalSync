"""GoalSync Transaction Agent Module."""

from .models import (
    TransactionAgentInput,
    TransactionAgentResult,
    AgentConfidence,
    TransactionTypeCategory,
)
from .prompts import (
    TRANSACTION_AGENT_SYSTEM_PROMPT,
    build_transaction_user_prompt,
)
from .llm_client import (
    OllamaClient,
    OllamaError,
    OllamaConnectionError,
    OllamaTimeoutError,
    OllamaResponseError,
    DEFAULT_OLLAMA_BASE_URL,
    DEFAULT_OLLAMA_MODEL,
)
from .agent import TransactionAgent
from .service import TransactionAgentService, OllamaUnavailableError

__all__ = [
    "TransactionAgentInput",
    "TransactionAgentResult",
    "AgentConfidence",
    "TransactionTypeCategory",
    "TRANSACTION_AGENT_SYSTEM_PROMPT",
    "build_transaction_user_prompt",
    "OllamaClient",
    "OllamaError",
    "OllamaConnectionError",
    "OllamaTimeoutError",
    "OllamaResponseError",
    "DEFAULT_OLLAMA_BASE_URL",
    "DEFAULT_OLLAMA_MODEL",
    "TransactionAgent",
    "TransactionAgentService",
    "OllamaUnavailableError",
]
