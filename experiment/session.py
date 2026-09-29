"""
Per-question LLM session handed to the routers.

Every Ollama call a router makes for one question goes through a
QuerySession, so all strategies share the same prompt, generation settings,
answer extraction and confidence, and every call is timed and recorded
(with Unix-ms timestamps that line up with EnergiBridge's Time column).
"""

import math
import time
from dataclasses import dataclass, field

import config
from benchmarks.base import Extraction
from ollama_client import OllamaError
from routers.base import Attempt

NANOSECONDS_PER_SECOND = 1_000_000_000


@dataclass
class CallRecord:
    """One Ollama call. Written as one row of calls.csv."""

    call_index: int
    kind: str                     # "generate" or "embed"
    model: str
    started_at_ms: int
    ended_at_ms: int
    latency_s: float
    total_duration_s: float | None = None
    load_duration_s: float | None = None
    prompt_eval_duration_s: float | None = None
    eval_duration_s: float | None = None
    prompt_tokens: int | None = None
    prompt_cached_tokens: int | None = None
    completion_tokens: int | None = None
    done_reason: str | None = None
    response: str | None = None
    extracted_answer: str | None = None
    confidence: float | None = None       # answer tokens only
    seq_confidence: float | None = None   # whole response
    error: str | None = None
    # Filled in by the runner after the router is done.
    correct: bool | None = None
    is_final: bool = False
    # Kept for scoring, not written to the CSV.
    extraction: Extraction | None = field(default=None, repr=False)


class QuerySession:
    def __init__(self, client, benchmark, question):
        self.client = client
        self.benchmark = benchmark
        self.question = question
        self.prompt = benchmark.format_prompt(question)
        self.calls: list[CallRecord] = []

        self._options = {
            **config.GENERATION["options"],
            "num_predict": config.MAX_NEW_TOKENS[benchmark.name],
        }

    def generate(self, model: str) -> Attempt:
        index = len(self.calls)
        started_at_ms = _now_ms()
        start = time.perf_counter()

        try:
            result = self.client.generate(
                model,
                self.prompt,
                keep_alive=config.GENERATION["keep_alive"],
                num_ctx=config.GENERATION["num_ctx"],
                think=config.GENERATION["think"],
                logprobs=config.GENERATION["logprobs"],
                options=self._options,
            )
        except OllamaError as e:
            # Record the failed call; the router decides whether to go on.
            self.calls.append(CallRecord(
                call_index=index, kind="generate", model=model,
                started_at_ms=started_at_ms, ended_at_ms=_now_ms(),
                latency_s=time.perf_counter() - start, error=str(e),
            ))
            return Attempt(
                model=model, response=None, extracted=None, confidence=None,
                done_reason=None, error=str(e), call_index=index,
            )

        latency_s = time.perf_counter() - start
        response = result["response"] or ""
        extraction = self.benchmark.extract_answer(response)
        confidence = span_confidence(result["logprobs"], response, extraction)
        seq_confidence = span_confidence(result["logprobs"], response, None)

        self.calls.append(CallRecord(
            call_index=index,
            kind="generate",
            model=model,
            started_at_ms=started_at_ms,
            ended_at_ms=_now_ms(),
            latency_s=latency_s,
            total_duration_s=_ns_to_s(result["total_duration"]),
            load_duration_s=_ns_to_s(result["load_duration"]),
            prompt_eval_duration_s=_ns_to_s(result["prompt_eval_duration"]),
            eval_duration_s=_ns_to_s(result["eval_duration"]),
            prompt_tokens=result["prompt_eval_count"],
            prompt_cached_tokens=result["prompt_eval_cached_count"],
            completion_tokens=result["eval_count"],
            done_reason=result["done_reason"],
            response=response,
            extracted_answer=extraction.value if extraction else None,
            confidence=confidence,
            seq_confidence=seq_confidence,
            extraction=extraction,
        ))

        return Attempt(
            model=model,
            response=response,
            extracted=extraction.value if extraction else None,
            confidence=confidence,
            done_reason=result["done_reason"],
            call_index=index,
        )

    def embed(self, text: str) -> list[float]:
        index = len(self.calls)
        model = config.EMBEDDING_MODEL
        started_at_ms = _now_ms()
        start = time.perf_counter()

        try:
            result = self.client.embed(
                model, text, keep_alive=config.GENERATION["keep_alive"]
            )
        except OllamaError as e:
            self.calls.append(CallRecord(
                call_index=index, kind="embed", model=model,
                started_at_ms=started_at_ms, ended_at_ms=_now_ms(),
                latency_s=time.perf_counter() - start, error=str(e),
            ))
            raise

        self.calls.append(CallRecord(
            call_index=index,
            kind="embed",
            model=model,
            started_at_ms=started_at_ms,
            ended_at_ms=_now_ms(),
            latency_s=time.perf_counter() - start,
            total_duration_s=_ns_to_s(result["total_duration"]),
            load_duration_s=_ns_to_s(result["load_duration"]),
            prompt_tokens=result["prompt_eval_count"],
        ))
        return result["embedding"]


def span_confidence(logprobs, response: str, extraction: Extraction | None):
    """exp(mean logprob) over the tokens that make up the extracted answer.

    With extraction=None, or when the token bytes do not line up with the
    response text, the whole response is used. Returns None without logprobs.

    The answer tokens are used because, after step-by-step reasoning, the
    mean over the whole response says little about the final answer.
    """
    if not logprobs:
        return None

    all_logprobs = [entry["logprob"] for entry in logprobs]
    if extraction is None:
        return _mean_probability(all_logprobs)

    token_bytes = [
        bytes(entry["bytes"]) if entry.get("bytes") is not None
        else entry["token"].encode("utf-8")
        for entry in logprobs
    ]
    encoded = response.encode("utf-8")
    if b"".join(token_bytes) != encoded:
        return _mean_probability(all_logprobs)

    # Character span -> byte span, since tokens can split multi-byte characters.
    span_start = len(response[: extraction.start].encode("utf-8"))
    span_end = len(response[: extraction.end].encode("utf-8"))

    selected = []
    offset = 0
    for logprob, piece in zip(all_logprobs, token_bytes):
        token_start, offset = offset, offset + len(piece)
        if token_start < span_end and offset > span_start:
            selected.append(logprob)

    return _mean_probability(selected or all_logprobs)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _mean_probability(logprobs):
    return math.exp(sum(logprobs) / len(logprobs))


def _ns_to_s(duration_ns):
    if duration_ns is None:
        return None
    return duration_ns / NANOSECONDS_PER_SECOND


def _now_ms() -> int:
    return time.time_ns() // 1_000_000
