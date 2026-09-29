"""
Interface shared by all benchmarks.

A benchmark only knows how to turn a Question into a prompt, how to find the
final answer in a model response, and how to score it. It never calls Ollama.
"""

import hashlib
import json
import re
from abc import ABC, abstractmethod
from dataclasses import dataclass
from pathlib import Path

import config


@dataclass(frozen=True)
class Question:
    id: str
    text: str
    reference: str
    choices: tuple[str, ...] = ()
    category: str | None = None

    def to_json(self) -> dict:
        return {
            "id": self.id,
            "text": self.text,
            "reference": self.reference,
            "choices": list(self.choices),
            "category": self.category,
        }

    @classmethod
    def from_json(cls, data: dict) -> "Question":
        return cls(
            id=str(data["id"]),
            text=data["text"],
            reference=str(data["reference"]),
            choices=tuple(data.get("choices") or ()),
            category=data.get("category"),
        )


@dataclass(frozen=True)
class Extraction:
    """The final answer found in a response, with its character span."""

    value: str
    start: int
    end: int


def load_questions(path) -> list[Question]:
    """Read a frozen question set written by scripts/prepare_data.py."""
    with open(path, encoding="utf-8") as f:
        return [Question.from_json(json.loads(line)) for line in f if line.strip()]


def write_questions(path, questions):
    with open(path, "w", encoding="utf-8") as f:
        for question in questions:
            f.write(json.dumps(question.to_json(), ensure_ascii=False) + "\n")


def sha256_file(path) -> str:
    """Hash of a data file, stored so every run records exactly what it read."""
    digest = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            digest.update(chunk)
    return digest.hexdigest()


def last_match(patterns, text) -> Extraction | None:
    """Return the last match of the first pattern that matches at all.

    Patterns are tried in priority order; each must have one capture group.
    The last match is used because models often restate options before
    giving their final answer.
    """
    for pattern in patterns:
        matches = list(re.finditer(pattern, text))
        if matches:
            match = matches[-1]
            return Extraction(match.group(1), match.start(1), match.end(1))
    return None


class Benchmark(ABC):
    # Short name used on the command line, in data file names and in config.
    name = "base"
    # Stored in the settings fingerprint: changing it invalidates router labels.
    prompt_template = ""

    def data_path(self, split: str) -> Path:
        return config.DATA_DIR / f"{self.name}_{split}.jsonl"

    def load(self, split: str, limit: int | None = None) -> list[Question]:
        path = self.data_path(split)
        if not path.exists():
            raise FileNotFoundError(
                f"{path} does not exist. Run: python -m scripts.prepare_data"
            )
        return load_questions(path)[:limit]

    @abstractmethod
    def from_hf_row(self, row: dict, index: int) -> Question:
        """Convert one Hugging Face dataset row (at position index) into a Question."""

    @abstractmethod
    def format_prompt(self, question: Question) -> str:
        """Build the exact prompt sent to every model."""

    @abstractmethod
    def extract_answer(self, response: str) -> Extraction | None:
        """Find the final answer in a response, or None if there is none."""

    @abstractmethod
    def is_correct(self, extraction: Extraction | None, question: Question) -> bool:
        """Score an extracted answer. A missing answer is always wrong."""
