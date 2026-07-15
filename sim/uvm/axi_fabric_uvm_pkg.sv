`timescale 1ns/1ps
package axi_fabric_uvm_pkg;
  import uvm_pkg::*;
  import axi4_uvm_vip_pkg::*;
  `include "uvm_macros.svh"

  class axi_scoreboard extends uvm_subscriber#(axi4_vip_item);
    `uvm_component_utils(axi_scoreboard)
    bit read_pending[4][16]; bit write_pending[4][16]; bit[1:0] read_expected[4][16]; bit[1:0] write_expected[4][16];
    int read_expected_beats[4][16]; int read_seen_beats[4][16]; int response_order[4][16];
    int requests,responses,mismatches,response_serial,current_epoch;
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    function bit[1:0] expected(bit[31:0] addr,bit[2:0] prot);
      bit mapped=(addr[31:28] inside {[0:3]}) && addr[27:16]==0;
      if(!mapped || (addr[31:28]==2 && prot[1])) return 2'b11;
      if(addr[31:28]==2 && addr[15:12]==4'hf) return 2'b10;
      return 2'b00;
    endfunction
    function void write(axi4_vip_item t);
      if(t.epoch!=current_epoch) begin mismatches++; return; end
      case(t.event_kind)
        AXI4_EV_AW: begin write_pending[t.master][t.id]=1; write_expected[t.master][t.id]=expected(t.addr,t.prot); requests++; end
        AXI4_EV_AR: begin read_pending[t.master][t.id]=1; read_expected[t.master][t.id]=expected(t.addr,t.prot); read_expected_beats[t.master][t.id]=t.beats; read_seen_beats[t.master][t.id]=0; requests++; end
        AXI4_EV_B: begin
          responses++; response_order[t.master][t.id]=response_serial++; if(!write_pending[t.master][t.id] || t.resp!=write_expected[t.master][t.id]) mismatches++; write_pending[t.master][t.id]=0;
        end
        AXI4_EV_R: begin
          read_seen_beats[t.master][t.id]++;
          if(t.last != (read_seen_beats[t.master][t.id]==read_expected_beats[t.master][t.id])) mismatches++;
          if(t.last) begin responses++; response_order[t.master][t.id]=response_serial++; if(!read_pending[t.master][t.id] || t.resp!=read_expected[t.master][t.id]) mismatches++; read_pending[t.master][t.id]=0; end
        end
      endcase
    endfunction
    function void reset_epoch(int epoch);
      current_epoch=epoch; requests=0; responses=0; mismatches=0; response_serial=0;
      for(int m=0;m<4;m++) for(int id=0;id<16;id++) begin read_pending[m][id]=0; write_pending[m][id]=0; read_expected_beats[m][id]=0; read_seen_beats[m][id]=0; response_order[m][id]=-1; end
    endfunction
  endclass

  class fabric_virtual_sequencer extends uvm_sequencer;
    `uvm_component_utils(fabric_virtual_sequencer)
    axi4_master_sequencer master_sqr[4];
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
  endclass

  class fabric_env extends uvm_env;
    `uvm_component_utils(fabric_env)
    axi4_master_agent agents[4]; axi4_master_config agent_cfg[4];
    axi_scoreboard scoreboard; fabric_virtual_sequencer vseqr; virtual axi_master_if vif;
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(virtual axi_master_if)::get(this,"","vif",vif)) `uvm_fatal("CFG","missing env vif")
      scoreboard=axi_scoreboard::type_id::create("scoreboard",this);
      vseqr=fabric_virtual_sequencer::type_id::create("vseqr",this);
      for(int m=0;m<4;m++) begin
        agent_cfg[m]=axi4_master_config::type_id::create($sformatf("agent_cfg%0d",m));
        agent_cfg[m].vif=vif; agent_cfg[m].master_index=m;
        uvm_config_db#(axi4_master_config)::set(this,$sformatf("agent%0d",m),"cfg",agent_cfg[m]);
        agents[m]=axi4_master_agent::type_id::create($sformatf("agent%0d",m),this);
      end
    endfunction
    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      for(int m=0;m<4;m++) begin agents[m].monitor.ap.connect(scoreboard.analysis_export); vseqr.master_sqr[m]=agents[m].sequencer; end
    endfunction
  endclass

  class directed_sequence extends uvm_sequence#(axi4_vip_item);
    `uvm_object_utils(directed_sequence)
    bit write; bit[3:0] id; bit[31:0] addr; int beats=1; bit[3:0] qos; bit[2:0] prot; bit[63:0] data;
    function new(string name="directed_sequence"); super.new(name); endfunction
    task body();
      axi4_vip_item item=axi4_vip_item::type_id::create("item"); start_item(item);
      item.write=write; item.id=id; item.addr=addr; item.beats=beats; item.qos=qos; item.prot=prot; item.data=data;
      finish_item(item);
    endtask
  endclass

  class fabric_virtual_sequence extends uvm_sequence;
    `uvm_object_utils(fabric_virtual_sequence)
    fabric_virtual_sequencer vseqr;
    function new(string name="fabric_virtual_sequence"); super.new(name); endfunction
    task start_one(int master,bit write,bit[3:0] id,bit[31:0] addr,int beats,bit[3:0] qos,bit[2:0] prot,bit[63:0] data);
      directed_sequence seq=directed_sequence::type_id::create($sformatf("m%0d_id%0d_seq",master,id));
      seq.write=write; seq.id=id; seq.addr=addr; seq.beats=beats; seq.qos=qos; seq.prot=prot; seq.data=data;
      seq.start(vseqr.master_sqr[master]);
    endtask
  endclass

  class multi_id_virtual_sequence extends fabric_virtual_sequence;
    `uvm_object_utils(multi_id_virtual_sequence)
    function new(string name="multi_id_virtual_sequence"); super.new(name); endfunction
    task body(); for(int id=1;id<=4;id++) start_one(0,0,4'(id),32'h1000_c000+32'(id*32),1,4'(id),0,0); endtask
  endclass

  class four_master_virtual_sequence extends fabric_virtual_sequence;
    `uvm_object_utils(four_master_virtual_sequence)
    function new(string name="four_master_virtual_sequence"); super.new(name); endfunction
    task body();
      fork
        start_one(0,0,1,32'h1000_d000,1,4,0,0);
        start_one(1,0,2,32'h1000_d020,1,4,0,0);
        start_one(2,0,3,32'h1000_d040,1,4,0,0);
        start_one(3,0,4,32'h1000_d060,1,4,0,0);
      join
    endtask
  endclass

  class starvation_virtual_sequence extends fabric_virtual_sequence;
    `uvm_object_utils(starvation_virtual_sequence)
    function new(string name="starvation_virtual_sequence"); super.new(name); endfunction
    task high_stream(int master,bit[31:0] base);
      for(int n=0;n<40;n++) start_one(master,0,4'(n+2),base+32'(n*8),1,15,0,0);
    endtask
    task body();
      fork
        start_one(0,0,1,32'h1000_e000,1,0,0,0);
        high_stream(1,32'h1000_e100);
        high_stream(2,32'h1000_e500);
        high_stream(3,32'h1000_e900);
      join
    endtask
  endclass

  class fabric_base_test extends uvm_test;
    `uvm_component_utils(fabric_base_test)
    fabric_env env; virtual axi_master_if vif;
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase); super.build_phase(phase);
      if(!uvm_config_db#(virtual axi_master_if)::get(this,"","vif",vif)) `uvm_fatal("CFG","missing test vif")
      env=fabric_env::type_id::create("env",this);
    endfunction
    task reset_dut();
      `uvm_info("TEST","asserting reset",UVM_LOW)
      vif.awvalid='0; vif.wvalid='0; vif.bready='1;
      vif.arvalid='0; vif.rready='1;
      vif.awid='0; vif.awaddr='0; vif.awlen='0;
      vif.awsize={4{3'd3}}; vif.awburst={4{2'b01}}; vif.awprot='0; vif.awqos='0;
      vif.wdata='0; vif.wstrb='1; vif.wlast='0;
      vif.arid='0; vif.araddr='0; vif.arlen='0;
      vif.arsize={4{3'd3}}; vif.arburst={4{2'b01}}; vif.arprot='0; vif.arqos='0;
      vif.rst_n=0; repeat(6) @(posedge vif.clk);
      vif.reset_epoch++; env.scoreboard.reset_epoch(vif.reset_epoch);
      vif.rst_n=1; repeat(3) @(posedge vif.clk);
      `uvm_info("TEST","reset complete",UVM_LOW)
    endtask
    task run_one(int master,bit write,bit[3:0] id,bit[31:0] addr,int beats,bit[3:0] qos,bit[2:0] prot,bit[63:0] data);
      directed_sequence seq=directed_sequence::type_id::create("seq");
      seq.write=write; seq.id=id; seq.addr=addr; seq.beats=beats; seq.qos=qos; seq.prot=prot; seq.data=data;
      seq.start(env.agents[master].sequencer);
    endtask
    function void check_scoreboard(); if(env.scoreboard.mismatches) `uvm_error("SCOREBOARD",$sformatf("mismatches=%0d",env.scoreboard.mismatches)) endfunction
    task wait_responses(int expected);
      int timeout=0;
      while(env.scoreboard.responses<expected && timeout<2000) begin @(posedge vif.clk); timeout++; end
      if(timeout>=2000) `uvm_error("SCOREBOARD",$sformatf("response timeout expected=%0d actual=%0d",expected,env.scoreboard.responses))
    endtask
    function void report_phase(uvm_phase phase);
      super.report_phase(phase);
      `uvm_info("SCOREBOARD_ACTIVITY",$sformatf("requests=%0d responses=%0d mismatches=%0d",
        env.scoreboard.requests,env.scoreboard.responses,env.scoreboard.mismatches),UVM_LOW)
    endfunction
  endclass

  class uvm_single_route_test extends fabric_base_test;
    `uvm_component_utils(uvm_single_route_test)
    function new(string n,uvm_component p); super.new(n,p); endfunction
    task run_phase(uvm_phase phase); phase.raise_objection(this); reset_dut(); run_one(0,1,1,32'h40,4,0,0,64'h1234); run_one(0,0,2,32'h40,4,0,0,0); wait_responses(2); check_scoreboard(); phase.drop_objection(this); endtask
  endclass
  class uvm_qos_contention_test extends fabric_base_test;
    `uvm_component_utils(uvm_qos_contention_test)
    function new(string n,uvm_component p); super.new(n,p); endfunction
    task run_phase(uvm_phase phase); phase.raise_objection(this); reset_dut();
      fork run_one(0,0,3,32'h10000100,1,1,0,0); run_one(1,0,4,32'h10000180,1,15,0,0); join
      wait_responses(2); if(vif.first_target1_master!=1) `uvm_error("QOS","high-QoS master did not win first") check_scoreboard(); phase.drop_objection(this);
    endtask
  endclass
  class uvm_error_security_test extends fabric_base_test;
    `uvm_component_utils(uvm_error_security_test)
    function new(string n,uvm_component p); super.new(n,p); endfunction
    task run_phase(uvm_phase phase); phase.raise_objection(this); reset_dut(); run_one(2,0,5,32'hF0000000,1,0,0,0); run_one(2,0,6,32'h20000000,1,0,3'b010,0); wait_responses(2); check_scoreboard(); phase.drop_objection(this); endtask
  endclass
  class uvm_multi_outstanding_test extends fabric_base_test;
    `uvm_component_utils(uvm_multi_outstanding_test)
    function new(string n,uvm_component p); super.new(n,p); endfunction
    task run_phase(uvm_phase phase); phase.raise_objection(this); reset_dut();
      run_one(0,0,1,32'h30000200,2,1,0,0);
      run_one(0,0,2,32'h00000200,2,1,0,0);
      run_one(0,0,3,32'h10000200,2,1,0,0);
      run_one(0,0,4,32'h20000200,2,1,0,0);
      wait_responses(4);
      if(env.scoreboard.requests!=4) `uvm_error("OUTSTANDING","expected four accepted requests")
      check_scoreboard(); phase.drop_objection(this);
    endtask
  endclass

  class uvm_multi_id_reorder_test extends fabric_base_test;
    `uvm_component_utils(uvm_multi_id_reorder_test)
    function new(string n,uvm_component p); super.new(n,p); endfunction
    task run_phase(uvm_phase phase);
      multi_id_virtual_sequence seq=multi_id_virtual_sequence::type_id::create("seq");
      phase.raise_objection(this); reset_dut(); seq.vseqr=env.vseqr; seq.start(null); wait_responses(4);
      if(env.scoreboard.response_order[0][2] > env.scoreboard.response_order[0][1]) `uvm_error("REORDER","target did not reorder distinct IDs")
      check_scoreboard(); phase.drop_objection(this);
    endtask
  endclass

  class uvm_four_master_contention_test extends fabric_base_test;
    `uvm_component_utils(uvm_four_master_contention_test)
    function new(string n,uvm_component p); super.new(n,p); endfunction
    task run_phase(uvm_phase phase);
      four_master_virtual_sequence seq=four_master_virtual_sequence::type_id::create("seq");
      phase.raise_objection(this); reset_dut(); seq.vseqr=env.vseqr; seq.start(null); wait_responses(4);
      if(env.scoreboard.requests!=4) `uvm_error("CONTENTION","expected four accepted requests")
      check_scoreboard(); phase.drop_objection(this);
    endtask
  endclass

  class uvm_qos_starvation_override_test extends fabric_base_test;
    `uvm_component_utils(uvm_qos_starvation_override_test)
    function new(string n,uvm_component p); super.new(n,p); endfunction
    task run_phase(uvm_phase phase);
      starvation_virtual_sequence seq=starvation_virtual_sequence::type_id::create("seq");
      phase.raise_objection(this); reset_dut(); seq.vseqr=env.vseqr; seq.start(null);
      wait_responses(env.scoreboard.requests); if(!vif.age_override_seen) `uvm_error("STARVATION","aging override was not observed")
      check_scoreboard(); phase.drop_objection(this);
    endtask
  endclass

  class uvm_reset_with_outstanding_test extends fabric_base_test;
    `uvm_component_utils(uvm_reset_with_outstanding_test)
    function new(string n,uvm_component p); super.new(n,p); endfunction
    task run_phase(uvm_phase phase);
      phase.raise_objection(this); reset_dut(); run_one(0,0,1,32'h1000_f000,4,1,0,0);
      repeat(3) @(posedge vif.clk); reset_dut(); run_one(0,0,2,32'h1000_f100,1,1,0,0);
      wait_responses(1); if(env.scoreboard.requests!=1) `uvm_error("RESET","post-reset request count mismatch")
      check_scoreboard(); phase.drop_objection(this);
    endtask
  endclass
endpackage
