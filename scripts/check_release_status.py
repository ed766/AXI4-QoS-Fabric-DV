#!/usr/bin/env python3
from __future__ import annotations

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "reports"


def rows(name: str) -> list[dict[str, str]]:
    path = REPORTS / name
    return list(csv.DictReader(path.open())) if path.exists() else []


def passes(name: str, field: str = "status") -> int:
    return sum(row.get(field) in ("PASS", "HIT", "YES") for row in rows(name))


def main() -> int:
    coverage = rows("code_coverage_summary.csv")
    reviewed = next((float(row["line_percent"]) for row in coverage if row["scope"] == "reviewed_executable_rtl"), 0.0)
    checks = [
        ("named_regression", passes("regression_summary.csv"), 25),
        ("uvm_runtime_smoke", passes("uvm_runtime_summary.csv"), 4),
        ("seeded_random_regression", passes("random_regress_summary.csv"), 100),
        ("functional_coverage", passes("functional_coverage.csv"), 56),
        ("interaction_coverage", passes("cross_coverage.csv"), 46),
        ("mutation_detection", passes("mutation_summary.csv", "detected"), 6),
        ("bounded_property_groups", sum(row["mode"] == "bounded_verilator" and row["status"] == "PASS" for row in rows("formal_summary.csv")), 1),
        ("solver_formal_groups", sum(row["mode"].startswith("Yosys_SMT") and row["status"] == "PASS" for row in rows("formal_summary.csv")), 2),
        ("model_replay", passes("model_replay_summary.csv"), 125),
        ("cdc_clock_ratios", passes("cdc_summary.csv"), 4),
        ("performance_points", passes("performance_summary.csv"), 24),
        ("synthesized_blocks", passes("synthesis_summary.csv"), 2),
        ("gate_level_smoke", passes("gate_level_summary.csv"), 1),
        ("reviewed_executable_line_percent", reviewed, 90.0),
    ]
    output = REPORTS / "release_readiness.csv"
    with output.open("w", newline="") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow(["criterion", "measured", "target", "status"])
        for name, measured, target in checks:
            writer.writerow([name, measured, target, "PASS" if measured >= target else "FAIL"])
    closed = sum(measured >= target for _, measured, target in checks)
    print(f"RELEASE_READINESS|closed={closed}|total={len(checks)}|report={output.relative_to(ROOT)}")
    return 0 if closed == len(checks) else 1


if __name__ == "__main__":
    raise SystemExit(main())
