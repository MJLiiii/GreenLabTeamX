"""Tests for experiment/run_experiment.py planning (no Ollama needed)."""

import io
import unittest
from contextlib import redirect_stdout
from pathlib import Path

import config
from experiment.run_experiment import _command, _settings_from_args, build_plan, main, parse_args

ROUTERS = ["always_small", "always_large", "cascade"]
BENCHMARKS = ["mmlu_pro", "gsm_hard"]


class BuildPlanTest(unittest.TestCase):
    def test_same_seed_same_order(self):
        first = build_plan(ROUTERS, BENCHMARKS, "eval", 3, idle=True, seed=7)
        second = build_plan(ROUTERS, BENCHMARKS, "eval", 3, idle=True, seed=7)
        self.assertEqual(first, second)

    def test_different_seed_different_order(self):
        first = build_plan(ROUTERS, BENCHMARKS, "eval", 3, idle=True, seed=7)
        second = build_plan(ROUTERS, BENCHMARKS, "eval", 3, idle=True, seed=8)
        self.assertNotEqual([r["run_id"] for r in first], [r["run_id"] for r in second])

    def test_contents(self):
        runs = build_plan(ROUTERS, BENCHMARKS, "eval", 3, idle=True, seed=7)
        self.assertEqual(len(runs), 3 * (len(ROUTERS) * len(BENCHMARKS) + 1))
        self.assertEqual(sum(r["kind"] == "idle" for r in runs), 3)
        self.assertEqual(len({r["run_id"] for r in runs}), len(runs))
        self.assertEqual([r["order_index"] for r in runs], list(range(1, len(runs) + 1)))
        self.assertTrue(all(r["status"] == "planned" for r in runs))

    def test_no_idle_runs_without_energy(self):
        runs = build_plan(ROUTERS, BENCHMARKS, "train", 1, idle=False, seed=7)
        self.assertFalse(any(r["kind"] == "idle" for r in runs))


class CommandTest(unittest.TestCase):
    RUN = {
        "kind": "run", "router": "cascade", "benchmark": "gsm_hard",
        "split": "eval", "run_id": "001_x",
    }

    def settings(self, *extra):
        args = parse_args(["--limit", "5", "--cascade-threshold", "0.8", *extra])
        return _settings_from_args(args, "test")

    def test_wrapped_in_energibridge(self):
        command = _command(self.RUN, Path("/tmp/run"), self.settings())
        self.assertEqual(command[0], config.ENERGIBRIDGE["path"])
        self.assertIn("--gpu", command)
        self.assertEqual(command[command.index("--interval") + 1], "200")
        inner = command[command.index("--") + 1:]
        self.assertEqual(inner[1:3], ["-m", "experiment.run"])
        self.assertEqual(inner[inner.index("--limit") + 1], "5")
        self.assertEqual(inner[inner.index("--threshold") + 1], "0.8")

    def test_no_energy(self):
        settings = self.settings("--no-energy")
        command = _command(self.RUN, Path("/tmp/run"), settings)
        self.assertEqual(command[1:3], ["-m", "experiment.run"])
        self.assertEqual((settings["cooldown_s"], settings["warmup_s"]), (0, 0))

    def test_idle_run(self):
        run = {"kind": "idle", "run_id": "002_idle"}
        command = _command(run, Path("/tmp/run"), self.settings())
        self.assertEqual(command[command.index("--") + 1:], ["sleep", "60"])


class DryRunTest(unittest.TestCase):
    def test_dry_run_prints_plan_and_writes_nothing(self):
        exp_id = "dry_run_test_should_not_exist"
        output = io.StringIO()
        with redirect_stdout(output):
            code = main(["--dry-run", "--exp-id", exp_id, "--reps", "2"])
        self.assertEqual(code, 0)
        self.assertIn("idle__rep2", output.getvalue())
        self.assertFalse((config.RESULTS_DIR / exp_id).exists())

    def test_default_plan_is_five_strategies_on_both_benchmarks(self):
        args = parse_args([])
        self.assertEqual(
            args.routers,
            ["small_only", "medium_only", "large_only", "cascade", "matrix_factorization"],
        )
        self.assertEqual(args.benchmarks, ["mmlu_pro", "gsm_hard"])
        runs = build_plan(args.routers, args.benchmarks, "eval", 1, idle=True, seed=1)
        measured = [run for run in runs if run["kind"] == "run"]
        self.assertEqual(len(measured), 10)
        self.assertEqual({run["benchmark"] for run in measured}, {"mmlu_pro", "gsm_hard"})


if __name__ == "__main__":
    unittest.main()
