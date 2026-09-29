"""
GSM-Hard (reasoning-machines/gsm-hard): GSM8K word problems with large numbers.

The reference answer is a float computed by a program, so answers are
compared numerically with a small tolerance.
"""

import math

from benchmarks.base import Benchmark, Extraction, Question, last_match

# "1,234,567.5", "-42", "3.14", ".5". The comma form comes first so
# thousands separators are kept, while a sentence comma ("is 5, so") is not.
NUMBER = r"-?\d{1,3}(?:,\d{3})+(?:\.\d+)?|-?\d+(?:\.\d+)?|-?\.\d+"

# Priority order: boxed answer, "the answer is N", then the last number.
ANSWER_PATTERNS = [
    rf"\\boxed\{{\s*\$?\s*({NUMBER})",
    rf"(?i:answer is)[\s:*$]*({NUMBER})",
    rf"({NUMBER})",
]

# Targets come from Python floats (e.g. 3244047.0999999996) and models round
# to a few decimals, hence the absolute tolerance. The relative tolerance only
# covers float noise: an off-by-one on a large target must still be wrong.
REL_TOL = 1e-9
ABS_TOL = 1e-2


class GSMHard(Benchmark):
    name = "gsm_hard"
    prompt_template = (
        "Solve the following math problem step by step. "
        'Finish your answer with "The answer is N" where N is the final number.\n'
        "\n"
        "Question: {question}\n"
        "Answer: Let's think step by step."
    )

    def from_hf_row(self, row: dict, index: int) -> Question:
        # The dataset has no id column, so the row position is the id.
        return Question(
            id=str(index),
            text=row["input"],
            reference=repr(float(row["target"])),
        )

    def format_prompt(self, question: Question) -> str:
        return self.prompt_template.format(question=question.text)

    def extract_answer(self, response: str) -> Extraction | None:
        return last_match(ANSWER_PATTERNS, response or "")

    def is_correct(self, extraction: Extraction | None, question: Question) -> bool:
        if extraction is None:
            return False
        predicted = parse_number(extraction.value)
        reference = float(question.reference)
        if predicted is None or not math.isfinite(reference):
            return False
        return math.isclose(predicted, reference, rel_tol=REL_TOL, abs_tol=ABS_TOL)


def parse_number(text: str) -> float | None:
    try:
        return float(text.replace(",", ""))
    except ValueError:
        return None
