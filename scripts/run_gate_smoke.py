#!/usr/bin/env python3
from __future__ import annotations
import csv,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; BUILD=ROOT/'build/gate'; OUT=ROOT/'reports/gate_level_summary.csv'
def main()->int:
  BUILD.mkdir(parents=True,exist_ok=True)
  cmd=['verilator','--binary','--sv','--timing','--assert','-Wno-fatal','--top-module','tb_qos_properties','-Mdir',str(BUILD),
       'build/synthesis/qos_arbiter_netlist.v','formal/tb_qos_properties.sv']
  compile_run=subprocess.run(cmd,cwd=ROOT,text=True,capture_output=True)
  run=subprocess.run([str(BUILD/'Vtb_qos_properties')],cwd=ROOT,text=True,capture_output=True) if compile_run.returncode==0 else compile_run
  (BUILD/'gate.log').write_text(compile_run.stdout+compile_run.stderr+run.stdout+run.stderr)
  row={'test':'qos_arbiter_zero_delay_gate_smoke','status':'PASS' if run.returncode==0 else 'FAIL','checks':'3','note':'Yosys generic-cell netlist; full-fabric gate smoke requires read-slang frontend'}
  with OUT.open('w',newline='') as f:w=csv.DictWriter(f,fieldnames=row.keys(),lineterminator='\n');w.writeheader();w.writerow(row)
  print(f'GATE_LEVEL_RESULT|status={row["status"]}|scope=qos_arbiter')
  return run.returncode
if __name__=='__main__':raise SystemExit(main())
