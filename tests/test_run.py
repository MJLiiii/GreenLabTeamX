"""End-to-end test for experiment/run.py. Skipped when Ollama is not reachable."""

import csv
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import config
from ollama_client import OllamaClient

FIXTURE = Path(__file__).parent / "fixtures" / "gsm_hard_tiny.jsonl"

client = OllamaClient()
OLLAMA_UP = client.is_available()


def run(router, out_dir, *extra):
    return subprocess.run(
        [sys.executable, "-m", "experiment.run",
         "--router", router, "--benchmark", "gsm_hard",
         "--data", str(FIXTURE), "--limit", "2", "--out-dir", str(out_dir), *extra],
        cwd=config.ROOT, capture_output=True, text=True, timeout=900,
    )


def read_csv(path):
    with open(path, newline="", encoding="utf-8") as f:
        return list(csv.DictReader(f))


@unittest.skipUnless(OLLAMA_UP, f"Ollama is not reachable at {client.base_url}")
class RunTest(unittest.TestCase):
    def test_always_small(self):
        with tempfile.TemporaryDirectory() as tmp:
            out_dir = Path(tmp) / "always_small"
            completed = run("always_small", out_dir)
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)

            queries = read_csv(out_dir / "queries.csv")
            self.assertEqual(len(queries), 2)
            for row in queries:
                self.assertEqual(row["error"], "")
                self.assertEqual(row["final_model"], config.MODELS["small"])
                self.assertEqual(row["num_generate_calls"], "1")
                self.assertIn(row["correct"], ("True", "False"))

            calls = read_csv(out_dir / "calls.csv")
            self.assertEqual(len(calls), 2)
            for call in calls:
                self.assertEqual(call["is_final"], "True")
                self.assertTrue(call["confidence"])
                self.assertLess(int(call["started_at_ms"]), int(call["ended_at_ms"]))

            info = json.loads((out_dir / "run.json").read_text())
            self.assertEqual(info["num_questions"], 2)
            self.assertEqual(info["settings_fingerprint"], config.settings_fingerprint())
            self.assertIsNotNone(info["finished_at"])
            self.assertEqual(info["summary"]["errors"], 0)

    def test_cascade(self):
        with tempfile.TemporaryDirectory() as tmp:
            out_dir = Path(tmp) / "cascade"
            completed = run("cascade", out_dir, "--threshold", "0.9")
            self.assertEqual(completed.returncode, 0, completed.stdout + completed.stderr)

            queries = read_csv(out_dir / "queries.csv")
            calls = read_csv(out_dir / "calls.csv")
            for row in queries:
                models = row["models_called"].split(">")
                self.assertEqual(models[0], config.MODELS["small"])
                self.assertEqual(models[-1], row["final_model"])
                self.assertEqual(
                    int(row["num_generate_calls"]),
                    sum(c["query_id"] == row["query_id"] for c in calls),
                )
                finals = [
                    c for c in calls
                    if c["query_id"] == row["query_id"] and c["is_final"] == "True"
                ]
                self.assertEqual(len(finals), 1)


if __name__ == "__main__":
    unittest.main()
