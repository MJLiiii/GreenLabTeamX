"""
Routing strategies from ExperimentPlanning.md, by command-line name.

Thresholds for cascade and mf come from artifacts/router_calibration.json
(written by scripts/fit_routers.py) unless one is passed explicitly.
"""

import json

import config
from routers.always import FixedModelRouter
from routers.cascade import CascadeRouter
from routers.matrix_factorization import MatrixFactorizationRouter

ROUTERS = {
    "always_small": lambda threshold: FixedModelRouter(
        config.MODELS["small"], name="always_small"
    ),
    "always_middle": lambda threshold: FixedModelRouter(
        config.MODELS["middle"], name="always_middle"
    ),
    "always_large": lambda threshold: FixedModelRouter(
        config.MODELS["large"], name="always_large"
    ),
    "cascade": lambda threshold: CascadeRouter(threshold),
    "mf": lambda threshold: MatrixFactorizationRouter.load(config.MF_ARTIFACT, threshold),
}

# Routers whose threshold is calibrated by scripts/fit_routers.py.
CALIBRATED_ROUTERS = ("cascade", "mf")


def build_router(name: str, threshold: float | None = None):
    if name not in ROUTERS:
        raise ValueError(f"Unknown router {name!r}. Choose from {sorted(ROUTERS)}.")
    if name in CALIBRATED_ROUTERS and threshold is None:
        threshold = calibrated_threshold(name)
    return ROUTERS[name](threshold)


def calibrated_threshold(name: str) -> float:
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
            f"Collect new train labels and rerun scripts/fit_routers.py."
        )
    return calibration["routers"][name]["threshold"]
