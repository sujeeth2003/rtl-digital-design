// Immediate generator and main decoder for the RV32I subset implemented here:
//   LUI AUIPC JAL JALR | BEQ BNE BLT BGE BLTU BGEU | LB LH LW LBU LHU SB SH SW
//   ADDI SLTI SLTIU XORI ORI ANDI SLLI SRLI SRAI | ADD SUB SLL SLT SLTU XOR SRL SRA OR AND
//   EBREAK (halts the core).  FENCE/ECALL/CSR are treated as NOPs.
module imm_gen (
    input  logic [31:0] instr,
    output logic [31:0] imm
);
    always_comb begin
        case (instr[6:0])
            7'b0010011, 7'b0000011, 7'b1100111:            // I-type: OP-IMM, LOAD, JALR
                imm = {{20{instr[31]}}, instr[31:20]};
            7'b0100011:                                    // S-type
                imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            7'b1100011:                                    // B-type
                imm = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
            7'b0110111, 7'b0010111:                        // U-type: LUI, AUIPC
                imm = {instr[31:12], 12'b0};
            7'b1101111:                                    // J-type: JAL
                imm = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
            default: imm = 32'd0;
        endcase
    end
endmodule

module control (
    input  logic [31:0] instr,
    output logic        reg_write, mem_read, mem_write,
    output logic        alu_src_imm,     // ALU b operand = immediate
    output logic        alu_a_pc,        // ALU a operand = PC (AUIPC)
    output logic [3:0]  alu_op,          // alu_pkg::alu_op_t encoding
    output logic        is_branch, is_jal, is_jalr, is_ebreak,
    output logic        uses_rs1, uses_rs2
);
    wire [6:0] opcode = instr[6:0];
    wire [2:0] f3     = instr[14:12];
    wire       f7_5   = instr[30];

    localparam logic [3:0] ADD = 4'd0, SUB = 4'd1, AND_ = 4'd2, OR_ = 4'd3, XOR_ = 4'd4,
                           SLL = 4'd6, SRL = 4'd7, SRA = 4'd8, SLT = 4'd9, SLTU = 4'd10, PASSB = 4'd11;

    always_comb begin
        reg_write = 0; mem_read = 0; mem_write = 0; alu_src_imm = 0; alu_a_pc = 0;
        alu_op = ADD; is_branch = 0; is_jal = 0; is_jalr = 0; is_ebreak = 0; uses_rs1 = 0; uses_rs2 = 0;
        case (opcode)
            7'b0110011: begin                                   // OP (register-register)
                reg_write = 1; uses_rs1 = 1; uses_rs2 = 1;
                case (f3)
                    3'b000: alu_op = f7_5 ? SUB : ADD;
                    3'b001: alu_op = SLL;
                    3'b010: alu_op = SLT;
                    3'b011: alu_op = SLTU;
                    3'b100: alu_op = XOR_;
                    3'b101: alu_op = f7_5 ? SRA : SRL;
                    3'b110: alu_op = OR_;
                    default: alu_op = AND_;
                endcase
            end
            7'b0010011: begin                                   // OP-IMM
                reg_write = 1; uses_rs1 = 1; alu_src_imm = 1;
                case (f3)
                    3'b000: alu_op = ADD;
                    3'b001: alu_op = SLL;
                    3'b010: alu_op = SLT;
                    3'b011: alu_op = SLTU;
                    3'b100: alu_op = XOR_;
                    3'b101: alu_op = f7_5 ? SRA : SRL;
                    3'b110: alu_op = OR_;
                    default: alu_op = AND_;
                endcase
            end
            7'b0000011: begin reg_write = 1; mem_read = 1; alu_src_imm = 1; uses_rs1 = 1; end          // LOAD
            7'b0100011: begin mem_write = 1; alu_src_imm = 1; uses_rs1 = 1; uses_rs2 = 1; end          // STORE
            7'b1100011: begin is_branch = 1; uses_rs1 = 1; uses_rs2 = 1; end                            // BRANCH
            7'b1101111: begin is_jal = 1; reg_write = 1; end                                            // JAL
            7'b1100111: begin is_jalr = 1; reg_write = 1; alu_src_imm = 1; uses_rs1 = 1; end            // JALR
            7'b0110111: begin reg_write = 1; alu_src_imm = 1; alu_op = PASSB; end                       // LUI
            7'b0010111: begin reg_write = 1; alu_src_imm = 1; alu_a_pc = 1; end                         // AUIPC
            7'b1110011: is_ebreak = (instr[31:20] == 12'h001) && (f3 == 3'b000);                        // EBREAK
            default: ;                                                                                  // NOP
        endcase
    end
endmodule
