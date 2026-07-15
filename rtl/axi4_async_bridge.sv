`timescale 1ns/1ps
module axi4_async_bridge #(
    parameter int ADDR_W = 32,
    parameter int DATA_W = 64,
    parameter int ID_W = 6,
    parameter int FIFO_DEPTH = 4
) (
    input logic s_clk,
    input logic s_rst_n,
    input logic m_clk,
    input logic m_rst_n,

    input logic s_awvalid, output logic s_awready,
    input logic [ID_W-1:0] s_awid,
    input logic [ADDR_W-1:0] s_awaddr,
    input logic [7:0] s_awlen,
    input logic [2:0] s_awsize,
    input logic [1:0] s_awburst,
    input logic [2:0] s_awprot,
    input logic [3:0] s_awqos,
    input logic s_wvalid, output logic s_wready,
    input logic [DATA_W-1:0] s_wdata,
    input logic [DATA_W/8-1:0] s_wstrb,
    input logic s_wlast,
    output logic s_bvalid, input logic s_bready,
    output logic [ID_W-1:0] s_bid,
    output logic [1:0] s_bresp,
    input logic s_arvalid, output logic s_arready,
    input logic [ID_W-1:0] s_arid,
    input logic [ADDR_W-1:0] s_araddr,
    input logic [7:0] s_arlen,
    input logic [2:0] s_arsize,
    input logic [1:0] s_arburst,
    input logic [2:0] s_arprot,
    input logic [3:0] s_arqos,
    output logic s_rvalid, input logic s_rready,
    output logic [ID_W-1:0] s_rid,
    output logic [DATA_W-1:0] s_rdata,
    output logic [1:0] s_rresp,
    output logic s_rlast,

    output logic m_awvalid, input logic m_awready,
    output logic [ID_W-1:0] m_awid,
    output logic [ADDR_W-1:0] m_awaddr,
    output logic [7:0] m_awlen,
    output logic [2:0] m_awsize,
    output logic [1:0] m_awburst,
    output logic [2:0] m_awprot,
    output logic [3:0] m_awqos,
    output logic m_wvalid, input logic m_wready,
    output logic [DATA_W-1:0] m_wdata,
    output logic [DATA_W/8-1:0] m_wstrb,
    output logic m_wlast,
    input logic m_bvalid, output logic m_bready,
    input logic [ID_W-1:0] m_bid,
    input logic [1:0] m_bresp,
    output logic m_arvalid, input logic m_arready,
    output logic [ID_W-1:0] m_arid,
    output logic [ADDR_W-1:0] m_araddr,
    output logic [7:0] m_arlen,
    output logic [2:0] m_arsize,
    output logic [1:0] m_arburst,
    output logic [2:0] m_arprot,
    output logic [3:0] m_arqos,
    input logic m_rvalid, output logic m_rready,
    input logic [ID_W-1:0] m_rid,
    input logic [DATA_W-1:0] m_rdata,
    input logic [1:0] m_rresp,
    input logic m_rlast
);
  localparam int AW_W = ID_W + ADDR_W + 8 + 3 + 2 + 3 + 4;
  localparam int W_W = DATA_W + DATA_W/8 + 1;
  localparam int B_W = ID_W + 2;
  localparam int R_W = ID_W + DATA_W + 2 + 1;
  logic [AW_W-1:0] aw_in, aw_out, ar_in, ar_out;
  logic [W_W-1:0] w_in, w_out;
  logic [B_W-1:0] b_in, b_out;
  logic [R_W-1:0] r_in, r_out;

  assign aw_in = {s_awid, s_awaddr, s_awlen, s_awsize, s_awburst, s_awprot, s_awqos};
  assign {m_awid, m_awaddr, m_awlen, m_awsize, m_awburst, m_awprot, m_awqos} = aw_out;
  assign ar_in = {s_arid, s_araddr, s_arlen, s_arsize, s_arburst, s_arprot, s_arqos};
  assign {m_arid, m_araddr, m_arlen, m_arsize, m_arburst, m_arprot, m_arqos} = ar_out;
  assign w_in = {s_wdata, s_wstrb, s_wlast};
  assign {m_wdata, m_wstrb, m_wlast} = w_out;
  assign b_in = {m_bid, m_bresp};
  assign {s_bid, s_bresp} = b_out;
  assign r_in = {m_rid, m_rdata, m_rresp, m_rlast};
  assign {s_rid, s_rdata, s_rresp, s_rlast} = r_out;

  async_fifo_gray #(.WIDTH(AW_W), .DEPTH(FIFO_DEPTH)) u_aw (
    .wclk(s_clk), .wrst_n(s_rst_n), .w_valid(s_awvalid), .w_ready(s_awready), .w_data(aw_in),
    .rclk(m_clk), .rrst_n(m_rst_n), .r_valid(m_awvalid), .r_ready(m_awready), .r_data(aw_out)
  );
  async_fifo_gray #(.WIDTH(W_W), .DEPTH(FIFO_DEPTH)) u_w (
    .wclk(s_clk), .wrst_n(s_rst_n), .w_valid(s_wvalid), .w_ready(s_wready), .w_data(w_in),
    .rclk(m_clk), .rrst_n(m_rst_n), .r_valid(m_wvalid), .r_ready(m_wready), .r_data(w_out)
  );
  async_fifo_gray #(.WIDTH(B_W), .DEPTH(FIFO_DEPTH)) u_b (
    .wclk(m_clk), .wrst_n(m_rst_n), .w_valid(m_bvalid), .w_ready(m_bready), .w_data(b_in),
    .rclk(s_clk), .rrst_n(s_rst_n), .r_valid(s_bvalid), .r_ready(s_bready), .r_data(b_out)
  );
  async_fifo_gray #(.WIDTH(AW_W), .DEPTH(FIFO_DEPTH)) u_ar (
    .wclk(s_clk), .wrst_n(s_rst_n), .w_valid(s_arvalid), .w_ready(s_arready), .w_data(ar_in),
    .rclk(m_clk), .rrst_n(m_rst_n), .r_valid(m_arvalid), .r_ready(m_arready), .r_data(ar_out)
  );
  async_fifo_gray #(.WIDTH(R_W), .DEPTH(FIFO_DEPTH)) u_r (
    .wclk(m_clk), .wrst_n(m_rst_n), .w_valid(m_rvalid), .w_ready(m_rready), .w_data(r_in),
    .rclk(s_clk), .rrst_n(s_rst_n), .r_valid(s_rvalid), .r_ready(s_rready), .r_data(r_out)
  );
endmodule
