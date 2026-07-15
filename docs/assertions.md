# Architectural Assertion Set

The simulation lane elaborates **112 assertion instances from 27 named assertion classes**. Assertions run in procedural, random, UVM, CDC, code-coverage, and mutation simulations.

| Area | Named properties | Protected invariant |
| --- | --- | --- |
| Initiator AXI | `a_s_aw_stable`, `a_s_w_stable`, `a_s_b_stable`, `a_s_ar_stable`, `a_s_r_stable` | Payload remains stable under backpressure. |
| Target AXI | `a_m_aw_stable`, `a_m_w_stable`, `a_m_ar_stable`, `a_m_r_stable` | Fabric output remains stable until target handshake. |
| Burst termination | `a_wlast_matches_awlen`, `a_rlast_matches_arlen`, known-last checks | Final-beat markers agree with accepted burst length. |
| Request ownership | `a_b_requires_accepted_aw`, `a_r_requires_accepted_ar` | No response retires without an accepted request. |
| Active IDs | duplicate-read/write and outstanding-bound assertions | Active IDs are unique and no initiator exceeds four requests. |
| Response routing | target B/R prefix assertions | Widened target IDs identify a valid originating initiator. |
| Asynchronous FIFOs | write/read Gray one-bit and stable-without-accept properties | Pointer synchronization changes by one Gray bit per transfer and cannot move on overflow/underflow attempts. |

The QoS arbiter additionally has bounded simulation checks and Yosys-SMT induction/cover evidence for request ownership, grant availability, highest-QoS selection, contention reachability, and aging-override reachability. This is open-source property evidence, not full-fabric commercial formal closure.
