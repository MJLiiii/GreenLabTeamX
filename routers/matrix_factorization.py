"""
Predictive routing with matrix factorization (in the spirit of RouteLLM).

The chance that model m answers query q correctly is modeled as

    P(correct | q, m) = sigmoid(V[m] · (W · e_q) + b[m])

where e_q is the unit-normalized embedding of the question text. W, V and b
are fitted by scripts/fit_routers.py on the train split. The router picks the
smallest model whose predicted chance is at least the threshold, and the
largest model otherwise. The embedding call is part of the measured cost.
"""

from pathlib import Path

import numpy as np

import config
from routers.base import BaseRouter, check_threshold


class MatrixFactorizationRouter(BaseRouter):
    name = "mf"

    def __init__(
        self,
        W,
        V,
        b,
        threshold: float,
        models=None,
        embedding_model: str = config.EMBEDDING_MODEL,
        artifact: str | None = None,
    ):
        super().__init__(models)

        self.W = np.asarray(W, dtype=float)   # (rank, embedding_dim)
        self.V = np.asarray(V, dtype=float)   # (n_models, rank)
        self.b = np.asarray(b, dtype=float)   # (n_models,)
        if self.V.shape != (len(self.models), self.W.shape[0]):
            raise ValueError(
                f"V has shape {self.V.shape}, expected "
                f"({len(self.models)}, {self.W.shape[0]})"
            )
        if self.b.shape != (len(self.models),):
            raise ValueError(f"b has shape {self.b.shape}, expected ({len(self.models)},)")

        self.threshold = check_threshold(threshold)
        self.embedding_model = embedding_model
        self.artifact = artifact

    @classmethod
    def load(cls, path=config.MF_ARTIFACT, threshold: float | None = None):
        """Load a fitted router and check it matches the current config."""
        path = Path(path)
        if not path.exists():
            raise FileNotFoundError(
                f"{path} does not exist. Fit it with: python -m scripts.fit_routers"
            )

        with np.load(path) as data:
            models = [str(m) for m in data["models"]]
            embedding_model = str(data["embedding_model"])
            fingerprint = str(data["fingerprint"])
            W, V, b = data["W"], data["V"], data["b"]

        if models != config.MODEL_ORDER:
            raise ValueError(f"{path} was fitted for {models}, config uses {config.MODEL_ORDER}")
        if embedding_model != config.EMBEDDING_MODEL:
            raise ValueError(
                f"{path} was fitted with {embedding_model}, "
                f"config uses {config.EMBEDDING_MODEL}"
            )
        if fingerprint != config.settings_fingerprint():
            raise ValueError(
                f"{path} was fitted on answers collected with other prompts or "
                f"generation settings. Collect new train labels and refit."
            )

        return cls(W, V, b, threshold, models, embedding_model, artifact=str(path))

    def predict(self, embedding) -> dict[str, float]:
        """Predicted chance that each model answers correctly."""
        probabilities = predict_matrix(self.W, self.V, self.b, [embedding])[0]
        return dict(zip(self.models, probabilities.tolist()))

    def choose(self, embedding) -> str:
        probabilities = self.predict(embedding)
        for model in self.models[:-1]:
            if probabilities[model] >= self.threshold:
                return model
        return self.models[-1]

    def _answer(self, question, llm):
        return llm.generate(self.choose(llm.embed(question.text)))

    def config(self) -> dict:
        return {
            **super().config(),
            "threshold": self.threshold,
            "rank": int(self.W.shape[0]),
            "embedding_model": self.embedding_model,
            "artifact": self.artifact,
        }


def normalize(embeddings) -> np.ndarray:
    """Scale each row to unit length."""
    embeddings = np.asarray(embeddings, dtype=float)
    norms = np.linalg.norm(embeddings, axis=1, keepdims=True)
    return embeddings / np.where(norms == 0, 1.0, norms)


def predict_matrix(W, V, b, embeddings) -> np.ndarray:
    """P(correct) for every (query, model) pair, shape (n_queries, n_models)."""
    logits = normalize(embeddings) @ W.T @ V.T + b
    return 1.0 / (1.0 + np.exp(-logits))
