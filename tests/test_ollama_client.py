"""Live tests for ollama_client.py. Skipped when Ollama is not reachable."""

import unittest

import config
from ollama_client import (
    OllamaClient,
    OllamaConnectionError,
    OllamaError,
    OllamaModelNotFoundError,
)

SMALL, MIDDLE, LARGE = config.MODEL_ORDER

client = OllamaClient()
OLLAMA_UP = client.is_available()


def embedding_model_installed():
    if not OLLAMA_UP:
        return False
    try:
        client.embed(config.EMBEDDING_MODEL, "probe")
        return True
    except OllamaError:
        return False


class OllamaClientOfflineTest(unittest.TestCase):
    def test_unreachable_server(self):
        # Nothing listens on port 1, so the connection is refused immediately.
        offline = OllamaClient(base_url="http://127.0.0.1:1", timeout=2)
        self.assertFalse(offline.is_available())
        with self.assertRaises(OllamaConnectionError):
            offline.generate(model=SMALL, prompt="hi")


@unittest.skipUnless(OLLAMA_UP, f"Ollama is not reachable at {client.base_url}")
class OllamaClientLiveTest(unittest.TestCase):
    def test_generate(self):
        result = client.generate(model=LARGE, prompt="What is 2 + 5?")

        self.assertEqual(result["model"], LARGE)
        self.assertIn("7", result["response"])
        self.assertGreater(result["eval_count"], 0)
        self.assertGreater(result["generation_tokens_per_second"], 0)

    def test_logprobs_and_options(self):
        result = client.generate(
            model=SMALL, prompt="Count from 1 to 100.",
            logprobs=True, options={"temperature": 0, "seed": 42, "num_predict": 5},
        )
        self.assertEqual(result["done_reason"], "length")
        self.assertLessEqual(result["eval_count"], 5)
        self.assertTrue(result["logprobs"])
        self.assertEqual(
            "".join(entry["token"] for entry in result["logprobs"]), result["response"]
        )

    def test_unknown_model(self):
        with self.assertRaises(OllamaModelNotFoundError):
            client.generate(model="no-such-model:1b", prompt="hi")

    def test_ps(self):
        self.assertIsInstance(client.ps(), list)


@unittest.skipUnless(
    embedding_model_installed(), f"{config.EMBEDDING_MODEL} is not available"
)
class OllamaEmbedLiveTest(unittest.TestCase):
    def test_embed(self):
        result = client.embed(config.EMBEDDING_MODEL, "What is 2 + 5?")
        self.assertGreater(len(result["embedding"]), 100)
        self.assertTrue(all(isinstance(x, float) for x in result["embedding"][:5]))


if __name__ == "__main__":
    unittest.main()
