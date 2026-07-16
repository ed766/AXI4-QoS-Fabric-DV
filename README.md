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
    UVM["Reusable AXI UVM agents + fabric scoreboard + SVA"] -.-> F
    TLM["Independent SystemC/TLM model"] -.-> F
```

## Executed Evidence

Run `make reports` to refresh this generated snapshot from `reports/project_metrics.csv`.

<!-- BEGIN GENERATED METRICS -->
| Evidence | Current result |
| --- | ---: |
| Named integrated regression | `30 / 30` |
| Seeded-random stress | `100 / 100` |
| SystemC trace replay | `130 / 130` |
| Real UVM runtime | `8 / 8` |
| Reusable AXI VIP self-test | `1 / 1` |
| Functional coverage | `56 / 56` |
| Advanced interaction coverage | `24 / 24` |
| Mutation detection | `6 / 6` |
| Integrated CDC ratios | `4 / 4` |
<!-- END GENERATED METRICS -->

Additional measured evidence includes `46 / 46` canonical interaction crosses, `29` named assertion classes (`120` elaborated instances), `95.00%` raw branch coverage, and sustained QoS/fairness characterization. Formal/property evidence closes `15 / 15` groups: `14` solver-backed proof, bounded-safety, cover, and mutation groups plus `1` bounded Verilator simulation group. Full-fabric synthesis and equivalence remain explicitly `SKIP` because of the installed Yosys frontend limitation.

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
make vip-selftest      # extracted master/reactive-target agent package without the fabric DUT
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
6. [Reusable AXI4 UVM VIP guide](vip/axi4/README.md)
7. [Coverage](docs/coverage.md)
8. [Code coverage and exclusions](docs/code_coverage.md)
9. [Performance](docs/performance.md)
10. [Implementation status](docs/implementation_status.md)
11. [Five-minute reviewer guide](docs/reviewer_guide.md)
12. [Assertion set](docs/assertions.md)
13. [Bug diary](docs/bug_diary.md)
14. [Formal evidence](docs/formal.md)

## Tool and Signoff Boundaries

The default flow uses Verilator, SystemC 2.3.4, Python, C++, Yosys, Yosys-SMTBMC, and Z3. UVM uses Verilator `v5.048` and `uvm-verilator` commit `656f20d087370a7c742e00188d20bbf30fa95339`; older local builds are not accepted as equivalent runtime evidence. Results are open-source engineering evidence, not AXI certification, CDC signoff, timing signoff, or commercial formal closure. Solver evidence covers the QoS arbiter plus reduced asynchronous-FIFO, active-ID, local-error, and route-ownership harnesses; full-fabric formal, synthesis, and sequential equivalence remain explicitly frontend-limited. Unexecuted work is labeled `PARTIAL` or `SKIP`, never as passing evidence.
