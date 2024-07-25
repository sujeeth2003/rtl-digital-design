// 5-stage in-order RV32I core:  IF -> ID -> EX -> MEM -> WB
//   * forwarding from MEM and WB into EX, one-cycle load-use stall, branch/jump resolved
//     in EX with a 2-cycle flush (see hazard_unit.sv)
//   * instruction and data memory are outside the core (asynchronous-read RAMs)
//   * EBREAK stops the core: everything younger than the EBREAK is squashed, so the final
//     architectural state is exactly "all instructions before the EBREAK executed".
module riscv_core (
    input  logic        clk, rst_n,
    // instruction memory (asynchronous read)
    output logic [31:0] imem_addr,
    input  logic [31:0] imem_rdata,
    // data memory: asynchronous read, synchronous write
    output logic [31:0] dmem_addr, dmem_wdata,
    output logic        dmem_we,
    output logic [2:0]  dmem_funct3,
    input  logic [31:0] dmem_rdata,
    // debug / statistics
    input  logic [4:0]  dbg_reg_addr,
    output logic [31:0] dbg_reg_data,
    output logic        halted,
    output logic [31:0] retired, stalls, flushes
);
    localparam logic [31:0] NOP = 32'h0000_0013;   // addi x0, x0, 0

    // -------------------------------------------------------------- IF
    logic [31:0] pc;
    logic        stall, flush, halted_r;
    logic        ex_taken;
    logic [31:0] ex_target;

    wire [31:0] pc_next = ex_taken ? ex_target : (stall ? pc : pc + 32'd4);
    always_ff @(posedge clk)
        if (!rst_n)          pc <= 32'd0;
        else if (!halted_r)  pc <= pc_next;
    assign imem_addr = pc;

    // IF/ID
    logic        ifid_valid;
    logic [31:0] ifid_pc, ifid_instr;
    always_ff @(posedge clk) begin
        if (!rst_n || flush) begin
            ifid_valid <= 1'b0; ifid_pc <= 32'd0; ifid_instr <= NOP;
        end else if (!stall) begin
            ifid_valid <= 1'b1; ifid_pc <= pc; ifid_instr <= imem_rdata;
        end
    end

