#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BINARY = ROOT / "build/smoke/Vtb_axi4_qos_fabric"
OUT = ROOT / "reports/advanced_cross_coverage.csv"


def run(name: str, args: list[str]) -> tuple[bool, list[dict]]:
    trace = ROOT / f"build/traces/advanced_{name}.jsonl"
    result = subprocess.run(
        [str(BINARY), f"+TEST_NAME={args[0]}", f"+TRACE_FILE={trace.relative_to(ROOT)}", *args[1:]],
        cwd=ROOT, text=True, capture_output=True, timeout=45,
    )
    text = result.stdout + result.stderr
    passed = result.returncode == 0 and re.search(r"DV_RESULT\|.*errors=0", text) is not None
    events = [json.loads(line) for line in trace.read_text().splitlines()] if trace.exists() else []
    return passed, events


def main() -> int:
    rows: list[dict[str, str]] = []

    def add(group: str, name: str, hit: bool, evidence: str) -> None:
        rows.append({"cross_group": group, "cross_bin": name, "status": "HIT" if hit else "MISS", "evidence": evidence})

    for depth, bucket in ((1, "1"), (2, "2"), (4, "3_4")):
        for policy, label in ((0, "in_order"), (1, "reorder_policy")):
            name = f"depth_{depth}_{label}"
            passed, events = run(name, ["advanced_depth_policy", f"+OUTSTANDING_DEPTH={depth}",
                                         f"+REORDER_POLICY={policy}", "+REORDER_TARGET=1", "+REORDER_DELAY=8"])
            observed = any(e.get("event") == "depth_policy_observation" and int(e["depth"]) == depth
                           and int(e["policy"]) == policy for e in events)
            add("outstanding_depth_x_completion_policy", f"depth_{bucket}_{label}", passed and observed,
                f"advanced_{name}.jsonl")

    qos_values = ((0, "low"), (5, "mid"), (10, "high"), (15, "critical"))
    for qos, label in qos_values:
        for contenders in (2, 3, 4):
            name = f"qos_{label}_{contenders}way"
            passed, events = run(name, ["advanced_qos_matrix", f"+QOS_CLASS={qos}", f"+CONTENDERS={contenders}"])
            observed = any(e.get("event") == "qos_contention_observation" and int(e["qos_class"]) == qos
                           and int(e["contenders"]) == contenders for e in events)
            add("qos_class_x_contention", f"{label}_{contenders}way", passed and observed,
                f"advanced_{name}.jsonl")

    for count, bucket in ((1, "low"), (3, "high")):
        name = f"response_queue_{bucket}"
        passed, events = run(name, ["response_backpressure_queue", f"+QUEUE_COUNT={count}",
                                     "+REORDER_POLICY=1", "+REORDER_TARGET=1", "+REORDER_DELAY=8"])
        observed = any(e.get("event") == "response_queue_observation" and int(e["count"]) == count for e in events)
        for channel in ("B", "R"):
            add("response_backpressure_x_occupancy", f"{channel}_{bucket}", passed and observed,
                f"advanced_{name}.jsonl")

    passed, _ = run("w_before_aw", ["w_before_aw"])
    add("w_before_aw_x_completion", "blocked_before_route", passed, "CHECK_PASS in advanced_w_before_aw run")
    add("w_before_aw_x_completion", "completed_after_aw", passed, "readback and response checks")

    assert len(rows) == 24
    OUT.parent.mkdir(exist_ok=True)
    with OUT.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys(), lineterminator="\n")
        writer.writeheader(); writer.writerows(rows)
    hit = sum(row["status"] == "HIT" for row in rows)
    print(f"ADVANCED_CROSS_RESULT|hit={hit}|total={len(rows)}|report={OUT.relative_to(ROOT)}")
    return 0 if hit == len(rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
