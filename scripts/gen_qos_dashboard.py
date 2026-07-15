#!/usr/bin/env python3
from __future__ import annotations

import csv
import json
import math
import statistics
import subprocess
from collections import defaultdict, deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BINARY = ROOT / "build/smoke/Vtb_axi4_qos_fabric"
OUT = ROOT / "reports/qos_fairness_summary.csv"
SVG = ROOT / "docs/images/qos_fairness_dashboard.svg"
POLICIES = ((0, "equal_qos"), (1, "mixed_qos"), (2, "starvation_override"))


def nearest(values: list[int], percentile: int) -> int:
    ordered = sorted(values)
    return ordered[max(0, math.ceil(percentile * len(ordered) / 100) - 1)]


def analyze(path: Path, masters: int, requests: int) -> list[dict]:
    pending = defaultdict(deque)
    latency = defaultdict(list)
    accepted_cycles = defaultdict(list)
    completion_cycles = defaultdict(list)
    grants = defaultdict(list)
    overrides = defaultdict(list)
    for line in path.read_text().splitlines():
        event = json.loads(line); kind = event.get("event"); cycle = int(event.get("cycle", 0))
        if kind == "perf_offer":
            master = int(event["master"])
            pending[(master, int(event["id"]))].append(cycle)
            accepted_cycles[master].append(cycle)
        elif kind == "ar":
            master = int(event["master"])
            if not accepted_cycles[master]:
                accepted_cycles[master].append(cycle)
        elif kind == "ar_grant":
            master = int(event["master"]); grants[master].append(cycle)
            if int(event.get("age_override", 0)): overrides[master].append(cycle)
        elif kind == "r" and int(event.get("last", 0)):
            key = (int(event["master"]), int(event["id"]))
            if pending[key]:
                latency[key[0]].append(cycle - pending[key].popleft())
                completion_cycles[key[0]].append(cycle)
    service_rates = []
    for master in range(masters):
        active_window = completion_cycles[master][-1] - accepted_cycles[master][0] + 1
        service_rates.append(len(latency[master]) / active_window)
    fairness = ((sum(service_rates) ** 2) /
                (masters * sum(value * value for value in service_rates))) if any(service_rates) else 0.0
    rows = []
    for master in range(masters):
        values = latency[master]
        gaps = [b-a for a, b in zip(grants[master], grants[master][1:])]
        rows.append({"master": master, "offered_requests": requests, "accepted_requests": len(values),
                     "accepted_per_cycle": f"{service_rates[master]:.5f}",
                     "mean_latency_cycles": f"{statistics.mean(values):.2f}",
                     "p50_latency_cycles": nearest(values, 50), "p95_latency_cycles": nearest(values, 95),
                     "max_latency_cycles": max(values),
                     "service_share_percent": f"{100*service_rates[master]/sum(service_rates):.2f}",
                     "max_service_gap_cycles": max(gaps) if gaps else 0,
                     "age_override_events": len(overrides[master]), "jain_fairness_index": f"{fairness:.5f}", "status": "PASS"})
    return rows


def draw_svg(summary: list[dict]) -> None:
    width, height = 900, 430
    colors = {"equal_qos": "#1976a3", "mixed_qos": "#d97706", "starvation_override": "#26734d"}
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}">',
             '<rect width="100%" height="100%" fill="#f7f3e8"/>',
             '<text x="50" y="38" font-family="sans-serif" font-size="22" font-weight="700" fill="#17202a">QoS fairness under sustained four-master contention</text>',
             '<line x1="70" y1="360" x2="850" y2="360" stroke="#334"/><line x1="70" y1="70" x2="70" y2="360" stroke="#334"/>']
    points_by_policy = defaultdict(list)
    for policy in colors:
        for bp in (0, 25, 50, 75):
            matches = [r for r in summary if r["policy"] == policy and int(r["backpressure_percent"]) == bp and int(r["masters"]) == 4]
            if matches: points_by_policy[policy].append((bp, float(matches[0]["jain_fairness_index"])))
    for bp in (0, 25, 50, 75):
        x = 90 + bp * 9.5
        parts.append(f'<text x="{x-10}" y="386" font-family="sans-serif" font-size="13">{bp}%</text>')
    values = [value for points in points_by_policy.values() for _, value in points]
    floor = max(0.0, math.floor((min(values) if values else 0.7) * 10) / 10 - 0.1)
    for step in range(5):
        value = floor + (1.0-floor)*step/4
        y = 360 - (value-floor)*290/(1.0-floor)
        parts.append(f'<line x1="70" y1="{y}" x2="850" y2="{y}" stroke="#d5d0c5"/><text x="35" y="{y+5}" font-family="sans-serif" font-size="12">{value:.1f}</text>')
    for index, (policy, color) in enumerate(colors.items()):
        pts = [(90 + bp*9.5, 360 - (value-floor)*290/(1.0-floor)) for bp, value in points_by_policy[policy]]
        parts.append(f'<polyline fill="none" stroke="{color}" stroke-width="4" points="{" ".join(f"{x},{y}" for x,y in pts)}"/>')
        for x, y in pts: parts.append(f'<circle cx="{x}" cy="{y}" r="5" fill="{color}"/>')
        parts.append(f'<rect x="650" y="{85+index*28}" width="18" height="5" fill="{color}"/><text x="680" y="{92+index*28}" font-family="sans-serif" font-size="13">{policy.replace("_", " ")}</text>')
    parts.append('<text x="390" y="414" font-family="sans-serif" font-size="13">Target backpressure duty cycle</text>')
    parts.append('<text transform="translate(18 280) rotate(-90)" font-family="sans-serif" font-size="13">Jain fairness index</text></svg>')
    SVG.parent.mkdir(parents=True, exist_ok=True); SVG.write_text("\n".join(parts))


def main() -> int:
    rows = []
    for policy, label in POLICIES:
        for masters in (2, 4):
            for bp in (0, 25, 50, 75):
                trace = ROOT / f"build/traces/qos_{label}_{masters}m_bp{bp}.jsonl"
                result = subprocess.run([str(BINARY), "+TEST_NAME=performance_sustained", f"+PERF_POLICY={policy}",
                                         f"+PERF_MASTERS={masters}", "+PERF_REQUESTS=48", f"+STALL_PERCENT={bp}",
                                         f"+TRACE_FILE={trace.relative_to(ROOT)}"], cwd=ROOT, text=True, capture_output=True, timeout=120)
                if result.returncode: raise SystemExit(f"QoS performance run failed: {label} {masters}m bp={bp}")
                for row in analyze(trace, masters, 48):
                    rows.append({"policy": label, "masters": masters, "backpressure_percent": bp, **row})
    OUT.parent.mkdir(exist_ok=True)
    with OUT.open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys(), lineterminator="\n")
        writer.writeheader(); writer.writerows(rows)
    draw_svg(rows)
    snapshot = []
    for label in ("equal_qos", "mixed_qos", "starvation_override"):
        for bp in (0, 75):
            selected = [row for row in rows if row["policy"] == label and int(row["masters"]) == 4
                        and int(row["backpressure_percent"]) == bp]
            snapshot.append({
                "policy": label,
                "bp": bp,
                "throughput": sum(float(row["accepted_per_cycle"]) for row in selected),
                "mean": statistics.mean(float(row["mean_latency_cycles"]) for row in selected),
                "p95": max(int(row["p95_latency_cycles"]) for row in selected),
                "fairness": float(selected[0]["jain_fairness_index"]),
                "gap": max(int(row["max_service_gap_cycles"]) for row in selected),
                "overrides": sum(int(row["age_override_events"]) for row in selected),
            })
    doc = ROOT / "docs/performance.md"
    text = doc.read_text() if doc.exists() else "# QoS and Contention Performance\n"
    text += ("\n## Sustained Fairness Dashboard\n\n"
             "![QoS fairness dashboard](images/qos_fairness_dashboard.svg)\n\n"
             "| Policy | Backpressure | Aggregate completions/cycle | Mean offer-to-response | P95 | Jain fairness | Max service gap | Overrides |\n"
             "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |\n" +
             "".join(f"| `{row['policy']}` | {row['bp']}% | {row['throughput']:.4f} | {row['mean']:.2f} | {row['p95']} | {row['fairness']:.5f} | {row['gap']} | {row['overrides']} |\n" for row in snapshot) +
             "\n"
             "The sustained lane reports per-master offered/accepted throughput, p50/p95/max latency, service share, "
             "maximum service gap, aging overrides, and Jain's fairness index over per-master sustained completion rates. "
             "All values come from normalized Verilator request/grant/response traces.\n")
    doc.write_text(text)
    print(f"QOS_DASHBOARD|points={len(rows)}|status=PASS|report={OUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
