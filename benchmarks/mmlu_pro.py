"""
MMLU-Pro (TIGER-Lab/MMLU-Pro): knowledge questions with up to 10 options.

Zero-shot chain-of-thought prompt in the style of the official evaluation.
"""

from benchmarks.base import Benchmark, Extraction, Question, last_match

LETTERS = "ABCDEFGHIJ"

# Priority order. There is deliberately no "any lone capital letter" fallback
# (used by the official script), because it matches the article "A".
ANSWER_PATTERNS = [
    r"(?i:answer is)[\s:*]*\(?\**([A-J])\**\)?(?![A-Za-z])",
    r"\\boxed\{\s*\(?([A-J])\)?\s*\}",
    r"[Aa]nswer:[\s*]*\(?([A-J])\)?(?![A-Za-z])",
]


class MMLUPro(Benchmark):
    name = "mmlu_pro"
    prompt_template = (
        "The following is a multiple choice question about {category}. "
        'Think step by step and then finish your answer with "The answer is (X)" '
        "where X is the correct letter choice.\n"
        "\n"
        "Question: {question}\n"
        "Options:\n"
        "{options}\n"
        "Answer: Let's think step by step."
    )

    def from_hf_row(self, row: dict, index: int) -> Question:
        return Question(
            id=str(row["question_id"]),
            text=row["question"],
            reference=row["answer"],
            choices=tuple(row["options"]),
            category=row["category"],
        )

    def format_prompt(self, question: Question) -> str:
        options = "\n".join(
            f"{letter}. {choice}"
            for letter, choice in zip(LETTERS, question.choices)
        )
        return self.prompt_template.format(
            category=question.category or "general knowledge",
            question=question.text,
            options=options,
        )

    def extract_answer(self, response: str) -> Extraction | None:
        return last_match(ANSWER_PATTERNS, response or "")

    def is_correct(self, extraction: Extraction | None, question: Question) -> bool:
        return extraction is not None and extraction.value == question.reference
