# Coverage Closure

Measured regression-derived functional coverage is **56 / 56**; same-run event interaction coverage is **46 / 46**. These metrics are separate from Verilator code coverage.

| Area | Hit | Total |
| --- | ---: | ---: |
| `operation` | 2 | 2 |
| `initiator` | 4 | 4 |
| `target` | 4 | 4 |
| `burst` | 5 | 5 |
| `size` | 4 | 4 |
| `strobe` | 3 | 3 |
| `response` | 3 | 3 |
| `error` | 7 | 7 |
| `security` | 2 | 2 |
| `arbitration` | 6 | 6 |
| `routing_reset_cdc` | 7 | 7 |
| `backpressure` | 4 | 4 |
| `random` | 5 | 5 |

| Cross group | Hit | Total |
| --- | ---: | ---: |
| `initiator_x_target` | 16 | 16 |
| `operation_x_burst` | 8 | 8 |
| `operation_x_response` | 6 | 6 |
| `security_x_operation` | 4 | 4 |
| `cdc_x_operation` | 2 | 2 |
| `backpressure_x_operation` | 6 | 6 |
| `contention_x_policy` | 4 | 4 |

Coverage is generated from passing named scenarios, passing seeded runs, and normalized request/response traces. A bin is not credited merely because a test has a matching name.
