"""Tests for benchmarks/ and scripts/prepare_data.py (no Ollama needed)."""

import tempfile
import unittest
from collections import Counter
from pathlib import Path

from benchmarks import BENCHMARKS
from benchmarks.base import Question, load_questions, write_questions
from benchmarks.gsm_hard import GSMHard
from benchmarks.mmlu_pro import MMLUPro
from scripts.prepare_data import _drop_duplicates, _proportional, _split

MMLU = MMLUPro()
GSM = GSMHard()


class MMLUProTest(unittest.TestCase):
    def extract(self, response):
        extraction = MMLU.extract_answer(response)
        return extraction.value if extraction else None

    def test_answer_is_pattern(self):
        self.assertEqual(self.extract("So the answer is (C)."), "C")
        self.assertEqual(self.extract("The answer is D"), "D")
        self.assertEqual(self.extract("The answer is **(B)**"), "B")

    def test_other_patterns(self):
        self.assertEqual(self.extract(r"Final: \boxed{E}"), "E")
        self.assertEqual(self.extract("Answer: (F)"), "F")

    def test_last_match_wins(self):
        response = "Maybe the answer is (A)? No, the answer is (G)."
        self.assertEqual(self.extract(response), "G")

    def test_no_answer(self):
        self.assertIsNone(self.extract("A tricky one. I am not sure."))
        # "A" as an article must not be taken as the answer.
        self.assertIsNone(self.extract("The answer is Asia, a continent."))
        self.assertIsNone(self.extract(""))
        self.assertIsNone(self.extract(None))

    def test_span_points_at_letter(self):
        response = "the answer is (H)"
        extraction = MMLU.extract_answer(response)
        self.assertEqual(response[extraction.start:extraction.end], "H")

    def test_prompt_lists_every_option(self):
        question = Question("1", "Pick one.", "B", ("x", "y", "z"), "math")
        prompt = MMLU.format_prompt(question)
        for line in ("A. x", "B. y", "C. z", "Pick one.", "about math"):
            self.assertIn(line, prompt)
        self.assertNotIn("D.", prompt)

    def test_is_correct(self):
        question = Question("1", "q", "B", ("x", "y"))
        self.assertTrue(MMLU.is_correct(MMLU.extract_answer("answer is (B)"), question))
        self.assertFalse(MMLU.is_correct(MMLU.extract_answer("answer is (A)"), question))
        self.assertFalse(MMLU.is_correct(None, question))

    def test_from_hf_row(self):
        row = {
            "question_id": 70, "question": "q", "options": ["a", "b"],
            "answer": "B", "answer_index": 1, "category": "business",
        }
        self.assertEqual(
            MMLU.from_hf_row(row, 0), Question("70", "q", "B", ("a", "b"), "business")
        )


class GSMHardTest(unittest.TestCase):
    def extract(self, response):
        extraction = GSM.extract_answer(response)
        return extraction.value if extraction else None

    def test_answer_is_pattern(self):
        self.assertEqual(self.extract("The answer is 1,234,567."), "1,234,567")
        self.assertEqual(self.extract("The answer is $3.50"), "3.50")
        self.assertEqual(self.extract("The answer is -9867630"), "-9867630")

    def test_boxed_wins(self):
        self.assertEqual(self.extract(r"\boxed{-42} and the answer is 7"), "-42")

    def test_answer_is_before_last_number(self):
        self.assertEqual(self.extract("The answer is 10. Check: 2 + 3 = 5"), "10")

    def test_last_number_fallback(self):
        self.assertEqual(self.extract("First 5, then 7."), "7")

    def test_no_number(self):
        self.assertIsNone(self.extract("I cannot solve this."))

    def test_tolerance(self):
        question = Question("1", "q", repr(3244047.0999999996))
        self.assertTrue(GSM.is_correct(GSM.extract_answer("answer is 3244047.1"), question))

        question = Question("2", "q", "-9867630.0")
        self.assertTrue(GSM.is_correct(GSM.extract_answer("answer is -9,867,630"), question))
        self.assertFalse(GSM.is_correct(GSM.extract_answer("answer is -9867631"), question))

        question = Question("3", "q", repr(16 / 3))
        self.assertTrue(GSM.is_correct(GSM.extract_answer("answer is 5.333"), question))
        self.assertFalse(GSM.is_correct(GSM.extract_answer("answer is 5"), question))
        self.assertFalse(GSM.is_correct(None, question))

    def test_from_hf_row(self):
        row = {"input": "q", "code": "...", "target": -9867630.0}
        self.assertEqual(GSM.from_hf_row(row, 12), Question("12", "q", "-9867630.0"))


class QuestionFilesTest(unittest.TestCase):
    def test_round_trip(self):
        questions = [
            Question("1", "q1", "A", ("x", "y"), "math"),
            Question("2", "q2", "7.0"),
        ]
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "q.jsonl"
            write_questions(path, questions)
            self.assertEqual(load_questions(path), questions)

    def test_fixtures_load(self):
        fixtures = Path(__file__).parent / "fixtures"
        for name in BENCHMARKS:
            self.assertTrue(load_questions(fixtures / f"{name}_tiny.jsonl"))


class PrepareDataTest(unittest.TestCase):
    def questions(self):
        return [
            Question(str(i), f"question {i}", "A", ("x",), category)
            for i, category in enumerate(["a"] * 60 + ["b"] * 30 + ["c"] * 10)
        ]

    def test_split_is_disjoint_and_sized(self):
        splits = _split(self.questions(), n_train=50, n_eval=20, seed=1)
        train_ids = {q.id for q in splits["train"]}
        eval_ids = {q.id for q in splits["eval"]}
        self.assertEqual((len(train_ids), len(eval_ids)), (50, 20))
        self.assertFalse(train_ids & eval_ids)

    def test_split_is_stratified(self):
        splits = _split(self.questions(), n_train=50, n_eval=20, seed=1)
        self.assertEqual(
            Counter(q.category for q in splits["eval"]), {"a": 12, "b": 6, "c": 2}
        )

    def test_split_is_deterministic(self):
        first = _split(self.questions(), 50, 20, seed=1)
        second = _split(self.questions(), 50, 20, seed=1)
        self.assertEqual(first, second)

    def test_split_too_large(self):
        with self.assertRaises(ValueError):
            _split(self.questions(), 90, 20, seed=1)

    def test_proportional_sums_to_total(self):
        quotas = _proportional({"a": 7, "b": 7, "c": 7}, 10)
        self.assertEqual(sum(quotas.values()), 10)

    def test_drop_duplicates(self):
        questions = [Question("1", "Same  text", "A"), Question("2", "same text", "B")]
        self.assertEqual([q.id for q in _drop_duplicates(questions)], ["1"])


if __name__ == "__main__":
    unittest.main()
