module route_owner_formal(input logic clk);
  logic rst_n=0,f_past_valid=0; logic [2:0] reset_count=0;
  (* anyseq *) logic aw_accept;
  (* anyseq *) logic owner_in;
  (* anyseq *) logic w_valid,target_ready,w_last;
  logic owner_valid=0,owner=0;
  logic w_ready;
  assign w_ready=owner_valid && target_ready;

  always @(posedge clk) begin
    f_past_valid<=1;
    if(reset_count<2) begin reset_count<=reset_count+1'b1; rst_n<=0; owner_valid<=0; owner<=0; end
    else begin
      rst_n<=1;
      if(!owner_valid && aw_accept) begin owner_valid<=1; owner<=owner_in; end
`ifdef FORMAL_BUG_ROUTE_UNLOCK
      else if(owner_valid && w_valid && w_ready) owner_valid<=0;
`else
      else if(owner_valid && w_valid && w_ready && w_last) owner_valid<=0;
`endif
      if(f_past_valid && $past(rst_n && owner_valid && !(w_valid && w_ready && w_last))) begin
        p_owner_held_until_last: assert(owner_valid);
        p_owner_identity_stable: assert(owner==$past(owner));
      end
      p_no_w_accept_without_owner: assert(!(w_valid && w_ready) || owner_valid);
      c_owner_handoff: cover(owner_valid && w_valid && w_ready && w_last);
    end
  end
endmodule
