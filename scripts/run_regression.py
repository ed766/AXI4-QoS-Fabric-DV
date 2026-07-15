#!/usr/bin/env python3
from __future__ import annotations

import argparse
import csv
import re
import subprocess
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build"
REPORTS = ROOT / "reports"
NAMED_REPORT = REPORTS / "regression_summary.csv"
RANDOM_REPORT = REPORTS / "random_regress_summary.csv"

NAMED_SCENARIOS = [
    "smoke", "single_master_rw", "target_matrix", "burst_lengths", "transfer_sizes",
    "partial_strobes", "malformed_unmapped", "malformed_misaligned", "malformed_burst",
    "boundary_4k", "security_access", "downstream_errors", "qos_priority", "equal_qos_rr", "starvation_override",
    "contention_two", "contention_four", "outstanding_ids", "write_burst_lock", "aw_delayed_w",
    "channel_backpressure_25", "channel_backpressure_75", "async_target", "reset_recovery",
    "local_error_matrix",
]


def run(binary: Path, name: str, args: list[str], timeout: int = 45, artifact_name: str | None = None) -> dict[str, str]:
    artifact_name = artifact_name or name
    trace = BUILD / "traces" / f"{artifact_name}.jsonl"
    log = BUILD / "logs" / f"{artifact_name}.log"
    trace.parent.mkdir(parents=True, exist_ok=True)
    log.parent.mkdir(parents=True, exist_ok=True)
    command = [str(binary), f"+TEST_NAME={name}", f"+TRACE_FILE={trace.relative_to(ROOT)}", *args]
    start = time.monotonic()
    try:
        result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, timeout=timeout)
        output = result.stdout + result.stderr
        match = re.search(r"DV_RESULT\|test=.*?\|checks=(\d+)\|errors=(\d+)", output)
        checks = int(match.group(1)) if match else 0
        errors = int(match.group(2)) if match else 1
        status = "PASS" if result.returncode == 0 and match and errors == 0 else "FAIL"
        bucket = "none" if status == "PASS" else "simulation_or_checker"
    except subprocess.TimeoutExpired as exc:
        output = (exc.stdout or "") + (exc.stderr or "")
        checks, errors, status, bucket = 0, 1, "FAIL", "timeout"
    log.write_text(output)
    return {
        "scenario": name,
        "status": status,
        "checks": str(checks),
        "errors": str(errors),
        "duration_seconds": f"{time.monotonic() - start:.3f}",
        "bucket": bucket,
        "trace": str(trace.relative_to(ROOT)),
        "log": str(log.relative_to(ROOT)),
    }


def write_csv(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys(), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def run_named(binary: Path) -> int:
    rows = []
    for name in NAMED_SCENARIOS:
        stall = "75" if name.endswith("75") else "25" if name.endswith("25") else "0"
        rows.append(run(binary, name, [f"+STALL_PERCENT={stall}"]))
    write_csv(NAMED_REPORT, rows)
    passed = sum(row["status"] == "PASS" for row in rows)
    print(f"REGRESSION_RESULT|passed={passed}|total={len(rows)}|report={NAMED_REPORT.relative_to(ROOT)}")
    return 0 if passed == len(rows) else 1


def run_random(binary: Path, manifest: Path) -> int:
    rows = []
    for source in csv.DictReader(manifest.open()):
        name = f"random_{int(source['index']):03d}"
        args = [
            f"+SEED={source['seed']}", f"+OPERATIONS={source['operations']}",
            f"+READ_PERCENT={source['read_percent']}", f"+BURST_MAX={source['burst_max']}",
            f"+STALL_PERCENT={source['backpressure_percent']}", f"+ERROR_PERCENT={source['error_percent']}",
            f"+SECURITY_PERCENT={source['security_percent']}",
        ]
        result = run(binary, "random_mixed_smoke", args, timeout=90, artifact_name=name)
        result["scenario"] = name
        row = {**source, **result}
        rows.append(row)
    write_csv(RANDOM_REPORT, rows)
    passed = sum(row["status"] == "PASS" for row in rows)
    print(f"RANDOM_RESULT|passed={passed}|total={len(rows)}|report={RANDOM_REPORT.relative_to(ROOT)}")
    return 0 if passed == len(rows) else 1


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--binary", type=Path, required=True)
    parser.add_argument("--named", action="store_true")
    parser.add_argument("--random", action="store_true")
    parser.add_argument("--manifest", type=Path, default=REPORTS / "random_manifest.csv")
    args = parser.parse_args()
    REPORTS.mkdir(exist_ok=True)
    status = 0
    if args.named:
        status |= run_named(args.binary)
    if args.random:
        status |= run_random(args.binary, args.manifest)
    return status


if __name__ == "__main__":
    raise SystemExit(main())
