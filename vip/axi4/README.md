# Reusable AXI4 UVM Agent Collateral

This package extracts the protocol-facing UVM components used by the QoS fabric regression. It demonstrates reusable master and reactive-target agent structure for the project’s documented AXI4 subset; it is not commercial VIP or AXI compliance collateral.

## Supported Transaction Contract

- 32-bit address, 64-bit data, and 4-bit initiator ID.
- Read and write requests with `INCR` bursts of 1-16 beats.
- Transfer sizes of 1, 2, 4, or 8 bytes.
- Legal byte strobes for writes.
- Multiple distinct outstanding IDs and legal completion reordering across IDs.
- Contiguous read beats; read-data interleaving is not supported.

`FIXED`, `WRAP`, exclusive, atomic, coherent, and full protocol-compliance behavior are outside this package.

## Components

`axi4_uvm_vip_pkg.sv` provides the transaction object, per-agent configuration, active master sequencer/driver/monitor/agent, and configurable reactive target behavior. Fabric-specific virtual sequences, QoS checking, ownership scoreboarding, and cross coverage remain above this reusable layer in `sim/uvm/axi_fabric_uvm_pkg.sv`.

Each agent receives its virtual interface and policy through `uvm_config_db`; no package-global four-master signal state is required. Target policy controls latency, backpressure, response ordering, errors, and outstanding limits within the supported subset.

## Configuration Pattern

```systemverilog
axi4_master_config cfg = axi4_master_config::type_id::create("cfg");
cfg.vif = master_vif;
cfg.master_index = 0;
cfg.active = 1'b1;
cfg.max_outstanding = 4;
uvm_config_db#(axi4_master_config)::set(this, "env.master", "cfg", cfg);
```

The exact fields in the checked-in package remain authoritative. Fabric tests create one configuration per agent so interfaces and target policies can differ independently.

## Sequence Pattern

```systemverilog
axi4_vip_item item = axi4_vip_item::type_id::create("item");
start_item(item);
item.write = 1'b0;
item.id = 4'h3;
item.addr = 32'h1000_0040;
item.beats = 4;
finish_item(item);
```

Monitors publish normalized AW, AR, B, and R events through analysis ports. The standalone self-test connects those events to an independent subscriber and requires matching request/response counts with zero UVM errors or mismatches.

## Running the Self-Test

```bash
export VERILATOR_UVM=/path/to/verilator-v5.048/bin/verilator
export UVM_HOME=/path/to/uvm-verilator/src
make vip-selftest
```

The canonical result is `reports/vip_selftest_summary.csv`. `make uvm-regress` separately verifies the extracted agents inside the full four-initiator/four-target fabric environment.

## Limitations

- The package implements the project subset, not every AXI4 option.
- It is validated with the pinned open-source Verilator/UVM environment and is not simulator-portability signoff.
- It does not provide protocol compliance certification, coverage models for unsupported AXI features, or commercial VIP support guarantees.
- Fabric-specific QoS, aging, security, CDC, and routing policy remain outside the generic agent layer.
