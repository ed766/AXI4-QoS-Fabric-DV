# QoS and Contention Performance

Behavioral Verilator measurements across identical named workloads. Values are verification/performance proxies, not silicon timing.

## Short-Scenario Diagnostics

| Workload | Accepted-to-response mean at 0% | Accepted-to-response mean at 75% | Delta | Aging overrides |
| --- | ---: | ---: | ---: | ---: |
| `target_matrix` | 4.38 | 9.00 | 4.62 | 0 |
| `contention_four` | 10.00 | 6.50 | -3.50 | 0 |
| `equal_qos_rr` | 2.50 | 1.00 | -1.50 | 0 |
| `qos_priority` | 4.25 | 7.19 | 2.94 | 0 |
| `starvation_override` | 15.25 | 1.00 | -14.25 | 1 |
| `outstanding_ids` | 10.00 | 17.12 | 7.12 | 0 |

These short tests diagnose paths rather than estimate sustained QoS. Target throttling can reduce accepted-to-response latency by reducing queued occupancy; sustained offered-throughput and fairness conclusions use the longer workload below. The CSV retains per-master p50/p95/max latency, arbitration wait, accepted throughput, and service share.

## Sustained Fairness Dashboard

![QoS fairness dashboard](images/qos_fairness_dashboard.svg)

| Policy | Backpressure | Aggregate completions/cycle | Mean offer-to-response | P95 | Jain fairness | Max service gap | Overrides |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `equal_qos` | 0% | 0.2520 | 20.95 | 23 | 0.99997 | 8 | 0 |
| `equal_qos` | 75% | 0.1262 | 15.62 | 19 | 0.99994 | 19 | 0 |
| `mixed_qos` | 0% | 0.3538 | 20.64 | 79 | 0.92751 | 64 | 3 |
| `mixed_qos` | 75% | 0.2493 | 16.28 | 129 | 0.77269 | 130 | 8 |
| `starvation_override` | 0% | 0.3111 | 19.43 | 79 | 0.98629 | 64 | 4 |
| `starvation_override` | 75% | 0.1565 | 15.89 | 127 | 0.98574 | 130 | 4 |

The sustained lane reports per-master offered/accepted throughput, p50/p95/max latency, service share, maximum service gap, aging overrides, and Jain's fairness index over per-master sustained completion rates. All values come from normalized Verilator request/grant/response traces.
