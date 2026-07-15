`timescale 1ns/1ps
module axi4_fabric_assertions #(
    parameter int NUM_MASTERS=4,
    parameter int NUM_SLAVES=4,
    parameter int ADDR_W=32,
    parameter int DATA_W=64,
    parameter int ID_W=4,
    parameter int TID_W=6
) (
    input logic clk,
    input logic rst_n,
    input logic [NUM_MASTERS-1:0] s_awvalid, s_awready,
    input logic [NUM_MASTERS-1:0][ID_W-1:0] s_awid,
    input logic [NUM_MASTERS-1:0][ADDR_W-1:0] s_awaddr,
    input logic [NUM_MASTERS-1:0][7:0] s_awlen,
    input logic [NUM_MASTERS-1:0][2:0] s_awsize,
    input logic [NUM_MASTERS-1:0][1:0] s_awburst,
    input logic [NUM_MASTERS-1:0][2:0] s_awprot,
    input logic [NUM_MASTERS-1:0][3:0] s_awqos,
    input logic [NUM_MASTERS-1:0] s_wvalid, s_wready, s_wlast,
    input logic [NUM_MASTERS-1:0][DATA_W-1:0] s_wdata,
    input logic [NUM_MASTERS-1:0][DATA_W/8-1:0] s_wstrb,
    input logic [NUM_MASTERS-1:0] s_bvalid, s_bready,
    input logic [NUM_MASTERS-1:0][ID_W-1:0] s_bid,
    input logic [NUM_MASTERS-1:0][1:0] s_bresp,
    input logic [NUM_MASTERS-1:0] s_arvalid, s_arready,
    input logic [NUM_MASTERS-1:0][ID_W-1:0] s_arid,
    input logic [NUM_MASTERS-1:0][ADDR_W-1:0] s_araddr,
    input logic [NUM_MASTERS-1:0][7:0] s_arlen,
    input logic [NUM_MASTERS-1:0][2:0] s_arsize,
    input logic [NUM_MASTERS-1:0][1:0] s_arburst,
    input logic [NUM_MASTERS-1:0][2:0] s_arprot,
    input logic [NUM_MASTERS-1:0][3:0] s_arqos,
    input logic [NUM_MASTERS-1:0] s_rvalid, s_rready, s_rlast,
    input logic [NUM_MASTERS-1:0][ID_W-1:0] s_rid,
    input logic [NUM_MASTERS-1:0][DATA_W-1:0] s_rdata,
    input logic [NUM_MASTERS-1:0][1:0] s_rresp,
    input logic [NUM_SLAVES-1:0] m_awvalid, m_awready, m_wvalid, m_wready, m_wlast,
    input logic [NUM_SLAVES-1:0][TID_W-1:0] m_awid,
    input logic [NUM_SLAVES-1:0][ADDR_W-1:0] m_awaddr,
    input logic [NUM_SLAVES-1:0][7:0] m_awlen,
    input logic [NUM_SLAVES-1:0][2:0] m_awsize,
    input logic [NUM_SLAVES-1:0][1:0] m_awburst,
    input logic [NUM_SLAVES-1:0][2:0] m_awprot,
    input logic [NUM_SLAVES-1:0][3:0] m_awqos,
    input logic [NUM_SLAVES-1:0][DATA_W-1:0] m_wdata,
    input logic [NUM_SLAVES-1:0][DATA_W/8-1:0] m_wstrb,
    input logic [NUM_SLAVES-1:0] m_bvalid, m_bready,
    input logic [NUM_SLAVES-1:0][TID_W-1:0] m_bid,
    input logic [NUM_SLAVES-1:0][1:0] m_bresp,
    input logic [NUM_SLAVES-1:0] m_arvalid, m_arready, m_rvalid, m_rready, m_rlast,
    input logic [NUM_SLAVES-1:0][TID_W-1:0] m_arid, m_rid,
    input logic [NUM_SLAVES-1:0][ADDR_W-1:0] m_araddr,
    input logic [NUM_SLAVES-1:0][7:0] m_arlen,
    input logic [NUM_SLAVES-1:0][2:0] m_arsize,
    input logic [NUM_SLAVES-1:0][1:0] m_arburst,
    input logic [NUM_SLAVES-1:0][2:0] m_arprot,
    input logic [NUM_SLAVES-1:0][3:0] m_arqos,
    input logic [NUM_SLAVES-1:0][DATA_W-1:0] m_rdata,
    input logic [NUM_SLAVES-1:0][1:0] m_rresp
);
  localparam int ID_COUNT=1<<ID_W;
  localparam int TARGET_ID_COUNT=1<<TID_W;
  localparam int WRITE_TRACK_DEPTH=16;
  logic [NUM_MASTERS-1:0][ID_COUNT-1:0] accepted_reads,accepted_writes;
  logic [NUM_SLAVES-1:0][TARGET_ID_COUNT-1:0][8:0] read_beats_by_id;
  logic [NUM_SLAVES-1:0][TARGET_ID_COUNT-1:0] read_id_tracking;
  logic [NUM_SLAVES-1:0][WRITE_TRACK_DEPTH-1:0][8:0] write_len_fifo;
  logic [NUM_SLAVES-1:0][3:0] write_len_wptr,write_len_rptr;
  logic [NUM_SLAVES-1:0][4:0] write_len_count;

  always_ff @(posedge clk or negedge rst_n) begin : p_architectural_scoreboard
    if(!rst_n) begin
      accepted_reads<='0; accepted_writes<='0;
      read_beats_by_id<='0; read_id_tracking<='0; write_len_fifo<='0;
      write_len_wptr<='0; write_len_rptr<='0; write_len_count<='0;
    end else begin
      for(int m=0;m<NUM_MASTERS;m++) begin
        if(s_awvalid[m]&&s_awready[m]) begin
          a_no_duplicate_write_id: assert(!accepted_writes[m][s_awid[m]]);
          accepted_writes[m][s_awid[m]]<=1'b1;
        end
        if(s_arvalid[m]&&s_arready[m]) begin
          a_no_duplicate_read_id: assert(!accepted_reads[m][s_arid[m]]);
          accepted_reads[m][s_arid[m]]<=1'b1;
        end
        if(s_bvalid[m]&&s_bready[m]) begin
          a_b_requires_accepted_aw: assert(accepted_writes[m][s_bid[m]]);
          accepted_writes[m][s_bid[m]]<=1'b0;
        end
        if(s_rvalid[m]&&s_rready[m]&&s_rlast[m]) begin
          a_r_requires_accepted_ar: assert(accepted_reads[m][s_rid[m]]);
          accepted_reads[m][s_rid[m]]<=1'b0;
        end
        a_write_outstanding_bound: assert($countones(accepted_writes[m])<=4);
        a_read_outstanding_bound: assert($countones(accepted_reads[m])<=4);
      end
      for(int s=0;s<NUM_SLAVES;s++) begin
        if(m_awvalid[s]&&m_awready[s]) begin
          a_write_length_queue_not_full: assert(int'(write_len_count[s]) < WRITE_TRACK_DEPTH);
          write_len_fifo[s][write_len_wptr[s]]<={1'b0,m_awlen[s]}+1'b1;
          write_len_wptr[s]<=write_len_wptr[s]+1'b1;
        end
        if(m_wvalid[s]&&m_wready[s]) begin
          a_w_requires_accepted_aw: assert(write_len_count[s]!=0);
          a_wlast_matches_awlen: assert(m_wlast[s]==(write_len_fifo[s][write_len_rptr[s]]==1));
          if(m_wlast[s]) write_len_rptr[s]<=write_len_rptr[s]+1'b1;
          else write_len_fifo[s][write_len_rptr[s]]<=write_len_fifo[s][write_len_rptr[s]]-1'b1;
        end
        case ({m_awvalid[s]&&m_awready[s],m_wvalid[s]&&m_wready[s]&&m_wlast[s]})
          2'b10: write_len_count[s]<=write_len_count[s]+1'b1;
          2'b01: write_len_count[s]<=write_len_count[s]-1'b1;
          default: write_len_count[s]<=write_len_count[s];
        endcase
        if(m_arvalid[s]&&m_arready[s]) begin
          a_target_read_id_not_duplicate: assert(!read_id_tracking[s][m_arid[s]]);
          read_id_tracking[s][m_arid[s]]<=1'b1;
          read_beats_by_id[s][m_arid[s]]<={1'b0,m_arlen[s]}+1'b1;
        end
        if(m_rvalid[s]&&m_rready[s]) begin
          a_r_requires_target_ar: assert(read_id_tracking[s][m_rid[s]]);
          a_rlast_matches_arlen: assert(m_rlast[s]==(read_beats_by_id[s][m_rid[s]]==1));
          read_beats_by_id[s][m_rid[s]]<=read_beats_by_id[s][m_rid[s]]-1'b1;
          if(m_rlast[s]) read_id_tracking[s][m_rid[s]]<=1'b0;
        end
        if(m_bvalid[s]&&m_bready[s]) a_b_target_prefix_valid: assert(int'(m_bid[s][ID_W +: TID_W-ID_W])<NUM_MASTERS);
        if(m_rvalid[s]&&m_rready[s]) a_r_target_prefix_valid: assert(int'(m_rid[s][ID_W +: TID_W-ID_W])<NUM_MASTERS);
      end
    end
  end
  generate
    for (genvar m=0; m<NUM_MASTERS; m++) begin : g_master_sva
      a_s_aw_stable: assert property (@(posedge clk) disable iff(!rst_n)
        s_awvalid[m] && !s_awready[m] |=> s_awvalid[m] && $stable({s_awid[m],s_awaddr[m],s_awlen[m],s_awsize[m],s_awburst[m],s_awprot[m],s_awqos[m]}));
      a_s_w_stable: assert property (@(posedge clk) disable iff(!rst_n)
        s_wvalid[m] && !s_wready[m] |=> s_wvalid[m] && $stable({s_wdata[m],s_wstrb[m],s_wlast[m]}));
      a_s_b_stable: assert property (@(posedge clk) disable iff(!rst_n)
        s_bvalid[m] && !s_bready[m] |=> s_bvalid[m] && $stable({s_bid[m],s_bresp[m]}));
      a_s_ar_stable: assert property (@(posedge clk) disable iff(!rst_n)
        s_arvalid[m] && !s_arready[m] |=> s_arvalid[m] && $stable({s_arid[m],s_araddr[m],s_arlen[m],s_arsize[m],s_arburst[m],s_arprot[m],s_arqos[m]}));
      a_s_r_stable: assert property (@(posedge clk) disable iff(!rst_n)
        s_rvalid[m] && !s_rready[m] |=> s_rvalid[m] && $stable({s_rid[m],s_rdata[m],s_rresp[m],s_rlast[m]}));
      a_s_wlast_known_when_valid: assert property (@(posedge clk) disable iff(!rst_n)
        s_wvalid[m] |-> !$isunknown(s_wlast[m]));
      a_s_rlast_known_when_valid: assert property (@(posedge clk) disable iff(!rst_n)
        s_rvalid[m] |-> !$isunknown(s_rlast[m]));
    end
    for (genvar s=0; s<NUM_SLAVES; s++) begin : g_target_sva
      a_m_aw_stable: assert property (@(posedge clk) disable iff(!rst_n)
        m_awvalid[s] && !m_awready[s] |=> m_awvalid[s] && $stable({m_awid[s],m_awaddr[s],m_awlen[s],m_awsize[s],m_awburst[s],m_awprot[s],m_awqos[s]}));
      a_m_w_stable: assert property (@(posedge clk) disable iff(!rst_n)
        m_wvalid[s] && !m_wready[s] |=> m_wvalid[s] && $stable({m_wdata[s],m_wstrb[s],m_wlast[s]}));
      a_m_ar_stable: assert property (@(posedge clk) disable iff(!rst_n)
        m_arvalid[s] && !m_arready[s] |=> m_arvalid[s] && $stable({m_arid[s],m_araddr[s],m_arlen[s],m_arsize[s],m_arburst[s],m_arprot[s],m_arqos[s]}));
      a_m_r_stable: assert property (@(posedge clk) disable iff(!rst_n)
        m_rvalid[s] && !m_rready[s] |=> m_rvalid[s] && $stable({m_rid[s],m_rdata[s],m_rresp[s],m_rlast[s]}));
      a_m_wlast_known_when_valid: assert property (@(posedge clk) disable iff(!rst_n)
        m_wvalid[s] |-> !$isunknown(m_wlast[s]));
      a_m_rlast_known_when_valid: assert property (@(posedge clk) disable iff(!rst_n)
        m_rvalid[s] |-> !$isunknown(m_rlast[s]));
    end
  endgenerate
endmodule
