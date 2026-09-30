"""
Fit the matrix-factorization router and calibrate the cascade and MF thresholds.

Fit one matrix-factorization router per benchmark and calibrate cascade and
MF thresholds on that benchmark's calibration split only. MMLU-Pro and
GSM-Hard are never fitted together. Eval labels are ignored.

    python -m experiment.run_experiment --exp-id calibration --split train \
        --routers small_only medium_only large_only --reps 1 --no-energy
    python -m scripts.fit_routers --results results/calibration

Writes:
    artifacts/mf_<benchmark>.npz       MF weights for that benchmark only
    artifacts/router_calibration.json  per-benchmark thresholds
    artifacts/threshold_sweep.csv      simulated accuracy and cost per threshold

Both thresholds are chosen on calibration data only: the
cheapest threshold whose simulated accuracy is at least
config.CALIBRATION_QUALITY_TARGET × always-large's accuracy. The simulation
replays the logged answers through the real router classes. This is valid
because generation is deterministic (temperature 0, fixed seed), so every
cascade stage makes exactly the call the matching fixed-model run made.
Cost is Ollama's measured total_duration, used as a proxy for energy; the
embedding call of the MF router (milliseconds) is left out.
"""

import argparse
import csv
import hashlib
import json
import random
import sys
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

import numpy as np

import config
from benchmarks import BENCHMARKS
from ollama_client import OllamaClient
from routers.base import Attempt
from routers.cascade import CascadeRouter
from routers.matrix_factorization import MatrixFactorizationRouter, predict_matrix

SWEEP_FIELDS = [
    "benchmark", "router", "subset", "threshold", "n", "accuracy", "cost_s",
    "target_accuracy", "meets_target", *(f"share_{m}" for m in config.MODEL_ORDER),
]


@dataclass(frozen=True)
class Label:
    """What one fixed-model run logged for one train question."""

    attempt: Attempt
    correct: bool
    cost_s: float


class ReplayLLM:
    """Answers from the logged calls instead of calling Ollama."""

    def __init__(self, labels: dict[str, Label], embedding=None):
        self.labels = labels
        self.embedding = embedding
        self.models_called = []

    def generate(self, model):
        self.models_called.append(model)
        return self.labels[model].attempt

    def embed(self, text):
        return self.embedding


def parse_args():
    parser = argparse.ArgumentParser(description=__doc__.strip().splitlines()[0])
    parser.add_argument(
        "--results", nargs="+", type=Path, required=True,
        help="experiment folders with train runs of the fixed-model routers",
    )
    return parser.parse_args()


def main():
    args = parse_args()
    fingerprint = config.settings_fingerprint()

    labels = load_labels(args.results, fingerprint)
    questions = question_index()
    names = sorted({key[0] for key in labels if key in questions})
    if not names:
        print(
            "No calibration questions have answers from all of "
            f"{config.MODEL_ORDER}. Collect calibration labels first (see --help).",
            file=sys.stderr,
        )
        return 1

    client = OllamaClient(base_url=config.OLLAMA_URL, timeout=config.CLIENT_TIMEOUT_S)
    fitted = {}
    sweep = []
    for name in names:
        keys = keys_for_benchmark(labels, questions, name)
        if len(keys) < 10:
            print(f"Skipping {name}: only {len(keys)} labeled questions.")
            continue
        print(f"\n{name}: {len(keys)} calibration questions with labels from all models")
        fitted[name] = fit_benchmark(
            name, keys, labels, questions, client, sweep, fingerprint,
        )

    if not fitted:
        print("Nothing was fitted.", file=sys.stderr)
        return 1

    payload = {
        "created_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "fingerprint": fingerprint,
        "quality_target": config.CALIBRATION_QUALITY_TARGET,
        "results": [str(path) for path in args.results],
        "benchmarks": fitted,
    }
    if len(fitted) == 1:
        only = next(iter(fitted.values()))
        payload["routers"] = {
            "cascade": only["cascade"],
            "matrix_factorization": only["matrix_factorization"],
            "mf": only["matrix_factorization"],
        }

    config.ARTIFACTS_DIR.mkdir(parents=True, exist_ok=True)
    config.CALIBRATION_FILE.write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")
    _write_sweep(config.ARTIFACTS_DIR / "threshold_sweep.csv", sweep)
    print(f"\nWrote {config.CALIBRATION_FILE}")
    print(f"Wrote {config.ARTIFACTS_DIR / 'threshold_sweep.csv'}")
    for name in fitted:
        print(f"Wrote {config.mf_artifact(name)}")
    return 0


def question_index() -> dict:
    """Calibration questions only. The eval split is not loaded."""
    questions = {}
    for name, benchmark in BENCHMARKS.items():
        path = benchmark.data_path("calibration")
        if path.exists() and path.name != f"{name}_eval.jsonl":
            for question in benchmark.load("calibration"):
                questions[(name, question.id)] = question
    return questions


def keys_for_benchmark(labels, questions, benchmark) -> list:
    """Label keys for one benchmark. Other benchmarks are left out."""
    return sorted(key for key in labels if key[0] == benchmark and key in questions)


def fit_benchmark(name, keys, labels, questions, client, sweep, fingerprint) -> dict:
    """Fit MF and calibrate both routers on this benchmark's calibration keys."""
    texts = [questions[key].text for key in keys]
    embeddings = embed_texts(client, texts)
    embedding_by_key = dict(zip(keys, embeddings))

    matrix = np.array(
        [[labels[key][model].correct for model in config.MODEL_ORDER] for key in keys],
        float,
    )
    position = {key: row for row, key in enumerate(keys)}
    fit_keys, val_keys = _split(keys, config.MF["val_fraction"], config.SEED)
    fit_rows = [position[key] for key in fit_keys]
    val_rows = [position[key] for key in val_keys]

    weights, factors, bias = fit_mf(
        embeddings[fit_rows], matrix[fit_rows],
        **{key: config.MF[key] for key in ("rank", "l2", "lr", "epochs")},
    )
    report_fit(weights, factors, bias, embeddings, matrix, fit_keys, fit_rows, val_keys, val_rows)

    start = len(sweep)
    cascade = calibrate(
        "cascade", lambda threshold: CascadeRouter(threshold), keys, "calibration",
        labels, questions, embedding_by_key, sweep,
    )
    matrix_factorization = calibrate(
        "matrix_factorization",
        lambda threshold: MatrixFactorizationRouter(weights, factors, bias, threshold),
        val_keys, "calibration-val",
        labels, questions, embedding_by_key, sweep,
    )
    for row in sweep[start:]:
        row["benchmark"] = name

    config.ARTIFACTS_DIR.mkdir(parents=True, exist_ok=True)
    np.savez(
        config.mf_artifact(name),
        W=weights, V=factors, b=bias,
        models=np.array(config.MODEL_ORDER),
        embedding_model=np.array(config.EMBEDDING_MODEL),
        fingerprint=np.array(fingerprint),
        benchmark=np.array(name),
    )
    return {"cascade": cascade, "matrix_factorization": matrix_factorization}


# ---------------------------------------------------------------------------
# Labels and embeddings
# ---------------------------------------------------------------------------

def load_labels(result_dirs, fingerprint) -> dict:
    """{(benchmark, query_id): {model: Label}} for questions all models answered."""
    labels = defaultdict(dict)
    skipped = 0

    for run_json in sorted(p for d in result_dirs for p in Path(d).rglob("run.json")):
        info = json.loads(run_json.read_text(encoding="utf-8"))
        if info.get("split") not in ("train", "calibration") or info["router"].get("class") != "FixedModelRouter":
            continue
        if info.get("settings_fingerprint") != fingerprint:
            skipped += 1
            continue

        benchmark = info["benchmark"]
        with open(run_json.parent / "calls.csv", newline="", encoding="utf-8") as f:
            for row in csv.DictReader(f):
                if row["kind"] != "generate" or row["error"]:
                    continue
                attempt = Attempt(
                    model=row["model"],
                    response=row["response"],
                    extracted=row["extracted_answer"] or None,
                    confidence=float(row["confidence"]) if row["confidence"] else None,
                    done_reason=row["done_reason"] or None,
                )
                # The first repetition wins if a question was run more than once.
                labels[(benchmark, row["query_id"])].setdefault(row["model"], Label(
                    attempt=attempt,
                    correct=row["correct"] == "True",
                    cost_s=float(row["total_duration_s"]),
                ))

    if skipped:
        print(f"Skipped {skipped} run(s) collected with other prompts or settings.")
    return {
        key: by_model for key, by_model in labels.items()
        if all(model in by_model for model in config.MODEL_ORDER)
    }


def embed_texts(client, texts) -> np.ndarray:
    """Embed texts with config.EMBEDDING_MODEL, cached in artifacts/embeddings/."""
    safe_name = config.EMBEDDING_MODEL.replace(":", "_").replace("/", "_")
    cache_path = config.EMBEDDING_CACHE_DIR / f"{safe_name}.json"
    cache = {}
    if cache_path.exists():
        cache = json.loads(cache_path.read_text(encoding="utf-8"))

    hashes = [hashlib.sha256(text.encode("utf-8")).hexdigest() for text in texts]
    missing = [(h, t) for h, t in zip(hashes, texts) if h not in cache]
    if missing:
        print(f"Embedding {len(missing)} question(s) with {config.EMBEDDING_MODEL} ...")
        for text_hash, text in missing:
            cache[text_hash] = client.embed(config.EMBEDDING_MODEL, text)["embedding"]
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        cache_path.write_text(json.dumps(cache), encoding="utf-8")

    return np.array([cache[h] for h in hashes], dtype=float)


# ---------------------------------------------------------------------------
# Matrix factorization
# ---------------------------------------------------------------------------

def fit_mf(X, Y, rank, l2, lr, epochs, seed=config.SEED):
    """Fit P(correct) = sigmoid(V · (W · x) + b) with full-batch Adam.

    X: (n, dim) embeddings, Y: (n, n_models) 0/1 correctness.
    """
    rng = np.random.default_rng(seed)
    X = X / np.linalg.norm(X, axis=1, keepdims=True)
    n, dim = X.shape
    n_models = Y.shape[1]

    rates = np.clip(Y.mean(axis=0), 0.01, 0.99)
    params = {
        "W": rng.normal(0.0, 0.1, (rank, dim)),
        "V": rng.normal(0.0, 0.1, (n_models, rank)),
        "b": np.log(rates / (1 - rates)),   # start at each model's accuracy
    }
    first = {k: np.zeros_like(v) for k, v in params.items()}
    second = {k: np.zeros_like(v) for k, v in params.items()}
    beta1, beta2, eps = 0.9, 0.999, 1e-8

    for step in range(1, epochs + 1):
        H = X @ params["W"].T                        # (n, rank)
        P = _sigmoid(H @ params["V"].T + params["b"])
        G = (P - Y) / (n * n_models)                 # d mean log-loss / d logits
        grads = {
            "W": (G @ params["V"]).T @ X + 2 * l2 * params["W"],
            "V": G.T @ H + 2 * l2 * params["V"],
            "b": G.sum(axis=0),
        }
        for k in params:
            first[k] = beta1 * first[k] + (1 - beta1) * grads[k]
            second[k] = beta2 * second[k] + (1 - beta2) * grads[k] ** 2
            corrected_first = first[k] / (1 - beta1 ** step)
            corrected_second = second[k] / (1 - beta2 ** step)
            params[k] -= lr * corrected_first / (np.sqrt(corrected_second) + eps)

    return params["W"], params["V"], params["b"]


def report_fit(W, V, b, embeddings, Y, fit_keys, fit_rows, val_keys, val_rows):
    """Compare MF on the validation part with two trivial predictors.

    If MF is not better than the per-benchmark prior, it has only learned
    which benchmark a question comes from.
    """
    Y_fit, Y_val = Y[fit_rows], Y[val_rows]

    global_prior = np.tile(Y_fit.mean(axis=0), (len(val_rows), 1))
    per_benchmark = {}
    for name in {k[0] for k in [*fit_keys, *val_keys]}:
        rows = [i for i, k in zip(fit_rows, fit_keys) if k[0] == name]
        per_benchmark[name] = Y[rows].mean(axis=0) if rows else Y_fit.mean(axis=0)
    benchmark_prior = np.array([per_benchmark[k[0]] for k in val_keys])
    mf = predict_matrix(W, V, b, embeddings[val_rows])

    print(f"\nMF fit on {len(fit_keys)} questions, validated on {len(val_keys)}:")
    print(f"  {'predictor':<18} {'log-loss':>9} {'accuracy':>9}")
    for name, predicted in [
        ("global prior", global_prior),
        ("benchmark prior", benchmark_prior),
        ("matrix fact.", mf),
    ]:
        print(f"  {name:<18} {_log_loss(predicted, Y_val):>9.4f} "
              f"{((predicted >= 0.5) == Y_val).mean():>9.1%}")


# ---------------------------------------------------------------------------
# Threshold calibration
# ---------------------------------------------------------------------------

def calibrate(name, make_router, keys, subset, labels, questions, embeddings, sweep):
    """Sweep config.THRESHOLD_GRID and pick the threshold for one router."""
    large = config.MODEL_ORDER[-1]
    large_accuracy = float(np.mean([labels[k][large].correct for k in keys]))
    target = config.CALIBRATION_QUALITY_TARGET * large_accuracy

    for model in config.MODEL_ORDER:
        sweep.append({
            "router": f"always:{model}", "subset": subset, "threshold": None,
            "n": len(keys),
            "accuracy": float(np.mean([labels[k][model].correct for k in keys])),
            "cost_s": float(np.mean([labels[k][model].cost_s for k in keys])),
            "target_accuracy": target, "meets_target": None,
            **{f"share_{m}": float(m == model) for m in config.MODEL_ORDER},
        })

    rows = []
    for threshold in config.THRESHOLD_GRID:
        router = make_router(threshold)
        correct, cost, finals = [], [], []
        for key in keys:
            llm = ReplayLLM(labels[key], embeddings.get(key))
            final = router.answer(questions[key], llm)
            correct.append(labels[key][final.model].correct)
            cost.append(sum(labels[key][m].cost_s for m in llm.models_called))
            finals.append(final.model)
        accuracy = float(np.mean(correct))
        rows.append({
            "router": name, "subset": subset, "threshold": threshold, "n": len(keys),
            "accuracy": accuracy, "cost_s": float(np.mean(cost)),
            "target_accuracy": target, "meets_target": bool(accuracy >= target),
            **{f"share_{m}": finals.count(m) / len(finals) for m in config.MODEL_ORDER},
        })
    sweep.extend(rows)

    meeting = [row for row in rows if row["meets_target"]]
    if meeting:
        chosen = min(meeting, key=lambda row: (row["cost_s"], -row["accuracy"]))
    else:
        chosen = max(rows, key=lambda row: (row["accuracy"], -row["cost_s"]))
        print(f"WARNING: no {name} threshold reaches the target; using the most accurate.")

    print(
        f"\n{name}: threshold {chosen['threshold']:.2f} -> accuracy "
        f"{chosen['accuracy']:.1%} (always-large {large_accuracy:.1%}, "
        f"target {target:.1%}), mean cost {chosen['cost_s']:.2f}s on {subset}"
    )
    return {
        "threshold": chosen["threshold"],
        "subset": subset,
        "n": len(keys),
        "simulated_accuracy": chosen["accuracy"],
        "simulated_cost_s": chosen["cost_s"],
        "always_large_accuracy": large_accuracy,
        "meets_target": chosen["meets_target"],
    }


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _split(keys, val_fraction, seed):
    shuffled = list(keys)
    random.Random(seed).shuffle(shuffled)
    n_val = max(1, round(len(shuffled) * val_fraction))
    return sorted(shuffled[n_val:]), sorted(shuffled[:n_val])


def _sigmoid(z):
    return 1.0 / (1.0 + np.exp(-z))


def _log_loss(predicted, actual):
    predicted = np.clip(predicted, 1e-6, 1 - 1e-6)
    return float(-np.mean(actual * np.log(predicted) + (1 - actual) * np.log(1 - predicted)))


def _write_sweep(path, rows):
    with open(path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=SWEEP_FIELDS)
        writer.writeheader()
        writer.writerows(rows)


if __name__ == "__main__":
    sys.exit(main())
