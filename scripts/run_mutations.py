#!/usr/bin/env python3
from __future__ import annotations
import csv,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; BUILD=ROOT/'build'/'mutations'; OUT=ROOT/'reports'/'mutation_summary.csv'
RTL=['rtl/qos_arbiter.sv','rtl/async_fifo_gray.sv','rtl/axi4_async_bridge.sv','rtl/axi4_qos_fabric.sv','sim/axi_memory_model.sv','sim/assertions/axi4_fabric_assertions.sv','sim/tb_axi4_qos_fabric.sv']
def run(name,define,top='tb_axi4_qos_fabric',sources=None,plusargs=None):
    d=BUILD/name; d.mkdir(parents=True,exist_ok=True); src=sources or RTL
    cmd=['verilator','--binary','--sv','--timing','--assert','-Wno-fatal',f'+define+{define}','--top-module',top,'-Mdir',str(d),*src]
    c=subprocess.run(cmd,cwd=ROOT,text=True,capture_output=True)
    if c.returncode:return {'mutation':name,'compile':'FAIL','detected':'NO','detector':'compile'}
    try:r=subprocess.run([str(d/f'V{top}'),*(plusargs or [])],cwd=ROOT,text=True,capture_output=True,timeout=8)
    except subprocess.TimeoutExpired:return {'mutation':name,'compile':'PASS','detected':'YES','detector':'timeout/no response'}
    (d/'run.log').write_text(r.stdout+r.stderr)
    return {'mutation':name,'compile':'PASS','detected':'YES' if r.returncode else 'NO','detector':'assertion/scoreboard'}
def main():
    BUILD.mkdir(parents=True,exist_ok=True);OUT.parent.mkdir(exist_ok=True)
    rows=[
      run('decode_boundary_error','BUG_DECODE_BOUNDARY',plusargs=['+TEST_NAME=local_error_matrix','+TRACE_FILE=/dev/null']),
      run('id_encoding_corruption','BUG_ID_CORRUPT'),
      run('early_write_route_unlock','BUG_EARLY_W_UNLOCK',plusargs=['+TEST_NAME=write_burst_lock','+TRACE_FILE=/dev/null']),
      run('wrong_response_owner','BUG_WRONG_RESPONSE_ROUTE'),
      run('age_counter_disabled','BUG_AGE_DISABLE','tb_qos_properties',['rtl/qos_arbiter.sv','formal/tb_qos_properties.sv']),
      run('security_mask_bypass','BUG_SECURITY_BYPASS'),
    ]
    with OUT.open('w',newline='') as f:w=csv.DictWriter(f,fieldnames=rows[0].keys(),lineterminator='\n');w.writeheader();w.writerows(rows)
    detected=sum(r['detected']=='YES' for r in rows);print(f'MUTATION_RESULT|detected={detected}|total={len(rows)}')
    return 0 if detected==len(rows) else 1
if __name__=='__main__':raise SystemExit(main())
