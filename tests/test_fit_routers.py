"""Tests for scripts/fit_routers.py on synthetic labels (no Ollama needed)."""

import json
import unittest

import numpy as np

import config
from benchmarks.base import Question
from routers.base import Attempt
from routers.cascade import CascadeRouter
from routers.matrix_factorization import predict_matrix
from scripts.fit_routers import Label, calibrate, fit_mf

SMALL, MIDDLE, LARGE = config.MODEL_ORDER


class FitMFTest(unittest.TestCase):
    def test_learns_which_queries_the_small_model_gets_right(self):
        rng = np.random.default_rng(0)
        easy = rng.normal([3.0, 0.0, 0.0], 0.3, (40, 3))
        hard = rng.normal([0.0, 3.0, 0.0], 0.3, (40, 3))
        X = np.vstack([easy, hard])
        # Easy queries: every model is right. Hard ones: only the large model.
        Y = np.vstack([np.ones((40, 3)), np.tile([0.0, 0.0, 1.0], (40, 1))])

        W, V, b = fit_mf(X, Y, rank=2, l2=1e-4, lr=0.05, epochs=500)
        P = predict_matrix(W, V, b, X)

        self.assertGreater(P[:40, 0].mean(), 0.8)
        self.assertLess(P[40:, 0].mean(), 0.2)
        self.assertGreater(P[:, 2].mean(), 0.8)


class CalibrateTest(unittest.TestCase):
    def labels(self):
        """Half the questions: small is right and sure. Other half: only large is right."""
        labels, questions = {}, {}
        for i in range(20):
            key = ("gsm_hard", str(i))
            easy = i < 10
            questions[key] = Question(str(i), f"q{i}", "1")
            labels[key] = {
                SMALL: Label(
                    Attempt(SMALL, "r", "1", 0.95 if easy else 0.6, "stop"),
                    correct=easy, cost_s=1.0,
                ),
                MIDDLE: Label(
                    Attempt(MIDDLE, "r", "1", 0.7, "stop"), correct=False, cost_s=3.0,
                ),
                LARGE: Label(
                    Attempt(LARGE, "r", "1", 0.9, "stop"), correct=True, cost_s=10.0,
                ),
            }
        return labels, questions

    def test_picks_cheapest_threshold_meeting_target(self):
        labels, questions = self.labels()
        sweep = []
        chosen = calibrate(
            "cascade", CascadeRouter, sorted(labels), "train",
            labels, questions, {}, sweep,
        )

        # Accepting only confident small answers (0.6 < t <= 0.95) is exact.
        self.assertGreater(chosen["threshold"], 0.7)
        self.assertLessEqual(chosen["threshold"], 0.95)
        self.assertEqual(chosen["simulated_accuracy"], 1.0)
        # Easy: 1s. Hard: small + middle + large = 14s. Mean 7.5s < 10s (always-large).
        self.assertAlmostEqual(chosen["simulated_cost_s"], 7.5)
        self.assertEqual(len(sweep), len(config.MODEL_ORDER) + len(config.THRESHOLD_GRID))
        # Written to router_calibration.json, so it must be plain JSON.
        json.dumps(chosen)

    def test_keys_stay_inside_one_benchmark(self):
        from scripts.fit_routers import keys_for_benchmark

        labels = {("mmlu_pro", "1"): {}, ("gsm_hard", "1"): {}, ("mmlu_pro", "2"): {}}
        questions = {("mmlu_pro", "1"): None, ("gsm_hard", "1"): None}
        self.assertEqual(keys_for_benchmark(labels, questions, "mmlu_pro"), [("mmlu_pro", "1")])
        self.assertEqual(keys_for_benchmark(labels, questions, "gsm_hard"), [("gsm_hard", "1")])


if __name__ == "__main__":
    unittest.main()
