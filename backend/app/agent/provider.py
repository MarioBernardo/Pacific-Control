import json
import re
from abc import ABC, abstractmethod
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen


class AgentProviderError(RuntimeError):
    pass


class AgentProviderNotConfigured(AgentProviderError):
    pass


class AgentProviderTimeout(AgentProviderError):
    pass


class AgentProvider(ABC):
    @abstractmethod
    def complete(self, system_prompt: str, user_prompt: str) -> str:
        raise NotImplementedError


class OpenAIProvider(AgentProvider):
    """Minimal server-side OpenAI-compatible chat-completions client."""

    def __init__(self, api_key: str, model: str, base_url: str, timeout: int):
        if not api_key or not model:
            raise AgentProviderNotConfigured(
                "El proveedor de IA no está configurado. Defina AI_API_KEY y AI_MODEL."
            )
        self.api_key = api_key
        self.model = model
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout

    def complete(self, system_prompt: str, user_prompt: str) -> str:
        payload = json.dumps({
            "model": self.model,
            "temperature": 0,
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt},
            ],
        }).encode("utf-8")
        request = Request(
            f"{self.base_url}/chat/completions",
            data=payload,
            method="POST",
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
        )
        try:
            with urlopen(request, timeout=self.timeout) as response:
                result = json.loads(response.read().decode("utf-8"))
            content = result["choices"][0]["message"]["content"]
            if not isinstance(content, str) or not content.strip():
                raise ValueError("empty response")
            return content.strip()
        except (TimeoutError,) as error:
            raise AgentProviderTimeout("El proveedor de IA excedió el tiempo de espera.") from error
        except HTTPError as error:
            # 401/403 (credencial), 429 (cuota) y 5xx se mantienen internos.
            raise AgentProviderError("El proveedor de IA rechazó o no pudo procesar la solicitud.") from error
        except (URLError, KeyError, IndexError, TypeError, ValueError,
                json.JSONDecodeError) as error:
            raise AgentProviderError("El proveedor de IA no pudo responder.") from error


class GeminiProvider(AgentProvider):
    """Google Gemini REST generateContent provider without an external SDK."""

    _model_pattern = re.compile(r"^[A-Za-z0-9._-]+$")

    def __init__(self, api_key: str, model: str, base_url: str, timeout: int):
        if not api_key or not model:
            raise AgentProviderNotConfigured(
                "El proveedor de IA no está configurado. Defina AI_API_KEY y AI_MODEL."
            )
        if not self._model_pattern.fullmatch(model):
            raise AgentProviderNotConfigured("AI_MODEL no tiene un formato válido.")
        self.api_key = api_key
        self.model = model
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout

    def complete(self, system_prompt: str, user_prompt: str) -> str:
        endpoint = (
            f"{self.base_url}/models/{quote(self.model, safe='')}:generateContent"
        )
        payload = json.dumps({
            "systemInstruction": {"parts": [{"text": system_prompt}]},
            "contents": [{
                "role": "user",
                "parts": [{"text": user_prompt}],
            }],
            "generationConfig": {"temperature": 0},
        }).encode("utf-8")
        request = Request(
            endpoint,
            data=payload,
            method="POST",
            headers={
                "x-goog-api-key": self.api_key,
                "Content-Type": "application/json",
            },
        )
        try:
            with urlopen(request, timeout=self.timeout) as response:
                result = json.loads(response.read().decode("utf-8"))
            candidates = result.get("candidates")
            if not isinstance(candidates, list) or not candidates:
                raise ValueError("missing candidates")
            content = candidates[0].get("content")
            parts = content.get("parts") if isinstance(content, dict) else None
            if not isinstance(parts, list) or not parts:
                raise ValueError("missing content parts")
            texts = [part.get("text", "").strip() for part in parts if isinstance(part, dict)]
            answer = "\n".join(text for text in texts if text)
            if not answer:
                raise ValueError("empty response")
            return answer
        except TimeoutError as error:
            raise AgentProviderTimeout("El proveedor de IA excedió el tiempo de espera.") from error
        except HTTPError as error:
            raise AgentProviderError("El proveedor de IA rechazó o no pudo procesar la solicitud.") from error
        except (URLError, KeyError, IndexError, TypeError, ValueError,
                json.JSONDecodeError) as error:
            raise AgentProviderError("El proveedor de IA no pudo responder.") from error
