"""
Minimal Ollama HTTP client (standard library only).

This module is only responsible for talking to the Ollama server.
Routing, benchmarking, energy measurement and model loading live elsewhere.
"""

import json
import socket
import urllib.error
import urllib.request


# ---------------------------------------------------------------------------
# Exceptions
# ---------------------------------------------------------------------------

class OllamaError(Exception):
    """Base class for all errors raised by OllamaClient."""


class OllamaConnectionError(OllamaError):
    """The Ollama server could not be reached."""


class OllamaTimeoutError(OllamaError):
    """The request took longer than the configured timeout."""


class OllamaHTTPError(OllamaError):
    """The server answered with a non-2xx HTTP status."""

    def __init__(self, message, status=None):
        super().__init__(message)
        self.status = status


class OllamaModelNotFoundError(OllamaHTTPError):
    """The requested model is not installed on the server."""


class OllamaResponseError(OllamaError):
    """The server returned invalid JSON or an error message in the body."""


# ---------------------------------------------------------------------------
# Client
# ---------------------------------------------------------------------------

NANOSECONDS_PER_SECOND = 1_000_000_000


class OllamaClient:
    def __init__(self, base_url="http://localhost:11434", timeout=300):
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout

    # -- public API ---------------------------------------------------------

    def is_available(self) -> bool:
        """Return True if the Ollama server responds, False otherwise."""
        try:
            self._request("GET", "/api/version", timeout=5)
            return True
        except OllamaError:
            return False

    def generate(
        self,
        model: str,
        prompt: str,
        *,
        keep_alive=-1,
        num_ctx=4096,
        think=False,
        options=None,
        logprobs=False,
    ) -> dict:
        """
        Send a single non-streaming prompt to Ollama and return a clean dict.

        `options` (temperature, seed, num_predict, ...) are merged over
        {"num_ctx": num_ctx}. With logprobs=True the result contains one
        {"token", "logprob", "bytes"} entry per generated token.

        Duration fields are reported by Ollama in nanoseconds and are
        returned unchanged. Missing fields are returned as None.
        """
        payload = {
            "model": model,
            "prompt": prompt,
            "stream": False,
            "keep_alive": keep_alive,
            "think": think,
            "options": {"num_ctx": num_ctx, **(options or {})},
        }
        if logprobs:
            payload["logprobs"] = True

        data = self._request("POST", "/api/generate", payload)

        eval_count = data.get("eval_count")
        eval_duration = data.get("eval_duration")

        return {
            "model": data.get("model", model),
            "response": data.get("response"),
            "thinking": data.get("thinking"),
            "done_reason": data.get("done_reason"),
            "total_duration": data.get("total_duration"),
            "load_duration": data.get("load_duration"),
            "prompt_eval_count": data.get("prompt_eval_count"),
            "prompt_eval_cached_count": data.get("prompt_eval_cached_count"),
            "prompt_eval_duration": data.get("prompt_eval_duration"),
            "eval_count": eval_count,
            "eval_duration": eval_duration,
            "generation_tokens_per_second": _tokens_per_second(
                eval_count, eval_duration
            ),
            "logprobs": data.get("logprobs"),
        }

    def embed(self, model: str, text: str, *, keep_alive=-1) -> dict:
        """Embed one text with an embedding model and return a clean dict."""
        payload = {"model": model, "input": text, "keep_alive": keep_alive}
        data = self._request("POST", "/api/embed", payload)

        embeddings = data.get("embeddings") or []
        if not embeddings:
            raise OllamaResponseError(f"No embedding returned by {model}")

        return {
            "model": data.get("model", model),
            "embedding": embeddings[0],
            "total_duration": data.get("total_duration"),
            "load_duration": data.get("load_duration"),
            "prompt_eval_count": data.get("prompt_eval_count"),
        }

    def ps(self) -> list[dict]:
        """Return the models currently loaded in memory (GET /api/ps)."""
        return self._request("GET", "/api/ps", timeout=10).get("models", [])

    def load(self, model: str, *, num_ctx=None, keep_alive=-1, embedding=False):
        """Load a model into memory without generating anything."""
        if embedding:
            # /api/embed has no "load only" form, so embed a tiny text.
            self._request(
                "POST", "/api/embed",
                {"model": model, "input": "load", "keep_alive": keep_alive},
            )
            return

        payload = {"model": model, "keep_alive": keep_alive}
        if num_ctx is not None:
            payload["options"] = {"num_ctx": num_ctx}
        self._request("POST", "/api/generate", payload)

    def unload(self, model: str, *, embedding=False):
        """Remove a model from memory (same effect as 'ollama stop')."""
        if embedding:
            self._request(
                "POST", "/api/embed",
                {"model": model, "input": "unload", "keep_alive": 0},
            )
            return
        self._request("POST", "/api/generate", {"model": model, "keep_alive": 0})

    # -- internals ----------------------------------------------------------

    def _request(self, method, path, payload=None, timeout=None):
        """Send an HTTP request and return the decoded JSON body as a dict."""
        url = self.base_url + path
        timeout = self.timeout if timeout is None else timeout

        body = None
        headers = {}
        if payload is not None:
            body = json.dumps(payload).encode("utf-8")
            headers["Content-Type"] = "application/json"

        request = urllib.request.Request(
            url, data=body, headers=headers, method=method
        )

        try:
            with urllib.request.urlopen(request, timeout=timeout) as response:
                raw = response.read().decode("utf-8")

        except urllib.error.HTTPError as e:
            # Must come before URLError, because HTTPError is a subclass of it.
            message = _extract_error_message(e)
            if e.code == 404 and "not found" in message.lower():
                raise OllamaModelNotFoundError(
                    f"Model not found: {message}. "
                    f"Check installed models with 'ollama list'.",
                    status=e.code,
                ) from e
            raise OllamaHTTPError(
                f"Ollama returned HTTP {e.code} for {method} {path}: {message}",
                status=e.code,
            ) from e

        except urllib.error.URLError as e:
            if isinstance(e.reason, (socket.timeout, TimeoutError)):
                raise OllamaTimeoutError(
                    f"Timed out after {timeout}s connecting to {url}"
                ) from e
            raise OllamaConnectionError(
                f"Could not reach Ollama at {self.base_url} ({e.reason}). "
                f"Is the server running? Try 'ollama serve'."
            ) from e

        except (socket.timeout, TimeoutError) as e:
            raise OllamaTimeoutError(
                f"Timed out after {timeout}s waiting for {method} {path}. "
                f"Consider increasing the client timeout."
            ) from e

        try:
            data = json.loads(raw)
        except json.JSONDecodeError as e:
            raise OllamaResponseError(
                f"Invalid JSON from {method} {path}: {raw[:200]!r}"
            ) from e

        if not isinstance(data, dict):
            raise OllamaResponseError(
                f"Expected a JSON object from {method} {path}, got {type(data).__name__}"
            )

        if "error" in data:
            raise OllamaResponseError(f"Ollama API error: {data['error']}")

        return data


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _tokens_per_second(token_count, duration_ns):
    """Convert a token count and a nanosecond duration into tokens/second."""
    if not token_count or not duration_ns:
        return None
    return token_count / (duration_ns / NANOSECONDS_PER_SECOND)


def _extract_error_message(http_error):
    """Pull Ollama's {"error": "..."} message out of an HTTPError if present."""
    try:
        raw = http_error.read().decode("utf-8")
    except Exception:
        return str(http_error.reason)

    try:
        return json.loads(raw).get("error", raw)
    except (json.JSONDecodeError, AttributeError):
        return raw or str(http_error.reason)

