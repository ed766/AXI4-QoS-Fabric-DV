# UVM Runtime Status

The UVM lane uses Verilator `v5.048` and `uvm-verilator` commit `656f20d087370a7c742e00188d20bbf30fa95339`. The reusable `vip/axi4` package contains a transaction, per-agent virtual-interface configuration, active master sequencer/driver/monitor/agent, and configurable reactive target policy. The fabric layer adds four configured master instances, a virtual sequencer, coordinated multi-master sequences, and an epoch/target/ID/beat-aware analysis-port scoreboard. Eight fabric tests run:

- `uvm_single_route_test`
- `uvm_qos_contention_test`
- `uvm_error_security_test`
- `uvm_multi_outstanding_test`
- `uvm_multi_id_reorder_test`
- `uvm_four_master_contention_test`
- `uvm_qos_starvation_override_test`
- `uvm_reset_with_outstanding_test`

The authoritative result is `reports/uvm_runtime_summary.csv`. A procedural test result is never substituted for a failed or timed-out UVM phase run.

The reusable agent contract, configuration pattern, supported transaction subset, and limitations are documented in the [AXI4 UVM VIP guide](../vip/axi4/README.md).

All eight tests complete through normal UVM build/connect/run/report phases with zero `UVM_ERROR`, zero `UVM_FATAL`, and non-zero expected scoreboard activity. No scenario alias or procedural fallback can produce a passing UVM row.

`make vip-selftest` independently connects the extracted master and reactive-target agents without the fabric DUT. Its authoritative `reports/vip_selftest_summary.csv` row requires two requests, two matching responses, zero mismatches, and zero UVM errors/fatals. Fabric target models retain deeper queued reordering policies above this reusable protocol-agent layer.

```bash
export VERILATOR_UVM=/path/to/verilator-v5.048/bin/verilator
export UVM_HOME=/path/to/uvm-verilator/src
make uvm-regress
make vip-selftest
```

UVM is the principal class-based methodology lane, while the procedural `30 / 30` suite remains a fast independent integration gate. Runtime support is pinned because open-source UVM support remains tool-version-sensitive.
