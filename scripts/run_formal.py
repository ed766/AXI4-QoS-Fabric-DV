#!/usr/bin/env python3
from __future__ import annotations
import csv,os,shutil,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]; BUILD=ROOT/'build'/'formal'; OUT=ROOT/'reports'/'formal_summary.csv'
def main():
    BUILD.mkdir(parents=True,exist_ok=True); OUT.parent.mkdir(exist_ok=True)
    cmd=['verilator','--binary','--sv','--timing','--assert','-Wno-fatal','--top-module','tb_qos_properties','-Mdir',str(BUILD),'rtl/qos_arbiter.sv','formal/tb_qos_properties.sv']
    c=subprocess.run(cmd,cwd=ROOT,text=True,capture_output=True)
    if c.returncode: raise SystemExit(c.stderr)
    r=subprocess.run([str(BUILD/'Vtb_qos_properties')],cwd=ROOT,text=True,capture_output=True)
    (BUILD/'bounded.log').write_text(r.stdout+r.stderr)
    rows=[{'property_group':'qos_grant_safety','mode':'bounded_verilator','depth':'33','status':'PASS' if r.returncode==0 else 'FAIL','runtime_seconds':'NA','note':'three executable arbiter invariants'}]
    solver=shutil.which('z3') or str(ROOT/'build/formal-venv/bin/z3')
    smt=BUILD/'qos_arbiter.smt2'; yosys=shutil.which('yosys'); smtbmc=shutil.which('yosys-smtbmc')
    if yosys and smtbmc and Path(solver).exists():
        synth=subprocess.run([yosys,'-q','-p',f'read_verilog -formal -sv rtl/qos_arbiter.sv formal/qos_arbiter_formal.sv; prep -top qos_arbiter_formal; async2sync; dffunmap; write_smt2 -wires {smt}'],cwd=ROOT,text=True,capture_output=True)
        env={**os.environ,'PATH':str(Path(solver).parent)+os.pathsep+os.environ['PATH']}
        start=time.monotonic()
        prove=subprocess.run([smtbmc,'-s','z3','-t','40','-i',str(smt)],cwd=ROOT,text=True,capture_output=True,env=env) if synth.returncode==0 else synth
        runtime=f'{time.monotonic()-start:.3f}'
        (BUILD/'solver_prove.log').write_text(prove.stdout+prove.stderr)
        cover=subprocess.run([smtbmc,'-s','z3','-t','80','-c',str(smt)],cwd=ROOT,text=True,capture_output=True,env=env) if synth.returncode==0 else synth
        (BUILD/'solver_cover.log').write_text(cover.stdout+cover.stderr)
        rows.append({'property_group':'qos_arbiter_safety','mode':'Yosys_SMT_induction','depth':'40','status':'PASS' if prove.returncode==0 else 'FAIL','runtime_seconds':runtime,'note':'grant ownership, availability, and highest-QoS safety'})
        rows.append({'property_group':'qos_arbiter_reachability','mode':'Yosys_SMT_cover','depth':'80','status':'PASS' if cover.returncode==0 else 'FAIL','runtime_seconds':'NA','note':'contention and aging override covers reachable'})
    else:
        rows.append({'property_group':'qos_arbiter_safety','mode':'Yosys_SMT_induction','depth':'40','status':'SKIP','runtime_seconds':'NA','note':'requires yosys-smtbmc and z3'})
    rows.append({'property_group':'full_fabric_solver','mode':'Yosys_SMT','depth':'NA','status':'SKIP','runtime_seconds':'NA','note':'requires a frontend supporting multidimensional SystemVerilog ports'})
    with OUT.open('w',newline='') as f:w=csv.DictWriter(f,fieldnames=rows[0].keys(),lineterminator='\n');w.writeheader();w.writerows(rows)
    solver_status=next(row['status'] for row in rows if row['property_group']=='qos_arbiter_safety')
    print(f'FORMAL_RESULT|bounded={rows[0]["status"]}|solver={solver_status}')
    return r.returncode or (1 if solver_status=='FAIL' else 0)
if __name__=='__main__': raise SystemExit(main())
