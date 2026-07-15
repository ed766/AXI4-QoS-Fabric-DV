# UVM Runtime Status

The UVM lane uses Verilator `v5.048` and `uvm-verilator` commit `656f20d087370a7c742e00188d20bbf30fa95339`. It contains four active master agents, per-agent sequencers, a virtual sequencer, coordinated multi-master virtual sequences, nonblocking request drivers, monitors, and an epoch/target/ID/beat-aware analysis-port scoreboard. Eight tests run:

- `uvm_single_route_test`
- `uvm_qos_contention_test`
- `uvm_error_security_test`
- `uvm_multi_outstanding_test`
- `uvm_multi_id_reorder_test`
- `uvm_four_master_contention_test`
- `uvm_qos_starvation_override_test`
- `uvm_reset_with_outstanding_test`

The authoritative result is `reports/uvm_runtime_summary.csv`. A procedural test result is never substituted for a failed or timed-out UVM phase run.

All eight tests complete through normal UVM build/connect/run/report phases with zero `UVM_ERROR`, zero `UVM_FATAL`, and non-zero expected scoreboard activity. No scenario alias or procedural fallback can produce a passing UVM row.

```bash
export VERILATOR_UVM=/path/to/verilator-v5.048/bin/verilator
export UVM_HOME=/path/to/uvm-verilator/src
make uvm-regress
```

UVM is the principal class-based methodology lane, while the procedural `30 / 30` suite remains a fast independent integration gate. Runtime support is pinned because open-source UVM support remains tool-version-sensitive.
