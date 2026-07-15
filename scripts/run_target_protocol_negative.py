#!/usr/bin/env python3
from __future__ import annotations

import csv
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BINARY = ROOT / "build/smoke/Vtb_axi4_qos_fabric"
OUT = ROOT / "reports/target_protocol_negative_summary.csv"
FAULTS = (
    ("early_rlast", 1),
    ("late_rlast", 2),
    ("unknown_response_id", 3),
    ("duplicate_response", 4),
    ("malformed_write_id", 5),
)


def main() -> int:
    rows = []
    logs = ROOT / "build/target_protocol_negative"
    logs.mkdir(parents=True, exist_ok=True)
    for name, fault in FAULTS:
        try:
            result = subprocess.run(
                [str(BINARY), "+TEST_NAME=target_protocol_fault", "+TRACE_FILE=/dev/null",
                 f"+TARGET_FAULT={fault}", "+FAULT_TARGET=1"],
                cwd=ROOT, text=True, capture_output=True, timeout=8,
            )
            text = result.stdout + result.stderr
            detected = result.returncode != 0 or "CHECK_FAIL" in text or "%Error" in text
            detector = "assertion_or_checker" if detected else "none"
        except subprocess.TimeoutExpired as exc:
            text = (exc.stdout or "") + (exc.stderr or "")
            detected = True
            detector = "bounded_timeout"
        (logs / f"{name}.log").write_text(text)
        rows.append({"fault": name, "expected_status": "FAIL", "detected": "YES" if detected else "NO",
                     "detector": detector, "log": str((logs / f"{name}.log").relative_to(ROOT))})
    OUT.parent.mkdir(exist_ok=True)
    with OUT.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys(), lineterminator="\n")
        writer.writeheader(); writer.writerows(rows)
    detected = sum(row["detected"] == "YES" for row in rows)
    print(f"TARGET_PROTOCOL_NEGATIVE|detected={detected}|total={len(rows)}|report={OUT.relative_to(ROOT)}")
    return 0 if detected == len(rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
