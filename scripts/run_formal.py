#!/usr/bin/env python3
from __future__ import annotations

import csv
import os
import shutil
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "build/formal"
OUT = ROOT / "reports/formal_summary.csv"


def solver_task(name: str, sources: list[str], top: str, mode: str, depth: int,
                define: str | None = None, expect_fail: bool = False) -> dict[str, str]:
    yosys = shutil.which("yosys")
    smtbmc = shutil.which("yosys-smtbmc")
    solver = shutil.which("z3") or str(ROOT / "build/formal-venv/bin/z3")
    if not yosys or not smtbmc or not Path(solver).exists():
        return {"property_group": name, "mode": f"Yosys_SMT_{mode}", "depth": str(depth),
                "status": "SKIP", "runtime_seconds": "NA", "note": "requires yosys-smtbmc and z3"}
    work = BUILD / name
    work.mkdir(parents=True, exist_ok=True)
    smt = work / f"{name}.smt2"
    define_arg = f"-D{define} " if define else ""
    script = f"read_verilog -formal -sv {define_arg}{' '.join(sources)}; prep -top {top}; async2sync; dffunmap; write_smt2 -wires {smt}"
    synth = subprocess.run([yosys, "-q", "-p", script], cwd=ROOT, text=True, capture_output=True)
    env = {**os.environ, "PATH": str(Path(solver).parent) + os.pathsep + os.environ["PATH"]}
    command = [smtbmc, "-s", "z3", "-t", str(depth)]
    if mode == "prove": command.append("-i")
    if mode == "cover": command.append("-c")
    command.append(str(smt))
    try:
        result = subprocess.run(command, cwd=ROOT, text=True, capture_output=True, env=env, timeout=60) if synth.returncode == 0 else synth
    except subprocess.TimeoutExpired as exc:
        class TimedOut:
            returncode = 124
            stdout = exc.stdout or ""
            stderr = (exc.stderr or "") + "\nsolver timeout"
        result = TimedOut()
    (work / f"{mode}.log").write_text(result.stdout + result.stderr)
    passed = result.returncode != 0 if expect_fail else result.returncode == 0
    note = "expected mutation counterexample" if expect_fail else ("solver-backed bounded safety" if mode == "bmc" else "leaf proof/cover with explicit reachability")
    return {"property_group": name, "mode": f"Yosys_SMT_{'mutation' if expect_fail else mode}",
            "depth": str(depth), "status": "PASS" if passed else "FAIL", "runtime_seconds": "NA", "note": note}


def main() -> int:
    BUILD.mkdir(parents=True, exist_ok=True)
    OUT.parent.mkdir(exist_ok=True)
    bounded_dir = BUILD / "bounded"
    bounded_dir.mkdir(exist_ok=True)
    compile_result = subprocess.run([
        "verilator", "--binary", "--sv", "--timing", "--assert", "-Wno-fatal",
        "--top-module", "tb_qos_properties", "-Mdir", str(bounded_dir),
        "rtl/qos_arbiter.sv", "formal/tb_qos_properties.sv",
    ], cwd=ROOT, text=True, capture_output=True)
    if compile_result.returncode:
        raise SystemExit(compile_result.stderr)
    bounded = subprocess.run([str(bounded_dir / "Vtb_qos_properties")], cwd=ROOT, text=True, capture_output=True)
    (bounded_dir / "run.log").write_text(bounded.stdout + bounded.stderr)
    rows = [{"property_group": "qos_grant_safety", "mode": "bounded_verilator", "depth": "33",
             "status": "PASS" if bounded.returncode == 0 else "FAIL", "runtime_seconds": "NA",
             "note": "three executable arbiter invariants"}]

    groups = (
        ("qos_arbiter", ["rtl/qos_arbiter.sv", "formal/qos_arbiter_formal.sv"], "qos_arbiter_formal", "prove", None, None),
        ("async_fifo", ["rtl/async_fifo_gray.sv", "formal/async_fifo_formal.sv"], "async_fifo_formal", "bmc", "FORMAL_BUG_FIFO_COUNT", "fifo_count"),
        ("id_tracker", ["formal/id_tracker_formal.sv"], "id_tracker_formal", "bmc", "FORMAL_BUG_ID_DUPLICATE", "duplicate_id"),
        ("local_error", ["formal/local_error_formal.sv"], "local_error_formal", "bmc", "FORMAL_BUG_ERROR_LEAK", "error_leak"),
        ("route_owner", ["formal/route_owner_formal.sv"], "route_owner_formal", "bmc", "FORMAL_BUG_ROUTE_UNLOCK", "early_unlock"),
    )
    for name, sources, top, proof_mode, mutation, mutation_name in groups:
        safety_depth = 16 if name == "async_fifo" else 40
        cover_depth = 20 if name == "async_fifo" else 80
        rows.append(solver_task(f"{name}_safety", sources, top, proof_mode, safety_depth))
        rows.append(solver_task(f"{name}_reachability", sources, top, "cover", cover_depth))
        if mutation:
            rows.append(solver_task(f"{name}_{mutation_name}_mutation", sources, top, "bmc", 20, mutation, True))
    rows.append({"property_group": "full_fabric_solver", "mode": "Yosys_SMT", "depth": "NA", "status": "SKIP",
                 "runtime_seconds": "NA", "note": "installed frontend does not support multidimensional SystemVerilog ports"})
    with OUT.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys(), lineterminator="\n")
        writer.writeheader(); writer.writerows(rows)
    required = [row for row in rows if row["property_group"] != "full_fabric_solver"]
    passed = sum(row["status"] == "PASS" for row in required)
    print(f"FORMAL_RESULT|passed={passed}|required={len(required)}|report={OUT.relative_to(ROOT)}")
    return 0 if bounded.returncode == 0 and passed == len(required) else 1


if __name__ == "__main__":
    raise SystemExit(main())
