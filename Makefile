PYTHON ?= python3
VERILATOR ?= verilator
VERILATOR_UVM ?= verilator
UVM_HOME ?= $(HOME)/uvm-verilator/src
BUILD := build
REPORTS := reports
RTL := rtl/qos_arbiter.sv rtl/async_fifo_gray.sv rtl/axi4_async_bridge.sv rtl/axi4_qos_fabric.sv
SIM := sim/axi_memory_model.sv sim/assertions/axi4_fabric_assertions.sv sim/tb_axi4_qos_fabric.sv

.PHONY: lint smoke regress model-test model-check model-replay uvm-check-env uvm-smoke uvm-regress formal-env \
        random-manifest random-stress functional-coverage code-coverage formal-prove mutation-check \
        async-cdc-check performance-sweep synth-check equivalence-check gate-level-smoke \
        project-check release-check reports clean

lint:
	$(VERILATOR) --lint-only --sv --top-module axi4_qos_fabric -Wall rtl/qos_arbiter.sv rtl/axi4_qos_fabric.sv
	$(VERILATOR) --lint-only --sv --top-module axi4_async_bridge -Wall rtl/async_fifo_gray.sv rtl/axi4_async_bridge.sv

$(BUILD)/smoke/Vtb_axi4_qos_fabric: $(RTL) $(SIM)
	mkdir -p $(BUILD)/smoke $(BUILD)/traces
	$(VERILATOR) --binary --sv --timing --assert -Wno-fatal --top-module tb_axi4_qos_fabric \
		-Mdir $(BUILD)/smoke $(RTL) $(SIM)

smoke: $(BUILD)/smoke/Vtb_axi4_qos_fabric
	$(BUILD)/smoke/Vtb_axi4_qos_fabric +TRACE_FILE=$(BUILD)/traces/smoke.jsonl | tee $(BUILD)/smoke.log

regress: $(BUILD)/smoke/Vtb_axi4_qos_fabric
	$(PYTHON) scripts/run_regression.py --binary $(BUILD)/smoke/Vtb_axi4_qos_fabric --named

$(BUILD)/model/model_selftest: model/fabric_tlm_model.cpp model/model_selftest.cpp model/fabric_tlm_model.h
	mkdir -p $(BUILD)/model
	g++ -std=c++17 -Wall -Wextra -Werror $$(pkg-config --cflags systemc) -Imodel \
		model/fabric_tlm_model.cpp model/model_selftest.cpp $$(pkg-config --libs systemc) -o $@

$(BUILD)/model/trace_checker: model/fabric_tlm_model.cpp model/trace_checker.cpp model/fabric_tlm_model.h
	mkdir -p $(BUILD)/model
	g++ -std=c++17 -Wall -Wextra -Werror $$(pkg-config --cflags systemc) -Imodel \
		model/fabric_tlm_model.cpp model/trace_checker.cpp $$(pkg-config --libs systemc) -o $@

model-test: $(BUILD)/model/model_selftest
	$< | tee $(BUILD)/model_selftest.log

model-check: smoke $(BUILD)/model/trace_checker
	$(BUILD)/model/trace_checker $(BUILD)/traces/smoke.jsonl | tee $(BUILD)/trace_check.log

model-replay: regress random-stress $(BUILD)/model/trace_checker
	$(PYTHON) scripts/run_model_replay.py

uvm-check-env:
	@test -x "$(VERILATOR_UVM)" || (echo "Missing VERILATOR_UVM=$(VERILATOR_UVM)"; exit 1)
	@test -f "$(UVM_HOME)/uvm_pkg.sv" || (echo "Missing UVM_HOME/uvm_pkg.sv"; exit 1)
	@$(VERILATOR_UVM) --version | head -1

uvm-smoke: uvm-check-env
	$(PYTHON) scripts/run_uvm.py --tests uvm_single_route_test,uvm_qos_contention_test,uvm_error_security_test,uvm_multi_outstanding_test

uvm-regress: uvm-smoke

random-manifest:
	$(PYTHON) scripts/gen_random_manifest.py --count 100

random-stress: random-manifest $(BUILD)/smoke/Vtb_axi4_qos_fabric
	$(PYTHON) scripts/run_regression.py --binary $(BUILD)/smoke/Vtb_axi4_qos_fabric --random

functional-coverage: regress random-stress formal-prove
	$(PYTHON) scripts/gen_coverage.py

code-coverage:
	$(PYTHON) scripts/run_code_coverage.py

async-cdc-check: smoke
	$(PYTHON) scripts/run_cdc_matrix.py

performance-sweep: smoke
	$(PYTHON) scripts/gen_performance.py

synth-check:
	$(PYTHON) scripts/run_synthesis.py

equivalence-check:
	$(PYTHON) scripts/run_equivalence.py

gate-level-smoke: synth-check
	$(PYTHON) scripts/run_gate_smoke.py

formal-env:
	$(PYTHON) scripts/ensure_formal_env.py

formal-prove: formal-env
	$(PYTHON) scripts/run_formal.py

mutation-check:
	$(PYTHON) scripts/run_mutations.py

reports: functional-coverage performance-sweep
	$(PYTHON) scripts/gen_reports.py metrics

project-check: lint model-test model-check uvm-smoke functional-coverage async-cdc-check performance-sweep reports

release-check: project-check model-replay code-coverage mutation-check synth-check equivalence-check gate-level-smoke
	$(PYTHON) scripts/check_release_status.py
	$(PYTHON) scripts/gen_reports.py metrics

clean:
	rm -rf $(BUILD)
