# Verification Traceability

| Requirement | Stimulus | Checker/property | Evidence |
| --- | --- | --- | --- |
| Address decode and local `DECERR` | Mapped/unmapped reads and writes | SystemC decoder and response scoreboard | smoke trace, functional coverage |
| Response ownership | Distinct initiator IDs and targets | ID-aware trace checker, response stability SVA | trace summary, assertions |
| Multiple outstanding / OOO | Four same-master read and write IDs; duplicate ID attempt | Active-ID assertions, response collector, SystemC replay | `outstanding_ids`, `uvm_multi_outstanding_test` |
| Burst integrity | Four-beat read/write | data scoreboard, W/R stability and last checks | smoke log |
| QoS priority | Simultaneous same-target AR | first-grant check and independent TLM arbitration | smoke log, model self-test |
| Starvation override | Continuously eligible low-QoS request against high-QoS stream | event-derived age override, bounded check, solver cover | formal and performance summaries |
| Access control | Non-secure access to S2 | local `DECERR`, no target request | smoke log, security mutation |
| Integrated CDC | Sustained S3 traffic, FIFO wrap, pending reset, four clock ratios | end-to-end data/ID and ghost-response checks | CDC summary |
| UVM methodology | Four phase-based tests including multi-ID traffic | UVM monitor and scoreboard | UVM runtime summary |
| Checker sensitivity | Decode, ID, W-lock, response-owner, age, and security mutations | assertion/scoreboard/timeout | mutation summary |
| Randomized stress | 100 manifest rows with applied traffic/fault knobs | protocol assertions and transaction checks | random regression summary |
| Coverage closure | Observed normalized request, grant, beat, response, reset, and configuration events | 56 flat bins and 46 interaction bins | coverage reports |
| Implementation proxy | QoS arbiter and async FIFO synthesis; QoS netlist smoke | Yosys stat and Verilator gate test | synthesis/gate reports |
