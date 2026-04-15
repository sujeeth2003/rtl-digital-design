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

    // ID/EX
    logic        idex_valid, idex_reg_write, idex_mem_read, idex_mem_write, idex_alu_src_imm, idex_alu_a_pc;
    logic        idex_is_branch, idex_is_jal, idex_is_jalr, idex_is_ebreak;
    logic [3:0]  idex_alu_op;
    logic [2:0]  idex_funct3;
    logic [4:0]  idex_rs1, idex_rs2, idex_rd;
    logic [31:0] idex_pc, idex_rs1_val, idex_rs2_val, idex_imm;

    wire id_bubble = !rst_n || flush || stall || !ifid_valid;
    // Datapath registers are loaded every cycle and never reset: when idex_valid is 0 (a bubble) nothing downstream may use them.
    // Only the CONTROL bits are cleared on a flush/stall. This matters for timing: `flush` is the latest signal in the design
    // (forwarding -> compare -> branch decision), and resetting ~130 flops from it created a huge fanout on the critical path.
    always_ff @(posedge clk) begin
        idex_alu_src_imm <= c_alu_src_imm; idex_alu_a_pc <= c_alu_a_pc; idex_alu_op <= c_alu_op;
        idex_funct3 <= ifid_instr[14:12];
        idex_rs1 <= c_uses_rs1 ? id_rs1 : 5'd0; idex_rs2 <= c_uses_rs2 ? id_rs2 : 5'd0; idex_rd <= id_rd;
        idex_pc <= ifid_pc; idex_rs1_val <= id_rs1_val; idex_rs2_val <= id_rs2_val; idex_imm <= id_imm;
        if (id_bubble) begin
            idex_valid <= 1'b0; idex_reg_write <= 1'b0; idex_mem_read <= 1'b0; idex_mem_write <= 1'b0;
            idex_is_branch <= 1'b0; idex_is_jal <= 1'b0; idex_is_jalr <= 1'b0; idex_is_ebreak <= 1'b0;
        end else begin
            idex_valid <= 1'b1; idex_reg_write <= c_reg_write; idex_mem_read <= c_mem_read; idex_mem_write <= c_mem_write;
            idex_is_branch <= c_is_branch; idex_is_jal <= c_is_jal; idex_is_jalr <= c_is_jalr; idex_is_ebreak <= c_is_ebreak;
        end
    end

    // -------------------------------------------------------------- EX
    logic [1:0]  fwd_a, fwd_b;
    logic        exmem_valid, exmem_reg_write, exmem_mem_read, exmem_mem_write, exmem_is_ebreak;
    logic [4:0]  exmem_rd;
    logic [2:0]  exmem_funct3;
    logic [31:0] exmem_result, exmem_store_data;
    logic        memwb_valid, memwb_reg_write;
    logic [4:0]  memwb_rd;
    logic [31:0] memwb_data;

    hazard_unit u_haz (.ex_rs1(idex_rs1), .ex_rs2(idex_rs2), .mem_rd(exmem_rd), .wb_rd(memwb_rd),
                       .mem_reg_write(exmem_valid & exmem_reg_write), .wb_reg_write(memwb_valid & memwb_reg_write),
                       .fwd_a(fwd_a), .fwd_b(fwd_b),
                       .id_rs1(id_rs1), .id_rs2(id_rs2), .id_uses_rs1(c_uses_rs1 & ifid_valid), .id_uses_rs2(c_uses_rs2 & ifid_valid),
                       .ex_mem_read(idex_mem_read), .ex_valid(idex_valid), .ex_rd(idex_rd),
                       .stall(stall), .ex_taken(ex_taken), .flush(flush));

    wire [31:0] a_fwd = (fwd_a == 2'b01) ? exmem_result : (fwd_a == 2'b10) ? memwb_data : idex_rs1_val;
    wire [31:0] b_fwd = (fwd_b == 2'b01) ? exmem_result : (fwd_b == 2'b10) ? memwb_data : idex_rs2_val;
    wire [31:0] alu_a = idex_alu_a_pc ? idex_pc : a_fwd;
    wire [31:0] alu_b = idex_alu_src_imm ? idex_imm : b_fwd;
    logic [31:0] alu_result;
    logic [3:0]  alu_flags_unused;
    alu #(.WIDTH(32)) u_alu (.a(alu_a), .b(alu_b), .op(idex_alu_op), .result(alu_result), .flags(alu_flags_unused));

    // One subtraction gives both orderings: a <u b is the borrow; a <s b differs from it only when the signs differ.
    wire [32:0] cmp_diff = {1'b0, a_fwd} - {1'b0, b_fwd};
    wire eq  = (a_fwd == b_fwd);
    wire lt  = ($signed(a_fwd) < $signed(b_fwd));
    wire ltu = (a_fwd < b_fwd);
    logic br_cond;
    always_comb begin
        case (idex_funct3)
            3'b000:  br_cond = eq;
            3'b001:  br_cond = !eq;
            3'b100:  br_cond = lt;
            3'b101:  br_cond = !lt;
            3'b110:  br_cond = ltu;
            3'b111:  br_cond = !ltu;
            default: br_cond = 1'b0;
        endcase
    end
    assign ex_taken  = idex_valid && ((idex_is_branch && br_cond) || idex_is_jal || idex_is_jalr);
    assign ex_target = idex_is_jalr ? (alu_result & 32'hFFFF_FFFE) : (idex_pc + idex_imm);
    wire [31:0] ex_result = (idex_is_jal || idex_is_jalr) ? (idex_pc + 32'd4) : alu_result;

    // EX/MEM
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            exmem_valid <= 1'b0; exmem_reg_write <= 1'b0; exmem_mem_read <= 1'b0; exmem_mem_write <= 1'b0;
            exmem_is_ebreak <= 1'b0; exmem_rd <= 5'd0; exmem_funct3 <= 3'd0; exmem_result <= 32'd0; exmem_store_data <= 32'd0;
        end else begin
            exmem_valid <= idex_valid; exmem_reg_write <= idex_reg_write; exmem_mem_read <= idex_mem_read;
            exmem_mem_write <= idex_mem_write; exmem_is_ebreak <= idex_is_ebreak; exmem_rd <= idex_rd;
            exmem_funct3 <= idex_funct3; exmem_result <= ex_result; exmem_store_data <= b_fwd;
        end
    end

    // -------------------------------------------------------------- MEM
    assign dmem_addr   = exmem_result;
    assign dmem_wdata  = exmem_store_data;
    assign dmem_we     = exmem_valid && exmem_mem_write && !halted_r;
    assign dmem_funct3 = exmem_funct3;

    always_ff @(posedge clk) begin
        if (!rst_n) halted_r <= 1'b0;
        else if (exmem_valid && exmem_is_ebreak) halted_r <= 1'b1;
    end
    assign halted = halted_r;

    // MEM/WB
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            memwb_valid <= 1'b0; memwb_reg_write <= 1'b0; memwb_rd <= 5'd0; memwb_data <= 32'd0;
        end else begin
            memwb_valid <= exmem_valid; memwb_reg_write <= exmem_reg_write; memwb_rd <= exmem_rd;
            memwb_data <= exmem_mem_read ? dmem_rdata : exmem_result;
        end
    end

    // -------------------------------------------------------------- WB
    assign wb_we   = memwb_valid && memwb_reg_write && !halted_r;
    assign wb_rd   = memwb_rd;
    assign wb_data = memwb_data;

    // statistics
    always_ff @(posedge clk) begin
        if (!rst_n) begin retired <= 32'd0; stalls <= 32'd0; flushes <= 32'd0; end
        else begin
            if (memwb_valid && !halted_r) retired <= retired + 32'd1;
            if (stall && !flush)          stalls  <= stalls  + 32'd1;
            if (flush)                    flushes <= flushes + 32'd1;
        end
    end
endmodule
