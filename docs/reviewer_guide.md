# Five-Minute Reviewer Guide

## One Command

```bash
export VERILATOR_UVM=/path/to/verilator-v5.048/bin/verilator
export UVM_HOME=/path/to/uvm-verilator/src
make release-check
```

## Evidence Path

| Question | Open this artifact |
| --- | --- |
| Did the tests pass? | `reports/release_readiness.csv` and `reports/regression_summary.csv` |
| Was randomized traffic actually executed? | `reports/random_regress_summary.csv` |
| What is covered? | `docs/coverage.md` and `reports/cross_coverage.csv` |
| Is code coverage reviewed honestly? | `docs/code_coverage.md` and `reports/code_coverage_exclusions.csv` |
| Is UVM real or compile-only? | `docs/uvm_status.md` and `reports/uvm_runtime_summary.csv` |
| Are checkers sensitive to bugs? | `reports/mutation_summary.csv` |
| Does the independent model check every run? | `reports/model_replay_summary.csv` |
| Which assertions protect the architecture? | `docs/assertions.md` |
| Was solver-backed formal executed? | `reports/formal_summary.csv` |
| What real bug was found? | `docs/bug_diary.md` |
| What implementation evidence ran? | `reports/synthesis_summary.csv` and `reports/gate_level_summary.csv` |
| How are requirements traced? | `docs/traceability.md` |
| What performance tradeoff was measured? | `docs/performance.md` |
| What remains outside signoff? | `docs/implementation_status.md` |

All checked-in summaries use relative artifact paths. Raw build products, traces, and logs remain under ignored `build/` directories.
