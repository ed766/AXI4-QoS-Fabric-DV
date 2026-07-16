#!/usr/bin/env python3
"""Check documentation links, generated blocks, and claim boundaries."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = [ROOT / "README.md", *sorted((ROOT / "docs").rglob("*.md")), ROOT / "vip" / "axi4" / "README.md"]
LINK = re.compile(r"!?(?:\[[^]]*\])\(([^)]+)\)")
failures: list[str] = []
for document in DOCS:
    text = document.read_text()
    if "/home/" in text or "/mnt/c/" in text:
        failures.append(f"{document.relative_to(ROOT)} contains a machine-specific path")
    for target in LINK.findall(text):
        target = target.split("#", 1)[0]
        if not target or "://" in target or target.startswith("mailto:"):
            continue
        if not (document.parent / target).resolve().exists():
            failures.append(f"{document.relative_to(ROOT)} has missing link {target}")
readme = (ROOT / "README.md").read_text()
if readme.count("<!-- BEGIN GENERATED METRICS -->") != 1 or readme.count("<!-- END GENERATED METRICS -->") != 1:
    failures.append("README.md must contain exactly one generated metric block")
if "14` solver-backed" not in readme or "bounded Verilator simulation group" not in readme:
    failures.append("README.md must distinguish solver-backed and bounded formal evidence")
if failures:
    print("\n".join(f"DOC_CHECK_FAIL|{failure}" for failure in failures))
    raise SystemExit(1)
print(f"DOC_CHECK_PASS|documents={len(DOCS)}")
