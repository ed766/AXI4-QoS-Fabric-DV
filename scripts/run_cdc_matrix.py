#!/usr/bin/env python3
from __future__ import annotations

import csv
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORT = ROOT / "reports" / "cdc_summary.csv"
RATIOS = [("1:1", 5000), ("2:3", 3333), ("3:2", 7500), ("5:3", 8333)]


def main() -> int:
    binary = ROOT / "build" / "smoke" / "Vtb_axi4_qos_fabric"
    rows = []
    for ratio, half_ps in RATIOS:
        trace = ROOT / "build" / "traces" / f"cdc_{ratio.replace(':', '_')}.jsonl"
        result = subprocess.run([
            str(binary), "+TEST_NAME=async_cdc_stress", f"+S3_HALF_PS={half_ps}",
            f"+TRACE_FILE={trace.relative_to(ROOT)}",
        ], cwd=ROOT, text=True, capture_output=True, timeout=30)
        match = re.search(r"DV_RESULT\|.*?\|checks=(\d+)\|errors=(\d+)", result.stdout)
        passed = result.returncode == 0 and match and int(match.group(2)) == 0
        rows.append({
            "clock_ratio": ratio, "source_period_ps": 10000, "target_period_ps": half_ps * 2,
            "channels": "AW/W/B/AR/R", "checks": match.group(1) if match else "0",
            "status": "PASS" if passed else "FAIL", "trace": str(trace.relative_to(ROOT)),
        })
    with REPORT.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys(), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    passed = sum(row["status"] == "PASS" for row in rows)
    print(f"CDC_RESULT|passed={passed}|total={len(rows)}")
    return 0 if passed == len(rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
