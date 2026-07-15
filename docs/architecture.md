# Architecture and Microarchitecture

The design is a shared crossbar-style AXI4 fabric, not a packet-switched NoC. Read and write address channels arbitrate independently per target. A target grant encodes the source initiator into the downstream ID; response routing decodes that prefix.

## Routing

| Target | Range | Policy |
| --- | --- | --- |
| S0 | `0x0000_0000-0x0000_FFFF` | Fast memory |
| S1 | `0x1000_0000-0x1000_FFFF` | Contention/backpressure target |
| S2 | `0x2000_0000-0x2000_FFFF` | Secure/error-capable target |
| S3 | `0x3000_0000-0x3000_FFFF` | Five-channel asynchronous bridge |

AW acceptance pushes a route record into a per-initiator FIFO. Since AXI4 has no WID, the W channel follows AW order and locks one initiator to a target through `WLAST`. R routing locks one target burst to an initiator through `RLAST`. Duplicate active IDs are backpressured.

## Arbitration and Security

Address arbitration selects an aged request first, otherwise the highest `AxQOS`, then round robin among ties. A request becomes age-eligible after 32 arbitration opportunities. Static target masks and secure-only target bits reject prohibited accesses locally. A rejected request cannot assert a target address channel.

## CDC

S3 crosses independent clocks through Gray-pointer AW, W, B, AR, and R FIFOs. Integrated tests execute `1:1`, `2:3`, `3:2`, and `5:3` ratios with sustained traffic, FIFO pointer wrap, independently skewed reset release, a reset with an outstanding read, no-ghost-response checking, and post-reset recovery.

## Outstanding Transactions

Read and write active-ID bitmaps permit four distinct IDs per initiator. The verification environment issues four reads and four writes from one initiator before retirement, checks duplicate-active-ID backpressure, and observes a later ID completing before an earlier asynchronous-target ID. Target IDs widen to `{initiator,id}` and are independently checked at request and response boundaries.
