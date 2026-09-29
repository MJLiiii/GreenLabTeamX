"""
Non-predictive routing: cascade from the smallest to the largest model.

Each model answers in turn. The first answer that was not cut off by the
token limit, could be extracted, and whose confidence (exp of the mean
logprob of the answer tokens) reaches the threshold is accepted; the largest
model always answers if it is reached. A cut-off response is never accepted:
its "answer" is just a number from the middle of the reasoning.
Every rejected attempt still costs energy and time, which is the trade-off
this strategy is measured on.
"""

from routers.base import Attempt, BaseRouter, check_threshold


class CascadeRouter(BaseRouter):
    name = "cascade"

    def __init__(self, threshold: float, models=None):
        super().__init__(models)
        self.threshold = check_threshold(threshold)

    def accepts(self, attempt: Attempt) -> bool:
        """True if the cascade stops at this attempt."""
        return (
            attempt.ok
            and attempt.done_reason != "length"
            and attempt.extracted is not None
            and attempt.confidence is not None
            and attempt.confidence >= self.threshold
        )

    def _answer(self, question, llm):
        for model in self.models[:-1]:
            attempt = llm.generate(model)
            if self.accepts(attempt):
                return attempt
        return llm.generate(self.models[-1])

    def config(self) -> dict:
        return {**super().config(), "threshold": self.threshold}
