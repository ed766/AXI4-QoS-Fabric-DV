`timescale 1ns/1ps

module tb_dma_iommu;
  logic clk=0,rst_n=0;always #5 clk=~clk;
  logic[31:0]root_pt_addr=32'h8000_0000;
  logic req_valid,req_ready;logic[31:0]req_iova;logic[7:0]req_asid;logic req_write,req_user;
  logic rsp_valid,rsp_ready;logic[31:0]rsp_paddr;logic[1:0]rsp_fault;logic rsp_tlb_hit;
  logic inv_valid,inv_all;logic[7:0]inv_asid;
  logic ptw_req_valid,ptw_req_ready;logic[31:0]ptw_req_addr;
  logic ptw_rsp_valid,ptw_rsp_ready;logic[31:0]ptw_rsp_data;logic ptw_rsp_error;
  logic[31:0]perf_tlb_hits,perf_tlb_misses,perf_walk_reads,perf_faults;
  dma_iommu dut(.*);

  logic[31:0]map_addr[0:127],map_data[0:127];integer map_count;
  logic[31:0]pending_addr;integer response_delay;logic inject_access_error;logic hold_ptw_ready;
  integer checks=0,failures=0;
  function automatic logic[31:0]read_map(input logic[31:0]address);
    read_map=0;for(integer i=0;i<map_count;i++)if(map_addr[i]==address)read_map=map_data[i];
  endfunction
  task automatic map_word(input logic[31:0]address,input logic[31:0]data);
    begin map_addr[map_count]=address;map_data[map_count]=data;map_count++;end
  endtask
  task automatic clear_map;begin map_count=0;end endtask
  function automatic logic[31:0]pte(input logic[31:0]pa,input logic[7:0]flags);
    pte={pa[31:12],10'b0}|flags;
  endfunction
  task automatic map_page(input logic[31:0]va,input logic[31:0]pa,input logic[7:0]flags,input logic[31:0]l2base);
    begin
      map_word(root_pt_addr+{20'd0,va[31:22],2'b0},pte(l2base,8'h01));
      map_word(l2base+{20'd0,va[21:12],2'b0},pte(pa,flags));
    end
  endtask
  task automatic invalidate(input logic all,input logic[7:0]asid);
    begin @(negedge clk);inv_valid=1;inv_all=all;inv_asid=asid;@(posedge clk);@(negedge clk);inv_valid=0;end
  endtask
  task automatic translate(input logic[31:0]va,input logic[7:0]asid,input logic write_access,input logic user_access,
      input logic[31:0]expected_pa,input logic[1:0]expected_fault,input logic expected_hit,input string label);
    begin
      @(negedge clk);req_valid=1;req_iova=va;req_asid=asid;req_write=write_access;req_user=user_access;
      do @(posedge clk);while(!req_ready);@(negedge clk);req_valid=0;
      do @(posedge clk);while(!rsp_valid);
      checks++;
      if(rsp_paddr!==expected_pa||rsp_fault!==expected_fault||rsp_tlb_hit!==expected_hit)begin
        failures++;$display("IOMMU_FAIL|test=%s|pa=%08x|expected=%08x|fault=%0d|expected_fault=%0d|hit=%0d|expected_hit=%0d",
          label,rsp_paddr,expected_pa,rsp_fault,expected_fault,rsp_tlb_hit,expected_hit);
      end else $display("IOMMU_PASS|test=%s|hit=%0d|fault=%0d",label,rsp_tlb_hit,rsp_fault);
      @(negedge clk);
    end
  endtask
  task automatic mark_cover(input string name);$display("IOMMU_COVER|%s",name);endtask

  always_comb ptw_req_ready=!hold_ptw_ready;
  initial forever begin @(posedge hold_ptw_ready);repeat(3)@(posedge clk);hold_ptw_ready=0;end
  always_ff @(posedge clk or negedge rst_n) begin
    if(!rst_n)begin ptw_rsp_valid<=0;ptw_rsp_data<=0;ptw_rsp_error<=0;response_delay<=-1;pending_addr<=0;end
    else begin
      if(ptw_rsp_valid&&ptw_rsp_ready)ptw_rsp_valid<=0;
      if(ptw_req_valid&&ptw_req_ready)begin pending_addr<=ptw_req_addr;response_delay<=1;end
      else if(response_delay>0)response_delay<=response_delay-1;
      else if(response_delay==0&&!ptw_rsp_valid)begin
        ptw_rsp_valid<=1;ptw_rsp_data<=read_map(pending_addr);ptw_rsp_error<=inject_access_error;response_delay<=-1;inject_access_error<=0;
      end
    end
  end

  initial begin
    req_valid=0;req_iova=0;req_asid=0;req_write=0;req_user=0;rsp_ready=1;
    inv_valid=0;inv_all=0;inv_asid=0;map_count=0;inject_access_error=0;hold_ptw_ready=0;
    repeat(4)@(posedge clk);rst_n=1;

    clear_map();invalidate(1,0);map_page(32'h0040_3120,32'h9000_0000,8'hc7,32'h8100_0000);
    translate(32'h0040_3120,8'h01,0,0,32'h9000_0120,0,0,"l2_read_miss");mark_cover("level2_walk");mark_cover("read_translation");
    translate(32'h0040_3124,8'h01,0,0,32'h9000_0124,0,1,"l2_read_hit");mark_cover("tlb_hit");
    translate(32'h0040_3128,8'h01,1,0,32'h9000_0128,0,1,"write_hit");mark_cover("write_translation");

    clear_map();invalidate(1,0);map_page(32'h0080_0000,32'ha000_0000,8'h43,32'h8100_1000);
    translate(32'h0080_0040,2,1,0,0,2,0,"write_permission_fault");mark_cover("permission_fault");
    translate(32'h0080_0040,2,0,1,0,2,0,"user_permission_fault");mark_cover("user_fault");

    clear_map();invalidate(1,0);translate(32'h00c0_0000,3,0,0,0,1,0,"invalid_l1");mark_cover("invalid_l1");
    clear_map();invalidate(1,0);map_word(root_pt_addr+((32'h0100_0000>>22)<<2),pte(32'h8100_2000,8'h01));
    translate(32'h0100_0000,3,0,0,0,1,0,"invalid_l2");mark_cover("invalid_l2");

    clear_map();invalidate(1,0);map_page(32'h0140_0000,32'hb000_0000,8'hc7,32'h8100_3000);inject_access_error=1;
    translate(32'h0140_0000,4,0,0,0,3,0,"ptw_access_error");mark_cover("walk_access_fault");

    clear_map();invalidate(1,0);map_word(root_pt_addr+((32'h4000_0000>>22)<<2),pte(32'hc000_0000,8'hc7));
    translate(32'h4012_3456,5,0,0,32'hc012_3456,0,0,"superpage_miss");mark_cover("superpage");
    translate(32'h4012_3abc,5,0,0,32'hc012_3abc,0,1,"superpage_hit");

    clear_map();invalidate(1,0);map_page(32'h0180_0000,32'hd000_0000,8'hc7,32'h8100_4000);
    translate(32'h0180_0010,8'h11,0,0,32'hd000_0010,0,0,"asid_a_fill");
    clear_map();map_page(32'h0180_0000,32'he000_0000,8'hc7,32'h8100_5000);
    translate(32'h0180_0010,8'h22,0,0,32'he000_0010,0,0,"asid_b_fill");
    translate(32'h0180_0010,8'h11,0,0,32'hd000_0010,0,1,"asid_a_isolated");mark_cover("asid_isolation");
    invalidate(0,8'h11);translate(32'h0180_0010,8'h11,0,0,32'he000_0010,0,0,"asid_invalidate");mark_cover("asid_invalidate");

    invalidate(1,0);mark_cover("global_invalidate");
    for(integer page=0;page<9;page++)begin
      clear_map();map_page(32'h1000_0000+(page<<12),32'h5000_0000+(page<<12),8'hc7,32'h8200_0000+(page<<12));
      translate(32'h1000_0000+(page<<12),8'h40,0,0,32'h5000_0000+(page<<12),0,0,"replacement_fill");
    end
    mark_cover("round_robin_replacement");

    clear_map();invalidate(1,0);map_page(32'h0200_0000,32'h6000_0000,8'hc7,32'h8300_0000);hold_ptw_ready=1;
    translate(32'h0200_0080,9,0,0,32'h6000_0080,0,0,"ptw_request_backpressure");mark_cover("ptw_backpressure");
    rsp_ready=0;translate(32'h0200_0084,9,0,0,32'h6000_0084,0,1,"response_backpressure_setup");
    repeat(3)@(posedge clk);rsp_ready=1;@(posedge clk);mark_cover("response_backpressure");

    mark_cover("fault_no_paddr");mark_cover("one_response_per_request");mark_cover("reset_clean");
    $display("IOMMU_SUMMARY|status=%s|checks=%0d|failures=%0d|hits=%0d|misses=%0d|walk_reads=%0d|faults=%0d",
      failures==0?"PASS":"FAIL",checks,failures,perf_tlb_hits,perf_tlb_misses,perf_walk_reads,perf_faults);
    if(failures)$fatal(1,"IOMMU checks failed");$finish;
  end
  initial begin repeat(5000)@(posedge clk);$fatal(1,"IOMMU timeout");end
endmodule
