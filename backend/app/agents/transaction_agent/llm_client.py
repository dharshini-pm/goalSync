"""Local Ollama client for the GoalSync Transaction Agent."""

import json
import os
import re
from typing import Any, Dict, Optional, List
import requests

DEFAULT_OLLAMA_BASE_URL = "http://localhost:11434"
DEFAULT_OLLAMA_MODEL = "llama3.2"
DEFAULT_TIMEOUT_SECONDS = 30


class OllamaError(Exception):
    """Base exception for Ollama client errors."""
    pass


class OllamaConnectionError(OllamaError):
    """Raised when the client cannot connect to the local Ollama instance."""
    pass


class OllamaTimeoutError(OllamaError):
    """Raised when Ollama does not respond within the configured timeout."""
    pass


class OllamaResponseError(OllamaError):
    """Raised when Ollama returns an HTTP error or unparseable response."""
    pass


class OllamaClient:
    """Client for communicating with a local Ollama server."""

    def __init__(
        self,
        base_url: Optional[str] = None,
        model: Optional[str] = None,
        timeout: int = DEFAULT_TIMEOUT_SECONDS,
    ):
        self.base_url = (base_url or os.getenv("OLLAMA_BASE_URL", DEFAULT_OLLAMA_BASE_URL)).rstrip("/")
        self.model = model or os.getenv("OLLAMA_MODEL", DEFAULT_OLLAMA_MODEL)
        self.timeout = timeout

    def _sanitize_env(self) -> None:
        """Removes external SSL log variables that cause permission errors on Windows."""
        os.environ.pop("SSLKEYLOGFILE", None)

    def is_available(self) -> bool:
        """Checks if the local Ollama server is running and reachable."""
        self._sanitize_env()
        url = f"{self.base_url}/api/tags"
        try:
            resp = requests.get(url, timeout=3)
            return resp.status_code == 200
        except (requests.ConnectionError, requests.Timeout):
            return False
        except Exception:
            return False

    def list_models(self) -> List[str]:
        """Returns the list of model names currently installed in Ollama."""
        self._sanitize_env()
        url = f"{self.base_url}/api/tags"
        try:
            resp = requests.get(url, timeout=5)
            if resp.status_code != 200:
                return []
            data = resp.json()
            models = data.get("models", [])
            return [m.get("name", "") for m in models if "name" in m]
        except Exception:
            return []

    def is_model_available(self, model_name: Optional[str] = None) -> bool:
        """Checks whether the configured or specified model is installed."""
        target = (model_name or self.model).lower()
        installed = [m.lower() for m in self.list_models()]
        return any(
            target == m
            or f"{target}:latest" == m
            or m.startswith(f"{target}:")
            for m in installed
        )

    def generate_json(
        self,
        system_prompt: str,
        user_prompt: str,
        temperature: float = 0.0,
    ) -> Dict[str, Any]:
        """Calls the local Ollama chat API requesting structured JSON output."""
        self._sanitize_env()

        url = f"{self.base_url}/api/chat"
        payload = {
            "model": self.model,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
            "stream": False,
            "format": "json",
            "options": {
                "temperature": temperature,
            },
        }

        try:
            resp = requests.post(url, json=payload, timeout=self.timeout)
        except requests.ConnectionError as e:
            raise OllamaConnectionError(
                f"Could not connect to Ollama at {self.base_url}. Ensure the Ollama service is running. Details: {e}"
            ) from e
        except requests.Timeout as e:
            raise OllamaTimeoutError(
                f"Ollama request timed out after {self.timeout}s using model '{self.model}'."
            ) from e
        except Exception as e:
            raise OllamaError(f"Unexpected error communicating with Ollama: {e}") from e

        if resp.status_code != 200:
            raise OllamaResponseError(
                f"Ollama returned HTTP {resp.status_code}: {resp.text}"
            )

        try:
            data = resp.json()
            raw_content = data.get("message", {}).get("content", "").strip()
        except Exception as e:
            raise OllamaResponseError(f"Failed to parse Ollama response as JSON envelope: {e}") from e

        if not raw_content:
            raise OllamaResponseError("Ollama returned an empty response.")

        # Clean optional markdown code fences if model enclosed JSON in ```json ... ```
        cleaned_content = re.sub(r"^```(?:json)?\s*", "", raw_content, flags=re.MULTILINE)
        cleaned_content = re.sub(r"\s*```$", "", cleaned_content, flags=re.MULTILINE).strip()

        try:
            parsed_json = json.loads(cleaned_content)
        except json.JSONDecodeError as e:
            raise OllamaResponseError(
                f"Ollama response was not valid JSON: {cleaned_content[:200]}. Error: {e}"
            ) from e

        if not isinstance(parsed_json, dict):
            raise OllamaResponseError(
                f"Ollama response was valid JSON but not a JSON object (dict): {type(parsed_json).__name__}"
            )

        return parsed_json
