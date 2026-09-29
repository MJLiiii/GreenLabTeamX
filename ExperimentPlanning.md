Choice of LLMs:
(Need to be under 27B)
https://huggingface.co/collections/Qwen/qwen35 4b 9b 27b
Small:4b
Middle:9b
Big:27b

Benchmarks:
MMLU-Pro, GSM-Hard
Routing Strategies:
Always small:MMLU-Pro, GSM-Hard
Always big:MMLU-Pro, GSM-Hard
Predictive: train matrix-factorization routing model on MMLU-Pro/GSM8K-Hard performance 
Non-predictive: Cascading routing:MMLU-Pro, GSM-Hard

Research Questions
The goal is refined into the following research questions:
• RQ1 – Energy Consumption: How does the energy con-
sumption of LLM routing strategies compare with small-
only and large-only inference baselines?
• RQ1.1 – Answer Quality: How does the answer qual-
ity achieved by LLM routing strategies compare with the
small-only and large-only baselines across knowledge and
mathematical reasoning tasks?
• RQ2 – Energy–Quality Trade-off: How do predictive
routing and cascading routing differ in their energy–quality
trade-offs?
• RQ3 – Computational Performance: How do the end-
to-end inference latency and resource utilization of LLM
routing strategies compare with the small-only and large-
only baselines?

https://github.com/tdurieux/EnergiBridge Use this tool to measure

Environment:
CPU: AMD Ryzen Threadripper PRO 9955WX 16-Cores
GPU: 2xNVIDIA RTX 4000 Ada Generation 20Gb VRAM
RAM: 4x16GiB DIMM DDR5 (Buffered) 4800 MHz
Ollama: 0.34.4

