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

    always_ff @(posedge clk)
        if (we && waddr != 5'd0) rf[waddr] <= wdata;

    assign rdata1   = (raddr1 == 5'd0) ? 32'd0 : (we && waddr == raddr1) ? wdata : rf[raddr1];
    assign rdata2   = (raddr2 == 5'd0) ? 32'd0 : (we && waddr == raddr2) ? wdata : rf[raddr2];
    assign dbg_data = (dbg_addr == 5'd0) ? 32'd0 : rf[dbg_addr];
endmodule
