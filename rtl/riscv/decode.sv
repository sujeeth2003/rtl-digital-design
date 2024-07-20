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

