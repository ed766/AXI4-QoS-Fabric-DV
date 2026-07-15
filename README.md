# AXI4 QoS Fabric RTL and DV Project

A standalone, synthesizable 4-initiator/4-target AXI4 shared fabric built to demonstrate SoC interconnect design and verification. The fabric implements independent read/write routing, ID ownership, four outstanding IDs per initiator, burst-locked data routing, QoS-aware round-robin arbitration with aging, static access control, local `DECERR`, and a five-channel asynchronous AXI target bridge.

This project is independent of the earlier RISC-V chiplet and L1 cache projects. No DUT RTL or reference model is reused.

## Architecture

```mermaid
flowchart LR
    M0["AXI master 0"] --> F["4x4 AXI4 QoS fabric"]
    M1["AXI master 1"] --> F
    M2["AXI master 2"] --> F
    M3["AXI master 3"] --> F
    F --> S0["S0 fast memory"]
    F --> S1["S1 backpressured memory"]
    F --> S2["S2 secure/error target"]
    F --> C["Five-channel async bridge"] --> S3["S3 async memory"]
    UVM["UVM agents + scoreboard + SVA"] -.-> F
    TLM["Independent SystemC/TLM model"] -.-> F
```

## Executed Evidence

The repository reports measured results separately from the full release targets. Run `make reports` to refresh the current snapshot.

| Evidence | Current executable scope |
| --- | --- |
| Named integrated regression | `30 / 30` routing, burst, error, queued response reordering, contention, reset, backpressure, and CDC scenarios |
| Seeded-random stress | `100 / 100` passing manifest-driven runs with reproducible knobs and logs |
| Protocol/data smoke checks | `38 / 38` passing |
| SystemC/TLM model self-test | `7 / 7` passing |
| Full trace replay | `130 / 130` named/random traces checked for routing, scheduled response order, beats, IDs, and memory effects |
| Assertions | `29` named classes and `120` elaborated protocol/CDC instances |
| UVM runtime | `8 / 8` real phase-based tests on Verilator `v5.048`, including four-agent contention, reorder, aging, and reset |
| Functional / interaction coverage | `56 / 56` bins, `46 / 46` canonical crosses, and `24 / 24` advanced concurrent-activity crosses |
| Verilator coverage | `86.05%` raw / `93.35%` reviewed line; `95.00%` raw branch; `69.71%` raw toggle |
| Mutation detection | `6 / 6` injected faults detected |
| Illegal-target checker sensitivity | `5 / 5` malformed response cases detected as expected failures |
| Integrated CDC / performance | `4 / 4` clock ratios; `120` diagnostic and `72` sustained QoS/fairness result rows |
| Solver formal | `15 / 15` required proof, bounded-safety, reachability-cover, and mutation-counterexample groups |
| Implementation proxy | `2 / 2` parseable blocks synthesize and QoS gate smoke passes; full fabric remains frontend-limited |

## Measured Visual Evidence

![QoS fairness under sustained contention](docs/images/qos_fairness_dashboard.svg)

The sustained dashboard compares equal-QoS, mixed-QoS, and aging-override service fairness across `0/25/50/75%` target backpressure. [The full performance report](docs/performance.md) retains per-master throughput, p50/p95/max latency, service share, maximum service gap, and override counts.

![Legal out-of-order response sequence](docs/images/out_of_order_response_waveform.svg)

The response trace accepts IDs `1,2,3,4` and completes them as `2,4,3,1`; [the debug diary](docs/bug_diary.md) explains the ownership bug exposed while enabling queued targets and how the target-side AW owner FIFO fixed it.

## Supported AXI4 Subset

- 32-bit address, 64-bit data, 4-bit initiator ID.
- Four initiators and four targets by default.
- `INCR` bursts of 1-16 beats and 1/2/4/8-byte transfer sizes.
- Four distinct outstanding read IDs and four distinct outstanding write IDs per initiator.
- Out-of-order completion across IDs; contiguous beats within an R burst.
- Target ID is `{initiator_index, initiator_id}` and is restored on response.
- Invalid, unmapped, misaligned, unsupported, 4-KiB-crossing, or denied accesses complete locally with `DECERR`.
- `FIXED`, `WRAP`, exclusive, atomic, coherent, and read-interleaved transactions are outside the contract.

This is a deliberately constrained AXI4 implementation, not protocol certification or reusable commercial VIP.

## Quick Start

```bash
make lint
make model-check
make uvm-regress       # auto-detects ~/verilator-v5.048 when present
make release-check
```

Optional evidence:

```bash
make regress
make random-stress
make advanced-cross-coverage
make target-protocol-negative
make code-coverage
make formal-prove
make mutation-check
make synth-check
make equivalence-check
make gate-level-smoke
make release-check       # executable release gate; fails if any measured criterion misses its target
```

## Reviewer Path

1. [Project metrics](docs/project_metrics.md)
2. [Architecture and AXI contract](docs/architecture.md)
3. [Verification plan](docs/verification_plan.md)
4. [Requirement traceability](docs/traceability.md)
5. [UVM runtime status](docs/uvm_status.md)
6. [Coverage](docs/coverage.md)
7. [Code coverage and exclusions](docs/code_coverage.md)
8. [Performance](docs/performance.md)
9. [Implementation status](docs/implementation_status.md)
10. [Five-minute reviewer guide](docs/reviewer_guide.md)
11. [Assertion set](docs/assertions.md)
12. [Bug diary](docs/bug_diary.md)
13. [Formal evidence](docs/formal.md)

## Tool and Signoff Boundaries

The default flow uses Verilator, SystemC 2.3.4, Python, C++, Yosys, Yosys-SMTBMC, and Z3. UVM uses Verilator `v5.048` and `uvm-verilator` commit `656f20d087370a7c742e00188d20bbf30fa95339`; older local builds are not accepted as equivalent runtime evidence. Results are open-source engineering evidence, not AXI certification, CDC signoff, timing signoff, or commercial formal closure. Solver evidence covers the QoS arbiter plus reduced asynchronous-FIFO, active-ID, local-error, and route-ownership harnesses; full-fabric formal, synthesis, and sequential equivalence remain explicitly frontend-limited. Unexecuted work is labeled `PARTIAL` or `SKIP`, never as passing evidence.
