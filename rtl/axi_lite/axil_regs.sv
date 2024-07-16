// AXI4-Lite slave: a small register bank.
//   reg 0..NREGS-2 : read/write, byte-strobe aware
//   reg NREGS-1    : read-only "write counter" (counts accepted writes); writing it returns SLVERR
//   address outside the bank returns SLVERR
// Handshake rules implemented (AMBA AXI4-Lite):
//   * VALID is never dependent on READY; once raised it holds until the handshake
//   * payload (BRESP/RDATA/RRESP) is stable while VALID && !READY
//   * write:  slave waits for BOTH awvalid and wvalid, then handshakes them together
//   * read:   arready when no read response is pending
module axil_regs #(
    parameter int ADDR_W = 6,
    parameter int NREGS  = 4          // 32-bit registers
) (
    input  logic        clk, rst_n,
    // write address / data / response
    input  logic [ADDR_W-1:0] awaddr,
    input  logic              awvalid,
    output logic              awready,
    input  logic [31:0]       wdata,
    input  logic [3:0]        wstrb,
    input  logic              wvalid,
    output logic              wready,
    output logic [1:0]        bresp,
    output logic              bvalid,
    input  logic              bready,
    // read address / data
    input  logic [ADDR_W-1:0] araddr,
    input  logic              arvalid,
    output logic              arready,
    output logic [31:0]       rdata,
    output logic [1:0]        rresp,
    output logic              rvalid,
    input  logic              rready
);
    localparam logic [1:0] OKAY = 2'b00, SLVERR = 2'b10;

