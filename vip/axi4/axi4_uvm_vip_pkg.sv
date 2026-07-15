`timescale 1ns/1ps
package axi4_uvm_vip_pkg;
  import uvm_pkg::*;
  `include "uvm_macros.svh"

  typedef enum {AXI4_EV_AW, AXI4_EV_AR, AXI4_EV_B, AXI4_EV_R} axi4_vip_event_e;
  typedef enum {AXI4_RESP_IN_ORDER, AXI4_RESP_REVERSE, AXI4_RESP_FIXED_DELAY,
                AXI4_RESP_SEEDED_RANDOM} axi4_response_policy_e;

  class axi4_vip_item extends uvm_sequence_item;
    rand bit write;
    rand bit [3:0] id;
    rand bit [31:0] addr;
    rand int unsigned beats;
    rand bit [3:0] qos;
    rand bit [2:0] prot;
    rand bit [63:0] data;
    bit [1:0] resp;
    axi4_vip_event_e event_kind;
    int unsigned master;
    int unsigned target;
    int unsigned epoch;
    bit last;
    constraint c_beats { beats inside {[1:16]}; }
    `uvm_object_utils_begin(axi4_vip_item)
      `uvm_field_int(write,UVM_DEFAULT) `uvm_field_int(id,UVM_DEFAULT)
      `uvm_field_int(addr,UVM_HEX) `uvm_field_int(beats,UVM_DEFAULT)
      `uvm_field_int(qos,UVM_DEFAULT) `uvm_field_int(prot,UVM_DEFAULT)
      `uvm_field_int(data,UVM_HEX) `uvm_field_int(resp,UVM_DEFAULT)
      `uvm_field_int(master,UVM_DEFAULT) `uvm_field_int(target,UVM_DEFAULT)
      `uvm_field_int(epoch,UVM_DEFAULT) `uvm_field_int(last,UVM_DEFAULT)
    `uvm_object_utils_end
    function new(string name="axi4_vip_item"); super.new(name); endfunction
  endclass

  class axi4_master_config extends uvm_object;
    `uvm_object_utils(axi4_master_config)
    virtual axi_master_if vif;
    int unsigned master_index;
    int unsigned max_outstanding=4;
    bit active=1;
    function new(string name="axi4_master_config"); super.new(name); endfunction
  endclass

  class axi4_target_config extends uvm_object;
    `uvm_object_utils(axi4_target_config)
    virtual axi_master_if vif;
    int unsigned master_index;
    int unsigned max_outstanding=4;
    int unsigned response_delay;
    int unsigned backpressure_percent;
    int unsigned random_seed=32'h5eed_1234;
    bit [1:0] read_response=2'b00;
    bit [1:0] write_response=2'b00;
    axi4_response_policy_e response_policy=AXI4_RESP_IN_ORDER;
    function new(string name="axi4_target_config"); super.new(name); endfunction
  endclass

  class axi4_master_sequencer extends uvm_sequencer#(axi4_vip_item);
    `uvm_component_utils(axi4_master_sequencer)
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
  endclass

  class axi4_master_driver extends uvm_driver#(axi4_vip_item);
    `uvm_component_utils(axi4_master_driver)
    axi4_master_config cfg;
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(axi4_master_config)::get(this,"","cfg",cfg))
        `uvm_fatal("AXI4_VIP_CFG","missing master configuration")
    endfunction
    task run_phase(uvm_phase phase);
      forever begin
        seq_item_port.get_next_item(req);
        if(req.write) drive_write(req); else drive_read(req);
        seq_item_port.item_done();
      end
    endtask
    task drive_write(axi4_vip_item item);
      int unsigned m=cfg.master_index;
      @(negedge cfg.vif.clk);
      cfg.vif.awid[m]=item.id; cfg.vif.awaddr[m]=item.addr;
      cfg.vif.awlen[m]=8'(item.beats-1); cfg.vif.awsize[m]=3; cfg.vif.awburst[m]=1;
      cfg.vif.awprot[m]=item.prot; cfg.vif.awqos[m]=item.qos; cfg.vif.awvalid[m]=1;
      do @(posedge cfg.vif.clk); while(!cfg.vif.awready[m]);
      @(negedge cfg.vif.clk); cfg.vif.awvalid[m]=0;
      for(int b=0;b<item.beats;b++) begin
        cfg.vif.wdata[m]=item.data+64'(b); cfg.vif.wstrb[m]='1;
        cfg.vif.wlast[m]=(b==item.beats-1); cfg.vif.wvalid[m]=1;
        do @(posedge cfg.vif.clk); while(!cfg.vif.wready[m]);
        @(negedge cfg.vif.clk); cfg.vif.wvalid[m]=0;
      end
    endtask
    task drive_read(axi4_vip_item item);
      int unsigned m=cfg.master_index;
      @(negedge cfg.vif.clk);
      cfg.vif.arid[m]=item.id; cfg.vif.araddr[m]=item.addr;
      cfg.vif.arlen[m]=8'(item.beats-1); cfg.vif.arsize[m]=3; cfg.vif.arburst[m]=1;
      cfg.vif.arprot[m]=item.prot; cfg.vif.arqos[m]=item.qos; cfg.vif.arvalid[m]=1;
      do @(posedge cfg.vif.clk); while(!cfg.vif.arready[m]);
      @(negedge cfg.vif.clk); cfg.vif.arvalid[m]=0;
    endtask
  endclass

  class axi4_master_monitor extends uvm_monitor;
    `uvm_component_utils(axi4_master_monitor)
    axi4_master_config cfg;
    uvm_analysis_port#(axi4_vip_item) ap;
    function new(string name,uvm_component parent); super.new(name,parent); ap=new("ap",this); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(axi4_master_config)::get(this,"","cfg",cfg))
        `uvm_fatal("AXI4_VIP_CFG","missing monitor configuration")
    endfunction
    task run_phase(uvm_phase phase);
      int unsigned m=cfg.master_index;
      forever begin
        @(posedge cfg.vif.clk);
        if(cfg.vif.rst_n && cfg.vif.awvalid[m] && cfg.vif.awready[m])
          publish(AXI4_EV_AW,cfg.vif.awid[m],cfg.vif.awaddr[m],0,0,cfg.vif.awprot[m],cfg.vif.awlen[m]+1);
        if(cfg.vif.rst_n && cfg.vif.arvalid[m] && cfg.vif.arready[m])
          publish(AXI4_EV_AR,cfg.vif.arid[m],cfg.vif.araddr[m],0,0,cfg.vif.arprot[m],cfg.vif.arlen[m]+1);
        if(cfg.vif.rst_n && cfg.vif.bvalid[m] && cfg.vif.bready[m])
          publish(AXI4_EV_B,cfg.vif.bid[m],0,cfg.vif.bresp[m],1,0,0);
        if(cfg.vif.rst_n && cfg.vif.rvalid[m] && cfg.vif.rready[m])
          publish(AXI4_EV_R,cfg.vif.rid[m],0,cfg.vif.rresp[m],cfg.vif.rlast[m],0,0);
      end
    endtask
    function void publish(axi4_vip_event_e kind,bit[3:0] id,bit[31:0] addr,
                          bit[1:0] resp,bit last,bit[2:0] prot,int beats);
      axi4_vip_item item=axi4_vip_item::type_id::create("observed");
      item.event_kind=kind; item.master=cfg.master_index; item.id=id; item.addr=addr;
      item.resp=resp; item.last=last; item.prot=prot; item.beats=beats;
      item.target=addr[31:28]; item.epoch=cfg.vif.reset_epoch; ap.write(item);
    endfunction
  endclass

  class axi4_master_agent extends uvm_agent;
    `uvm_component_utils(axi4_master_agent)
    axi4_master_config cfg;
    axi4_master_sequencer sequencer;
    axi4_master_driver driver;
    axi4_master_monitor monitor;
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(axi4_master_config)::get(this,"","cfg",cfg))
        `uvm_fatal("AXI4_VIP_CFG","missing agent configuration")
      uvm_config_db#(axi4_master_config)::set(this,"*","cfg",cfg);
      sequencer=axi4_master_sequencer::type_id::create("sequencer",this);
      driver=axi4_master_driver::type_id::create("driver",this);
      monitor=axi4_master_monitor::type_id::create("monitor",this);
    endfunction
    function void connect_phase(uvm_phase phase);
      driver.seq_item_port.connect(sequencer.seq_item_export);
    endfunction
  endclass

  class axi4_reactive_target_agent extends uvm_component;
    `uvm_component_utils(axi4_reactive_target_agent)
    axi4_target_config cfg;
    axi4_vip_item read_q[$],write_q[$];
    int unsigned random_state;
    function new(string name,uvm_component parent); super.new(name,parent); endfunction
    function void build_phase(uvm_phase phase);
      super.build_phase(phase);
      if(!uvm_config_db#(axi4_target_config)::get(this,"","cfg",cfg))
        `uvm_fatal("AXI4_VIP_CFG","missing target configuration")
    endfunction
    task run_phase(uvm_phase phase);
      random_state=cfg.random_seed;
      fork
        collect_requests();
        serve_reads();
        serve_writes();
      join
    endtask
    task collect_requests();
      int unsigned m=cfg.master_index;
      int unsigned cycle=0;
      cfg.vif.awready[m]=0; cfg.vif.wready[m]=0; cfg.vif.arready[m]=0;
      cfg.vif.bvalid[m]=0; cfg.vif.rvalid[m]=0; cfg.vif.rlast[m]=0;
      wait(cfg.vif.rst_n);
      forever begin
        @(negedge cfg.vif.clk);
        cycle++;
        cfg.vif.awready[m]=((cycle%100)>=cfg.backpressure_percent) && write_q.size()<cfg.max_outstanding;
        cfg.vif.wready[m]=((cycle%100)>=cfg.backpressure_percent);
        cfg.vif.arready[m]=((cycle%100)>=cfg.backpressure_percent) && read_q.size()<cfg.max_outstanding;
        @(posedge cfg.vif.clk);
        if(cfg.vif.awvalid[m] && cfg.vif.awready[m]) begin
          axi4_vip_item req=axi4_vip_item::type_id::create("target_write_req");
          req.write=1; req.id=cfg.vif.awid[m]; req.addr=cfg.vif.awaddr[m];
          req.beats=cfg.vif.awlen[m]+1; req.last=0; write_q.push_back(req);
        end
        if(cfg.vif.wvalid[m] && cfg.vif.wready[m] && cfg.vif.wlast[m]) begin
          for(int index=0;index<write_q.size();index++) if(!write_q[index].last) begin
            write_q[index].last=1; break;
          end
        end
        if(cfg.vif.arvalid[m] && cfg.vif.arready[m]) begin
          axi4_vip_item req=axi4_vip_item::type_id::create("target_read_req");
          req.write=0; req.id=cfg.vif.arid[m]; req.addr=cfg.vif.araddr[m];
          req.beats=cfg.vif.arlen[m]+1; req.last=1; read_q.push_back(req);
        end
      end
    endtask
    function int choose_index(int size);
      if(cfg.response_policy==AXI4_RESP_REVERSE) return size-1;
      if(cfg.response_policy==AXI4_RESP_SEEDED_RANDOM) begin
        random_state=1664525*random_state+1013904223;
        return random_state%size;
      end
      return 0;
    endfunction
    task serve_writes();
      int unsigned m=cfg.master_index;
      int index;
      axi4_vip_item req;
      forever begin
        wait(write_q.size()>0 && write_q[0].last);
        @(negedge cfg.vif.clk);
        index=choose_index(write_q.size());
        while(!write_q[index].last) index=(index+1)%write_q.size();
        req=write_q[index]; write_q.delete(index);
        respond_write(m,req.id);
      end
    endtask
    task respond_write(int unsigned m,bit[3:0] id);
      repeat(cfg.response_delay) @(negedge cfg.vif.clk);
      cfg.vif.bid[m]=id; cfg.vif.bresp[m]=cfg.write_response; cfg.vif.bvalid[m]=1;
      do @(negedge cfg.vif.clk); while(!cfg.vif.bready[m]);
      cfg.vif.bvalid[m]=0;
    endtask
    task serve_reads();
      int unsigned m=cfg.master_index;
      int index;
      axi4_vip_item req;
      forever begin
        wait(read_q.size()>0); @(negedge cfg.vif.clk);
        index=choose_index(read_q.size());
        req=read_q[index]; read_q.delete(index);
        respond_read(m,req.id,req.addr,req.beats);
      end
    endtask
    task respond_read(int unsigned m,bit[3:0] id,bit[31:0] addr,int unsigned beats);
      repeat(cfg.response_delay) @(negedge cfg.vif.clk);
      for(int b=0;b<beats;b++) begin
        cfg.vif.rid[m]=id; cfg.vif.rdata[m]={32'hcafe_0000|addr[15:0],32'(b)};
        cfg.vif.rresp[m]=cfg.read_response; cfg.vif.rlast[m]=(b==beats-1); cfg.vif.rvalid[m]=1;
        do @(negedge cfg.vif.clk); while(!cfg.vif.rready[m]);
        cfg.vif.rvalid[m]=0;
      end
      cfg.vif.rlast[m]=0;
    endtask
  endclass
endpackage
