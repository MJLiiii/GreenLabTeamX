"""Machine description stored with an experiment. Routers do not import this."""

import platform
import socket

from experiment.models import gpu_snapshot


def collect_hardware() -> dict:
    snapshot = gpu_snapshot()
    return {
        "hostname": socket.gethostname(),
        "platform": platform.platform(),
        "python": platform.python_version(),
        "gpus": snapshot.get("gpus"),
        "gpu_error": snapshot.get("error"),
    }
