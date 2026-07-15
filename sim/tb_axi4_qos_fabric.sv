`timescale 1ns/1ps
module tb_axi4_qos_fabric;
  localparam int NM=4, NS=4, AW=32, DW=64, IW=4, MIW=2, TIW=6;
  logic clk=0, rst_n=0, s3_clk=0, s3_rst_n=0;
  integer s3_half_ps;
  always #5 clk = ~clk;
  initial begin
    s3_half_ps=7000;
    void'($value$plusargs("S3_HALF_PS=%d",s3_half_ps));
    forever #(s3_half_ps*1ps) s3_clk = ~s3_clk;
  end

  logic [NM-1:0] s_awvalid, s_awready, s_wvalid, s_wready, s_wlast, s_bvalid, s_bready;
  logic [NM-1:0][IW-1:0] s_awid, s_bid;
  logic [NM-1:0][AW-1:0] s_awaddr;
  logic [NM-1:0][7:0] s_awlen;
  logic [NM-1:0][2:0] s_awsize, s_awprot;
  logic [NM-1:0][1:0] s_awburst, s_bresp;
  logic [NM-1:0][3:0] s_awqos;
  logic [NM-1:0][DW-1:0] s_wdata;
  logic [NM-1:0][DW/8-1:0] s_wstrb;
  logic [NM-1:0] s_arvalid, s_arready, s_rvalid, s_rready, s_rlast;
  logic [NM-1:0][IW-1:0] s_arid, s_rid;
  logic [NM-1:0][AW-1:0] s_araddr;
  logic [NM-1:0][7:0] s_arlen;
  logic [NM-1:0][2:0] s_arsize, s_arprot;
  logic [NM-1:0][1:0] s_arburst, s_rresp;
  logic [NM-1:0][3:0] s_arqos;
  logic [NM-1:0][DW-1:0] s_rdata;

  logic [NS-1:0] m_awvalid, m_awready, m_wvalid, m_wready, m_wlast, m_bvalid, m_bready;
  logic [NS-1:0][TIW-1:0] m_awid, m_bid;
  logic [NS-1:0][AW-1:0] m_awaddr;
  logic [NS-1:0][7:0] m_awlen;
  logic [NS-1:0][2:0] m_awsize, m_awprot;
  logic [NS-1:0][1:0] m_awburst, m_bresp;
  logic [NS-1:0][3:0] m_awqos;
  logic [NS-1:0][DW-1:0] m_wdata;
  logic [NS-1:0][DW/8-1:0] m_wstrb;
  logic [NS-1:0] m_arvalid, m_arready, m_rvalid, m_rready, m_rlast;
  logic [NS-1:0][TIW-1:0] m_arid, m_rid;
  logic [NS-1:0][AW-1:0] m_araddr;
  logic [NS-1:0][7:0] m_arlen;
  logic [NS-1:0][2:0] m_arsize, m_arprot;
  logic [NS-1:0][1:0] m_arburst, m_rresp;
  logic [NS-1:0][3:0] m_arqos;
  logic [NS-1:0][DW-1:0] m_rdata;
  logic [NS-1:0] mon_ar_age_override, mon_aw_age_override;
  integer errors=0, checks=0;
  integer trace_fd;
  string trace_path;
  string test_name;
  integer read_done [NM][1<<IW];
  integer write_done [NM][1<<IW];
  integer response_serial;
  integer read_order [NM][1<<IW];
  integer write_order [NM][1<<IW];
  integer configured_stall_percent;
  logic age_override_seen;

  axi4_qos_fabric #(.SECURE_ONLY(4'b0100)) dut (.*);
  axi4_fabric_assertions sva (.*);

  initial begin
    configured_stall_percent=0;
    void'($value$plusargs("STALL_PERCENT=%d",configured_stall_percent));
    response_serial=0;
    for(int m=0;m<NM;m++) for(int id=0;id<(1<<IW);id++) begin
      read_done[m][id]=0; write_done[m][id]=0; read_order[m][id]=-1; write_order[m][id]=-1;
    end
    if (!$value$plusargs("TRACE_FILE=%s", trace_path)) trace_path = "build/traces/smoke.jsonl";
    trace_fd = $fopen(trace_path, "w");
    if (trace_fd == 0) $fatal(1,"unable to open trace file %s",trace_path);
    $fdisplay(trace_fd,"{\"event\":\"config\",\"cycle\":0,\"stall_percent\":%0d,\"s3_half_ps\":%0d}",configured_stall_percent,s3_half_ps);
  end

  always_ff @(posedge clk) begin
    if(!rst_n) age_override_seen<=0;
    else if(|mon_ar_age_override || |mon_aw_age_override) age_override_seen<=1;
    if (rst_n) begin
      for (int m=0; m<NM; m++) begin
        if (s_awvalid[m] && s_awready[m])
          $fdisplay(trace_fd,"{\"event\":\"aw\",\"cycle\":%0d,\"master\":%0d,\"id\":%0d,\"address\":%0d,\"target\":%0d,\"legal\":%0d,\"len\":%0d,\"size\":%0d,\"burst\":%0d,\"qos\":%0d,\"prot\":%0d}",
            $time/10,m,s_awid[m],s_awaddr[m],dut.aw_target[m],dut.aw_legal[m],s_awlen[m]+1,s_awsize[m],s_awburst[m],s_awqos[m],s_awprot[m]);
        if (s_arvalid[m] && s_arready[m])
          $fdisplay(trace_fd,"{\"event\":\"ar\",\"cycle\":%0d,\"master\":%0d,\"id\":%0d,\"address\":%0d,\"target\":%0d,\"legal\":%0d,\"len\":%0d,\"size\":%0d,\"burst\":%0d,\"qos\":%0d,\"prot\":%0d}",
            $time/10,m,s_arid[m],s_araddr[m],dut.ar_target[m],dut.ar_legal[m],s_arlen[m]+1,s_arsize[m],s_arburst[m],s_arqos[m],s_arprot[m]);
        if (s_bvalid[m] && s_bready[m])
          begin
            write_done[m][s_bid[m]] <= write_done[m][s_bid[m]] + 1;
            response_serial <= response_serial + 1;
            write_order[m][s_bid[m]] <= response_serial;
            $fdisplay(trace_fd,"{\"event\":\"b\",\"cycle\":%0d,\"master\":%0d,\"id\":%0d,\"resp\":%0d}",$time/10,m,s_bid[m],s_bresp[m]);
          end
        if (s_rvalid[m] && s_rready[m])
          begin
            $fdisplay(trace_fd,"{\"event\":\"r\",\"cycle\":%0d,\"master\":%0d,\"id\":%0d,\"resp\":%0d,\"last\":%0d,\"data\":\"%016h\"}",$time/10,m,s_rid[m],s_rresp[m],s_rlast[m],s_rdata[m]);
            if (s_rlast[m]) begin
              read_done[m][s_rid[m]] <= read_done[m][s_rid[m]] + 1;
              response_serial <= response_serial + 1;
              read_order[m][s_rid[m]] <= response_serial;
            end
          end
        if (s_wvalid[m] && s_wready[m])
          $fdisplay(trace_fd,"{\"event\":\"w\",\"cycle\":%0d,\"master\":%0d,\"data\":\"%016h\",\"strb\":%0d,\"last\":%0d}",$time/10,m,s_wdata[m],s_wstrb[m],s_wlast[m]);
      end
      for (int s=0; s<NS; s++) begin
        if (m_awvalid[s] && m_awready[s])
          $fdisplay(trace_fd,"{\"event\":\"aw_grant\",\"cycle\":%0d,\"target\":%0d,\"master\":%0d,\"id\":%0d,\"qos\":%0d,\"age_override\":%0d}",
            $time/10,s,m_awid[s][5:4],m_awid[s][3:0],m_awqos[s],mon_aw_age_override[s]);
        if (m_arvalid[s] && m_arready[s])
          $fdisplay(trace_fd,"{\"event\":\"ar_grant\",\"cycle\":%0d,\"target\":%0d,\"master\":%0d,\"id\":%0d,\"qos\":%0d,\"age_override\":%0d}",
            $time/10,s,m_arid[s][5:4],m_arid[s][3:0],m_arqos[s],mon_ar_age_override[s]);
        if (m_wvalid[s] && m_wready[s])
          $fdisplay(trace_fd,"{\"event\":\"target_w\",\"cycle\":%0d,\"target\":%0d,\"data\":\"%016h\",\"strb\":%0d,\"last\":%0d}",$time/10,s,m_wdata[s],m_wstrb[s],m_wlast[s]);
        if (m_bvalid[s] && m_bready[s])
          $fdisplay(trace_fd,"{\"event\":\"target_b\",\"cycle\":%0d,\"target\":%0d,\"master\":%0d,\"id\":%0d,\"resp\":%0d}",$time/10,s,m_bid[s][5:4],m_bid[s][3:0],m_bresp[s]);
        if (m_rvalid[s] && m_rready[s])
          $fdisplay(trace_fd,"{\"event\":\"target_r\",\"cycle\":%0d,\"target\":%0d,\"master\":%0d,\"id\":%0d,\"resp\":%0d,\"last\":%0d,\"data\":\"%016h\"}",$time/10,s,m_rid[s][5:4],m_rid[s][3:0],m_rresp[s],m_rlast[s],m_rdata[s]);
      end
    end
  end

  always @(negedge rst_n)
    if (trace_fd != 0) $fdisplay(trace_fd,"{\"event\":\"reset\",\"cycle\":%0d,\"asserted\":1}",$time/10);
  always @(posedge rst_n)
    if (trace_fd != 0) $fdisplay(trace_fd,"{\"event\":\"reset\",\"cycle\":%0d,\"asserted\":0}",$time/10);

  generate for (genvar g=0; g<3; g++) begin : g_mem
    axi_memory_model #(.BASE_ADDR(AW'(g) << 28), .ERROR_ENABLE(g==2), .TARGET_INDEX(g)) mem (
      .clk, .rst_n,
      .awvalid(m_awvalid[g]), .awready(m_awready[g]), .awid(m_awid[g]), .awaddr(m_awaddr[g]),
      .awlen(m_awlen[g]), .awsize(m_awsize[g]), .awburst(m_awburst[g]),
      .wvalid(m_wvalid[g]), .wready(m_wready[g]), .wdata(m_wdata[g]), .wstrb(m_wstrb[g]), .wlast(m_wlast[g]),
      .bvalid(m_bvalid[g]), .bready(m_bready[g]), .bid(m_bid[g]), .bresp(m_bresp[g]),
      .arvalid(m_arvalid[g]), .arready(m_arready[g]), .arid(m_arid[g]), .araddr(m_araddr[g]),
      .arlen(m_arlen[g]), .arsize(m_arsize[g]), .arburst(m_arburst[g]),
      .rvalid(m_rvalid[g]), .rready(m_rready[g]), .rid(m_rid[g]), .rdata(m_rdata[g]),
      .rresp(m_rresp[g]), .rlast(m_rlast[g])
    );
  end endgenerate

  logic a_awvalid,a_awready,a_wvalid,a_wready,a_wlast,a_bvalid,a_bready;
  logic [TIW-1:0] a_awid,a_bid;
  logic [AW-1:0] a_awaddr;
  logic [7:0] a_awlen; logic [2:0] a_awsize,a_awprot; logic [1:0] a_awburst,a_bresp; logic [3:0] a_awqos;
  logic [DW-1:0] a_wdata; logic [DW/8-1:0] a_wstrb;
  logic a_arvalid,a_arready,a_rvalid,a_rready,a_rlast;
  logic [TIW-1:0] a_arid,a_rid; logic [AW-1:0] a_araddr; logic [7:0] a_arlen;
  logic [2:0] a_arsize,a_arprot; logic [1:0] a_arburst,a_rresp; logic [3:0] a_arqos; logic [DW-1:0] a_rdata;

  axi4_async_bridge #(.ID_W(TIW)) s3_bridge (
    .s_clk(clk), .s_rst_n(rst_n), .m_clk(s3_clk), .m_rst_n(s3_rst_n),
    .s_awvalid(m_awvalid[3]), .s_awready(m_awready[3]), .s_awid(m_awid[3]), .s_awaddr(m_awaddr[3]),
    .s_awlen(m_awlen[3]), .s_awsize(m_awsize[3]), .s_awburst(m_awburst[3]), .s_awprot(m_awprot[3]), .s_awqos(m_awqos[3]),
    .s_wvalid(m_wvalid[3]), .s_wready(m_wready[3]), .s_wdata(m_wdata[3]), .s_wstrb(m_wstrb[3]), .s_wlast(m_wlast[3]),
    .s_bvalid(m_bvalid[3]), .s_bready(m_bready[3]), .s_bid(m_bid[3]), .s_bresp(m_bresp[3]),
    .s_arvalid(m_arvalid[3]), .s_arready(m_arready[3]), .s_arid(m_arid[3]), .s_araddr(m_araddr[3]),
    .s_arlen(m_arlen[3]), .s_arsize(m_arsize[3]), .s_arburst(m_arburst[3]), .s_arprot(m_arprot[3]), .s_arqos(m_arqos[3]),
    .s_rvalid(m_rvalid[3]), .s_rready(m_rready[3]), .s_rid(m_rid[3]), .s_rdata(m_rdata[3]), .s_rresp(m_rresp[3]), .s_rlast(m_rlast[3]),
    .m_awvalid(a_awvalid), .m_awready(a_awready), .m_awid(a_awid), .m_awaddr(a_awaddr), .m_awlen(a_awlen),
    .m_awsize(a_awsize), .m_awburst(a_awburst), .m_awprot(a_awprot), .m_awqos(a_awqos),
    .m_wvalid(a_wvalid), .m_wready(a_wready), .m_wdata(a_wdata), .m_wstrb(a_wstrb), .m_wlast(a_wlast),
    .m_bvalid(a_bvalid), .m_bready(a_bready), .m_bid(a_bid), .m_bresp(a_bresp),
    .m_arvalid(a_arvalid), .m_arready(a_arready), .m_arid(a_arid), .m_araddr(a_araddr), .m_arlen(a_arlen),
    .m_arsize(a_arsize), .m_arburst(a_arburst), .m_arprot(a_arprot), .m_arqos(a_arqos),
    .m_rvalid(a_rvalid), .m_rready(a_rready), .m_rid(a_rid), .m_rdata(a_rdata), .m_rresp(a_rresp), .m_rlast(a_rlast)
  );
  axi_memory_model #(.BASE_ADDR(32'h3000_0000), .TARGET_INDEX(3)) async_mem (
    .clk(s3_clk), .rst_n(s3_rst_n),
    .awvalid(a_awvalid), .awready(a_awready), .awid(a_awid), .awaddr(a_awaddr), .awlen(a_awlen), .awsize(a_awsize), .awburst(a_awburst),
    .wvalid(a_wvalid), .wready(a_wready), .wdata(a_wdata), .wstrb(a_wstrb), .wlast(a_wlast),
    .bvalid(a_bvalid), .bready(a_bready), .bid(a_bid), .bresp(a_bresp),
    .arvalid(a_arvalid), .arready(a_arready), .arid(a_arid), .araddr(a_araddr), .arlen(a_arlen), .arsize(a_arsize), .arburst(a_arburst),
    .rvalid(a_rvalid), .rready(a_rready), .rid(a_rid), .rdata(a_rdata), .rresp(a_rresp), .rlast(a_rlast)
  );

  task automatic check_cond(input bit cond, input string name);
    checks++;
    if (!cond) begin errors++; $display("CHECK_FAIL|%s",name); end
    else $display("CHECK_PASS|%s",name);
  endtask

  task automatic issue_write_cfg(input int m, input logic[IW-1:0] id, input logic[AW-1:0] addr,
      input int beats, input logic[2:0] size, input logic[1:0] burst, input logic[3:0] qos,
      input logic[2:0] prot, input logic[DW-1:0] seed, input logic[DW/8-1:0] strb,
      output logic[1:0] resp);
    @(negedge clk);
    s_awid[m]=id; s_awaddr[m]=addr; s_awlen[m]=8'(beats-1); s_awsize[m]=size;
    s_awburst[m]=burst; s_awprot[m]=prot; s_awqos[m]=qos; s_awvalid[m]=1;
    do @(posedge clk); while (!s_awready[m]);
    @(negedge clk); s_awvalid[m]=0;
    for (int b=0;b<beats;b++) begin
      s_wdata[m]=seed+DW'(b); s_wstrb[m]=strb; s_wlast[m]=(b==beats-1); s_wvalid[m]=1;
      do @(posedge clk); while (!s_wready[m]);
      @(negedge clk); s_wvalid[m]=0;
    end
    do @(posedge clk); while (!s_bvalid[m]);
    resp=s_bresp[m];
    check_cond(s_bid[m]==id,"write response ID");
    @(negedge clk);
  endtask

  task automatic issue_write(input int m, input logic[IW-1:0] id, input logic[AW-1:0] addr,
      input int beats, input logic[3:0] qos, input logic[2:0] prot, input logic[DW-1:0] seed,
      output logic[1:0] resp);
    issue_write_cfg(m,id,addr,beats,3,1,qos,prot,seed,'1,resp);
  endtask

  task automatic issue_read_cfg(input int m, input logic[IW-1:0] id, input logic[AW-1:0] addr,
      input int beats, input logic[2:0] size, input logic[1:0] burst, input logic[3:0] qos,
      input logic[2:0] prot, input logic[DW-1:0] expected, input bit check_data,
      output logic[1:0] resp);
    @(negedge clk);
    s_arid[m]=id; s_araddr[m]=addr; s_arlen[m]=8'(beats-1); s_arsize[m]=size;
    s_arburst[m]=burst; s_arprot[m]=prot; s_arqos[m]=qos; s_arvalid[m]=1;
    do @(posedge clk); while (!s_arready[m]);
    @(negedge clk); s_arvalid[m]=0;
    for (int b=0;b<beats;b++) begin
      do @(posedge clk); while (!s_rvalid[m]);
      resp=s_rresp[m];
      check_cond(s_rid[m]==id,"read response ID");
      check_cond(s_rlast[m]==(b==beats-1),"read last placement");
      if (check_data) check_cond(s_rdata[m]==expected+DW'(b),"read data");
      @(negedge clk);
    end
  endtask

  task automatic issue_read(input int m, input logic[IW-1:0] id, input logic[AW-1:0] addr,
      input int beats, input logic[3:0] qos, input logic[2:0] prot, input logic[DW-1:0] expected,
      input bit check_data, output logic[1:0] resp);
    issue_read_cfg(m,id,addr,beats,3,1,qos,prot,expected,check_data,resp);
  endtask

  task automatic submit_ar(input int m, input logic[IW-1:0] id, input logic[AW-1:0] addr,
      input int beats, input logic[3:0] qos);
    @(negedge clk);
    s_arid[m]=id; s_araddr[m]=addr; s_arlen[m]=8'(beats-1); s_arsize[m]=3;
    s_arburst[m]=1; s_arprot[m]=0; s_arqos[m]=qos; s_arvalid[m]=1;
    do @(posedge clk); while (!s_arready[m]);
    @(negedge clk); s_arvalid[m]=0;
  endtask

  task automatic submit_aw(input int m, input logic[IW-1:0] id, input logic[AW-1:0] addr,
      input int beats, input logic[3:0] qos);
    @(negedge clk);
    s_awid[m]=id; s_awaddr[m]=addr; s_awlen[m]=8'(beats-1); s_awsize[m]=3;
    s_awburst[m]=1; s_awprot[m]=0; s_awqos[m]=qos; s_awvalid[m]=1;
    do @(posedge clk); while (!s_awready[m]);
    @(negedge clk); s_awvalid[m]=0;
  endtask

  task automatic stream_ar(input int m,input int count,input logic[3:0] qos,input logic[AW-1:0] base);
    @(negedge clk);
    s_arvalid[m]=1; s_arlen[m]=0; s_arsize[m]=3; s_arburst[m]=1; s_arprot[m]=0; s_arqos[m]=qos;
    for(int n=0;n<count;n++) begin
      s_arid[m]=IW'(n+2); s_araddr[m]=base+AW'(n*8);
      do @(posedge clk); while(!s_arready[m]);
      @(negedge clk);
    end
    s_arvalid[m]=0;
  endtask

  task automatic send_w(input int m, input int beats, input logic[DW-1:0] seed);
    for (int b=0;b<beats;b++) begin
      s_wdata[m]=seed+DW'(b); s_wstrb[m]='1; s_wlast[m]=(b==beats-1); s_wvalid[m]=1;
      do @(posedge clk); while (!s_wready[m]);
      @(negedge clk); s_wvalid[m]=0;
    end
  endtask

  task automatic wait_read_id(input int m,input logic[IW-1:0] id,input int prior);
    int timeout=0;
    while (read_done[m][id] == prior && timeout < 500) begin @(posedge clk); timeout++; end
    check_cond(timeout < 500,$sformatf("read completion m%0d id%0d",m,id));
  endtask

  task automatic wait_write_id(input int m,input logic[IW-1:0] id,input int prior);
    int timeout=0;
    while (write_done[m][id] == prior && timeout < 500) begin @(posedge clk); timeout++; end
    check_cond(timeout < 500,$sformatf("write completion m%0d id%0d",m,id));
  endtask

  task automatic scenario_smoke();
    logic [1:0] resp;
    issue_write(0,4'h1,32'h0000_0040,4,0,0,64'h1000,resp); check_cond(resp==0,"mapped burst write OKAY");
    issue_read(0,4'h2,32'h0000_0040,4,0,0,64'h1000,1,resp); check_cond(resp==0,"mapped burst read OKAY");
    issue_read(1,4'h3,32'hF000_0000,1,0,0,0,0,resp); check_cond(resp==2'b11,"unmapped read DECERR");
    issue_write(1,4'h4,32'hF000_0000,1,0,0,64'h55,resp); check_cond(resp==2'b11,"unmapped write DECERR");
    issue_read(2,4'h5,32'h2000_0000,1,0,3'b010,0,0,resp); check_cond(resp==2'b11,"nonsecure secure-target DECERR");
    issue_write(2,4'hb,32'h2000_0080,1,0,3'b010,64'hbad,resp); check_cond(resp==2'b11,"nonsecure secure-target write DECERR");
    issue_read(2,4'h6,32'h2000_0000,1,0,3'b000,0,0,resp); check_cond(resp==0,"secure target allowed");
    issue_write(3,4'h7,32'h3000_0080,2,5,0,64'hCAFE_0000,resp); check_cond(resp==0,"async target write");
    issue_read(3,4'h8,32'h3000_0080,2,5,0,64'hCAFE_0000,1,resp); check_cond(resp==0,"async target read");
    @(negedge clk);
    s_arid[0]=9; s_araddr[0]=32'h1000_0100; s_arlen[0]=0; s_arsize[0]=3; s_arburst[0]=1; s_arqos[0]=1; s_arvalid[0]=1;
    s_arid[1]=10; s_araddr[1]=32'h1000_0180; s_arlen[1]=0; s_arsize[1]=3; s_arburst[1]=1; s_arqos[1]=15; s_arvalid[1]=1;
    #1; check_cond(m_arvalid[1] && m_arid[1][5:4]==1,"higher QoS first grant");
    do @(posedge clk); while (!s_arready[1]); @(negedge clk); s_arvalid[1]=0;
    do @(posedge clk); while (!s_arready[0]); @(negedge clk); s_arvalid[0]=0;
    repeat(12) @(posedge clk);
  endtask

  task automatic scenario_target_matrix();
    logic [1:0] resp; logic [31:0] addr;
    for(int m=0;m<NM;m++) begin
      addr=32'(m)<<28; issue_write(m,4'(m+1),addr+32'h200,2,4'(m),0,64'h1100+(64'(m)<<8),resp);
      check_cond(resp==0,$sformatf("target%0d write",m));
      issue_read(m,4'(m+5),addr+32'h200,2,4'(m),0,64'h1100+(64'(m)<<8),1,resp);
      check_cond(resp==0,$sformatf("target%0d read",m));
    end
  endtask

  task automatic scenario_burst_size_strobe();
    logic [1:0] resp; int beats;
    for(int bucket=0;bucket<5;bucket++) begin
      beats=1<<bucket;
      issue_write(0,4'(bucket),32'h0000_1000+32'(bucket*256),beats,0,0,64'h2000+(64'(bucket)<<8),resp);
      check_cond(resp==0,$sformatf("burst length %0d",beats));
      issue_read(0,4'(bucket+5),32'h0000_1000+32'(bucket*256),beats,0,0,64'h2000+(64'(bucket)<<8),1,resp);
      check_cond(resp==0,$sformatf("burst read length %0d",beats));
    end
    for(int size=0;size<4;size++) begin
      issue_write_cfg(1,4'(size+5),32'h1000_2000+32'(size*64),1,3'(size),1,0,0,
        64'h0123_4567_89ab_cdef,8'(1<<size)-1,resp);
      check_cond(resp==0,$sformatf("transfer size %0d",1<<size));
    end
    for(int mask=1;mask<16;mask++) begin
      issue_write_cfg(0,4'(mask),32'h0000_3000+32'(mask*8),1,3,1,0,0,64'hf0e1_d2c3_b4a5_9687,8'(mask),resp);
      check_cond(resp==0,$sformatf("partial strobe %0h",mask));
    end
  endtask

  task automatic scenario_local_errors();
    logic [1:0] resp;
    issue_read_cfg(0,1,32'hf000_0000,1,3,1,0,0,0,0,resp); check_cond(resp==3,"unmapped local error");
    issue_read_cfg(0,5,32'h0001_0000,1,3,1,0,0,0,0,resp); check_cond(resp==3,"decode window boundary error");
    issue_read_cfg(0,2,32'h0000_0004,1,3,1,0,0,0,0,resp); check_cond(resp==3,"misaligned local error");
    issue_read_cfg(0,3,32'h0000_0040,1,3,0,0,0,0,0,resp); check_cond(resp==3,"unsupported burst local error");
    issue_read_cfg(0,4,32'h0000_0ff8,2,3,1,0,0,0,0,resp); check_cond(resp==3,"4k crossing local error");
  endtask

  task automatic scenario_downstream_errors();
    logic [1:0] resp;
    issue_read(2,1,32'h2000_f000,2,0,0,0,0,resp); check_cond(resp==2,"downstream read SLVERR");
    issue_write(2,2,32'h2000_f000,2,0,0,64'hdead,resp); check_cond(resp==2,"downstream write SLVERR");
  endtask

  task automatic scenario_parallel(input int contenders,input bit writes);
    logic [1:0] resp[4];
    fork
      if(contenders>0) begin if(writes) issue_write(0,1,32'h1000_4000,4,1,0,64'h100,resp[0]); else issue_read(0,1,32'h1000_4000,4,1,0,0,0,resp[0]); end
      if(contenders>1) begin if(writes) issue_write(1,2,32'h1000_4080,4,2,0,64'h200,resp[1]); else issue_read(1,2,32'h1000_4080,4,2,0,0,0,resp[1]); end
      if(contenders>2) begin if(writes) issue_write(2,3,32'h1000_4100,4,3,0,64'h300,resp[2]); else issue_read(2,3,32'h1000_4100,4,3,0,0,0,resp[2]); end
      if(contenders>3) begin if(writes) issue_write(3,4,32'h1000_4180,4,4,0,64'h400,resp[3]); else issue_read(3,4,32'h1000_4180,4,4,0,0,0,resp[3]); end
    join
    for(int m=0;m<contenders;m++) check_cond(resp[m]==0,$sformatf("parallel master %0d",m));
  endtask

  task automatic scenario_equal_qos_rr();
    logic[1:0] resp[4];
    fork
      issue_read(0,1,32'h1000_5000,1,5,0,0,0,resp[0]);
      issue_read(1,2,32'h1000_5008,1,5,0,0,0,resp[1]);
      issue_read(2,3,32'h1000_5010,1,5,0,0,0,resp[2]);
      issue_read(3,4,32'h1000_5018,1,5,0,0,0,resp[3]);
    join
    for(int m=0;m<4;m++) check_cond(resp[m]==0,$sformatf("equal QoS master %0d serviced",m));
  endtask

  task automatic scenario_starvation_override();
    logic[1:0] low_resp;
    fork
      issue_read(0,1,32'h1000_6000,1,0,0,0,0,low_resp);
      stream_ar(1,35,15,32'h1000_6100);
    join
    repeat(20) @(posedge clk);
    check_cond(low_resp==0,"starved request eventually serviced");
    check_cond(age_override_seen,"starvation override observed");
  endtask

  task automatic scenario_outstanding_ids();
    int before_r[4]; int before_w[4];
    for (int id=0;id<4;id++) before_r[id]=read_done[0][id+1];
    // The asynchronous request is intentionally issued first; faster targets may complete later IDs first.
    s_rready[0]=0;
    submit_ar(0,1,32'h3000_0200,2,1);
    submit_ar(0,2,32'h0000_0200,2,1);
    submit_ar(0,3,32'h1000_0200,2,1);
    submit_ar(0,4,32'h2000_0200,2,1);
    check_cond($countones(dut.rd_id_active[0])==4,"four same-master read IDs active");
    @(negedge clk); s_arid[0]=1; s_araddr[0]=32'h0000_0800; s_arlen[0]=0; s_arsize[0]=3;
    s_arburst[0]=1; s_arprot[0]=0; s_arqos[0]=0; s_arvalid[0]=1;
    #1; check_cond(!s_arready[0],"duplicate active read ID backpressured");
    s_arvalid[0]=0;
    s_rready[0]=1;
    for (int id=0;id<4;id++) wait_read_id(0,IW'(id+1),before_r[id]);
    check_cond(read_order[0][2] < read_order[0][1],"distinct IDs may complete out of order");

    for (int id=0;id<4;id++) before_w[id]=write_done[0][id+5];
    submit_aw(0,5,32'h0000_1000,2,1);
    submit_aw(0,6,32'h1000_1000,2,1);
    submit_aw(0,7,32'h2000_1000,2,1);
    submit_aw(0,8,32'h3000_1000,2,1);
    check_cond($countones(dut.wr_id_active[0])==4,"four same-master write IDs active");
    send_w(0,2,64'h5000); send_w(0,2,64'h6000); send_w(0,2,64'h7000); send_w(0,2,64'h8000);
    for (int id=0;id<4;id++) wait_write_id(0,IW'(id+5),before_w[id]);
  endtask

  task automatic scenario_reset_recovery();
    logic [1:0] resp;
    issue_read(0,1,32'h0000_0400,1,0,0,0,0,resp); check_cond(resp==0,"pre-reset request");
    @(negedge clk); rst_n=0; s3_rst_n=0; repeat(4) @(posedge clk); rst_n=1; repeat(3) @(posedge s3_clk); s3_rst_n=1;
    issue_read(1,2,32'h1000_0400,1,0,0,0,0,resp); check_cond(resp==0,"post-reset request");
  endtask

  task automatic scenario_async_cdc_stress();
    logic[1:0] resp; int prior;
    for(int n=0;n<12;n++) begin
      issue_write(3,IW'(n),32'h3000_4000+AW'(n*16),2,4'(n),0,64'hc0dc_0000+DW'(n*16),resp);
      check_cond(resp==0,"async FIFO wrap write");
      issue_read(3,IW'(n),32'h3000_4000+AW'(n*16),2,4'(n),0,64'hc0dc_0000+DW'(n*16),1,resp);
      check_cond(resp==0,"async FIFO wrap read");
    end
    prior=read_done[3][15]; s_rready[3]=0;
    submit_ar(3,15,32'h3000_5000,4,0);
    repeat(3) @(posedge clk);
    rst_n=0; repeat(2) @(posedge clk); s3_rst_n=0; repeat(3) @(posedge s3_clk);
    rst_n=1; repeat(2) @(posedge clk); s3_rst_n=1; s_rready[3]=1; repeat(12) @(posedge clk);
    check_cond(read_done[3][15]==prior,"no post-reset ghost response");
    issue_read(3,14,32'h3000_5100,1,0,0,0,0,resp);
    check_cond(resp==0,"async bridge recovers after skewed reset");
  endtask

  task automatic scenario_random();
    integer operations,read_percent,error_percent,security_percent,burst_max;
    int unsigned seed,rv; integer m,target,beats; logic [31:0] addr; logic [1:0] resp; bit do_read,expect_error;
    if(!$value$plusargs("SEED=%d",seed)) seed=1;
    if(!$value$plusargs("OPERATIONS=%d",operations)) operations=50;
    if(!$value$plusargs("READ_PERCENT=%d",read_percent)) read_percent=50;
    if(!$value$plusargs("ERROR_PERCENT=%d",error_percent)) error_percent=0;
    if(!$value$plusargs("SECURITY_PERCENT=%d",security_percent)) security_percent=0;
    if(!$value$plusargs("BURST_MAX=%d",burst_max)) burst_max=4;
    void'($urandom(seed));
    for(int op=0;op<operations;op++) begin
      rv=$urandom(); m=op%4; target=((op/4)+seed)%4; do_read=((rv>>8)%100)<read_percent;
      case((rv>>16)%4) 0:beats=1; 1:beats=(burst_max>=2)?2:1; 2:beats=(burst_max>=4)?4:1; default:beats=(burst_max>=8)?8:1; endcase
      addr=(32'(target)<<28)+32'h8000+32'(((rv>>12)&32'h0000_03f0)); expect_error=0;
      if(((rv>>20)%100)<error_percent) begin target=2; addr=32'h2000_f000; expect_error=1; end
      if(target==2 && ((rv>>24)%100)<security_percent) begin
        issue_read(m,4'(op),addr,beats,4'((rv>>28)&15),3'b010,0,0,resp); check_cond(resp==3,"random security reject");
      end else if(do_read) begin
        issue_read(m,4'(op),addr,beats,4'((rv>>28)&15),0,0,0,resp); check_cond(resp==(expect_error?2:0),"random read response");
      end else begin
        issue_write(m,4'(op),addr,beats,4'((rv>>28)&15),0,64'(rv)^64'(op),resp); check_cond(resp==(expect_error?2:0),"random write response");
      end
    end
  endtask

  initial begin
    s_awvalid='0; s_wvalid='0; s_bready='1; s_arvalid='0; s_rready='1;
    s_awid='0; s_awaddr='0; s_awlen='0; s_awsize='0; s_awburst='0; s_awprot='0; s_awqos='0;
    s_wdata='0; s_wstrb='0; s_wlast='0;
    s_arid='0; s_araddr='0; s_arlen='0; s_arsize='0; s_arburst='0; s_arprot='0; s_arqos='0;
    repeat(5) @(posedge clk); rst_n=1;
    repeat(4) @(posedge s3_clk); s3_rst_n=1;
    if(!$value$plusargs("TEST_NAME=%s",test_name)) test_name="smoke";
    case(test_name)
      "smoke","qos_priority","security_access","async_target": scenario_smoke();
      "async_cdc_stress": scenario_async_cdc_stress();
      "target_matrix","single_master_rw": scenario_target_matrix();
      "burst_lengths","transfer_sizes","partial_strobes": scenario_burst_size_strobe();
      "malformed_unmapped","malformed_misaligned","malformed_burst","boundary_4k","local_error_matrix": scenario_local_errors();
      "downstream_errors": scenario_downstream_errors();
      "contention_two": scenario_parallel(2,0);
      "equal_qos_rr": scenario_equal_qos_rr();
      "starvation_override": scenario_starvation_override();
      "contention_four": scenario_parallel(4,0);
      "outstanding_ids": scenario_outstanding_ids();
      "write_burst_lock","aw_delayed_w": scenario_parallel(4,1);
      "channel_backpressure_25","channel_backpressure_75": scenario_target_matrix();
      "reset_recovery","reset_outstanding": scenario_reset_recovery();
      "random_mixed_smoke": scenario_random();
      default: begin errors++; $display("CHECK_FAIL|unknown test %s",test_name); end
    endcase
    $display("DV_RESULT|test=%s|checks=%0d|errors=%0d",test_name,checks,errors);
    $fclose(trace_fd);
    if (errors != 0) $fatal(1,"fabric smoke failed");
    $finish;
  end

  initial begin
    repeat(200000) @(posedge clk);
    $fatal(1,"timeout");
  end
endmodule
