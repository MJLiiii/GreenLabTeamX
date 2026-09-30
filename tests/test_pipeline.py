"""Pipeline tests that do not need Ollama or EnergiBridge installed."""

import csv
import json
import tempfile
import unittest
from pathlib import Path

import numpy as np

import config
from benchmarks import BENCHMARKS
from benchmarks.base import Question
from benchmarks.gsm_hard import GSMHard
from benchmarks.mmlu_pro import MMLUPro
from experiment.run import run_query
from experiment.run_experiment import main
from measurement.aggregate import aggregate_experiment
from measurement.energibridge import profile_csv, summary_joules, wrap
from routers.always import FixedModelRouter
from routers.cascade import CascadeRouter
from routers.matrix_factorization import MatrixFactorizationRouter
from scripts.fit_routers import fit_mf, load_labels

FIXTURE = Path(__file__).parent / "fixtures" / "energy_tiny.csv"
MMLU = MMLUPro()
GSM = GSMHard()


class BenchmarkContractTest(unittest.TestCase):
    def test_mmlu_pro_prompt_and_letter_accuracy(self):
        question = Question("1", "Pick one.", "B", ("x", "y", "z"), "math")
        prompt = MMLU.format_prompt(question)
        self.assertIn('The answer is (X)', prompt)
        self.assertIn("A. x", prompt)
        self.assertIn("B. y", prompt)
        self.assertIn("Question: Pick one.", prompt)
        self.assertTrue(MMLU.is_correct(MMLU.extract_answer("The answer is (B)"), question))
        self.assertFalse(MMLU.is_correct(MMLU.extract_answer("The answer is (C)"), question))

    def test_gsm_hard_extracts_the_final_number_and_rejects_off_by_one(self):
        question = Question("1", "What is 6 times 7?", "42.0")
        prompt = GSM.format_prompt(question)
        self.assertIn("The answer is N", prompt)
        self.assertIn("Question: What is 6 times 7?", prompt)
        self.assertEqual(GSM.extract_answer("work 7, The answer is 42").value, "42")
        self.assertTrue(GSM.is_correct(GSM.extract_answer("The answer is 42"), question))
        self.assertFalse(GSM.is_correct(GSM.extract_answer("The answer is 43"), question))
        # A letter is not a GSM-Hard answer, and a number is not an MMLU-Pro letter.
        self.assertFalse(GSM.is_correct(MMLU.extract_answer("The answer is (B)"), question))
        self.assertFalse(MMLU.is_correct(GSM.extract_answer("The answer is 42"), question))


class EnergiBridgeTest(unittest.TestCase):
    def test_wrap_uses_the_real_cli_and_does_not_load_models(self):
        command = wrap(
            ["python", "-m", "experiment.run", "--benchmark", "gsm_hard"],
            "/tmp/energy.csv",
            binary="energibridge",
        )
        self.assertEqual(
            command[:8],
            ["energibridge", "--output", "/tmp/energy.csv", "--interval", "200",
             "--max-execution", "21600", "--gpu"],
        )
        self.assertIn("--summary", command)
        self.assertEqual(command[command.index("--") + 1], "python")
        self.assertNotIn("load_models", command)

    def test_summary_line_and_gpu_profile(self):
        text = "Energy consumption in joules: 1598.462417602539 for 16.26 sec of execution.\n"
        self.assertAlmostEqual(summary_joules(text), 1598.462417602539)
        profile = profile_csv(FIXTURE)
        self.assertAlmostEqual(profile["total_gpu_joules"], 10.0)
        self.assertAlmostEqual(profile["total_cpu_joules"], 3.0)
        self.assertAlmostEqual(profile["mean_cpu_utilization_pct"], 30.0)
        self.assertAlmostEqual(profile["mean_gpu_utilization_pct"], 80 / 3)
        self.assertEqual(profile["peak_gpu_memory_mib"], 300.0)
        self.assertEqual(profile["peak_system_memory_bytes"], 8000.0)


class AggregationTest(unittest.TestCase):
    def test_j_per_query_keeps_benchmarks_separate(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for name, benchmark, correct in (
                ("mmlu", "mmlu_pro", ["True", "False"]),
                ("gsm", "gsm_hard", ["True", "True"]),
            ):
                run_dir = root / name
                run_dir.mkdir()
                (run_dir / "run.json").write_text(json.dumps({
                    "run_id": name,
                    "benchmark": benchmark,
                    "split": "eval",
                    "settings_fingerprint": "abc",
                    "router": {"router": "small_only"},
                }), encoding="utf-8")
                with open(run_dir / "queries.csv", "w", newline="", encoding="utf-8") as handle:
                    writer = csv.DictWriter(handle, fieldnames=["correct", "latency_ms"])
                    writer.writeheader()
                    for flag in correct:
                        writer.writerow({"correct": flag, "latency_ms": "1000"})
                (run_dir / "energy.csv").write_text(FIXTURE.read_text(encoding="utf-8"), encoding="utf-8")
            rows = {row["benchmark"]: row for row in aggregate_experiment(root)}
            self.assertEqual(set(rows), {"mmlu_pro", "gsm_hard"})
            self.assertAlmostEqual(rows["mmlu_pro"]["accuracy"], 0.5)
            self.assertAlmostEqual(rows["gsm_hard"]["accuracy"], 1.0)
            self.assertEqual(rows["mmlu_pro"]["accuracy_metric"], "multiple_choice_accuracy")
            self.assertEqual(rows["gsm_hard"]["accuracy_metric"], "exact_match_extracted_number")
            self.assertAlmostEqual(rows["gsm_hard"]["mean_j_per_query"], 5.0)
            self.assertAlmostEqual(rows["gsm_hard"]["mean_latency_ms"], 1000.0)
            self.assertAlmostEqual(rows["gsm_hard"]["mean_gpu_utilization_pct"], 80 / 3)
            self.assertEqual(rows["gsm_hard"]["peak_gpu_memory_mib"], 300.0)


class LatencyPathTest(unittest.TestCase):
    def test_end_to_end_latency_covers_every_cascade_call(self):
        class Stub:
            def generate(self, model, prompt, **kwargs):
                return {
                    "response": "The answer is 7",
                    "done_reason": "stop",
                    "logprobs": None,
                    "total_duration": None,
                    "load_duration": None,
                    "prompt_eval_duration": None,
                    "eval_duration": None,
                    "prompt_eval_count": 3,
                    "prompt_eval_cached_count": 0,
                    "eval_count": 4,
                }

        question = Question("1", "How many?", "7.0")
        router = CascadeRouter(0.99)
        row, calls = run_query(Stub(), router, GSM, question, "run", "eval")
        self.assertEqual(row["num_generate_calls"], 3)
        self.assertEqual(len(calls), 3)
        self.assertEqual(row["models_called"].split(">"), config.MODEL_ORDER)
        self.assertAlmostEqual(float(row["latency_ms"]), float(row["latency_s"]) * 1000.0)
        self.assertGreater(row["latency_ms"], 0)

        fixed = FixedModelRouter(config.MODELS["small"], name="small_only")
        one, one_calls = run_query(Stub(), fixed, GSM, question, "run", "eval")
        self.assertEqual(one["final_model"], config.MODELS["small"])
        self.assertEqual(len(one_calls), 1)
        self.assertEqual(one["router"], "small_only")


class MatrixFactorizationArtifactTest(unittest.TestCase):
    def test_train_and_load_are_benchmark_specific(self):
        rng = np.random.default_rng(1)
        features = rng.normal(size=(30, 4))
        labels = np.ones((30, 3))
        weights, factors, bias = fit_mf(
            features, labels, rank=2, l2=1e-4, lr=0.05, epochs=5,
        )
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "mf_gsm_hard.npz"
            np.savez(
                path,
                W=weights, V=factors, b=bias,
                models=np.array(config.MODEL_ORDER),
                embedding_model=np.array(config.EMBEDDING_MODEL),
                fingerprint=np.array(config.settings_fingerprint()),
                benchmark=np.array("gsm_hard"),
            )
            router = MatrixFactorizationRouter.load(path, 0.5, benchmark="gsm_hard")
            self.assertEqual(router.benchmark, "gsm_hard")
            self.assertEqual(router.threshold, 0.5)
            with self.assertRaises(ValueError):
                MatrixFactorizationRouter.load(path, 0.5, benchmark="mmlu_pro")


class SmokeTest(unittest.TestCase):
    def test_dry_run_lists_both_benchmarks(self):
        import io
        from contextlib import redirect_stdout

        output = io.StringIO()
        with redirect_stdout(output):
            code = main(["--dry-run", "--exp-id", "smoke_should_not_exist", "--reps", "1"])
        text = output.getvalue()
        self.assertEqual(code, 0)
        self.assertIn("small_only__mmlu_pro__rep1", text)
        self.assertIn("matrix_factorization__gsm_hard__rep1", text)
        self.assertNotIn("gsm8k", text)
        self.assertFalse((config.RESULTS_DIR / "smoke_should_not_exist").exists())


class LeakageTest(unittest.TestCase):
    def test_frozen_calibration_and_eval_are_disjoint(self):
        for name in ("mmlu_pro", "gsm_hard"):
            benchmark = BENCHMARKS[name]
            calibration = {q.id for q in benchmark.load("calibration")}
            evaluation = {q.id for q in benchmark.load("eval")}
            self.assertTrue(calibration)
            self.assertTrue(evaluation)
            self.assertFalse(calibration & evaluation)
            self.assertNotEqual(benchmark.data_path("calibration"), benchmark.data_path("eval"))

    def test_eval_runs_are_not_training_labels(self):
        fingerprint = config.settings_fingerprint()
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            for split, query_id in (("eval", "heldout"), ("train", "cal")):
                run_dir = root / split
                run_dir.mkdir()
                (run_dir / "run.json").write_text(json.dumps({
                    "split": split,
                    "benchmark": "gsm_hard",
                    "settings_fingerprint": fingerprint,
                    "router": {"class": "FixedModelRouter", "router": "small_only"},
                }), encoding="utf-8")
                fields = [
                    "kind", "error", "query_id", "model", "response",
                    "extracted_answer", "confidence", "done_reason", "correct",
                    "total_duration_s",
                ]
                with open(run_dir / "calls.csv", "w", newline="", encoding="utf-8") as handle:
                    writer = csv.DictWriter(handle, fieldnames=fields)
                    writer.writeheader()
                    for model in config.MODEL_ORDER:
                        writer.writerow({
                            "kind": "generate", "error": "", "query_id": query_id,
                            "model": model, "response": "The answer is 1",
                            "extracted_answer": "1", "confidence": "0.9", "done_reason": "stop",
                            "correct": "True", "total_duration_s": "1.0",
                        })
            labels = load_labels([root], fingerprint)
            self.assertIn(("gsm_hard", "cal"), labels)
            self.assertNotIn(("gsm_hard", "heldout"), labels)


if __name__ == "__main__":
    unittest.main()
