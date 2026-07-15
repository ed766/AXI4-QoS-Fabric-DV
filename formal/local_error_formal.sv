module local_error_formal(input logic clk);
  logic rst_n=0; logic [2:0] reset_count=0;
  (* anyseq *) logic request_valid,response_ready;
  logic request_ready,pending,response_valid,target_valid;
  logic [7:0] accepted=0,completed=0;
  assign request_ready=!pending;
  assign response_valid=pending;
`ifdef FORMAL_BUG_ERROR_LEAK
  assign target_valid=request_valid;
`else
  assign target_valid=1'b0;
`endif
  always @(posedge clk) begin
    if(reset_count<2) begin reset_count<=reset_count+1'b1; rst_n<=0; pending<=0; accepted<=0; completed<=0; end
    else begin
      rst_n<=1;
      if(request_valid && request_ready) begin pending<=1; accepted<=accepted+1'b1; end
      if(response_valid && response_ready) begin pending<=0; completed<=completed+1'b1; end
      p_local_error_no_target: assert(!target_valid);
      p_one_response_per_request: assert(completed<=accepted);
      p_pending_matches_count: assert((accepted-completed)<=1);
      c_local_error_response: cover(response_valid && response_ready);
    end
  end
endmodule
