# Formal and Property Evidence

The project separates simulation assertions from solver-backed evidence.

| Scope | Mode | Depth | Result |
| --- | --- | ---: | --- |
| QoS grant safety | Bounded Verilator property harness | 33 | PASS |
| QoS ownership, availability, and priority | Yosys-SMTBMC induction with Z3 | 40 | PASS |
| Contention and aging-override reachability | Yosys-SMTBMC cover with Z3 | 80 | PASS |
| Async FIFO count/ordering safety | Yosys-SMTBMC bounded safety | 16 | PASS |
| Async FIFO wraparound | Yosys-SMTBMC cover | 20 | PASS |
| Active-ID uniqueness/count/clear | Yosys-SMTBMC bounded safety | 40 | PASS |
| Multiple active IDs | Yosys-SMTBMC cover | 80 | PASS |
| Local-error containment/response count | Yosys-SMTBMC bounded safety | 40 | PASS |
| Local `DECERR` response | Yosys-SMTBMC cover | 80 | PASS |
| W owner held through final beat | Yosys-SMTBMC bounded safety | 40 | PASS |
| Ownership handoff | Yosys-SMTBMC cover | 80 | PASS |
| Four leaf mutations | Expected solver counterexamples | 20 | PASS |
| Full 4x4 fabric | Yosys-SMT | NA | SKIP: installed frontend cannot parse multidimensional ports |

The solver environment is reproducibly created by `make formal-env` with pinned `z3-solver==4.16.0.0`. The report closes **15 / 15** required bounded-simulation, proof, bounded-safety, cover, and expected-mutation groups. Covers prevent safety results from being presented without reachability evidence. Only the QoS arbiter safety property closes by induction; leaf groups are honestly labeled bounded safety, and this is not full-fabric commercial formal closure.
