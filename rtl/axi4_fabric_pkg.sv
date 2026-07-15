package axi4_fabric_pkg;
  parameter int AXI_ADDR_W = 32;
  parameter int AXI_DATA_W = 64;
  parameter int AXI_ID_W   = 4;

  typedef enum logic [1:0] {
    AXI_RESP_OKAY   = 2'b00,
    AXI_RESP_EXOKAY = 2'b01,
    AXI_RESP_SLVERR = 2'b10,
    AXI_RESP_DECERR = 2'b11
  } axi_resp_e;

  function automatic logic burst_crosses_4k(
      input logic [AXI_ADDR_W-1:0] addr,
      input logic [7:0] len,
      input logic [2:0] size
  );
    logic [12:0] last_offset;
    last_offset = {1'b0, addr[11:0]} + (({5'b0, len} + 13'd1) << size) - 13'd1;
    return last_offset[12];
  endfunction

  function automatic logic transfer_aligned(
      input logic [AXI_ADDR_W-1:0] addr,
      input logic [2:0] size
  );
    logic [AXI_ADDR_W-1:0] mask;
    mask = ({{(AXI_ADDR_W-1){1'b0}}, 1'b1} << size) - 1'b1;
    return (addr & mask) == '0;
  endfunction
endpackage
