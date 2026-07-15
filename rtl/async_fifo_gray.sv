`timescale 1ns/1ps
module async_fifo_gray #(
    parameter int WIDTH = 64,
    parameter int DEPTH = 4
) (
    input  logic wclk,
    input  logic wrst_n,
    input  logic w_valid,
    output logic w_ready,
    input  logic [WIDTH-1:0] w_data,
    input  logic rclk,
    input  logic rrst_n,
    output logic r_valid,
    input  logic r_ready,
    output logic [WIDTH-1:0] r_data
);
  localparam int PTR_W = $clog2(DEPTH) + 1;
  logic [WIDTH-1:0] mem [0:DEPTH-1];
  logic [PTR_W-1:0] wbin, wgray, rbin, rgray;
  logic [PTR_W-1:0] rgray_w1, rgray_w2, wgray_r1, wgray_r2;
  logic [PTR_W-1:0] wbin_next, wgray_next, rbin_next, rgray_next, wgray_inc;
  logic full, empty;

  function automatic logic [PTR_W-1:0] bin2gray(input logic [PTR_W-1:0] value);
    bin2gray = (value >> 1) ^ value;
  endfunction

  /* verilator lint_off WIDTHEXPAND */
  assign wbin_next = wbin + (w_valid && w_ready);
  assign wgray_next = bin2gray(wbin_next);
  assign rbin_next = rbin + (r_valid && r_ready);
  assign rgray_next = bin2gray(rbin_next);
  assign wgray_inc = bin2gray(wbin + 1'b1);
  /* verilator lint_on WIDTHEXPAND */
  assign full = wgray_inc == {~rgray_w2[PTR_W-1:PTR_W-2], rgray_w2[PTR_W-3:0]};
  assign empty = rgray == wgray_r2;
  assign w_ready = !full;
  assign r_valid = !empty;
  assign r_data = mem[rbin[$clog2(DEPTH)-1:0]];

  always_ff @(posedge wclk or negedge wrst_n) begin
    if (!wrst_n) begin
      wbin <= '0;
      wgray <= '0;
      rgray_w1 <= '0;
      rgray_w2 <= '0;
    end else begin
      rgray_w1 <= rgray;
      rgray_w2 <= rgray_w1;
      if (w_valid && w_ready) begin
        mem[wbin[$clog2(DEPTH)-1:0]] <= w_data;
        wbin <= wbin_next;
        wgray <= wgray_next;
      end
    end
  end

  always_ff @(posedge rclk or negedge rrst_n) begin
    if (!rrst_n) begin
      rbin <= '0;
      rgray <= '0;
      wgray_r1 <= '0;
      wgray_r2 <= '0;
    end else begin
      wgray_r1 <= wgray;
      wgray_r2 <= wgray_r1;
      if (r_valid && r_ready) begin
        rbin <= rbin_next;
        rgray <= rgray_next;
      end
    end
  end

`ifdef VERILATOR
  a_write_gray_one_bit: assert property (@(posedge wclk) disable iff(!wrst_n)
    w_valid && w_ready |=> $onehot(wgray ^ $past(wgray)));
  a_write_pointer_stable_without_accept: assert property (@(posedge wclk) disable iff(!wrst_n)
    !(w_valid && w_ready) |=> $stable(wgray));
  a_read_gray_one_bit: assert property (@(posedge rclk) disable iff(!rrst_n)
    r_valid && r_ready |=> $onehot(rgray ^ $past(rgray)));
  a_read_pointer_stable_without_accept: assert property (@(posedge rclk) disable iff(!rrst_n)
    !(r_valid && r_ready) |=> $stable(rgray));
`endif
endmodule
