`timescale 1ns/1ps

module tb_full_fabric_gate;
  localparam int NM=4, NS=4, AW=32, DW=64, IW=4, TIW=6;
  logic clk, rst_n;
  initial clk = 1'b0;
  always #5 clk=~clk;
  logic [NM-1:0] s_awvalid,s_awready,s_wvalid,s_wready,s_wlast,s_bvalid,s_bready;
  logic [NM-1:0][IW-1:0] s_awid,s_bid;
  logic [NM-1:0][AW-1:0] s_awaddr;
  logic [NM-1:0][7:0] s_awlen;
  logic [NM-1:0][2:0] s_awsize,s_awprot;
  logic [NM-1:0][1:0] s_awburst,s_bresp;
  logic [NM-1:0][3:0] s_awqos;
  logic [NM-1:0][DW-1:0] s_wdata;
  logic [NM-1:0][DW/8-1:0] s_wstrb;
  logic [NM-1:0] s_arvalid,s_arready,s_rvalid,s_rready,s_rlast;
  logic [NM-1:0][IW-1:0] s_arid,s_rid;
  logic [NM-1:0][AW-1:0] s_araddr;
  logic [NM-1:0][7:0] s_arlen;
  logic [NM-1:0][2:0] s_arsize,s_arprot;
  logic [NM-1:0][1:0] s_arburst,s_rresp;
  logic [NM-1:0][3:0] s_arqos;
  logic [NM-1:0][DW-1:0] s_rdata;
  logic [NS-1:0] m_awvalid,m_awready,m_wvalid,m_wready,m_wlast,m_bvalid,m_bready;
  logic [NS-1:0][TIW-1:0] m_awid,m_bid;
  logic [NS-1:0][AW-1:0] m_awaddr;
  logic [NS-1:0][7:0] m_awlen;
  logic [NS-1:0][2:0] m_awsize,m_awprot;
  logic [NS-1:0][1:0] m_awburst,m_bresp;
  logic [NS-1:0][3:0] m_awqos;
  logic [NS-1:0][DW-1:0] m_wdata;
  logic [NS-1:0][DW/8-1:0] m_wstrb;
  logic [NS-1:0] m_arvalid,m_arready,m_rvalid,m_rready,m_rlast;
  logic [NS-1:0][TIW-1:0] m_arid,m_rid;
  logic [NS-1:0][AW-1:0] m_araddr;
  logic [NS-1:0][7:0] m_arlen;
  logic [NS-1:0][2:0] m_arsize,m_arprot;
  logic [NS-1:0][1:0] m_arburst,m_rresp;
  logic [NS-1:0][3:0] m_arqos;
  logic [NS-1:0][DW-1:0] m_rdata;
  logic [NS-1:0] mon_ar_age_override,mon_aw_age_override;
  integer checks=0;

  axi4_qos_fabric dut (.*);

  task automatic issue_ar(input logic [AW-1:0] address,input logic [IW-1:0] id,
      output logic [TIW-1:0] target_id);
    begin
      @(negedge clk); s_arvalid[0]=1; s_araddr[0]=address; s_arid[0]=id;
      do @(posedge clk); while(!s_arready[0]);
      target_id=m_arid[0];
      @(negedge clk); s_arvalid[0]=0;
    end
  endtask

  initial begin
    logic [TIW-1:0] captured_id;
    rst_n=0;
    s_awvalid='0;s_awid='0;s_awaddr='0;s_awlen='0;s_awsize='0;s_awburst='0;s_awprot='0;s_awqos='0;
    s_wvalid='0;s_wdata='0;s_wstrb='0;s_wlast='0;s_bready='1;
    s_arvalid='0;s_arid='0;s_araddr='0;s_arlen='0;s_arsize='0;s_arburst='0;s_arprot='0;s_arqos='0;s_rready='1;
    m_awready='1;m_wready='1;m_bvalid='0;m_bid='0;m_bresp='0;
    m_arready='1;m_rvalid='0;m_rid='0;m_rdata='0;m_rresp='0;m_rlast='0;
    repeat(4) @(posedge clk); rst_n=1;

    s_arlen[0]=0;s_arsize[0]=3;s_arburst[0]=2'b01;
    issue_ar(32'h0000_0040,4'h3,captured_id);
    $display("GATE_STAGE|mapped_ar_accepted|tid=%0h",captured_id);
    checks++;
    @(negedge clk); m_rvalid[0]=1;m_rid[0]=captured_id;m_rdata[0]=64'h1122_3344_5566_7788;m_rlast[0]=1;
    wait(s_rvalid[0]);
    $display("GATE_STAGE|mapped_r_seen");
    if(s_rid[0]!==4'h3||s_rdata[0]!==64'h1122_3344_5566_7788||s_rresp[0]!==0||!s_rlast[0]) $fatal(1,"mapped read route failed");
    checks++; @(negedge clk);m_rvalid[0]=0;m_rlast[0]=0;

    issue_ar(32'hf000_0000,4'h7,captured_id);
    $display("GATE_STAGE|local_ar_accepted");
    wait(s_rvalid[0]);
    $display("GATE_STAGE|local_r_seen");
    if(s_rid[0]!==4'h7||s_rresp[0]!==2'b11||!s_rlast[0]||(|m_arvalid)) $fatal(1,"local DECERR failed");
    checks++; @(posedge clk);

    @(negedge clk);s_awvalid[1]=1;s_awid[1]=4'h5;s_awaddr[1]=32'h1000_0020;s_awlen[1]=0;s_awsize[1]=3;s_awburst[1]=2'b01;
    do @(posedge clk);while(!s_awready[1]);
    captured_id=m_awid[1];
    $display("GATE_STAGE|mapped_aw_accepted");
    checks++; @(negedge clk);s_awvalid[1]=0;s_wvalid[1]=1;s_wdata[1]=64'hfeed_face_1234_5678;s_wstrb[1]='1;s_wlast[1]=1;
    do @(posedge clk);while(!s_wready[1]);
    $display("GATE_STAGE|mapped_w_accepted");
    if(!m_wvalid[1]||m_wdata[1]!==64'hfeed_face_1234_5678||!m_wlast[1])$fatal(1,"mapped write route failed");
    checks++;@(negedge clk);s_wvalid[1]=0;m_bvalid[1]=1;m_bid[1]=captured_id;m_bresp[1]=0;
    wait(s_bvalid[1]);if(s_bid[1]!==4'h5||s_bresp[1]!==0)$fatal(1,"write response route failed");
    $display("GATE_STAGE|mapped_b_seen");
    checks++;@(negedge clk);m_bvalid[1]=0;
    $display("FULL_FABRIC_GATE_SUMMARY|status=PASS|checks=%0d",checks);
    $finish;
  end
  initial begin repeat(500) @(posedge clk);$fatal(1,"gate smoke timeout");end
endmodule
