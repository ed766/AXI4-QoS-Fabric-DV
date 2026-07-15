`timescale 1ns/1ps
module axi_memory_model #(
    parameter int ADDR_W = 32,
    parameter int DATA_W = 64,
    parameter int ID_W = 6,
    parameter int WORDS = 8192,
    parameter int TARGET_INDEX = 0,
    parameter logic [ADDR_W-1:0] BASE_ADDR = '0,
    parameter bit ERROR_ENABLE = 0
) (
    input logic clk,
    input logic rst_n,
    input logic awvalid, output logic awready,
    input logic [ID_W-1:0] awid,
    input logic [ADDR_W-1:0] awaddr,
    input logic [7:0] awlen,
    input logic [2:0] awsize,
    input logic [1:0] awburst,
    input logic wvalid, output logic wready,
    input logic [DATA_W-1:0] wdata,
    input logic [DATA_W/8-1:0] wstrb,
    input logic wlast,
    output logic bvalid, input logic bready,
    output logic [ID_W-1:0] bid,
    output logic [1:0] bresp,
    input logic arvalid, output logic arready,
    input logic [ID_W-1:0] arid,
    input logic [ADDR_W-1:0] araddr,
    input logic [7:0] arlen,
    input logic [2:0] arsize,
    input logic [1:0] arburst,
    output logic rvalid, input logic rready,
    output logic [ID_W-1:0] rid,
    output logic [DATA_W-1:0] rdata,
    output logic [1:0] rresp,
    output logic rlast
);
  logic [DATA_W-1:0] mem [0:WORDS-1];
  logic write_active, read_active;
  logic [ADDR_W-1:0] write_addr, read_addr;
  logic [8:0] write_beats, read_beats;
  logic [2:0] write_size, read_size;
  logic write_error, read_error;
  integer stall_percent;
  integer cycle_count;
  logic stall_now;

  function automatic int word_index(input logic [ADDR_W-1:0] addr);
    return int'((addr - BASE_ADDR) >> $clog2(DATA_W/8)) % WORDS;
  endfunction

  initial begin
    stall_percent = 0;
    void'($value$plusargs("STALL_PERCENT=%d", stall_percent));
    for (int i = 0; i < WORDS; i++) mem[i] = 64'hA500_0000_0000_0000 ^ DATA_W'(i);
  end

  assign stall_now = stall_percent != 0 && ((cycle_count * 37 + TARGET_INDEX * 17) % 100) < stall_percent;
  assign awready = !write_active && !bvalid && !stall_now;
  assign wready = write_active && !bvalid && !stall_now;
  assign arready = !read_active && !stall_now;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      write_active <= 1'b0;
      read_active <= 1'b0;
      bvalid <= 1'b0;
      rvalid <= 1'b0;
      bid <= '0;
      bresp <= '0;
      rid <= '0;
      rdata <= '0;
      rresp <= '0;
      rlast <= 1'b0;
      write_addr <= '0;
      read_addr <= '0;
      write_beats <= '0;
      read_beats <= '0;
      write_size <= '0;
      read_size <= '0;
      write_error <= 1'b0;
      read_error <= 1'b0;
      cycle_count <= 0;
    end else begin
      cycle_count <= cycle_count + 1;
      if (awvalid && awready) begin
        write_active <= 1'b1;
        write_addr <= awaddr;
        write_beats <= {1'b0, awlen} + 1'b1;
        write_size <= awsize;
        bid <= awid;
        write_error <= ERROR_ENABLE && awaddr[15:12] == 4'hF;
        if (awburst != 2'b01) write_error <= 1'b1;
      end
      if (wvalid && wready) begin
        if (!write_error) begin
          for (int byte_lane = 0; byte_lane < DATA_W/8; byte_lane++) begin
            if (wstrb[byte_lane])
              mem[word_index(write_addr)][byte_lane*8 +: 8] <= wdata[byte_lane*8 +: 8];
          end
        end
        write_addr <= write_addr + (ADDR_W'(1) << write_size);
        write_beats <= write_beats - 1'b1;
        if (wlast || write_beats == 1) begin
          write_active <= 1'b0;
          bvalid <= 1'b1;
          bresp <= write_error ? 2'b10 : 2'b00;
        end
      end
      if (bvalid && bready) bvalid <= 1'b0;

      if (arvalid && arready) begin
        read_active <= 1'b1;
        read_addr <= araddr;
        read_beats <= {1'b0, arlen} + 1'b1;
        read_size <= arsize;
        rid <= arid;
        read_error <= ERROR_ENABLE && araddr[15:12] == 4'hF;
        rvalid <= 1'b1;
        rdata <= mem[word_index(araddr)];
        rresp <= ERROR_ENABLE && araddr[15:12] == 4'hF ? 2'b10 : 2'b00;
        rlast <= arlen == 0;
        if (arburst != 2'b01) rresp <= 2'b10;
      end else if (rvalid && rready) begin
        if (read_beats == 1) begin
          rvalid <= 1'b0;
          read_active <= 1'b0;
          rlast <= 1'b0;
        end else begin
          read_addr <= read_addr + (ADDR_W'(1) << read_size);
          read_beats <= read_beats - 1'b1;
          rdata <= mem[word_index(read_addr + (ADDR_W'(1) << read_size))];
          rresp <= read_error ? 2'b10 : 2'b00;
          rlast <= read_beats == 2;
        end
      end
    end
  end
endmodule
