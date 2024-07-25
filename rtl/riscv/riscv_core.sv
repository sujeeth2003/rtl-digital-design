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

    // -------------------------------------------------------------- ID
    logic        c_reg_write, c_mem_read, c_mem_write, c_alu_src_imm, c_alu_a_pc, c_is_branch, c_is_jal, c_is_jalr, c_is_ebreak;
    logic        c_uses_rs1, c_uses_rs2;
    logic [3:0]  c_alu_op;
    logic [31:0] id_imm, id_rs1_val, id_rs2_val;
    wire  [4:0]  id_rs1 = ifid_instr[19:15], id_rs2 = ifid_instr[24:20], id_rd = ifid_instr[11:7];

    control u_ctl (.instr(ifid_instr), .reg_write(c_reg_write), .mem_read(c_mem_read), .mem_write(c_mem_write),
                   .alu_src_imm(c_alu_src_imm), .alu_a_pc(c_alu_a_pc), .alu_op(c_alu_op), .is_branch(c_is_branch),
                   .is_jal(c_is_jal), .is_jalr(c_is_jalr), .is_ebreak(c_is_ebreak), .uses_rs1(c_uses_rs1), .uses_rs2(c_uses_rs2));
    imm_gen u_imm (.instr(ifid_instr), .imm(id_imm));

    // write-back signals (declared here, driven in WB)
    logic        wb_we;
    logic [4:0]  wb_rd;
    logic [31:0] wb_data;
    regfile u_rf (.clk(clk), .we(wb_we), .waddr(wb_rd), .wdata(wb_data),
                  .raddr1(id_rs1), .raddr2(id_rs2), .rdata1(id_rs1_val), .rdata2(id_rs2_val),
                  .dbg_addr(dbg_reg_addr), .dbg_data(dbg_reg_data));

