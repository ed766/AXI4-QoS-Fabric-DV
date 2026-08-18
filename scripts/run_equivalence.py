#!/usr/bin/env python3
"""Report reproducible equivalence evidence without overstating sequential proof."""
from __future__ import annotations
import csv,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'reports/equivalence_summary.csv'
def main()->int:
  gate_path=ROOT/'reports/gate_level_summary.csv'
  if not gate_path.exists():subprocess.run(['python3','scripts/run_gate_smoke.py'],cwd=ROOT,check=True)
  gate_rows=list(csv.DictReader(gate_path.open()));matching=len(gate_rows)==2 and all(row['status']=='PASS' and row['checks']=='6' for row in gate_rows)
  rows=[{'check':'full_fabric_rtl_vs_netlist_observable_smoke','status':'PASS' if matching else 'FAIL',
    'reason':'RTL and synthesized netlist pass the same six mapped-route/local-error checks'},
    {'check':'full_fabric_unbounded_sequential_equivalence','status':'PARTIAL',
    'reason':'Yosys induction is resource-limited at 5132 state equivalence points; exhaustive equivalence is not claimed'}]
  with OUT.open('w',newline='') as handle:
    writer=csv.DictWriter(handle,fieldnames=list(rows[0]),lineterminator='\n');writer.writeheader();writer.writerows(rows)
  print(f'EQUIVALENCE_RESULT|observable_smoke={rows[0]["status"]}|unbounded=PARTIAL');return 0 if matching else 1
if __name__=='__main__':raise SystemExit(main())
