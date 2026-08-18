#!/usr/bin/env python3
from __future__ import annotations
import csv,re,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];BUILD=ROOT/'build/gate';OUT=ROOT/'reports/gate_level_summary.csv'

def run_case(name:str,sources:list[str],extra:list[str])->dict[str,str]:
  obj=BUILD/name;shutil.rmtree(obj,ignore_errors=True)
  command=['verilator','--binary','--sv','--timing','-Wall','-Wno-BLKSEQ','-Wno-UNUSEDSIGNAL','-Wno-SYNCASYNCNET',*extra,
    '--top-module','tb_full_fabric_gate','--Mdir',str(obj),*sources,'sim/tb_full_fabric_gate.sv']
  compiled=subprocess.run(command,cwd=ROOT,text=True,capture_output=True)
  executed=subprocess.run([str(obj/'Vtb_full_fabric_gate')],cwd=ROOT,text=True,capture_output=True) if compiled.returncode==0 else compiled
  log=compiled.stdout+compiled.stderr+executed.stdout+executed.stderr;(BUILD/f'{name}.log').write_text(log)
  match=re.search(r'FULL_FABRIC_GATE_SUMMARY\|status=PASS\|checks=(\d+)',log)
  return {'test':name,'status':'PASS' if executed.returncode==0 and match else 'FAIL','checks':match.group(1) if match else '0',
    'note':'mapped read/write routing plus local DECERR'}

def main()->int:
  BUILD.mkdir(parents=True,exist_ok=True)
  rows=[run_case('full_fabric_rtl_smoke',['rtl/qos_arbiter.sv','rtl/axi4_qos_fabric.sv'],[]),
    run_case('full_fabric_zero_delay_netlist_smoke',['build/synthesis/full_fabric_netlist.v'],
      ['-Wno-WIDTHEXPAND','-Wno-WIDTHTRUNC','-Wno-UNOPTFLAT','-Wno-UNDRIVEN','-Wno-DECLFILENAME','-Wno-TIMESCALEMOD'])]
  with OUT.open('w',newline='') as handle:
    writer=csv.DictWriter(handle,fieldnames=list(rows[0]),lineterminator='\n');writer.writeheader();writer.writerows(rows)
  passed=sum(row['status']=='PASS' for row in rows);print(f'GATE_LEVEL_RESULT|passed={passed}|total={len(rows)}|scope=full_fabric')
  return 0 if passed==len(rows) else 1
if __name__=='__main__':raise SystemExit(main())
