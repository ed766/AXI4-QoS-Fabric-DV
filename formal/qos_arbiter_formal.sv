module qos_arbiter_formal(input logic clk);
  logic rst_n=0;
  logic [2:0] reset_count=0;
  (* anyseq *) logic [3:0] req;
  (* anyseq *) logic [15:0] qos_flat;
  logic grant_valid,age_override;
  logic [1:0] grant_idx;
  logic accept;
  logic highest_ok;

  assign accept=grant_valid;
  qos_arbiter #(.REQUESTERS(4),.STARVE_LIMIT(4),.AGE_W(3)) dut(.*);

  always @* begin
    highest_ok=1'b1;
    if(grant_valid && !age_override)
      for(integer i=0;i<4;i=i+1)
        if(req[i] && qos_flat[grant_idx*4 +: 4]<qos_flat[i*4 +: 4]) highest_ok=1'b0;
  end

  always @(posedge clk) begin
    if(reset_count<2) begin reset_count<=reset_count+1'b1; rst_n<=1'b0; end
    else rst_n<=1'b1;
    if(rst_n) begin
      p_grant_is_requested: assert(!grant_valid || req[grant_idx]);
      p_override_is_requested: assert(!age_override || (grant_valid && req[grant_idx]));
      p_grant_exists_for_request: assert(req=='0 || grant_valid);
      p_highest_qos_wins: assert(highest_ok);
      c_contention: cover($countones(req)>=2 && grant_valid);
      c_age_override: cover(age_override);
    end
  end
endmodule
