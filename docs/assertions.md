# Architectural Assertion Set

The integrated simulation lane elaborates **120 assertion instances from 29 named assertion classes**: 25 fabric protocol classes plus four asynchronous-FIFO classes. Assertions run in procedural, random, UVM, CDC, code-coverage, and mutation simulations.

| Area | Named properties | Protected invariant |
| --- | --- | --- |
| Initiator AXI | `a_s_aw_stable`, `a_s_w_stable`, `a_s_b_stable`, `a_s_ar_stable`, `a_s_r_stable` | Payload remains stable under backpressure. |
| Target AXI | `a_m_aw_stable`, `a_m_w_stable`, `a_m_ar_stable`, `a_m_r_stable` | Fabric output remains stable until target handshake. |
| Burst termination | `a_wlast_matches_awlen`, `a_rlast_matches_arlen`, known-last checks | Final-beat markers agree with accepted burst length. |
| Request ownership | `a_b_requires_accepted_aw`, `a_r_requires_accepted_ar` | No response retires without an accepted request. |
| Active IDs | duplicate-read/write and outstanding-bound assertions | Active IDs are unique and no initiator exceeds four requests. |
| Queued target ownership | target read-ID tracking and AW-length FIFO assertions | R is checked per widened ID; W follows accepted target AW order through `WLAST`. |
| Response routing | target B/R prefix assertions | Widened target IDs identify a valid originating initiator. |
| Asynchronous FIFOs | write/read Gray one-bit and stable-without-accept properties | Pointer synchronization changes by one Gray bit per transfer and cannot move on overflow/underflow attempts. |

The QoS arbiter additionally has bounded simulation checks and Yosys-SMT induction/cover evidence for request ownership, grant availability, highest-QoS selection, contention reachability, and aging-override reachability. This is open-source property evidence, not full-fabric commercial formal closure.
