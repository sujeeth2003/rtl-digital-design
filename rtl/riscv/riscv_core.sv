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

