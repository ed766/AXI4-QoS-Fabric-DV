# Verification Plan

## Closure Layers

| Layer | Target | Command | Evidence |
| --- | ---: | --- | --- |
| Named integrated regression | `25 / 25` | `make regress` | `regression_summary.csv` |
| Seeded-random stress | `100 / 100` | `make random-stress` | `random_regress_summary.csv` |
| Real UVM runtime smoke | `4 / 4` | `make uvm-smoke` | `uvm_runtime_summary.csv` |
| Independent SystemC/TLM checking | `125 / 125` trace replays | `make model-replay` | `model_replay_summary.csv` |
| Functional coverage | `56 / 56` | `make functional-coverage` | `functional_coverage.csv` |
| Interaction coverage | `46 / 46` | `make functional-coverage` | `cross_coverage.csv` |
| Assertions and bounded properties | zero failure | simulation / `make formal-prove` | SVA and `formal_summary.csv` |
| Mutation sensitivity | `6 / 6` | `make mutation-check` | `mutation_summary.csv` |
| Integrated CDC | `4 / 4` ratios | `make async-cdc-check` | `cdc_summary.csv` |
| Performance characterization | `112` per-master points | `make performance-sweep` | `performance_summary.csv` |
| Reviewed executable line coverage | at least `90%` | `make code-coverage` | raw and reviewed reports |

## Scenario Scope

Named tests cover mapped traffic, burst lengths, transfer sizes, byte strobes, malformed and boundary requests, security, downstream errors, two/four-way contention, QoS priority, equal-class arbitration, write locking, target backpressure, reset recovery, and asynchronous traffic. The random lane applies every manifest field directly: operation count, read/write mix, burst maximum, backpressure, error density, security density, and seed. The seed deterministically drives master, target, address, operation, and QoS selection.

Coverage is credited from passing scenarios and normalized request/response events. Functional, interaction, code, assertion, and mutation coverage remain separate evidence types.

## Acceptance

- Every executable row meets expectation with no assertion, scoreboard, model, or timeout failure.
- Local/security errors create no downstream side effects; responses preserve initiator ownership and IDs.
- All four CDC ratios complete full read/write traffic without loss or duplication.
- Raw code coverage remains visible; reviewed exclusions require a line-level rationale and evidence.
- Solver, synthesis, equivalence, and gate-level limitations remain explicit and are not counted as passing signoff evidence.
