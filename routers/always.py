"""
Baselines: every question goes to the same model (always small/middle/large).
"""

from routers.base import BaseRouter


class FixedModelRouter(BaseRouter):
    def __init__(self, model: str, name: str | None = None, models=None):
        super().__init__(models)

        if model not in self.models:
            raise ValueError(f"{model!r} is not in the model list {self.models}")
        self.model = model
        if name is not None:
            self.name = name

    def _answer(self, question, llm):
        return llm.generate(self.model)

    def config(self) -> dict:
        return {**super().config(), "model": self.model}
