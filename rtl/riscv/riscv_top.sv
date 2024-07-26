// Core + instruction/data RAM + testbench access ports.
//   prog_*  : write the instruction RAM (load a program while in reset)
//   dinit_* : write the data RAM
//   dbg_*   : read a register / a data word after the program halts
module riscv_top (
    input  logic        clk, rst_n,
    input  logic        prog_we,  input logic [9:0] prog_addr,  input logic [31:0] prog_data,
    input  logic        dinit_we, input logic [9:0] dinit_addr, input logic [31:0] dinit_data,
    input  logic [4:0]  dbg_reg_addr,  output logic [31:0] dbg_reg_data,
    input  logic [9:0]  dbg_mem_addr,  output logic [31:0] dbg_mem_data,
    output logic        halted,
    output logic [31:0] retired, stalls, flushes
);
    logic [31:0] imem [0:1023];
    always_ff @(posedge clk) if (prog_we) imem[prog_addr] <= prog_data;

