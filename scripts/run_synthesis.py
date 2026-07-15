#!/usr/bin/env python3
from __future__ import annotations
import csv,re,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; OUT=ROOT/'reports/synthesis_summary.csv'; BUILD=ROOT/'build/synthesis'

def synth(name:str,sources:str,top:str,netlist:str)->dict[str,str]:
    yosys=shutil.which('yosys'); start='read_verilog -sv '+sources
    script=f'{start}; hierarchy -top {top}; proc; opt; memory; opt; techmap; opt; stat; write_verilog -noattr {BUILD/netlist}'
    run=subprocess.run([yosys,'-p',script],cwd=ROOT,text=True,capture_output=True) if yosys else None
    (BUILD/f'{name}.log').write_text((run.stdout+'\n'+run.stderr) if run else 'Yosys unavailable')
    cells='NA'; wires='NA'
    if run and run.returncode==0:
      cell_match=re.findall(r'Number of cells:\s+(\d+)',run.stdout); wire_match=re.findall(r'Number of wire bits:\s+(\d+)',run.stdout)
      cells=cell_match[-1] if cell_match else 'NA'; wires=wire_match[-1] if wire_match else 'NA'
    return {'variant':name,'status':'PASS' if run and run.returncode==0 else 'FAIL','cell_count':cells,
      'register_wire_proxy':wires,'timing_proxy':'NA','note':'Yosys generic-cell structural proxy'}

def main()->int:
    BUILD.mkdir(parents=True,exist_ok=True); OUT.parent.mkdir(exist_ok=True)
    rows=[synth('qos_arbiter','rtl/qos_arbiter.sv','qos_arbiter','qos_arbiter_netlist.v'),
          synth('async_fifo_gray','rtl/async_fifo_gray.sv','async_fifo_gray','async_fifo_gray_netlist.v')]
    rows.append({'variant':'4x4_full_fabric','status':'SKIP','cell_count':'NA','register_wire_proxy':'NA','timing_proxy':'NA',
      'note':'Yosys 0.33 lacks a multidimensional-SystemVerilog port frontend; use read-slang for full-fabric synthesis'})
    with OUT.open('w',newline='') as f:w=csv.DictWriter(f,fieldnames=rows[0].keys(),lineterminator='\n');w.writeheader();w.writerows(rows)
    passed=sum(r['status']=='PASS' for r in rows)
    print(f'SYNTH_RESULT|passed={passed}|executable=2|full_fabric=SKIP')
    return 0 if passed==2 else 1
if __name__=='__main__': raise SystemExit(main())
