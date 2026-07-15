`timescale 1ns/1ps
module tb_qos_properties;
  logic clk=0,rst_n=0; always #1 clk=~clk;
  logic [3:0] req; logic [15:0] qos_flat; logic accept;
  logic grant_valid,age_override; logic [1:0] grant_idx;
  logic override_seen;
  qos_arbiter dut(.*);
  integer errors=0;
  task check(input bit cond,input string name); if(!cond) begin errors++; $display("PROPERTY_FAIL|%s",name); end endtask
  initial begin
    req=0;qos_flat=0;accept=0;override_seen=0;repeat(3)@(posedge clk);rst_n=1;
    for(int mask=1;mask<16;mask++) begin
      @(negedge clk); req=4'(mask); qos_flat={4'd2,4'd9,4'd4,4'd1}; accept=1; #1;
      check(grant_valid,"request produces grant"); check(req[grant_idx],"grant selects requester");
    end
    @(negedge clk); req=4'b0011;qos_flat={4'd0,4'd0,4'd15,4'd1};accept=1;
    repeat(34) begin @(negedge clk); if(age_override && grant_idx==0) override_seen=1; end
    #1; check(override_seen,"starvation override");
    $display("FORMAL_RESULT|properties=3|errors=%0d",errors);
    if(errors!=0)$fatal(1,"bounded properties failed"); $finish;
  end
endmodule
