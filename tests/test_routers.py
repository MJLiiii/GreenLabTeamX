"""Tests for routers/ with a scripted fake LLM (no Ollama needed)."""

import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import numpy as np

import config
from benchmarks.base import Question
from routers import ROUTERS, build_router
from routers.always import FixedModelRouter
from routers.base import Attempt, BaseRouter
from routers.cascade import CascadeRouter
from routers.matrix_factorization import MatrixFactorizationRouter

SMALL, MIDDLE, LARGE = config.MODEL_ORDER
QUESTION = Question(id="1", text="What is 1?", reference="1")


def attempt(model, extracted="1", confidence=0.99, error=None, done_reason="stop"):
    return Attempt(
        model=model, response="The answer is 1", extracted=extracted,
        confidence=confidence, done_reason=done_reason, error=error,
    )


class FakeLLM:
    """Scripted stand-in for experiment.session.QuerySession."""

    def __init__(self, attempts=None, embedding=None):
        self.attempts = attempts or {}
        self.embedding = embedding
        self.generated = []
        self.embedded = []

    def generate(self, model):
        self.generated.append(model)
        return self.attempts.get(model, attempt(model))

    def embed(self, text):
        self.embedded.append(text)
        return self.embedding


class FirstModelRouter(BaseRouter):
    name = "first"

    def _answer(self, question, llm):
        return llm.generate(self.models[0])


class UnknownModelRouter(BaseRouter):
    def _answer(self, question, llm):
        return attempt("not-a-real-model")


class BaseRouterTest(unittest.TestCase):
    def test_cannot_instantiate_base_class(self):
        with self.assertRaises(TypeError):
            BaseRouter()

    def test_default_models(self):
        self.assertEqual(FirstModelRouter().models, config.MODEL_ORDER)

    def test_models_list_is_copied(self):
        models = ["a", "b"]
        router = FirstModelRouter(models=models)
        models.append("c")
        self.assertEqual(router.models, ["a", "b"])

    def test_empty_model_list_is_rejected(self):
        with self.assertRaises(ValueError):
            FirstModelRouter(models=[])

    def test_non_question_is_rejected(self):
        with self.assertRaises(TypeError):
            FirstModelRouter().answer("What is 1?", FakeLLM())

    def test_run_is_the_strategy_interface(self):
        llm = FakeLLM()
        final = FirstModelRouter().run(QUESTION, llm)
        self.assertEqual(final.model, SMALL)
        self.assertEqual(llm.generated, [SMALL])

    def test_unknown_model_is_rejected(self):
        with self.assertRaises(ValueError):
            UnknownModelRouter().answer(QUESTION, FakeLLM())

    def test_config(self):
        self.assertEqual(
            FirstModelRouter(models=["x"]).config(),
            {"router": "first", "class": "FirstModelRouter", "models": ["x"]},
        )


class FixedModelRouterTest(unittest.TestCase):
    def test_makes_one_call_with_its_model(self):
        llm = FakeLLM()
        final = FixedModelRouter(MIDDLE).answer(QUESTION, llm)
        self.assertEqual(llm.generated, [MIDDLE])
        self.assertEqual(final.model, MIDDLE)

    def test_unknown_model_is_rejected(self):
        with self.assertRaises(ValueError):
            FixedModelRouter("not-a-real-model")

    def test_config(self):
        config_ = FixedModelRouter(SMALL, name="always_small").config()
        self.assertEqual(config_["router"], "always_small")
        self.assertEqual(config_["model"], SMALL)


class CascadeRouterTest(unittest.TestCase):
    def run_cascade(self, attempts, threshold=0.9):
        llm = FakeLLM(attempts)
        final = CascadeRouter(threshold).answer(QUESTION, llm)
        return final, llm.generated

    def test_accepts_confident_small_answer(self):
        final, called = self.run_cascade({})
        self.assertEqual(called, [SMALL])
        self.assertEqual(final.model, SMALL)

    def test_escalates_on_low_confidence(self):
        final, called = self.run_cascade({SMALL: attempt(SMALL, confidence=0.5)})
        self.assertEqual(called, [SMALL, MIDDLE])
        self.assertEqual(final.model, MIDDLE)

    def test_escalates_on_missing_answer(self):
        _, called = self.run_cascade({SMALL: attempt(SMALL, extracted=None)})
        self.assertEqual(called, [SMALL, MIDDLE])

    def test_escalates_on_missing_confidence(self):
        _, called = self.run_cascade({SMALL: attempt(SMALL, confidence=None)})
        self.assertEqual(called, [SMALL, MIDDLE])

    def test_escalates_on_truncated_answer(self):
        _, called = self.run_cascade({SMALL: attempt(SMALL, done_reason="length")})
        self.assertEqual(called, [SMALL, MIDDLE])

    def test_escalates_on_error(self):
        _, called = self.run_cascade({SMALL: attempt(SMALL, error="timeout")})
        self.assertEqual(called, [SMALL, MIDDLE])

    def test_largest_model_always_answers(self):
        low = {m: attempt(m, confidence=0.1) for m in config.MODEL_ORDER}
        final, called = self.run_cascade(low)
        self.assertEqual(called, [SMALL, MIDDLE, LARGE])
        self.assertEqual(final.model, LARGE)

    def test_threshold_is_validated(self):
        for threshold in (None, -0.1, 1.5):
            with self.assertRaises(ValueError):
                CascadeRouter(threshold)

    def test_config_includes_threshold(self):
        self.assertEqual(CascadeRouter(0.8).config()["threshold"], 0.8)


# Rank-2 model on 2-d embeddings: [1, 0] suits the small model, [0, 1] the
# middle model, and [-1, -1] no model except the large fallback.
W = np.eye(2)
V = np.array([[10.0, 0.0], [0.0, 10.0], [0.0, 0.0]])
B = np.array([0.0, 0.0, 5.0])


def save_artifact(path, **overrides):
    data = {
        "W": W, "V": V, "b": B,
        "models": np.array(config.MODEL_ORDER),
        "embedding_model": np.array(config.EMBEDDING_MODEL),
        "fingerprint": np.array(config.settings_fingerprint()),
        **overrides,
    }
    np.savez(path, **data)


class MatrixFactorizationRouterTest(unittest.TestCase):
    def router(self, threshold=0.9):
        return MatrixFactorizationRouter(W, V, B, threshold)

    def test_choose(self):
        router = self.router()
        self.assertEqual(router.choose([1.0, 0.0]), SMALL)
        self.assertEqual(router.choose([0.0, 3.0]), MIDDLE)
        self.assertEqual(router.choose([-1.0, -1.0]), LARGE)

    def test_answer_embeds_question_then_generates(self):
        llm = FakeLLM(embedding=[0.0, 1.0])
        final = self.router().answer(QUESTION, llm)
        self.assertEqual(llm.embedded, [QUESTION.text])
        self.assertEqual(llm.generated, [MIDDLE])
        self.assertEqual(final.model, MIDDLE)

    def test_predict_returns_probabilities(self):
        probabilities = self.router().predict([1.0, 0.0])
        self.assertEqual(list(probabilities), config.MODEL_ORDER)
        self.assertGreater(probabilities[SMALL], 0.99)

    def test_shape_mismatch_is_rejected(self):
        with self.assertRaises(ValueError):
            MatrixFactorizationRouter(W, V[:2], B, 0.9)

    def test_load(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "mf.npz"
            save_artifact(path)
            router = MatrixFactorizationRouter.load(path, threshold=0.9)
            self.assertEqual(router.choose([1.0, 0.0]), SMALL)
            self.assertEqual(router.config()["artifact"], str(path))

    def test_load_rejects_mismatches(self):
        mismatches = [
            {"models": np.array(["a", "b", "c"])},
            {"embedding_model": np.array("other-embedder")},
            {"fingerprint": np.array("stale")},
        ]
        with tempfile.TemporaryDirectory() as tmp:
            for overrides in mismatches:
                path = Path(tmp) / "mf.npz"
                save_artifact(path, **overrides)
                with self.assertRaises(ValueError):
                    MatrixFactorizationRouter.load(path, threshold=0.9)

    def test_load_missing_file(self):
        with self.assertRaises(FileNotFoundError):
            MatrixFactorizationRouter.load("/nonexistent/mf.npz", threshold=0.9)


class RegistryTest(unittest.TestCase):
    def test_fixed_routers(self):
        for name, model in [
            ("always_small", SMALL), ("always_middle", MIDDLE), ("always_large", LARGE),
        ]:
            router = build_router(name)
            self.assertEqual((router.name, router.model), (name, model))

    def test_explicit_threshold(self):
        self.assertEqual(build_router("cascade", threshold=0.5).threshold, 0.5)

    def test_calibrated_threshold(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "calibration.json"
            path.write_text(json.dumps({
                "fingerprint": config.settings_fingerprint(),
                "routers": {"cascade": {"threshold": 0.7}, "mf": {"threshold": 0.6}},
            }))
            with mock.patch.object(config, "CALIBRATION_FILE", path):
                self.assertEqual(build_router("cascade").threshold, 0.7)

    def test_stale_calibration_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "calibration.json"
            path.write_text(json.dumps({"fingerprint": "stale", "routers": {}}))
            with mock.patch.object(config, "CALIBRATION_FILE", path):
                with self.assertRaises(ValueError):
                    build_router("cascade")

    def test_missing_calibration(self):
        with mock.patch.object(config, "CALIBRATION_FILE", Path("/nonexistent.json")):
            with self.assertRaises(FileNotFoundError):
                build_router("cascade")

    def test_mf_from_artifact(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "mf.npz"
            save_artifact(path)
            with mock.patch.object(config, "MF_ARTIFACT", path):
                self.assertEqual(build_router("mf", threshold=0.9).name, "mf")

    def test_unknown_router(self):
        with self.assertRaises(ValueError):
            build_router("random")

    def test_registry_matches_experiment_plan(self):
        from routers import ALIASES, CANONICAL_STRATEGIES

        self.assertEqual(
            set(CANONICAL_STRATEGIES),
            {"small_only", "medium_only", "large_only", "cascade", "matrix_factorization"},
        )
        self.assertEqual(ALIASES["always_small"], "small_only")
        self.assertEqual(build_router("small_only").name, "small_only")
        self.assertEqual(build_router("always_small").name, "always_small")
        self.assertEqual(build_router("medium_only").model, MIDDLE)
        self.assertEqual(build_router("large_only").model, LARGE)

    def test_thresholds_are_per_benchmark(self):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "calibration.json"
            path.write_text(json.dumps({
                "fingerprint": config.settings_fingerprint(),
                "benchmarks": {
                    "mmlu_pro": {"cascade": {"threshold": 0.2}},
                    "gsm_hard": {"cascade": {"threshold": 0.8}},
                },
            }))
            with mock.patch.object(config, "CALIBRATION_FILE", path):
                self.assertEqual(build_router("cascade", benchmark="mmlu_pro").threshold, 0.2)
                self.assertEqual(build_router("cascade", benchmark="gsm_hard").threshold, 0.8)


if __name__ == "__main__":
    unittest.main()
