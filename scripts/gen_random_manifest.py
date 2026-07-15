#!/usr/bin/env python3
from __future__ import annotations
import argparse,csv,random
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
    ap=argparse.ArgumentParser(); ap.add_argument('--count',type=int,default=100); args=ap.parse_args()
    out=ROOT/'reports'/'random_manifest.csv'; out.parent.mkdir(exist_ok=True)
    fields=['index','seed','operations','read_percent','burst_max','backpressure_percent','error_percent','security_percent','status']
    with out.open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=fields,lineterminator='\n'); w.writeheader()
        for i in range(args.count):
            r=random.Random(0xA410000+i)
            w.writerow(dict(index=i,seed=0xA410000+i,operations=r.choice([50,100,200]),read_percent=r.choice([25,50,75]),
              burst_max=r.choice([1,4,8,16]),backpressure_percent=r.choice([0,25,50,75]),
              error_percent=r.choice([0,1,5]),security_percent=r.choice([0,10,25]),status='GENERATED'))
    print(f'RANDOM_MANIFEST|rows={args.count}|executed=0|path={out.relative_to(ROOT)}')
if __name__=='__main__': main()
