#!/usr/bin/env python3
"""Build the optional DMA IOMMU and generate report-backed evidence."""
from __future__ import annotations
import csv,re,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];BUILD=ROOT/'build/iommu';REPORTS=ROOT/'reports'
REQUIRED=("level2_walk","read_translation","tlb_hit","write_translation","permission_fault","user_fault",
  "invalid_l1","invalid_l2","walk_access_fault","superpage","asid_isolation","asid_invalidate","global_invalidate",
  "round_robin_replacement","ptw_backpressure","response_backpressure","fault_no_paddr","one_response_per_request","reset_clean")
def main()->int:
  shutil.rmtree(BUILD,ignore_errors=True);BUILD.mkdir(parents=True)
  command=['verilator','--binary','--sv','--timing','--assert','-Wall','-Wno-BLKSEQ','-Wno-SYNCASYNCNET','-Wno-UNUSEDSIGNAL',
    '-Wno-WIDTHEXPAND','-Wno-WIDTHTRUNC','--top-module','tb_dma_iommu','--Mdir',str(BUILD/'obj'),
    'rtl/dma_iommu.sv','sim/tb_dma_iommu.sv']
  compiled=subprocess.run(command,cwd=ROOT,text=True,capture_output=True)
  executed=subprocess.run([str(BUILD/'obj/Vtb_dma_iommu')],cwd=ROOT,text=True,capture_output=True) if compiled.returncode==0 else compiled
  log=compiled.stdout+compiled.stderr+executed.stdout+executed.stderr;(BUILD/'run.log').write_text(log)
  match=re.search(r'IOMMU_SUMMARY\|status=(\w+)\|checks=(\d+)\|failures=(\d+)\|hits=(\d+)\|misses=(\d+)\|walk_reads=(\d+)\|faults=(\d+)',log)
  covered=set(re.findall(r'IOMMU_COVER\|([^\n\r]+)',log));passed=executed.returncode==0 and match and match.group(1)=='PASS'
  row={'test':'dma_iommu_matrix','status':'PASS' if passed else 'FAIL','checks':match.group(2) if match else '0',
    'failures':match.group(3) if match else 'NA','tlb_hits':match.group(4) if match else '0','tlb_misses':match.group(5) if match else '0',
    'walk_reads':match.group(6) if match else '0','faults':match.group(7) if match else '0','assertions':'6'}
  with (REPORTS/'iommu_summary.csv').open('w',newline='') as handle:
    writer=csv.DictWriter(handle,fieldnames=list(row),lineterminator='\n');writer.writeheader();writer.writerow(row)
  with (REPORTS/'iommu_coverage.csv').open('w',newline='') as handle:
    writer=csv.writer(handle,lineterminator='\n');writer.writerow(['coverage_point','status']);writer.writerows((point,'COVERED' if point in covered else 'MISSING') for point in REQUIRED)
  hit=sum(point in covered for point in REQUIRED);print(f'IOMMU_RESULT|status={row["status"]}|checks={row["checks"]}|coverage={hit}/{len(REQUIRED)}')
  return 0 if passed and hit==len(REQUIRED) else 1
if __name__=='__main__':raise SystemExit(main())
