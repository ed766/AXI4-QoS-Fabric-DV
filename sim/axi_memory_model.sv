`timescale 1ns/1ps
module axi_memory_model #(
    parameter int ADDR_W = 32,
    parameter int DATA_W = 64,
    parameter int ID_W = 6,
    parameter int WORDS = 8192,
    parameter int TARGET_INDEX = 0,
    parameter logic [ADDR_W-1:0] BASE_ADDR = '0,
    parameter bit ERROR_ENABLE = 0,
    parameter int MAX_OUTSTANDING = 8
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
  typedef struct {
    logic [ID_W-1:0] id;
    logic [ADDR_W-1:0] addr;
    logic [8:0] beats;
    logic [2:0] size;
    logic [1:0] resp;
    integer age;
    integer serial;
  } transaction_t;

  logic [DATA_W-1:0] mem [0:WORDS-1];
  transaction_t read_queue[$];
  transaction_t write_queue[$];
  transaction_t write_responses[$];
  transaction_t active_read;
  integer read_beat;
  integer write_beat;
  integer stall_percent;
  integer cycle_count;
  integer reorder_policy;
  integer reorder_target;
  integer reorder_delay;
  integer reorder_seed;
  integer target_fault;
  integer fault_target;
  integer sequence_count;
  logic stall_now;
  logic duplicate_b_pending;
  logic [ID_W-1:0] duplicate_bid;
  logic [1:0] duplicate_bresp;

  function automatic int word_index(input logic [ADDR_W-1:0] addr);
    return int'((addr - BASE_ADDR) >> $clog2(DATA_W/8)) % WORDS;
  endfunction

  function automatic bit selected_target();
    return TARGET_INDEX == reorder_target;
  endfunction

  initial begin
    stall_percent = 0;
    reorder_policy = 0;
    reorder_target = 1;
    reorder_delay = 6;
    reorder_seed = 1;
    target_fault = 0;
    fault_target = 1;
    void'($value$plusargs("STALL_PERCENT=%d", stall_percent));
    void'($value$plusargs("REORDER_POLICY=%d", reorder_policy));
    void'($value$plusargs("REORDER_TARGET=%d", reorder_target));
    void'($value$plusargs("REORDER_DELAY=%d", reorder_delay));
    void'($value$plusargs("REORDER_SEED=%d", reorder_seed));
    void'($value$plusargs("TARGET_FAULT=%d", target_fault));
    void'($value$plusargs("FAULT_TARGET=%d", fault_target));
    for (int i = 0; i < WORDS; i++) mem[i] = 64'hA500_0000_0000_0000 ^ DATA_W'(i);
  end

  assign stall_now = stall_percent != 0 && ((cycle_count * 37 + TARGET_INDEX * 17) % 100) < stall_percent;
  assign awready = write_queue.size() < MAX_OUTSTANDING && !stall_now;
  assign wready = write_queue.size() != 0 && !stall_now;
  assign arready = read_queue.size() < MAX_OUTSTANDING && !stall_now;

  always @(posedge clk or negedge rst_n) begin : target_behavior
    transaction_t request;
    transaction_t selected;
    integer choice;
    integer random_value;
    bit response_ready;
    if (!rst_n) begin
      read_queue.delete();
      write_queue.delete();
      write_responses.delete();
      bvalid <= 1'b0;
      rvalid <= 1'b0;
      bid <= '0;
      bresp <= '0;
      rid <= '0;
      rdata <= '0;
      rresp <= '0;
      rlast <= 1'b0;
      active_read = '{default:'0};
      read_beat = 0;
      write_beat = 0;
      cycle_count <= 0;
      sequence_count = 0;
      duplicate_b_pending <= 1'b0;
      duplicate_bid <= '0;
      duplicate_bresp <= '0;
    end else begin
      cycle_count <= cycle_count + 1;
      for (int i = 0; i < read_queue.size(); i++) read_queue[i].age++;
      for (int i = 0; i < write_responses.size(); i++) write_responses[i].age++;

      if (awvalid && awready) begin
        request.id = awid;
        request.addr = awaddr;
        request.beats = {1'b0, awlen} + 1'b1;
        request.size = awsize;
        request.resp = (ERROR_ENABLE && awaddr[15:12] == 4'hF) || awburst != 2'b01 ? 2'b10 : 2'b00;
        request.age = 0;
        request.serial = sequence_count++;
        write_queue.push_back(request);
      end

      if (wvalid && wready) begin
        if (write_queue[0].resp == 2'b00) begin
          for (int byte_lane = 0; byte_lane < DATA_W/8; byte_lane++) begin
            if (wstrb[byte_lane])
              mem[word_index(write_queue[0].addr + ADDR_W'(write_beat << write_queue[0].size))][byte_lane*8 +: 8]
                <= wdata[byte_lane*8 +: 8];
          end
        end
        if (wlast || write_beat == int'(write_queue[0].beats)-1) begin
          selected = write_queue.pop_front();
          selected.age = 0;
          write_responses.push_back(selected);
          write_beat = 0;
        end else begin
          write_beat++;
        end
      end

      if (arvalid && arready) begin
        request.id = arid;
        request.addr = araddr;
        request.beats = {1'b0, arlen} + 1'b1;
        request.size = arsize;
        request.resp = (ERROR_ENABLE && araddr[15:12] == 4'hF) || arburst != 2'b01 ? 2'b10 : 2'b00;
        request.age = 0;
        request.serial = sequence_count++;
        read_queue.push_back(request);
      end

      if (bvalid && bready) begin
        if (target_fault == 4 && TARGET_INDEX == fault_target && !duplicate_b_pending) begin
          duplicate_b_pending <= 1'b1;
          duplicate_bid <= bid;
          duplicate_bresp <= bresp;
        end
        bvalid <= 1'b0;
      end
      if (!bvalid) begin
        if (duplicate_b_pending) begin
          bvalid <= 1'b1;
          bid <= duplicate_bid;
          bresp <= duplicate_bresp;
          duplicate_b_pending <= 1'b0;
        end else if (write_responses.size() != 0) begin
          choice = 0;
          response_ready = 1'b1;
          if (selected_target() && reorder_policy == 1) begin
            response_ready = write_responses.size() >= 2 || write_responses[0].age >= reorder_delay;
            choice = write_responses.size()-1;
          end else if (selected_target() && reorder_policy == 2) begin
            response_ready = write_responses[0].age >= reorder_delay;
          end else if (selected_target() && reorder_policy == 3) begin
            response_ready = write_responses[0].age >= reorder_delay || write_responses.size() >= 2;
            random_value = (reorder_seed * 1103515245 + cycle_count * 12345) & 32'h7fff_ffff;
            choice = random_value % write_responses.size();
          end
          if (response_ready) begin
            selected = write_responses[choice];
            write_responses.delete(choice);
            bvalid <= 1'b1;
            bid <= (target_fault == 5 && TARGET_INDEX == fault_target) ? selected.id ^ ID_W'(1) : selected.id;
            bresp <= selected.resp;
          end
        end
      end

      if (rvalid && rready) begin
        if (read_beat == int'(active_read.beats)-1) begin
          rvalid <= 1'b0;
          rlast <= 1'b0;
          read_beat = 0;
        end else begin
          read_beat++;
          rdata <= mem[word_index(active_read.addr + ADDR_W'(read_beat << active_read.size))];
          rresp <= active_read.resp;
          rlast <= read_beat == int'(active_read.beats)-1;
          if (target_fault == 1 && TARGET_INDEX == fault_target && active_read.beats > 1) rlast <= 1'b1;
          if (target_fault == 2 && TARGET_INDEX == fault_target && read_beat == int'(active_read.beats)-1) rlast <= 1'b0;
        end
      end
      if (!rvalid && read_queue.size() != 0) begin
        choice = 0;
        response_ready = 1'b1;
        if (selected_target() && reorder_policy == 1) begin
          response_ready = read_queue.size() >= 2 || read_queue[0].age >= reorder_delay;
          choice = read_queue.size()-1;
        end else if (selected_target() && reorder_policy == 2) begin
          response_ready = read_queue[0].age >= reorder_delay;
        end else if (selected_target() && reorder_policy == 3) begin
          response_ready = read_queue[0].age >= reorder_delay || read_queue.size() >= 2;
          random_value = (reorder_seed * 1664525 + cycle_count * 1013904223) & 32'h7fff_ffff;
          choice = random_value % read_queue.size();
        end
        if (response_ready) begin
          active_read = read_queue[choice];
          read_queue.delete(choice);
          read_beat = 0;
          rvalid <= 1'b1;
          rid <= (target_fault == 3 && TARGET_INDEX == fault_target) ? active_read.id ^ ID_W'(1) : active_read.id;
          rdata <= mem[word_index(active_read.addr)];
          rresp <= active_read.resp;
          rlast <= active_read.beats == 1;
          if (target_fault == 1 && TARGET_INDEX == fault_target && active_read.beats > 1) rlast <= 1'b1;
          if (target_fault == 2 && TARGET_INDEX == fault_target && active_read.beats == 1) rlast <= 1'b0;
        end
      end
    end
  end
endmodule
