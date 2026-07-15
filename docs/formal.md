# Formal and Property Evidence

The project separates simulation assertions from solver-backed evidence.

| Scope | Mode | Depth | Result |
| --- | --- | ---: | --- |
| QoS grant safety | Bounded Verilator property harness | 33 | PASS |
| QoS ownership, availability, and priority | Yosys-SMTBMC induction with Z3 | 40 | PASS |
| Contention and aging-override reachability | Yosys-SMTBMC cover with Z3 | 80 | PASS |
| Full 4x4 fabric | Yosys-SMT | NA | SKIP: installed frontend cannot parse multidimensional ports |

The solver environment is reproducibly created by `make formal-env` with pinned `z3-solver==4.16.0.0`. Passing covers prevent the QoS safety result from being presented without evidence that contention and aging paths are reachable. These are open-source proofs for the arbiter, not full-fabric commercial formal closure.
