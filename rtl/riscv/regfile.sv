// 32 x 32 register file: two read ports, one write port, x0 hard-wired to 0.
// Reads bypass a same-cycle write (write-first), so an instruction in ID sees the
// value being written back by the instruction in WB without an extra stall.
module regfile (
    input  logic        clk,
    input  logic        we,
    input  logic [4:0]  waddr,
    input  logic [31:0] wdata,
    input  logic [4:0]  raddr1, raddr2,
    output logic [31:0] rdata1, rdata2,
    input  logic [4:0]  dbg_addr,        // extra read port for the testbench
    output logic [31:0] dbg_data
);
    logic [31:0] rf [0:31];

