# Verification Traceability

| Requirement | Stimulus | Checker/property | Evidence |
| --- | --- | --- | --- |
| Address decode and local `DECERR` | Mapped/unmapped reads and writes | SystemC decoder and response scoreboard | smoke trace, functional coverage |
| Response ownership | Distinct initiator IDs and targets | ID-aware trace checker, response stability SVA | trace summary, assertions |
| Multiple outstanding / OOO | Queued target policies return distinct IDs in reverse/fixed/random order | Active-ID assertions, epoch/target/ID/beat UVM scoreboard, SystemC scheduler replay | reorder scenarios, advanced crosses, waveform |
| Burst integrity | Four-beat read/write | data scoreboard, W/R stability and last checks | smoke log |
| QoS priority | Simultaneous same-target AR | first-grant check and independent TLM arbitration | smoke log, model self-test |
| Starvation override | Continuously eligible low-QoS request against high-QoS stream | event-derived age override, bounded check, solver cover | formal and performance summaries |
| Access control | Non-secure access to S2 | local `DECERR`, no target request | smoke log, security mutation |
| Integrated CDC | Sustained S3 traffic, FIFO wrap, pending reset, four clock ratios | end-to-end data/ID and ghost-response checks | CDC summary |
| UVM methodology | Eight phase-based tests including virtual multi-master sequences | UVM monitors and epoch/target/ID/beat scoreboard | UVM runtime summary |
| Reusable protocol agents | Extracted master plus reactive-target agent connected without the fabric DUT | analysis-port event checker and UVM report counts | VIP self-test summary |
| Checker sensitivity | Decode, ID, W-lock, response-owner, age, and security mutations | assertion/scoreboard/timeout | mutation summary |
| Randomized stress | 100 manifest rows with applied traffic/fault knobs | protocol assertions and transaction checks | random regression summary |
| Coverage closure | Observed normalized request, grant, beat, response, reset, and configuration events | 56 flat bins and 46 interaction bins | coverage reports |
| Advanced interaction closure | Depth/policy, QoS/contention, response queue/backpressure, W-before-AW | 24 same-window bins from focused traces | advanced cross report |
| Illegal target protocol | Early/late RLAST, unknown RID, duplicate B, malformed BID | SVA/checker/timeout expected detection | target protocol negative summary |
| Implementation proxy | QoS arbiter and async FIFO synthesis; QoS netlist smoke | Yosys stat and Verilator gate test | synthesis/gate reports |
