# Code Coverage

Verilator line coverage is reported separately from functional and interaction coverage. Raw design RTL coverage is **85.88%**; reviewed executable RTL coverage is **93.25%**. Raw branch coverage is **95.19%** and raw toggle coverage is **68.84%**. The raw values are always retained.

| RTL file | Covered | Total | Raw line coverage |
| --- | ---: | ---: | ---: |
| `rtl/async_fifo_gray.sv` | 41 | 42 | 97.62% |
| `rtl/axi4_async_bridge.sv` | 42 | 62 | 67.74% |
| `rtl/axi4_qos_fabric.sv` | 288 | 327 | 88.07% |
| `rtl/qos_arbiter.sv` | 61 | 72 | 84.72% |

Reviewed exclusions: **177** instrumentation points. Every point is listed in `reports/code_coverage_exclusions.csv` with a source classification or independent execution evidence. No reachable error path, state transition, or functional behavior is excluded solely to improve the metric.
