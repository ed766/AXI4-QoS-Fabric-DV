`timescale 1ns/1ps
package axi_fabric_uvm_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  typedef enum {EV_AW,EV_AR,EV_B,EV_R} event_kind_e;
  virtual axi_master_if g_master_vif;
  logic [3:0] g_awready,g_wready,g_bvalid,g_arready,g_rvalid,g_rlast;
  logic [3:0][3:0] g_bid,g_rid;
  logic [3:0][1:0] g_bresp,g_rresp;
  logic [3:0][63:0] g_rdata;
  int g_first_target1_master=-1;
  int g_reset_epoch=0;
  bit g_age_override_seen=0;

  class axi_item extends uvm_sequence_item;
    rand bit write;
    rand bit [3:0] id;
    rand bit [31:0] addr;
    rand int unsigned beats;
    rand bit [3:0] qos;
    rand bit [2:0] prot;
    rand bit [63:0] data;
    bit [1:0] resp;
    event_kind_e event_kind;
    int unsigned master;
    int unsigned target;
    int unsigned epoch;
    bit last;
    constraint c_beats { beats inside {[1:16]}; }
    `uvm_object_utils_begin(axi_item)
      `uvm_field_int(write,UVM_DEFAULT) `uvm_field_int(id,UVM_DEFAULT)
      `uvm_field_int(addr,UVM_HEX) `uvm_field_int(beats,UVM_DEFAULT)
      `uvm_field_int(qos,UVM_DEFAULT) `uvm_field_int(prot,UVM_DEFAULT)
      `uvm_field_int(data,UVM_HEX) `uvm_field_int(resp,UVM_DEFAULT)
      `uvm_field_int(target,UVM_DEFAULT) `uvm_field_int(epoch,UVM_DEFAULT)
    `uvm_object_utils_end
    function new(string name="axi_item"); super.new(name); endfunction
  endclass

  class axi_sequencer extends uvm_sequencer#(axi_item);
    `uvm_component_utils(axi_sequencer)
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
  endclass

  class axi_driver extends uvm_driver#(axi_item);
    `uvm_component_utils(axi_driver)
    virtual axi_master_if vif;
    int unsigned master;
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(int unsigned)::get(this,"","master",master)) `uvm_fatal("CFG","missing master index")
      vif=g_master_vif;
      if(vif==null) `uvm_fatal("CFG","missing master vif")
    endfunction
    task run_phase(uvm_phase phase);
      forever begin
        seq_item_port.get_next_item(req);
        `uvm_info("DRV",$sformatf("master=%0d got item write=%0d addr=%08x beats=%0d",master,req.write,req.addr,req.beats),UVM_LOW)
        if(req.write) drive_write(req); else drive_read(req);
        `uvm_info("DRV",$sformatf("master=%0d issued item id=%0d",master,req.id),UVM_LOW)
        seq_item_port.item_done();
      end
    endtask
    task drive_write(axi_item item);
      @(negedge vif.clk); vif.awid[master]=item.id; vif.awaddr[master]=item.addr;
      vif.awlen[master]=8'(item.beats-1); vif.awsize[master]=3; vif.awburst[master]=1;
      vif.awprot[master]=item.prot; vif.awqos[master]=item.qos; vif.awvalid[master]=1;
      do @(posedge vif.clk); while(!g_awready[master]); @(negedge vif.clk); vif.awvalid[master]=0;
      `uvm_info("DRV",$sformatf("master=%0d AW accepted",master),UVM_LOW)
      for(int b=0;b<item.beats;b++) begin
        vif.wdata[master]=item.data+64'(b); vif.wstrb[master]='1;
        vif.wlast[master]=(b==item.beats-1); vif.wvalid[master]=1;
        do @(posedge vif.clk); while(!g_wready[master]); @(negedge vif.clk); vif.wvalid[master]=0;
      end
      // B completion is collected independently by the monitor/scoreboard, allowing more AW IDs to issue.
    endtask
    task drive_read(axi_item item);
      @(negedge vif.clk); vif.arid[master]=item.id; vif.araddr[master]=item.addr;
      vif.arlen[master]=8'(item.beats-1); vif.arsize[master]=3; vif.arburst[master]=1;
      vif.arprot[master]=item.prot; vif.arqos[master]=item.qos; vif.arvalid[master]=1;
      do @(posedge vif.clk); while(!g_arready[master]); @(negedge vif.clk); vif.arvalid[master]=0;
      `uvm_info("DRV",$sformatf("master=%0d AR accepted",master),UVM_LOW)
      // R completion is collected independently by the monitor/scoreboard, allowing pipelined IDs.
    endtask
  endclass

  class axi_monitor extends uvm_monitor;
    `uvm_component_utils(axi_monitor)
    virtual axi_master_if vif; int unsigned master;
    uvm_analysis_port#(axi_item) ap;
    function new(string name,uvm_component parent); super.new(name,parent); ap=new("ap",this); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(int unsigned)::get(this,"","master",master)) `uvm_fatal("CFG","missing monitor master")
      vif=g_master_vif;
    endfunction
    task run_phase(uvm_phase phase);
      forever begin
        @(posedge vif.clk);
        if(vif.rst_n && vif.awvalid[master] && g_awready[master]) publish(EV_AW,vif.awid[master],vif.awaddr[master],0,0,vif.awprot[master],vif.awlen[master]+1);
        if(vif.rst_n && vif.arvalid[master] && g_arready[master]) publish(EV_AR,vif.arid[master],vif.araddr[master],0,0,vif.arprot[master],vif.arlen[master]+1);
        if(vif.rst_n && g_bvalid[master] && vif.bready[master]) publish(EV_B,g_bid[master],0,g_bresp[master],1,0,0);
        if(vif.rst_n && g_rvalid[master] && vif.rready[master]) publish(EV_R,g_rid[master],0,g_rresp[master],g_rlast[master],0,0);
      end
    endtask
    function void publish(event_kind_e kind,bit[3:0] id,bit[31:0] addr,bit[1:0] resp,bit last,bit[2:0] prot,int beats);
      axi_item item=axi_item::type_id::create("observed");
      item.event_kind=kind; item.master=master; item.id=id; item.addr=addr; item.resp=resp;
      item.last=last; item.prot=prot; item.beats=beats; item.target=addr[31:28]; item.epoch=g_reset_epoch; ap.write(item);
    endfunction
  endclass

  class axi_agent extends uvm_agent;
    `uvm_component_utils(axi_agent)
    axi_sequencer sequencer; axi_driver driver; axi_monitor monitor; int unsigned master;
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(int unsigned)::get(this,"","master",master)) master=0;
      uvm_config_db#(int unsigned)::set(this,"*","master",master);
      sequencer=axi_sequencer::type_id::create("sequencer",this);
      driver=axi_driver::type_id::create("driver",this);
      monitor=axi_monitor::type_id::create("monitor",this);
    endfunction
    function void connect_phase(uvm_phase phase); driver.seq_item_port.connect(sequencer.seq_item_export); endfunction
  endclass

  class axi_scoreboard extends uvm_subscriber#(axi_item);
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
    function void write(axi_item t);
      if(t.epoch!=current_epoch) begin mismatches++; return; end
      case(t.event_kind)
        EV_AW: begin write_pending[t.master][t.id]=1; write_expected[t.master][t.id]=expected(t.addr,t.prot); requests++; end
        EV_AR: begin read_pending[t.master][t.id]=1; read_expected[t.master][t.id]=expected(t.addr,t.prot); read_expected_beats[t.master][t.id]=t.beats; read_seen_beats[t.master][t.id]=0; requests++; end
        EV_B: begin
          responses++; response_order[t.master][t.id]=response_serial++; if(!write_pending[t.master][t.id] || t.resp!=write_expected[t.master][t.id]) mismatches++; write_pending[t.master][t.id]=0;
        end
        EV_R: begin
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
    axi_sequencer master_sqr[4];
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
  endclass

  class fabric_env extends uvm_env;
    `uvm_component_utils(fabric_env)
    axi_agent agents[4]; axi_scoreboard scoreboard; fabric_virtual_sequencer vseqr;
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      scoreboard=axi_scoreboard::type_id::create("scoreboard",this);
      vseqr=fabric_virtual_sequencer::type_id::create("vseqr",this);
      for(int m=0;m<4;m++) begin
        uvm_config_db#(int unsigned)::set(this,$sformatf("agent%0d",m),"master",m);
        agents[m]=axi_agent::type_id::create($sformatf("agent%0d",m),this);
      end
    endfunction
    function void connect_phase(uvm_phase phase);
      super.connect_phase(phase);
      for(int m=0;m<4;m++) begin agents[m].monitor.ap.connect(scoreboard.analysis_export); vseqr.master_sqr[m]=agents[m].sequencer; end
    endfunction
  endclass

  class directed_sequence extends uvm_sequence#(axi_item);
    `uvm_object_utils(directed_sequence)
    bit write; bit[3:0] id; bit[31:0] addr; int beats=1; bit[3:0] qos; bit[2:0] prot; bit[63:0] data;
    function new(string name="directed_sequence"); super.new(name); endfunction
    task body();
      axi_item item=axi_item::type_id::create("item"); start_item(item);
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
    fabric_env env;
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase); super.build_phase(phase); env=fabric_env::type_id::create("env",this); endfunction
    task reset_dut();
      `uvm_info("TEST","asserting reset",UVM_LOW)
      g_master_vif.awvalid='0; g_master_vif.wvalid='0; g_master_vif.bready='1;
      g_master_vif.arvalid='0; g_master_vif.rready='1;
      g_master_vif.awid='0; g_master_vif.awaddr='0; g_master_vif.awlen='0;
      g_master_vif.awsize={4{3'd3}}; g_master_vif.awburst={4{2'b01}}; g_master_vif.awprot='0; g_master_vif.awqos='0;
      g_master_vif.wdata='0; g_master_vif.wstrb='1; g_master_vif.wlast='0;
      g_master_vif.arid='0; g_master_vif.araddr='0; g_master_vif.arlen='0;
      g_master_vif.arsize={4{3'd3}}; g_master_vif.arburst={4{2'b01}}; g_master_vif.arprot='0; g_master_vif.arqos='0;
      g_master_vif.rst_n=0; repeat(6) @(posedge g_master_vif.clk);
      g_reset_epoch++; env.scoreboard.reset_epoch(g_reset_epoch);
      g_master_vif.rst_n=1; repeat(3) @(posedge g_master_vif.clk);
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
      while(env.scoreboard.responses<expected && timeout<2000) begin @(posedge g_master_vif.clk); timeout++; end
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
      wait_responses(2); if(g_first_target1_master!=1) `uvm_error("QOS","high-QoS master did not win first") check_scoreboard(); phase.drop_objection(this);
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
      wait_responses(env.scoreboard.requests); if(!g_age_override_seen) `uvm_error("STARVATION","aging override was not observed")
      check_scoreboard(); phase.drop_objection(this);
    endtask
  endclass

  class uvm_reset_with_outstanding_test extends fabric_base_test;
    `uvm_component_utils(uvm_reset_with_outstanding_test)
    function new(string n,uvm_component p); super.new(n,p); endfunction
    task run_phase(uvm_phase phase);
      phase.raise_objection(this); reset_dut(); run_one(0,0,1,32'h1000_f000,4,1,0,0);
      repeat(3) @(posedge g_master_vif.clk); reset_dut(); run_one(0,0,2,32'h1000_f100,1,1,0,0);
      wait_responses(1); if(env.scoreboard.requests!=1) `uvm_error("RESET","post-reset request count mismatch")
      check_scoreboard(); phase.drop_objection(this);
    endtask
  endclass
endpackage
