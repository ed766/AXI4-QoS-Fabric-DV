#!/usr/bin/env python3
from __future__ import annotations
import csv, re, subprocess
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
CHECKER=ROOT/'build/model/trace_checker'
OUT=ROOT/'reports/model_replay_summary.csv'

def main()->int:
    sources=[]
    for report in ('regression_summary.csv','random_regress_summary.csv'):
        path=ROOT/'reports'/report
        if path.exists(): sources.extend(row for row in csv.DictReader(path.open()) if row['status']=='PASS')
    rows=[]
    for source in sources:
        trace=ROOT/source['trace']
        run=subprocess.run([str(CHECKER),str(trace)],cwd=ROOT,text=True,capture_output=True)
        match=re.search(r'TRACE_RESULT\|events=(\d+)\|requests=(\d+)\|grants=(\d+)\|beats=(\d+)\|responses=(\d+)\|memory_checks=(\d+)\|errors=(\d+)',run.stdout)
        rows.append({'scenario':source['scenario'],'events':match.group(1) if match else 0,
          'requests':match.group(2) if match else 0,'beats':match.group(4) if match else 0,
          'responses':match.group(5) if match else 0,'memory_checks':match.group(6) if match else 0,
          'errors':match.group(7) if match else 1,'status':'PASS' if run.returncode==0 and match else 'FAIL'})
    OUT.parent.mkdir(exist_ok=True)
    with OUT.open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=rows[0].keys(),lineterminator='\n');w.writeheader();w.writerows(rows)
    passed=sum(row['status']=='PASS' for row in rows)
    print(f'MODEL_REPLAY_RESULT|passed={passed}|total={len(rows)}|report={OUT.relative_to(ROOT)}')
    return 0 if rows and passed==len(rows) else 1
if __name__=='__main__': raise SystemExit(main())
