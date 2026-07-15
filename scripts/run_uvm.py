#!/usr/bin/env python3
from __future__ import annotations
import argparse,csv,os,re,shutil,subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
BUILD=ROOT/'build'/'uvm'; REPORT=ROOT/'reports'/'uvm_runtime_summary.csv'
VERILATOR=os.environ.get('VERILATOR_UVM','verilator')
UVM_HOME=Path(os.environ.get('UVM_HOME',str(Path.home()/'uvm-verilator'/'src')))

def build()->Path:
    binary=BUILD/'Vtb_axi4_fabric_uvm'
    sources=[UVM_HOME/'uvm_pkg.sv',ROOT/'sim/uvm/axi_master_if.sv',ROOT/'sim/uvm/axi_fabric_uvm_pkg.sv',
             ROOT/'rtl/qos_arbiter.sv',ROOT/'rtl/axi4_qos_fabric.sv',ROOT/'sim/axi_memory_model.sv',
             ROOT/'sim/assertions/axi4_fabric_assertions.sv',ROOT/'sim/uvm/tb_axi4_fabric_uvm.sv']
    if binary.exists() and binary.stat().st_mtime >= max(path.stat().st_mtime for path in sources): return binary
    if BUILD.exists(): shutil.rmtree(BUILD)
    BUILD.mkdir(parents=True,exist_ok=True)
    cmd=[VERILATOR,'--binary','-j','2','--sv','--timing','--assert','-Wno-fatal','-Wno-DECLFILENAME',
         '-Wno-PINCONNECTEMPTY','-Wno-WIDTHEXPAND','-Wno-WIDTHTRUNC','-Wno-UNUSEDSIGNAL',
         '+define+UVM_NO_DPI',f'+incdir+{UVM_HOME}','-Isim/uvm',str(UVM_HOME/'uvm_pkg.sv'),
         'sim/uvm/axi_master_if.sv','sim/uvm/axi_fabric_uvm_pkg.sv','rtl/qos_arbiter.sv',
         'rtl/axi4_qos_fabric.sv','sim/axi_memory_model.sv','sim/assertions/axi4_fabric_assertions.sv',
         'sim/uvm/tb_axi4_fabric_uvm.sv','--top-module','tb_axi4_fabric_uvm','-Mdir',str(BUILD)]
    result=subprocess.run(cmd,cwd=ROOT,text=True,capture_output=True)
    (BUILD/'compile.log').write_text(result.stdout+'\n'+result.stderr)
    if result.returncode: raise SystemExit(f'UVM compile failed; see {BUILD / "compile.log"}')
    return binary

def counts(text:str,kind:str)->int:
    found=re.findall(rf'UVM_{kind}\s*:\s*(\d+)',text)
    return int(found[-1]) if found else len(re.findall(rf'^UVM_{kind}',text,re.M))

def main()->int:
    ap=argparse.ArgumentParser(); ap.add_argument('--tests',required=True); args=ap.parse_args()
    binary=build(); rows=[]; logs=BUILD/'logs'; logs.mkdir(exist_ok=True)
    for test in args.tests.split(','):
        extra=[]
        if test in ('uvm_multi_id_reorder_test','uvm_four_master_contention_test'):
            extra=['+REORDER_POLICY=1','+REORDER_TARGET=1','+REORDER_DELAY=8']
        elif test=='uvm_reset_with_outstanding_test':
            extra=['+REORDER_POLICY=2','+REORDER_TARGET=1','+REORDER_DELAY=30']
        result=subprocess.run([str(binary),f'+UVM_TESTNAME={test}','+UVM_VERBOSITY=UVM_LOW',*extra],cwd=ROOT,text=True,capture_output=True,timeout=120)
        text=result.stdout+'\n'+result.stderr; (logs/f'{test}.log').write_text(text)
        err,fatal=counts(text,'ERROR'),counts(text,'FATAL')
        activity=re.search(r'\[SCOREBOARD_ACTIVITY\]\s+requests=(\d+)\s+responses=(\d+)\s+mismatches=(\d+)',text)
        requests=int(activity.group(1)) if activity else 0
        responses=int(activity.group(2)) if activity else 0
        mismatches=int(activity.group(3)) if activity else 1
        rows.append({'test':test,'status':'PASS' if result.returncode==0 and err==0 and fatal==0 and requests>0 and responses>0 and mismatches==0 else 'FAIL',
                     'uvm_info':counts(text,'INFO'),'uvm_warning':counts(text,'WARNING'),'uvm_error':err,'uvm_fatal':fatal,
                     'scoreboard_requests':requests,'scoreboard_responses':responses,'scoreboard_mismatches':mismatches,
                     'log':str((logs/f'{test}.log').relative_to(ROOT))})
    REPORT.parent.mkdir(exist_ok=True)
    with REPORT.open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=rows[0].keys(),lineterminator='\n'); w.writeheader(); w.writerows(rows)
    passed=sum(r['status']=='PASS' for r in rows); print(f'UVM_RESULT|passed={passed}|total={len(rows)}|report={REPORT.relative_to(ROOT)}')
    return 0 if passed==len(rows) else 1
if __name__=='__main__': raise SystemExit(main())
