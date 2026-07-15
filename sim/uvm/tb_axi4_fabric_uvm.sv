`timescale 1ns/1ps
module tb_axi4_fabric_uvm;
  import uvm_pkg::*;
  import axi_fabric_uvm_pkg::*;
  localparam int NM=4,NS=4,AW=32,DW=64,IW=4,TIW=6;
  logic clk=0; always #5 clk=~clk;
  logic rst_n;
  axi_master_if #(.NUM_MASTERS(NM)) mif(clk);
  logic [NS-1:0] m_awvalid,m_awready,m_wvalid,m_wready,m_wlast,m_bvalid,m_bready;
  logic [NS-1:0][TIW-1:0] m_awid,m_bid; logic [NS-1:0][AW-1:0] m_awaddr;
  logic [NS-1:0][7:0] m_awlen; logic [NS-1:0][2:0] m_awsize,m_awprot;
  logic [NS-1:0][1:0] m_awburst,m_bresp; logic [NS-1:0][3:0] m_awqos;
  logic [NS-1:0][DW-1:0] m_wdata; logic [NS-1:0][DW/8-1:0] m_wstrb;
  logic [NS-1:0] m_arvalid,m_arready,m_rvalid,m_rready,m_rlast;
  logic [NS-1:0][TIW-1:0] m_arid,m_rid; logic [NS-1:0][AW-1:0] m_araddr;
  logic [NS-1:0][7:0] m_arlen; logic [NS-1:0][2:0] m_arsize,m_arprot;
  logic [NS-1:0][1:0] m_arburst,m_rresp; logic [NS-1:0][3:0] m_arqos; logic [NS-1:0][DW-1:0] m_rdata;
  logic [NS-1:0] mon_ar_age_override,mon_aw_age_override;

  assign rst_n=mif.rst_n;
  axi4_qos_fabric #(.SECURE_ONLY(4'b0100)) dut(
    .clk,.rst_n,
    .s_awvalid(mif.awvalid),.s_awready(mif.awready),.s_awid(mif.awid),.s_awaddr(mif.awaddr),
    .s_awlen(mif.awlen),.s_awsize(mif.awsize),.s_awburst(mif.awburst),.s_awprot(mif.awprot),.s_awqos(mif.awqos),
    .s_wvalid(mif.wvalid),.s_wready(mif.wready),.s_wdata(mif.wdata),.s_wstrb(mif.wstrb),.s_wlast(mif.wlast),
    .s_bvalid(mif.bvalid),.s_bready(mif.bready),.s_bid(mif.bid),.s_bresp(mif.bresp),
    .s_arvalid(mif.arvalid),.s_arready(mif.arready),.s_arid(mif.arid),.s_araddr(mif.araddr),
    .s_arlen(mif.arlen),.s_arsize(mif.arsize),.s_arburst(mif.arburst),.s_arprot(mif.arprot),.s_arqos(mif.arqos),
    .s_rvalid(mif.rvalid),.s_rready(mif.rready),.s_rid(mif.rid),.s_rdata(mif.rdata),.s_rresp(mif.rresp),.s_rlast(mif.rlast),
    .m_awvalid,.m_awready,.m_awid,.m_awaddr,.m_awlen,.m_awsize,.m_awburst,.m_awprot,.m_awqos,
    .m_wvalid,.m_wready,.m_wdata,.m_wstrb,.m_wlast,.m_bvalid,.m_bready,.m_bid,.m_bresp,
    .m_arvalid,.m_arready,.m_arid,.m_araddr,.m_arlen,.m_arsize,.m_arburst,.m_arprot,.m_arqos,
    .m_rvalid,.m_rready,.m_rid,.m_rdata,.m_rresp,.m_rlast,.mon_ar_age_override,.mon_aw_age_override);
  axi4_fabric_assertions sva(
    .clk,.rst_n,
    .s_awvalid(mif.awvalid),.s_awready(mif.awready),.s_awid(mif.awid),.s_awaddr(mif.awaddr),
    .s_awlen(mif.awlen),.s_awsize(mif.awsize),.s_awburst(mif.awburst),.s_awprot(mif.awprot),.s_awqos(mif.awqos),
    .s_wvalid(mif.wvalid),.s_wready(mif.wready),.s_wdata(mif.wdata),.s_wstrb(mif.wstrb),.s_wlast(mif.wlast),
    .s_bvalid(mif.bvalid),.s_bready(mif.bready),.s_bid(mif.bid),.s_bresp(mif.bresp),
    .s_arvalid(mif.arvalid),.s_arready(mif.arready),.s_arid(mif.arid),.s_araddr(mif.araddr),
    .s_arlen(mif.arlen),.s_arsize(mif.arsize),.s_arburst(mif.arburst),.s_arprot(mif.arprot),.s_arqos(mif.arqos),
    .s_rvalid(mif.rvalid),.s_rready(mif.rready),.s_rid(mif.rid),.s_rdata(mif.rdata),.s_rresp(mif.rresp),.s_rlast(mif.rlast),
    .m_awvalid,.m_awready,.m_awid,.m_awaddr,.m_awlen,.m_awsize,.m_awburst,.m_awprot,.m_awqos,
    .m_wvalid,.m_wready,.m_wdata,.m_wstrb,.m_wlast,
    .m_bvalid,.m_bready,.m_bid,.m_bresp,
    .m_arvalid,.m_arready,.m_arid,.m_araddr,.m_arlen,.m_arsize,.m_arburst,.m_arprot,.m_arqos,
    .m_rvalid,.m_rready,.m_rid,.m_rdata,.m_rresp,.m_rlast);
  generate for(genvar s=0;s<NS;s++) begin:g_mem
    axi_memory_model #(.BASE_ADDR(AW'(s)<<28),.ERROR_ENABLE(s==2),.TARGET_INDEX(s)) target(
      .clk,.rst_n,.awvalid(m_awvalid[s]),.awready(m_awready[s]),.awid(m_awid[s]),.awaddr(m_awaddr[s]),
      .awlen(m_awlen[s]),.awsize(m_awsize[s]),.awburst(m_awburst[s]),.wvalid(m_wvalid[s]),.wready(m_wready[s]),
      .wdata(m_wdata[s]),.wstrb(m_wstrb[s]),.wlast(m_wlast[s]),.bvalid(m_bvalid[s]),.bready(m_bready[s]),.bid(m_bid[s]),.bresp(m_bresp[s]),
      .arvalid(m_arvalid[s]),.arready(m_arready[s]),.arid(m_arid[s]),.araddr(m_araddr[s]),.arlen(m_arlen[s]),
      .arsize(m_arsize[s]),.arburst(m_arburst[s]),.rvalid(m_rvalid[s]),.rready(m_rready[s]),.rid(m_rid[s]),
      .rdata(m_rdata[s]),.rresp(m_rresp[s]),.rlast(m_rlast[s]));
  end endgenerate

  always_ff @(posedge clk) if(!rst_n) mif.first_target1_master<=-1;
    else if(mif.first_target1_master<0 && m_arvalid[1] && m_arready[1]) mif.first_target1_master<=m_arid[1][5:4];
  always_ff @(posedge clk) if(!rst_n) mif.age_override_seen<=0;
    else if(|mon_ar_age_override || |mon_aw_age_override) mif.age_override_seen<=1;

  initial begin
    mif.rst_n=0; mif.reset_epoch=0;
    mif.awvalid='0; mif.wvalid='0; mif.bready='1; mif.arvalid='0; mif.rready='1;
    mif.awid='0; mif.awaddr='0; mif.awlen='0; mif.awsize={NM{3'd3}}; mif.awburst={NM{2'b01}}; mif.awprot='0; mif.awqos='0;
    mif.wdata='0; mif.wstrb='1; mif.wlast='0;
    mif.arid='0; mif.araddr='0; mif.arlen='0; mif.arsize={NM{3'd3}}; mif.arburst={NM{2'b01}}; mif.arprot='0; mif.arqos='0;
    uvm_config_db#(virtual axi_master_if)::set(null,"uvm_test_top*","vif",mif);
    run_test();
  end
  initial begin repeat(20000) @(posedge clk); `uvm_fatal("TIMEOUT","UVM test exceeded 20000 cycles") end
endmodule
