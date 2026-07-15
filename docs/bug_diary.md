# Bug Diary

## Target Payload Changed Under Backpressure

**Scenario:** a continuously eligible low-QoS read competed with a stream of high-QoS reads while the target periodically deasserted `ARREADY`.

**Symptom:** `a_m_ar_stable` failed because the selected target-side AR payload changed while `ARVALID && !ARREADY`.

**Root cause:** arbitration was recomputed combinationally every cycle. A newly arriving higher-QoS request could replace an already presented grant before the target handshake.

**Fix:** `qos_arbiter` now captures and holds the selected requester and age-override state until `accept`. QoS and round-robin selection resume only after the held transfer handshakes.

**Regression evidence:** `starvation_override` now observes the aging override, the stability assertion remains clean, `25 / 25` named tests pass, and the mutation suite remains `6 / 6` detected.

## Random Stream Re-Seeded Every Operation

**Symptom:** event-derived coverage showed some seeded runs contained only reads despite a mixed read percentage.

**Root cause:** `$urandom(seed)` reinitialized the generator on every loop iteration.

**Fix:** the generator is seeded once and subsequent operations use `$urandom()`. The regenerated corpus contains observed read, write, error, security, and QoS mixes and remains reproducible by manifest seed.
