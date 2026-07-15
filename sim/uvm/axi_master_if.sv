`timescale 1ns/1ps
interface axi_master_if #(parameter int NUM_MASTERS=4, ADDR_W=32, DATA_W=64, ID_W=4) (input logic clk);
  logic rst_n;
  logic [NUM_MASTERS-1:0] awvalid,wvalid,wlast,bready;
  logic [NUM_MASTERS-1:0][ID_W-1:0] awid;
  logic [NUM_MASTERS-1:0][ADDR_W-1:0] awaddr;
  logic [NUM_MASTERS-1:0][7:0] awlen;
  logic [NUM_MASTERS-1:0][2:0] awsize,awprot;
  logic [NUM_MASTERS-1:0][1:0] awburst;
  logic [NUM_MASTERS-1:0][3:0] awqos;
  logic [NUM_MASTERS-1:0][DATA_W-1:0] wdata;
  logic [NUM_MASTERS-1:0][DATA_W/8-1:0] wstrb;
  logic [NUM_MASTERS-1:0] arvalid,rready;
  logic [NUM_MASTERS-1:0][ID_W-1:0] arid;
  logic [NUM_MASTERS-1:0][ADDR_W-1:0] araddr;
  logic [NUM_MASTERS-1:0][7:0] arlen;
  logic [NUM_MASTERS-1:0][2:0] arsize,arprot;
  logic [NUM_MASTERS-1:0][1:0] arburst;
  logic [NUM_MASTERS-1:0][3:0] arqos;

endinterface
