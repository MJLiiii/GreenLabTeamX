"""
Base class shared by all routers.

A router decides which model(s) answer a question. It never talks to Ollama
directly and never scores answers: it calls the LLM interface it is given
(experiment/session.py), which formats the prompt, applies the fixed
generation settings, and times and records every call. This keeps prompts,
settings and measurements identical across routing strategies.
"""

from abc import ABC, abstractmethod
from dataclasses import dataclass
from typing import Protocol

import config
from benchmarks.base import Question


@dataclass(frozen=True)
class Attempt:
    """One generate call as a router sees it: no reference, no correctness."""

    model: str
    response: str | None
    extracted: str | None      # final answer found in the response, if any
    confidence: float | None   # exp(mean logprob) of the answer tokens
    done_reason: str | None
    error: str | None = None
    call_index: int | None = None

    @property
    def ok(self) -> bool:
        return self.error is None


class LLM(Protocol):
    def generate(self, model: str) -> Attempt:
        """Answer the current question with the given model."""

    def embed(self, text: str) -> list[float]:
        """Embed a text with config.EMBEDDING_MODEL."""


class BaseRouter(ABC):
    # Short name used on the command line and in result files.
    name = "base"

    def __init__(self, models=None):
        if models is None:
            models = config.MODEL_ORDER

        # Ordered from smallest to largest (see config.MODEL_ORDER).
        self.models = list(models)
        if not self.models:
            raise ValueError(f"{type(self).__name__} needs at least one model.")

    def answer(self, question: Question, llm: LLM) -> Attempt:
        """Answer one question and return the attempt used as final answer."""
        if not isinstance(question, Question):
            raise TypeError(
                f"question must be a Question, got {type(question).__name__}"
            )

        attempt = self._answer(question, llm)

        # Catch router bugs early instead of reporting an unknown model.
        if attempt.model not in self.models:
            raise ValueError(
                f"{type(self).__name__} answered with {attempt.model!r}, "
                f"which is not in its model list {self.models}"
            )

        return attempt

    def config(self) -> dict:
        """Settings needed to reproduce this router's decisions.

        Subclasses with extra settings (thresholds, weights file, ...)
        should extend this dict.
        """
        return {
            "router": self.name,
            "class": type(self).__name__,
            "models": list(self.models),
        }

    @abstractmethod
    def _answer(self, question: Question, llm: LLM) -> Attempt:
        """Call llm.generate() one or more times. Implemented by each router."""


def check_threshold(threshold) -> float:
    if threshold is None or not 0.0 <= threshold <= 1.0:
        raise ValueError(f"threshold must be between 0 and 1, got {threshold!r}")
    return float(threshold)
