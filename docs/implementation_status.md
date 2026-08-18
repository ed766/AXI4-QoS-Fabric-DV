# Implementation Status

## Executed Release Evidence

- Synthesizable 4x4 read/write fabric with ID widening, four active IDs per initiator, AW route FIFOs, burst-locked W/R routing, QoS priority, equal-class round robin, and 32-opportunity starvation override.
- Local malformed/security `DECERR` behavior and downstream error propagation.
- Five-channel Gray-pointer asynchronous bridge exercised at four source/target clock ratios.
- `30 / 30` named scenarios, `100 / 100` seeded-random runs, `56 / 56` functional bins, `46 / 46` canonical crosses, and `24 / 24` advanced crosses.
- Real UVM runtime: four active master agents, virtual sequences, and `8 / 8` phase-based tests on Verilator `v5.048`.
- Independent SystemC/TLM self-test and `130 / 130` normalized trace replays checking target response schedules, bursts, IDs, and memory effects.
- `29` named assertion classes (`120` elaborated protocol/CDC instances), `15 / 15` required formal groups, and `6 / 6` RTL mutation detections.
- `5 / 5` malformed-target expected failures validate checker sensitivity without claiming illegal-target recovery.
- `86.05%` raw design line, `93.35%` reviewed executable line, `95.00%` raw branch, and `69.71%` raw toggle coverage.

`make project-check` refreshes the core evidence. `make release-check` additionally enforces code-coverage and mutation thresholds and writes `reports/release_readiness.csv`.

## Explicit Non-Signoff Limits

- Solver-backed QoS and leaf-block safety/reachability pass. The frontend now elaborates the complete fabric, but full-state solver proof remains `SKIP` because of state-space cost.
- Yosys synthesis passes for the QoS arbiter, asynchronous FIFO, and complete 4x4 fabric. RTL and the zero-delay generic netlist pass the same six observable routing/error checks. Unbounded sequential equivalence remains `PARTIAL` and is not claimed as closure.
- The implementation is a documented AXI4 subset, not AXI certification, commercial CDC signoff, or timing signoff.
