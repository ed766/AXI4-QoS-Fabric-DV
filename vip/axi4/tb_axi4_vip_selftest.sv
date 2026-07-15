`timescale 1ns/1ps
package axi4_vip_selftest_pkg;
  import uvm_pkg::*;
  import axi4_uvm_vip_pkg::*;
  `include "uvm_macros.svh"

  class axi4_vip_selftest_sequence extends uvm_sequence#(axi4_vip_item);
    `uvm_object_utils(axi4_vip_selftest_sequence)
    bit write; bit[3:0] id; bit[31:0] addr; int unsigned beats; bit[63:0] data;
    function new(string name="axi4_vip_selftest_sequence"); super.new(name); endfunction
    task body();
      axi4_vip_item item=axi4_vip_item::type_id::create("item");
      start_item(item); item.write=write; item.id=id; item.addr=addr;
      item.beats=beats; item.data=data; item.qos=4; item.prot=0; finish_item(item);
    endtask
  endclass

  class axi4_vip_event_checker extends uvm_subscriber#(axi4_vip_item);
    `uvm_component_utils(axi4_vip_event_checker)
    int requests,responses,mismatches;
    bit read_pending[16],write_pending[16];
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    function void write(axi4_vip_item item);
      case(item.event_kind)
        AXI4_EV_AW: begin requests++; write_pending[item.id]=1; end
        AXI4_EV_AR: begin requests++; read_pending[item.id]=1; end
        AXI4_EV_B: begin responses++; if(!write_pending[item.id]) mismatches++; write_pending[item.id]=0; end
        AXI4_EV_R: if(item.last) begin responses++; if(!read_pending[item.id]) mismatches++; read_pending[item.id]=0; end
      endcase
    endfunction
  endclass

  class axi4_vip_selftest extends uvm_test;
    `uvm_component_utils(axi4_vip_selftest)
    virtual axi_master_if vif;
    axi4_master_config master_cfg;
    axi4_target_config target_cfg;
    axi4_master_agent master;
    axi4_reactive_target_agent target;
    axi4_vip_event_checker event_sink;
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual axi_master_if)::get(this,"","vif",vif)) `uvm_fatal("CFG","missing vif")
      master_cfg=axi4_master_config::type_id::create("master_cfg");
      master_cfg.vif=vif; master_cfg.master_index=0;
      target_cfg=axi4_target_config::type_id::create("target_cfg");
      target_cfg.vif=vif; target_cfg.master_index=0; target_cfg.response_delay=2;
      target_cfg.backpressure_percent=25;
      uvm_config_db#(axi4_master_config)::set(this,"master","cfg",master_cfg);
      uvm_config_db#(axi4_target_config)::set(this,"target","cfg",target_cfg);
      master=axi4_master_agent::type_id::create("master",this);
      target=axi4_reactive_target_agent::type_id::create("target",this);
      event_sink=axi4_vip_event_checker::type_id::create("event_sink",this);
    endfunction
    function void connect_phase(uvm_phase phase); master.monitor.ap.connect(event_sink.analysis_export); endfunction
    task run_phase(uvm_phase phase);
      axi4_vip_selftest_sequence seq;
      phase.raise_objection(this);
      wait(vif.rst_n); repeat(2) @(posedge vif.clk);
      seq=axi4_vip_selftest_sequence::type_id::create("read_seq");
      seq.write=0; seq.id=1; seq.addr=32'h100; seq.beats=2; seq.start(master.sequencer);
      repeat(10) @(posedge vif.clk);
      seq=axi4_vip_selftest_sequence::type_id::create("write_seq");
      seq.write=1; seq.id=2; seq.addr=32'h200; seq.beats=2; seq.data=64'h1234_5678_9abc_def0;
      seq.start(master.sequencer);
      repeat(20) @(posedge vif.clk);
      if(event_sink.requests!=2 || event_sink.responses!=2 || event_sink.mismatches!=0)
        `uvm_error("VIP_SELFTEST",$sformatf("requests=%0d responses=%0d mismatches=%0d",event_sink.requests,event_sink.responses,event_sink.mismatches))
      `uvm_info("VIP_SELFTEST",$sformatf("requests=%0d responses=%0d mismatches=%0d",event_sink.requests,event_sink.responses,event_sink.mismatches),UVM_NONE)
      phase.drop_objection(this);
    endtask
  endclass
endpackage

module tb_axi4_vip_selftest;
  import uvm_pkg::*;
  import axi4_vip_selftest_pkg::*;
  logic clk=0; always #5 clk=~clk;
  axi_master_if vif(clk);
  initial begin
    vif.rst_n=0; vif.reset_epoch=0;
    vif.awvalid=0; vif.wvalid=0; vif.bready=1; vif.arvalid=0; vif.rready=1;
    vif.awid=0; vif.awaddr=0; vif.awlen=0; vif.awsize=3; vif.awburst=1; vif.awprot=0; vif.awqos=0;
    vif.wdata=0; vif.wstrb='1; vif.wlast=0;
    vif.arid=0; vif.araddr=0; vif.arlen=0; vif.arsize=3; vif.arburst=1; vif.arprot=0; vif.arqos=0;
    uvm_config_db#(virtual axi_master_if)::set(null,"uvm_test_top","vif",vif);
    run_test("axi4_vip_selftest");
  end
  initial begin repeat(5) @(posedge clk); vif.reset_epoch=1; vif.rst_n=1; end
  initial begin repeat(1000) @(posedge clk); `uvm_fatal("TIMEOUT","VIP self-test timeout") end
endmodule
