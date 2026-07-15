module id_tracker_formal(input logic clk);
  logic rst_n=0; logic [2:0] reset_count=0;
  (* anyseq *) logic accept,complete;
  (* anyseq *) logic [1:0] accept_id,complete_id;
  logic [3:0] active=0; logic accept_ready;
  integer count;

`ifdef FORMAL_BUG_ID_DUPLICATE
  assign accept_ready=1'b1;
`else
  assign accept_ready=!active[accept_id];
`endif
  always @* begin count=0; for(integer i=0;i<4;i=i+1) count=count+active[i]; end
  always @(posedge clk) begin
    if(reset_count<2) begin reset_count<=reset_count+1'b1; rst_n<=0; active<=0; end
    else begin
      rst_n<=1;
      assume(!complete || active[complete_id]);
      if(complete && active[complete_id]) active[complete_id]<=0;
      if(accept && accept_ready) active[accept_id]<=1;
      p_duplicate_blocked: assert(!(accept && accept_ready && active[accept_id]));
      p_count_bounded: assert(count<=4);
      p_complete_matching_only: assert(!complete || active[complete_id]);
      c_multiple_active_ids: cover(count>=2);
    end
  end
endmodule
