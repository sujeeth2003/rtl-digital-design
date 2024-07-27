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

// 4 KiB data RAM: asynchronous read with byte/half/word sign- or zero-extension,
// synchronous write with byte enables. Little-endian. Addresses wrap at 4 KiB.
module dmem (
    input  logic        clk,
    input  logic [31:0] addr, wdata,
    input  logic        we,
    input  logic [2:0]  funct3,           // 000 B, 001 H, 010 W, 100 BU, 101 HU
    output logic [31:0] rdata,
    input  logic        init_we, input logic [9:0] init_addr, input logic [31:0] init_data,
    input  logic [9:0]  dbg_addr,
    output logic [31:0] dbg_data
);
    logic [31:0] mem [0:1023];
    wire [9:0] idx = addr[11:2];
    wire [1:0] off = addr[1:0];
    wire [31:0] word = mem[idx];
    assign dbg_data = mem[dbg_addr];

    logic [7:0]  b;
    logic [15:0] h;
    always_comb begin
        b = word[8*off +: 8];
        h = off[1] ? word[31:16] : word[15:0];
        case (funct3)
            3'b000:  rdata = {{24{b[7]}}, b};
            3'b001:  rdata = {{16{h[15]}}, h};
            3'b100:  rdata = {24'd0, b};
            3'b101:  rdata = {16'd0, h};
            default: rdata = word;
        endcase
    end

    logic [31:0] wword;                   // read-modify-write of the addressed word
    always_comb begin
        wword = word;
        case (funct3[1:0])
            2'b00:   wword[8*off +: 8] = wdata[7:0];
            2'b01:   if (off[1]) wword[31:16] = wdata[15:0]; else wword[15:0] = wdata[15:0];
            default: wword = wdata;
        endcase
    end

    always_ff @(posedge clk) begin
        if (init_we)  mem[init_addr] <= init_data;
        else if (we)  mem[idx] <= wword;
    end
endmodule
