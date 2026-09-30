# AGENTS.md

## Project Goal

Refactor this repository into a reproducible experimental pipeline for
evaluating LLM routing strategies on MMLU-Pro and GSM-Hard.

The pipeline must support three Ollama-hosted models:

- 4B
- 9B
- 27B

All three models may remain resident concurrently, but queries are processed
according to the selected experimental strategy.

## Required Experimental Pipeline

The complete pipeline must support:

1. Dataset preparation
2. Calibration/train/evaluation splitting
3. Running all candidate models on calibration data
4. Training a matrix-factorization router
5. Configuring the cascading router
6. Running fixed-model and routing strategies
7. Measuring energy, accuracy, latency, utilization, and memory
8. Persisting raw measurements
9. Computing aggregate metrics
10. Producing reproducible result files

The entire pipeline should be executable from a small number of documented
commands.

## Benchmarks

Support:

- MMLU-Pro
- GSM-Hard

Each benchmark must have its own:

- dataset adapter
- prompt construction
- answer extraction
- correctness function
- calibration/train/evaluation split
- trained matrix-factorization router

Do not mix MMLU-Pro and GSM-Hard accuracy values.

### Quality Metrics

MMLU-Pro:
- multiple-choice accuracy

GSM-Hard:
- exact-match accuracy on the extracted final numeric answer

## Experimental Strategies

Support at least:

1. `small_only`
2. `medium_only`
3. `large_only`
4. `cascade`
5. `matrix_factorization`

All strategies must implement the same interface and produce the same
structured output format.

Example conceptual interface:

```python
result = strategy.run(query)