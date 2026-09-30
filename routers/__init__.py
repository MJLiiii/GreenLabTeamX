"""
Routing strategies, by command-line name.

Canonical names are the five strategies in AGENT.md. Older names remain as
aliases so existing commands keep working.

Cascade and matrix-factorization thresholds come from
artifacts/router_calibration.json unless one is passed explicitly.
Matrix-factorization weights are loaded per benchmark.
"""

import json

import config
from routers.always import FixedModelRouter
from routers.cascade import CascadeRouter
from routers.matrix_factorization import MatrixFactorizationRouter

CANONICAL_STRATEGIES = (
    "small_only",
    "medium_only",
    "large_only",
    "cascade",
    "matrix_factorization",
)

ALIASES = {
    "always_small": "small_only",
    "always_middle": "medium_only",
    "always_large": "large_only",
    "mf": "matrix_factorization",
}

_MODEL_KEY = {
    "small_only": "small",
    "medium_only": "middle",
    "large_only": "large",
}

ROUTERS = {name: name for name in (*CANONICAL_STRATEGIES, *ALIASES)}

CALIBRATED_ROUTERS = ("cascade", "matrix_factorization", "mf")

_THRESHOLD_KEYS = {
    "cascade": ("cascade",),
    "matrix_factorization": ("matrix_factorization", "mf"),
    "mf": ("mf", "matrix_factorization"),
}


def build_router(name: str, threshold: float | None = None, benchmark: str | None = None):
    canonical = ALIASES.get(name, name)
    if canonical not in _MODEL_KEY and canonical not in ("cascade", "matrix_factorization"):
        raise ValueError(f"Unknown router {name!r}. Choose from {sorted(ROUTERS)}.")

    if canonical in ("cascade", "matrix_factorization") and threshold is None:
        threshold = calibrated_threshold(canonical, benchmark)

    if canonical in _MODEL_KEY:
        recorded = name if name in ALIASES else canonical
        return FixedModelRouter(config.MODELS[_MODEL_KEY[canonical]], name=recorded)

    if canonical == "cascade":
        return CascadeRouter(threshold)

    path = _mf_path(benchmark)
    router = MatrixFactorizationRouter.load(path, threshold, benchmark=benchmark)
    router.name = "mf" if name == "mf" else "matrix_factorization"
    return router


def calibrated_threshold(name: str, benchmark: str | None = None) -> float:
    path = config.CALIBRATION_FILE
    if not path.exists():
        raise FileNotFoundError(
            f"{path} does not exist. Run 'python -m scripts.fit_routers' "
            f"or pass a threshold explicitly."
        )

    calibration = json.loads(path.read_text(encoding="utf-8"))
    if calibration.get("fingerprint") != config.settings_fingerprint():
        raise ValueError(
            f"{path} was calibrated with other prompts or generation settings. "
            f"Collect new calibration labels and rerun scripts/fit_routers.py."
        )

    canonical = ALIASES.get(name, name)
    keys = _THRESHOLD_KEYS.get(canonical, (canonical, name))
    per_benchmark = calibration.get("benchmarks", {})
    if benchmark and benchmark in per_benchmark:
        block = per_benchmark[benchmark]
        for key in keys:
            if key in block:
                return block[key]["threshold"]
        raise KeyError(f"No {canonical} threshold for benchmark {benchmark!r} in {path}.")

    routers = calibration.get("routers") or {}
    for key in keys:
        if key in routers:
            return routers[key]["threshold"]
    known = sorted(per_benchmark)
    raise KeyError(
        f"No threshold for {canonical!r} in {path}. Pass benchmark= one of {known}."
    )


def _mf_path(benchmark: str | None):
    """Prefer the per-benchmark file. Fall back to a legacy pooled artifact."""
    if not benchmark:
        return config.MF_ARTIFACT
    specific = config.mf_artifact(benchmark)
    if specific.exists() or not config.MF_ARTIFACT.exists():
        return specific
    return config.MF_ARTIFACT
