#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TRACE = ROOT / "build/traces/same_target_reorder.jsonl"
OUTPUT = ROOT / "docs/images/out_of_order_response_waveform.svg"


def main() -> int:
    events = [json.loads(line) for line in TRACE.read_text().splitlines()]
    requests = [event for event in events if event.get("event") == "ar"]
    schedules = [event for event in events if event.get("event") == "target_r_schedule"]
    responses = [event for event in events if event.get("event") == "r"]
    selected = requests + schedules + responses
    start = min(event["cycle"] for event in selected) - 1
    end = max(event["cycle"] for event in selected) + 1
    x0, width = 180, 850

    def xpos(cycle: int) -> float:
        return x0 + (cycle - start) * width / (end - start)

    rows = (("AR accepted", requests, "#177e89"),
            ("Target schedule", schedules, "#d97706"),
            ("R completion", responses, "#26734d"))
    parts = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="1100" height="360" viewBox="0 0 1100 360">',
        '<rect width="100%" height="100%" fill="#f7f3e8"/>',
        '<text x="45" y="38" font-family="sans-serif" font-size="22" font-weight="700" fill="#17202a">Legal out-of-order completion across distinct AXI IDs</text>',
        '<text x="45" y="64" font-family="sans-serif" font-size="13" fill="#46525c">Requests accepted 1,2,3,4; target returns 2,4,3,1 without read-beat interleaving.</text>',
    ]
    for cycle in range(start, end + 1):
        x = xpos(cycle)
        parts.append(f'<line x1="{x:.1f}" y1="82" x2="{x:.1f}" y2="300" stroke="#ded8ca"/>')
        parts.append(f'<text x="{x-7:.1f}" y="325" font-family="monospace" font-size="11" fill="#59636b">{cycle}</text>')
    for row_index, (label, row_events, color) in enumerate(rows):
        y = 115 + row_index * 78
        parts.append(f'<text x="45" y="{y+5}" font-family="sans-serif" font-size="14" font-weight="600">{label}</text>')
        parts.append(f'<line x1="{x0}" y1="{y}" x2="{x0+width}" y2="{y}" stroke="#7b8287" stroke-width="2"/>')
        for event in row_events:
            x = xpos(int(event["cycle"]))
            ident = int(event["id"])
            parts.append(f'<circle cx="{x:.1f}" cy="{y}" r="17" fill="{color}"/>')
            parts.append(f'<text x="{x-4:.1f}" y="{y+5}" font-family="monospace" font-size="13" font-weight="700" fill="white">{ident}</text>')
    parts.extend([
        '<text x="440" y="350" font-family="sans-serif" font-size="12" fill="#46525c">Verilator trace cycles; circle labels are original initiator IDs.</text>',
        '</svg>',
    ])
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text("\n".join(parts) + "\n")
    print(f"REORDER_WAVEFORM|requests={len(requests)}|responses={len(responses)}|output={OUTPUT.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
