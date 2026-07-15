# Implementation Status

## Executed Release Evidence

- Synthesizable 4x4 read/write fabric with ID widening, four active IDs per initiator, AW route FIFOs, burst-locked W/R routing, QoS priority, equal-class round robin, and 32-opportunity starvation override.
- Local malformed/security `DECERR` behavior and downstream error propagation.
- Five-channel Gray-pointer asynchronous bridge exercised at four source/target clock ratios.
- `25 / 25` named scenarios, `100 / 100` seeded-random runs, `56 / 56` functional bins, and `46 / 46` event-derived crosses.
- Real UVM runtime: four active master agents and `4 / 4` phase-based tests on Verilator `v5.048`, including multi-ID traffic.
- Independent SystemC/TLM self-test and `125 / 125` normalized trace replays checking bursts and memory effects.
- `27` named assertion classes (`112` elaborated protocol/CDC instances), bounded checks, two solver proof/cover groups, and `6 / 6` mutation detections.
- `85.88%` raw design line coverage and `93.25%` reviewed executable line coverage with explicit exclusions.

`make project-check` refreshes the core evidence. `make release-check` additionally enforces code-coverage and mutation thresholds and writes `reports/release_readiness.csv`.

## Explicit Non-Signoff Limits

- Solver-backed QoS safety and reachability pass; full-fabric proof remains `SKIP` because the installed frontend cannot parse multidimensional AXI ports.
- Yosys synthesis passes for the QoS arbiter and asynchronous FIFO, and a generic-netlist QoS gate smoke passes. Full-fabric synthesis remains `SKIP`; sequential equivalence is `PARTIAL` and not claimed as closure.
- The implementation is a documented AXI4 subset, not AXI certification, commercial CDC signoff, or timing signoff.
