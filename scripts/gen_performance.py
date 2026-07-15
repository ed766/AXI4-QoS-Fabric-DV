#!/usr/bin/env python3
from __future__ import annotations
import csv,json,statistics,subprocess
from collections import defaultdict,deque
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
WORKLOADS=("target_matrix","contention_four","equal_qos_rr","qos_priority","starvation_override","outstanding_ids")

def nearest(values:list[int],percentile:int)->int:
    ordered=sorted(values); return ordered[max(0,(percentile*len(ordered)+99)//100-1)]

def analyze(path:Path):
    pending=defaultdict(deque); grant_wait=defaultdict(list); latency=defaultdict(list)
    accepted=defaultdict(int); overrides=0; cycles=[]
    for line in path.read_text().splitlines():
        event=json.loads(line); kind=event.get('event'); cycle=int(event.get('cycle',0)); cycles.append(cycle)
        if kind in ('aw','ar'):
            op='write' if kind=='aw' else 'read'; key=(int(event['master']),int(event['id']),op)
            pending[key].append(cycle); accepted[(int(event['master']),op)]+=1
        elif kind in ('aw_grant','ar_grant'):
            op='write' if kind=='aw_grant' else 'read'; key=(int(event['master']),int(event['id']),op)
            if pending[key]: grant_wait[(int(event['master']),op)].append(cycle-pending[key][0])
            overrides+=int(event.get('age_override',0))
        elif kind=='b' or (kind=='r' and int(event.get('last',0))):
            op='write' if kind=='b' else 'read'; key=(int(event['master']),int(event['id']),op)
            if pending[key]: latency[(int(event['master']),op)].append(cycle-pending[key].popleft())
    window=max(cycles)-min(cycles)+1 if cycles else 0; total=sum(accepted.values())
    return accepted,latency,grant_wait,overrides,window,total

def main()->int:
    binary=ROOT/'build/smoke/Vtb_axi4_qos_fabric'; rows=[]
    for workload in WORKLOADS:
      for bp in (0,25,50,75):
        trace=ROOT/f'build/traces/perf_{workload}_bp{bp}.jsonl'
        run=subprocess.run([str(binary),f'+TEST_NAME={workload}',f'+STALL_PERCENT={bp}',f'+TRACE_FILE={trace.relative_to(ROOT)}'],cwd=ROOT,text=True,capture_output=True,timeout=90)
        if run.returncode: raise SystemExit(f'performance failed workload={workload} bp={bp}')
        accepted,latencies,waits,overrides,window,total=analyze(trace)
        for master in range(4):
          for op in ('read','write'):
            values=latencies[(master,op)]
            if not values: continue
            arbitration=waits[(master,op)]
            rows.append({'workload':workload,'backpressure_percent':bp,'master':master,'operation':op,
              'requests':len(values),'mean_latency_cycles':f'{statistics.mean(values):.2f}',
              'p50_latency_cycles':nearest(values,50),'p95_latency_cycles':nearest(values,95),'max_latency_cycles':max(values),
              'mean_arbitration_wait_cycles':f'{statistics.mean(arbitration):.2f}' if arbitration else 'NA',
              'accepted_requests_per_cycle':f'{len(values)/window:.4f}' if window else 'NA',
              'service_share_percent':f'{100*accepted[(master,op)]/total:.2f}' if total else 'NA',
              'age_override_events':overrides,'status':'PASS'})
    out=ROOT/'reports/performance_summary.csv'; out.parent.mkdir(exist_ok=True)
    with out.open('w',newline='') as f:
      w=csv.DictWriter(f,fieldnames=rows[0].keys(),lineterminator='\n');w.writeheader();w.writerows(rows)
    highlights=[]
    for workload in WORKLOADS:
      subset=[r for r in rows if r['workload']==workload]
      mean0=statistics.mean(float(r['mean_latency_cycles']) for r in subset if int(r['backpressure_percent'])==0)
      mean75=statistics.mean(float(r['mean_latency_cycles']) for r in subset if int(r['backpressure_percent'])==75)
      highlights.append((workload,mean0,mean75,mean75-mean0,max(int(r['age_override_events']) for r in subset)))
    (ROOT/'docs/performance.md').write_text(
      '# QoS and Contention Performance\n\nBehavioral Verilator measurements across identical named workloads. Values are verification/performance proxies, not silicon timing.\n\n'
      '| Workload | Mean latency at 0% | Mean latency at 75% | Added latency | Aging overrides |\n| --- | ---: | ---: | ---: | ---: |\n'+
      ''.join(f'| `{name}` | {low:.2f} | {high:.2f} | {delta:.2f} | {overrides} |\n' for name,low,high,delta,overrides in highlights)+
      '\nThe CSV additionally reports per-master p50/p95/max latency, arbitration wait, accepted throughput, and service share for 0/25/50/75% backpressure. Equal-QoS, mixed-QoS, aging override, multi-outstanding, and asynchronous-target traffic are measured separately.\n')
    print(f'PERFORMANCE_RESULT|points={len(rows)}|workloads={len(WORKLOADS)}|status=PASS')
    return 0
if __name__=='__main__': raise SystemExit(main())
