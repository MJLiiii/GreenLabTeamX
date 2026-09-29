"""Tests for experiment/session.py with a fake Ollama client (no Ollama needed)."""

import math
import unittest

import config
from benchmarks.base import Extraction, Question
from benchmarks.gsm_hard import GSMHard
from experiment.session import QuerySession, span_confidence
from ollama_client import OllamaTimeoutError

QUESTION = Question(id="1", text="What is 40 + 2?", reference="42.0")


def logprobs(pieces):
    """[(token, logprob), ...] -> Ollama's logprobs format."""
    return [
        {"token": token, "logprob": logprob, "bytes": list(token.encode("utf-8"))}
        for token, logprob in pieces
    ]


class FakeClient:
    def __init__(self, error=None):
        self.error = error
        self.generate_calls = []
        self.embed_calls = []

    def generate(self, model, prompt, **kwargs):
        self.generate_calls.append({"model": model, "prompt": prompt, **kwargs})
        if self.error:
            raise self.error
        return {
            "response": "40 + 2 = 42. The answer is 42",
            "done_reason": "stop",
            "total_duration": 2_000_000_000,
            "load_duration": 1_000_000,
            "prompt_eval_count": 30,
            "prompt_eval_cached_count": 0,
            "prompt_eval_duration": 100_000_000,
            "eval_count": 12,
            "eval_duration": 1_500_000_000,
            "logprobs": logprobs([
                ("40 + 2 = 42.", -0.5), (" The answer is ", -0.1),
                ("4", -0.2), ("2", -0.4),
            ]),
        }

    def embed(self, model, text, **kwargs):
        self.embed_calls.append({"model": model, "text": text, **kwargs})
        return {
            "embedding": [0.1, 0.2], "total_duration": 5_000_000,
            "load_duration": 0, "prompt_eval_count": 8,
        }


class SpanConfidenceTest(unittest.TestCase):
    RESPONSE = "The answer is 42"
    LOGPROBS = logprobs([("The", -1.0), (" answer is ", -1.0), ("4", -0.2), ("2", -0.4)])

    def test_uses_answer_tokens_only(self):
        extraction = Extraction("42", 14, 16)
        confidence = span_confidence(self.LOGPROBS, self.RESPONSE, extraction)
        self.assertAlmostEqual(confidence, math.exp(-0.3))

    def test_whole_response_without_extraction(self):
        confidence = span_confidence(self.LOGPROBS, self.RESPONSE, None)
        self.assertAlmostEqual(confidence, math.exp(-2.6 / 4))

    def test_multibyte_characters(self):
        # "é" split over two tokens, as byte-level tokenizers do.
        entries = [
            {"token": "�", "logprob": -3.0, "bytes": [0xC3]},
            {"token": "�", "logprob": -3.0, "bytes": [0xA9]},
            {"token": " 5", "logprob": -0.1, "bytes": [0x20, 0x35]},
        ]
        confidence = span_confidence(entries, "é 5", Extraction("5", 2, 3))
        self.assertAlmostEqual(confidence, math.exp(-0.1))

    def test_misaligned_tokens_fall_back_to_whole_response(self):
        confidence = span_confidence(self.LOGPROBS, "something else", Extraction("x", 0, 1))
        self.assertAlmostEqual(confidence, math.exp(-2.6 / 4))

    def test_no_logprobs(self):
        self.assertIsNone(span_confidence(None, self.RESPONSE, None))
        self.assertIsNone(span_confidence([], self.RESPONSE, None))


class QuerySessionTest(unittest.TestCase):
    def test_generate_applies_settings_and_records_call(self):
        client = FakeClient()
        session = QuerySession(client, GSMHard(), QUESTION)
        attempt = session.generate("qwen3.5:4b")

        sent = client.generate_calls[0]
        self.assertEqual(sent["prompt"], GSMHard().format_prompt(QUESTION))
        self.assertEqual(sent["options"]["num_predict"], config.MAX_NEW_TOKENS["gsm_hard"])
        self.assertEqual(sent["options"]["temperature"], 0)
        self.assertEqual(sent["logprobs"], config.GENERATION["logprobs"])

        self.assertEqual(attempt.extracted, "42")
        self.assertEqual(attempt.call_index, 0)
        self.assertAlmostEqual(attempt.confidence, math.exp(-0.3))

        call = session.calls[0]
        self.assertEqual((call.kind, call.model), ("generate", "qwen3.5:4b"))
        self.assertEqual(call.total_duration_s, 2.0)
        self.assertEqual(call.completion_tokens, 12)
        self.assertLessEqual(call.started_at_ms, call.ended_at_ms)
        self.assertGreater(call.started_at_ms, 1_700_000_000_000)

    def test_generate_error_is_recorded_not_raised(self):
        session = QuerySession(FakeClient(OllamaTimeoutError("slow")), GSMHard(), QUESTION)
        attempt = session.generate("qwen3.5:4b")
        self.assertEqual(attempt.error, "slow")
        self.assertFalse(attempt.ok)
        self.assertEqual(session.calls[0].error, "slow")

    def test_embed_is_recorded(self):
        client = FakeClient()
        session = QuerySession(client, GSMHard(), QUESTION)
        self.assertEqual(session.embed(QUESTION.text), [0.1, 0.2])
        self.assertEqual(client.embed_calls[0]["model"], config.EMBEDDING_MODEL)
        self.assertEqual(session.calls[0].kind, "embed")

    def test_call_indexes_increase(self):
        session = QuerySession(FakeClient(), GSMHard(), QUESTION)
        session.embed(QUESTION.text)
        session.generate("qwen3.5:4b")
        self.assertEqual([c.call_index for c in session.calls], [0, 1])


if __name__ == "__main__":
    unittest.main()
