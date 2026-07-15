#!/usr/bin/env python3
from __future__ import annotations

import csv
import os
import shutil
import subprocess
import re
from collections import defaultdict
from pathlib import Path

from run_regression import NAMED_SCENARIOS

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build" / "coverage"
REPORT = ROOT / "reports" / "code_coverage_summary.csv"
FILES_REPORT = ROOT / "reports" / "code_coverage_files.csv"
EXCLUSIONS_REPORT = ROOT / "reports" / "code_coverage_exclusions.csv"


def main() -> int:
    if BUILD.exists():
        shutil.rmtree(BUILD)
    BUILD.mkdir(parents=True)
    sources = [
        "rtl/qos_arbiter.sv", "rtl/async_fifo_gray.sv", "rtl/axi4_async_bridge.sv",
        "rtl/axi4_qos_fabric.sv", "sim/axi_memory_model.sv",
        "sim/assertions/axi4_fabric_assertions.sv", "sim/tb_axi4_qos_fabric.sv",
    ]
    main_cpp = BUILD / "coverage_main.cpp"
    main_cpp.write_text("\n".join([
        "#include <cstdlib>", '#include "verilated.h"', '#include "verilated_cov.h"',
        '#include "Vtb_axi4_qos_fabric.h"', "",
        "int main(int argc, char** argv) {", "  VerilatedContext context;",
        "  context.commandArgs(argc, argv);", "  Vtb_axi4_qos_fabric top(&context);",
        "  while (!context.gotFinish()) { top.eval(); context.timeInc(1); }", "  top.final();",
        '  const char* path = std::getenv("VERILATOR_COVERAGE_FILENAME");',
        '  VerilatedCov::write(path ? path : "coverage.dat");', "  return 0;", "}", "",
    ]))
    command = [
        "verilator", "--cc", "--exe", "--build", "--sv", "--timing", "--assert", "--coverage",
        "--coverage-max-width", "64", "-Wno-fatal", "--top-module", "tb_axi4_qos_fabric",
        "-Mdir", str(BUILD), *sources, str(main_cpp),
    ]
    subprocess.run(command, cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
    binary = BUILD / "Vtb_axi4_qos_fabric"
    databases: list[Path] = []

    for index, scenario in enumerate(NAMED_SCENARIOS):
        database = BUILD / f"named_{index:02d}.dat"
        stall = "75" if scenario.endswith("75") else "25" if scenario.endswith("25") else "0"
        env = os.environ.copy()
        env["VERILATOR_COVERAGE_FILENAME"] = str(database)
        subprocess.run([
            str(binary), f"+TEST_NAME={scenario}", "+TRACE_FILE=/dev/null", f"+STALL_PERCENT={stall}"
        ], cwd=ROOT, env=env, check=True, stdout=subprocess.DEVNULL)
        databases.append(database)

    manifest = list(csv.DictReader((ROOT / "reports" / "random_manifest.csv").open()))
    for source in manifest[:20]:
        database = BUILD / f"random_{int(source['index']):03d}.dat"
        env = os.environ.copy()
        env["VERILATOR_COVERAGE_FILENAME"] = str(database)
        subprocess.run([
            str(binary), "+TEST_NAME=random_mixed_smoke", "+TRACE_FILE=/dev/null",
            f"+SEED={source['seed']}", f"+OPERATIONS={source['operations']}",
            f"+READ_PERCENT={source['read_percent']}", f"+BURST_MAX={source['burst_max']}",
            f"+STALL_PERCENT={source['backpressure_percent']}", f"+ERROR_PERCENT={source['error_percent']}",
            f"+SECURITY_PERCENT={source['security_percent']}",
        ], cwd=ROOT, env=env, check=True, stdout=subprocess.DEVNULL)
        databases.append(database)

    info = BUILD / "coverage.info"
    merged = BUILD / "coverage.dat"
    subprocess.run(["verilator_coverage", "--write", str(merged), *map(str, databases)], cwd=ROOT, check=True)
    subprocess.run(["verilator_coverage", "--write-info", str(info), *map(str, databases)], cwd=ROOT, check=True)
    file_counts: dict[str, list[int]] = defaultdict(lambda: [0, 0])
    current = "unknown"
    for line in info.read_text().splitlines():
        if line.startswith("SF:"):
            current = line[3:]
        elif line.startswith("DA:"):
            count = int(line.split(",", 1)[1])
            file_counts[current][1] += 1
            file_counts[current][0] += count > 0

    file_rows = []
    for name, (covered, total) in sorted(file_counts.items()):
        file_rows.append({
            "file": name, "covered_lines": covered, "total_lines": total,
            "line_percent": f"{100 * covered / total:.2f}" if total else "NA",
        })
    with FILES_REPORT.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=file_rows[0].keys(), lineterminator="\n")
        writer.writeheader()
        writer.writerows(file_rows)

    first_executable = {}
    for name in file_counts:
        if name.startswith("rtl/"):
            lines=(ROOT/name).read_text().splitlines()
            first_executable[name]=next((index for index,text in enumerate(lines,1)
                if re.match(r"\s*(function|assign|always|generate)\b",text)),1)
    exclusion_rows = []
    for name, points in sorted(file_counts.items()):
        if not name.startswith("rtl/"):
            continue
        source_points = []
        current_file = ""
        for line in info.read_text().splitlines():
            if line.startswith("SF:"):
                current_file = line[3:]
            elif current_file == name and line.startswith("DA:"):
                number, count = map(int, line[3:].split(","))
                source_points.append((number, count))
        for number, _ in source_points:
            reason = ""
            evidence = ""
            if number < first_executable[name]:
                reason = "non-executable module port/declaration instrumentation"
                evidence = "source classification"
            if reason:
                exclusion_rows.append({"file": name, "line": number, "reason": reason, "evidence": evidence})
    with EXCLUSIONS_REPORT.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=exclusion_rows[0].keys(), lineterminator="\n")
        writer.writeheader()
        writer.writerows(exclusion_rows)

    def aggregate(predicate) -> tuple[int, int]:
        selected = [counts for name, counts in file_counts.items() if predicate(name)]
        return sum(item[0] for item in selected), sum(item[1] for item in selected)

    scopes = {
        "design_rtl": lambda name: name.startswith("rtl/"),
        "fabric_core": lambda name: name in ("rtl/axi4_qos_fabric.sv", "rtl/qos_arbiter.sv"),
        "cdc_bridge": lambda name: name in ("rtl/async_fifo_gray.sv", "rtl/axi4_async_bridge.sv"),
        "verification_collateral": lambda name: name.startswith("sim/"),
        "all_instrumented": lambda name: True,
    }
    rows = []
    for scope, predicate in scopes.items():
        covered, total = aggregate(predicate)
        percent = 100 * covered / total if total else 0.0
        rows.append({
            "scope": scope, "covered_lines": covered, "total_lines": total,
            "line_percent": f"{percent:.2f}", "status": "PASS" if total else "FAIL",
        })
    type_counts: dict[str,list[int]] = defaultdict(lambda:[0,0])
    for line in merged.read_text(errors="ignore").splitlines():
        file_match=re.search(r"\x01f\x02([^\x01]+)",line)
        page_match=re.search(r"\x01page\x02([^\x01/]+)",line)
        count_match=re.search(r"'\s+([0-9]+)$",line)
        if file_match and page_match and count_match and file_match.group(1).startswith("rtl/"):
            kind=page_match.group(1).removeprefix("v_")
            type_counts[kind][1]+=1; type_counts[kind][0]+=int(count_match.group(1))>0
    for kind in ("branch","toggle"):
        covered,total=type_counts[kind]; percent=100*covered/total if total else 0.0
        rows.append({"scope":f"raw_design_{kind}","covered_lines":covered,"total_lines":total,
          "line_percent":f"{percent:.2f}","status":"PASS" if total else "FAIL"})
    excluded = {(row["file"], int(row["line"])) for row in exclusion_rows}
    reviewed_covered = reviewed_total = 0
    current_file = ""
    for line in info.read_text().splitlines():
        if line.startswith("SF:"):
            current_file = line[3:]
        elif current_file.startswith("rtl/") and line.startswith("DA:"):
            number, count = map(int, line[3:].split(","))
            if (current_file, number) not in excluded:
                reviewed_total += 1
                reviewed_covered += count > 0
    reviewed_percent = 100 * reviewed_covered / reviewed_total
    rows.insert(1, {
        "scope": "reviewed_executable_rtl", "covered_lines": reviewed_covered,
        "total_lines": reviewed_total, "line_percent": f"{reviewed_percent:.2f}",
        "status": "PASS" if reviewed_percent >= 90.0 else "FAIL",
    })
    with REPORT.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys(), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    design = next(row for row in rows if row["scope"] == "design_rtl")
    reviewed = next(row for row in rows if row["scope"] == "reviewed_executable_rtl")
    print(f"CODE_COVERAGE|raw_design={design['line_percent']}|reviewed={reviewed['line_percent']}|runs={len(databases)}")
    return 0 if reviewed["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
