module async_fifo_formal(input logic clk);
  logic rst_n=0; logic [2:0] reset_count=0;
  (* anyseq *) logic w_valid, r_ready;
  (* anyseq *) logic [7:0] w_data;
  logic w_ready,r_valid; logic [7:0] r_data;
  logic [7:0] writes=0,reads=0;

  async_fifo_gray #(.WIDTH(8),.DEPTH(4)) dut(
    .wclk(clk),.wrst_n(rst_n),.w_valid,.w_ready,.w_data,
    .rclk(clk),.rrst_n(rst_n),.r_valid,.r_ready,.r_data);

  always @(posedge clk) begin
    if(reset_count<2) begin reset_count<=reset_count+1'b1; rst_n<=0; writes<=0; reads<=0; end
    else begin
      rst_n<=1;
      if(w_valid && w_ready) writes<=writes+1'b1;
`ifdef FORMAL_BUG_FIFO_COUNT
      if(r_ready) reads<=reads+1'b1;
`else
      if(r_valid && r_ready) reads<=reads+1'b1;
`endif
      p_no_underflow: assert(reads<=writes);
      p_no_overflow: assert(writes-reads<=4);
      c_fifo_wrap: cover(writes>=6 && reads>=2);
    end
  end
endmodule
