#!/usr/bin/env python3
from __future__ import annotations
import csv, os, re, shutil, subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
BUILD=ROOT/'build'/'vip_selftest'
REPORT=ROOT/'reports'/'vip_selftest_summary.csv'
VERILATOR=os.environ.get('VERILATOR_UVM',str(Path.home()/'verilator-v5.048'/'bin'/'verilator'))
UVM_HOME=Path(os.environ.get('UVM_HOME',str(Path.home()/'uvm-verilator'/'src')))

def main()->int:
    sources=[UVM_HOME/'uvm_pkg.sv',ROOT/'sim/uvm/axi_master_if.sv',
             ROOT/'vip/axi4/axi4_uvm_vip_pkg.sv',ROOT/'vip/axi4/tb_axi4_vip_selftest.sv']
    binary=BUILD/'Vtb_axi4_vip_selftest'
    rebuild=not binary.exists() or binary.stat().st_mtime < max(path.stat().st_mtime for path in sources)
    if rebuild:
        if BUILD.exists(): shutil.rmtree(BUILD)
        BUILD.mkdir(parents=True)
        cmd=[VERILATOR,'--binary','-j','2','--sv','--timing','-Wno-fatal','-Wno-DECLFILENAME',
             '-Wno-WIDTHEXPAND','-Wno-WIDTHTRUNC','-Wno-UNUSEDSIGNAL','+define+UVM_NO_DPI',
             f'+incdir+{UVM_HOME}','-Isim/uvm','-Ivip/axi4',*[str(p) for p in sources],
             '--top-module','tb_axi4_vip_selftest','-Mdir',str(BUILD)]
        compile_result=subprocess.run(cmd,cwd=ROOT,text=True,capture_output=True)
        (BUILD/'compile.log').write_text(compile_result.stdout+'\n'+compile_result.stderr)
    else:
        compile_result=subprocess.CompletedProcess([],0,"","")
    status='COMPILE_FAIL'; errors=fatals=requests=responses=mismatches=0
    if compile_result.returncode==0:
        run=subprocess.run([str(binary),'+UVM_VERBOSITY=UVM_LOW'],cwd=ROOT,text=True,capture_output=True,timeout=60)
        output=run.stdout+'\n'+run.stderr; (BUILD/'run.log').write_text(output)
        errors=int(re.findall(r'UVM_ERROR\s*:\s*(\d+)',output)[-1]) if re.findall(r'UVM_ERROR\s*:\s*(\d+)',output) else 0
        fatals=int(re.findall(r'UVM_FATAL\s*:\s*(\d+)',output)[-1]) if re.findall(r'UVM_FATAL\s*:\s*(\d+)',output) else 0
        activity=re.search(r'requests=(\d+) responses=(\d+) mismatches=(\d+)',output)
        if activity: requests,responses,mismatches=map(int,activity.groups())
        status='PASS' if run.returncode==0 and errors==0 and fatals==0 and requests==2 and responses==2 and mismatches==0 else 'FAIL'
    REPORT.parent.mkdir(exist_ok=True)
    with REPORT.open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=['test','status','requests','responses','mismatches','uvm_error','uvm_fatal','log'],lineterminator='\n')
        w.writeheader(); w.writerow({'test':'axi4_vip_selftest','status':status,'requests':requests,'responses':responses,
                                     'mismatches':mismatches,'uvm_error':errors,'uvm_fatal':fatals,'log':'build/vip_selftest/run.log'})
    print(f'VIP_SELFTEST|status={status}|requests={requests}|responses={responses}|mismatches={mismatches}')
    return 0 if status=='PASS' else 1

if __name__=='__main__': raise SystemExit(main())
