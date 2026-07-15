# Verification Plan

## Closure Layers

| Layer | Target | Command | Evidence |
| --- | ---: | --- | --- |
| Named integrated regression | `30 / 30` | `make regress` | `regression_summary.csv` |
| Seeded-random stress | `100 / 100` | `make random-stress` | `random_regress_summary.csv` |
| Real UVM runtime regression | `8 / 8` | `make uvm-regress` | `uvm_runtime_summary.csv` |
| Reusable AXI VIP self-test | `1 / 1` | `make vip-selftest` | `vip_selftest_summary.csv` |
| Independent SystemC/TLM checking | `130 / 130` trace replays | `make model-replay` | `model_replay_summary.csv` |
| Functional coverage | `56 / 56` | `make functional-coverage` | `functional_coverage.csv` |
| Interaction coverage | `46 / 46` | `make functional-coverage` | `cross_coverage.csv` |
| Advanced concurrent crosses | `24 / 24` | `make advanced-cross-coverage` | `advanced_cross_coverage.csv` |
| Assertions and bounded properties | zero failure | simulation / `make formal-prove` | SVA and `formal_summary.csv` |
| Mutation sensitivity | `6 / 6` | `make mutation-check` | `mutation_summary.csv` |
| Integrated CDC | `4 / 4` ratios | `make async-cdc-check` | `cdc_summary.csv` |
| Illegal-target checker sensitivity | `5 / 5` expected detections | `make target-protocol-negative` | `target_protocol_negative_summary.csv` |
| Performance characterization | `120` diagnostic + `72` sustained rows | `make performance-sweep` | performance/QoS summaries |
| Reviewed executable line coverage | at least `90%` | `make code-coverage` | raw and reviewed reports |

## Scenario Scope

Named tests additionally cover queued target responses, legal out-of-order completion across distinct IDs, simultaneous read/write response traffic, response-channel backpressure, and W-before-AW blocking. The random lane applies every manifest field directly: operation count, read/write mix, burst maximum, backpressure, error density, security density, and seed. The seed deterministically drives master, target, address, operation, and QoS selection.

Coverage is credited from passing scenarios and normalized request/response events. Functional, interaction, code, assertion, and mutation coverage remain separate evidence types.

## Acceptance

- Every executable row meets expectation with no assertion, scoreboard, model, or timeout failure.
- Local/security errors create no downstream side effects; responses preserve initiator ownership and IDs.
- Protocol-legal target reordering preserves per-ID order and contiguous read bursts; malformed target responses are expected-fail checker tests, not DUT recovery claims.
- All four CDC ratios complete full read/write traffic without loss or duplication.
- Raw code coverage remains visible; reviewed exclusions require a line-level rationale and evidence.
- Solver, synthesis, equivalence, and gate-level limitations remain explicit and are not counted as passing signoff evidence.
