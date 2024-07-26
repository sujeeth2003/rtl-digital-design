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

    logic [31:0] imem_addr, imem_rdata;
    assign imem_rdata = imem[imem_addr[11:2]];

    logic [31:0] dmem_addr, dmem_wdata, dmem_rdata;
    logic        dmem_we;
    logic [2:0]  dmem_funct3;

    riscv_core u_core (.clk(clk), .rst_n(rst_n), .imem_addr(imem_addr), .imem_rdata(imem_rdata),
                       .dmem_addr(dmem_addr), .dmem_wdata(dmem_wdata), .dmem_we(dmem_we), .dmem_funct3(dmem_funct3),
                       .dmem_rdata(dmem_rdata), .dbg_reg_addr(dbg_reg_addr), .dbg_reg_data(dbg_reg_data),
                       .halted(halted), .retired(retired), .stalls(stalls), .flushes(flushes));

    dmem u_dmem (.clk(clk), .addr(dmem_addr), .wdata(dmem_wdata), .we(dmem_we), .funct3(dmem_funct3), .rdata(dmem_rdata),
                 .init_we(dinit_we), .init_addr(dinit_addr), .init_data(dinit_data),
                 .dbg_addr(dbg_mem_addr), .dbg_data(dbg_mem_data));
endmodule

