"""Benchmarks used in the experiment, by command-line name."""

from benchmarks.gsm_hard import GSMHard
from benchmarks.mmlu_pro import MMLUPro

BENCHMARKS = {
    benchmark.name: benchmark
    for benchmark in (MMLUPro(), GSMHard())
}
