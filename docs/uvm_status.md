# UVM Runtime Status

The UVM lane uses Verilator `v5.048` and `uvm-verilator` commit `656f20d087370a7c742e00188d20bbf30fa95339`. It contains four active master agents, sequencers, nonblocking request drivers, monitors, a shared analysis-port scoreboard, directed sequences, and four tests:

- `uvm_single_route_test`
- `uvm_qos_contention_test`
- `uvm_error_security_test`
- `uvm_multi_outstanding_test`

The authoritative result is `reports/uvm_runtime_summary.csv`. A procedural test result is never substituted for a failed or timed-out UVM phase run.

All three tests currently complete through normal UVM build/connect/run/report phases with zero `UVM_ERROR` and zero `UVM_FATAL`. Verilator `5.043-devel` was also evaluated during bring-up: it entered UVM but stalled before the test run phase, so it is not treated as passing evidence.

```bash
export VERILATOR_UVM=/path/to/verilator-v5.048/bin/verilator
export UVM_HOME=/path/to/uvm-verilator/src
make uvm-smoke
```

UVM is a real runtime methodology lane, but it is not presented as equivalent to the 24-scenario integrated regression. Its release requirement is the three representative phase-based tests completing with zero UVM errors/fatals and expected scoreboard activity.
