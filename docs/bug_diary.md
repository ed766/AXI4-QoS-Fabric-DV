# Bug Diary

## Target Payload Changed Under Backpressure

**Scenario:** a continuously eligible low-QoS read competed with a stream of high-QoS reads while the target periodically deasserted `ARREADY`.

**Symptom:** `a_m_ar_stable` failed because the selected target-side AR payload changed while `ARVALID && !ARREADY`.

**Root cause:** arbitration was recomputed combinationally every cycle. A newly arriving higher-QoS request could replace an already presented grant before the target handshake.

**Fix:** `qos_arbiter` now captures and holds the selected requester and age-override state until `accept`. QoS and round-robin selection resume only after the held transfer handshakes.

**Regression evidence:** `starvation_override` now observes the aging override, the stability assertion remains clean, `30 / 30` named tests pass, and the mutation suite remains `6 / 6` detected.

## Random Stream Re-Seeded Every Operation

**Symptom:** event-derived coverage showed some seeded runs contained only reads despite a mixed read percentage.

**Root cause:** `$urandom(seed)` reinitialized the generator on every loop iteration.

**Fix:** the generator is seeded once and subsequent operations use `$urandom()`. The regenerated corpus contains observed read, write, error, security, and QoS mixes and remains reproducible by manifest seed.

## Queued AW Ownership Broke Under Multiple Outstanding Writes

**Scenario:** the target model was upgraded from one active transaction to queued requests with legal completion reordering across distinct IDs.

**Symptom:** when more than one AW was accepted for the same target, W data could be selected by master scan order rather than the target's AW acceptance order. That could associate a legal W burst with the wrong widened ID.

**Checker evidence:** the normalized target-beat trace and SystemC ownership replay disagreed, while the new AW-order assertion queue localized the problem to target W ownership rather than response routing.

**Root cause:** the original fabric retained per-initiator AW route FIFOs but had no target-side FIFO recording the sequence of accepted AW owners. That was sufficient only while the target model accepted one write at a time.

**Fix:** a target-side AW ownership FIFO now drives W arbitration. Ownership remains burst-locked through the matching `WLAST`, and the assertion checker tracks accepted AW lengths in the same target order.

**Regression evidence:** queued write traffic, simultaneous read/write response traffic, W-before-AW blocking, `130 / 130` SystemC replays, and `6 / 6` mutations pass.

## Out-of-Order Response Case Study

![Out-of-order AXI response waveform](images/out_of_order_response_waveform.svg)

The `same_target_reorder` trace accepts read IDs `1,2,3,4` and legally completes them as `2,4,3,1`. The target model does not interleave beats within a burst, the widened ID preserves initiator ownership, and the UVM/SystemC scoreboards match responses by reset epoch, master, target, ID, and beat. Illegal early/late `RLAST`, unknown ID, duplicate B, and malformed BID are separate expected-fail tests; they are not presented as protocol-legal reordering.
