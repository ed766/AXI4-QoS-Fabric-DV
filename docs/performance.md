# QoS and Contention Performance

Behavioral Verilator measurements across identical named workloads. Values are verification/performance proxies, not silicon timing.

| Workload | Mean latency at 0% | Mean latency at 75% | Added latency | Aging overrides |
| --- | ---: | ---: | ---: | ---: |
| `target_matrix` | 4.38 | 9.00 | 4.62 | 0 |
| `contention_four` | 4.00 | 4.00 | 0.00 | 0 |
| `equal_qos_rr` | 1.00 | 1.00 | 0.00 | 0 |
| `qos_priority` | 4.19 | 7.19 | 3.00 | 0 |
| `starvation_override` | 1.00 | 1.00 | 0.00 | 1 |
| `outstanding_ids` | 10.00 | 17.12 | 7.12 | 0 |

The CSV additionally reports per-master p50/p95/max latency, arbitration wait, accepted throughput, and service share for 0/25/50/75% backpressure. Equal-QoS, mixed-QoS, aging override, multi-outstanding, and asynchronous-target traffic are measured separately.
