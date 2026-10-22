"""Dimensional and boundary checks for the independent SCI calculation."""

import copy
import csv
import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from scripts.compute_sci import carbon, historical_byte_match, integrate_trace, validate_parameters


class SciTests(unittest.TestCase):
    def setUp(self):
        self.parameters = json.loads((Path(__file__).resolve().parents[1]
            / "analysis/sci_20261022/parameters.json").read_text())

    def trace(self, rows, duplicate=False):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "energy.csv"
            with path.open("w", newline="") as handle:
                writer = csv.writer(handle)
                writer.writerow(["Time", "CPU_ENERGY (J)", "GPU0_POWER (mWatts)", "GPU1_POWER (mWatts)"])
                writer.writerows(rows)
            return integrate_trace(path, duplicate)

    def test_two_gpus_time_units_and_cumulative_cpu(self):
        # Linear power ramps over 2 s: GPU0=20 J, GPU1=40 J;
        # CPU counter difference=100 J, not the counter sum or per-core sum.
        result = self.trace([[1000, 900, 0, 10000], [3000, 1000, 20000, 30000]])
        self.assertEqual(result["gpu0_j"], 20)
        self.assertEqual(result["gpu1_j"], 40)
        self.assertEqual(result["cpu_j"], 100)
        self.assertEqual(result["duration_s"], 2)

    def test_duplicate_keeps_later_sample_and_separates_cpu_jump(self):
        result = self.trace([[1000, 900, 90000, 90000], [1000, 905, 10000, 20000],
                             [2000, 915, 10000, 20000]], duplicate=True)
        self.assertEqual(result["gpu_j"], 30)
        self.assertEqual(result["cpu_j"], 10)
        self.assertEqual(result["excluded_cpu_initialization_j"], 5)

    def test_bad_timestamp_counter_or_registry_fails(self):
        for rows, duplicate in [([[0, 1, 1, 1], [0, 2, 1, 1]], False),
                                ([[0, 2, 1, 1], [1, 1, 1, 1]], False),
                                ([[2, 1, 1, 1], [1, 2, 1, 1]], False)]:
            with self.subTest(rows=rows), self.assertRaises(ValueError):
                self.trace(rows, duplicate)

    def test_energy_losses_and_embodied_allocation_have_correct_units(self):
        p = {**self.parameters, "other_hardware_w": 100, "power_supply_efficiency": .5,
             "pue": 1.5, "grid_g_co2e_per_kwh": 200, "embodied_kg_co2e": 1000,
             "expected_life_years": 4, "resource_share": .5}
        result = carbon(3.6e6, 3600, p)
        self.assertAlmostEqual(result["facility_kwh"], 3.3)
        self.assertAlmostEqual(result["operational_g_co2e"], 660)
        self.assertAlmostEqual(result["embodied_g_co2e"], 1e6 / (4 * 8760) * .5)
        self.assertAlmostEqual(result["total_g_co2e"], 660 + 1e6 / (4 * 8760) * .5)

    def test_only_newline_transformation_is_accepted(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "trace.csv"
            path.write_bytes(b"a,b\n1,2\n")
            expected = hashlib.sha256(b"a,b\r\n1,2\r\n").hexdigest()
            self.assertTrue(historical_byte_match(path, expected)[1])
            path.write_bytes(b"a,b\n1,3\n")
            self.assertFalse(historical_byte_match(path, expected)[1])

    def test_nonphysical_model_inputs_fail(self):
        for key, value in [("power_supply_efficiency", 0), ("pue", float("nan")),
                           ("pue", .8), ("expected_life_years", 0), ("resource_share", 1.1)]:
            p = copy.copy(self.parameters)
            p[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError):
                validate_parameters(p)


if __name__ == "__main__":
    unittest.main()
