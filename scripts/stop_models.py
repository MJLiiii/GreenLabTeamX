"""
Unload all experiment models from Ollama.

    python -m scripts.stop_models
"""

import config
from experiment.models import unload_all
from ollama_client import OllamaClient


def main():
    client = OllamaClient(base_url=config.OLLAMA_URL, timeout=config.CLIENT_TIMEOUT_S)
    unload_all(client)
    print("\nDone. Check with: ollama ps")


if __name__ == "__main__":
    main()
