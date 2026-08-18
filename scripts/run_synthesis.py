#!/usr/bin/env python3
from __future__ import annotations
import csv,os,re,shutil,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'reports/synthesis_summary.csv';BUILD=ROOT/'build/synthesis'

def yosys_binary()->str|None:
  requested=os.environ.get('YOSYS'); candidates=[requested,str(Path.home()/'.cache/oss-cad-suite/bin/yosys'),shutil.which('yosys')]
  return next((item for item in candidates if item and Path(item).is_file()),None)

def synth(yosys:str,name:str,sources:str,top:str,netlist:str,flatten:bool=False)->dict[str,str]:
  passes='proc; '+('flatten; ' if flatten else '')+'opt; memory; opt; techmap; opt'
  script=f'read_verilog -sv -DSYNTHESIS {sources}; hierarchy -top {top}; {passes}; stat; write_verilog -noattr {BUILD/netlist}'
  started=time.monotonic();run=subprocess.run([yosys,'-p',script],cwd=ROOT,text=True,capture_output=True);runtime=time.monotonic()-started
  (BUILD/f'{name}.log').write_text(run.stdout+'\n'+run.stderr)
  cells=re.findall(r'(?:Number of cells:\s+|^\s+)(\d+) cells$',run.stdout,re.MULTILINE)
  wires=re.findall(r'(?:Number of wire bits:\s+|^\s+)(\d+) wire bits$',run.stdout,re.MULTILINE)
  return {'variant':name,'status':'PASS' if run.returncode==0 else 'FAIL','cell_count':cells[-1] if cells else 'NA',
    'register_wire_proxy':wires[-1] if wires else 'NA','timing_proxy':'NA','runtime_seconds':f'{runtime:.2f}',
    'note':'Yosys generic-cell structural proxy; no technology timing signoff'}

def main()->int:
  BUILD.mkdir(parents=True,exist_ok=True);OUT.parent.mkdir(exist_ok=True);yosys=yosys_binary()
  if not yosys:raise SystemExit('Yosys is required')
  rows=[synth(yosys,'qos_arbiter','rtl/qos_arbiter.sv','qos_arbiter','qos_arbiter_netlist.v'),
        synth(yosys,'async_fifo_gray','rtl/async_fifo_gray.sv','async_fifo_gray','async_fifo_gray_netlist.v'),
        synth(yosys,'dma_iommu','rtl/dma_iommu.sv','dma_iommu','dma_iommu_netlist.v'),
        synth(yosys,'4x4_full_fabric','rtl/qos_arbiter.sv rtl/axi4_qos_fabric.sv','axi4_qos_fabric','full_fabric_netlist.v',True)]
  with OUT.open('w',newline='') as handle:
    writer=csv.DictWriter(handle,fieldnames=list(rows[0]),lineterminator='\n');writer.writeheader();writer.writerows(rows)
  passed=sum(row['status']=='PASS' for row in rows);print(f'SYNTH_RESULT|passed={passed}|executable={len(rows)}|full_fabric={rows[-1]["status"]}')
  return 0 if passed==len(rows) else 1
if __name__=='__main__':raise SystemExit(main())
