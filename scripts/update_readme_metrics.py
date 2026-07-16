#!/usr/bin/env python3
"""Refresh the generated evidence table in README.md."""

from __future__ import annotations

import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
README = ROOT / "README.md"
METRICS = ROOT / "reports" / "project_metrics.csv"
START = "<!-- BEGIN GENERATED METRICS -->"
END = "<!-- END GENERATED METRICS -->"
SELECTED = (
    ("named_regression", "Named integrated regression"),
    ("seeded_random_regression", "Seeded-random stress"),
    ("full_model_replay", "SystemC trace replay"),
    ("uvm_runtime", "Real UVM runtime"),
    ("reusable_axi_vip_selftest", "Reusable AXI VIP self-test"),
    ("functional_coverage", "Functional coverage"),
    ("advanced_interaction_coverage", "Advanced interaction coverage"),
    ("mutation_detection", "Mutation detection"),
    ("integrated_cdc", "Integrated CDC ratios"),
)


def main() -> int:
    values = {row["metric"]: row["value"] for row in csv.DictReader(METRICS.open())}
    missing = [key for key, _ in SELECTED if key not in values]
    if missing:
        raise SystemExit(f"Missing canonical metrics: {', '.join(missing)}")
    block = [START, "| Evidence | Current result |", "| --- | ---: |"]
    block.extend(f"| {label} | `{values[key]}` |" for key, label in SELECTED)
    block.append(END)
    text = README.read_text()
    if START not in text or END not in text:
        raise SystemExit("README generated-metrics markers are missing")
    prefix, rest = text.split(START, 1)
    _, suffix = rest.split(END, 1)
    README.write_text(prefix + "\n".join(block) + suffix)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
