// Parameterized ALU: any WIDTH, enum opcodes, struct flags.
package alu_pkg;
    typedef enum logic [3:0] {
        ALU_ADD  = 4'd0,
        ALU_SUB  = 4'd1,
        ALU_AND  = 4'd2,
        ALU_OR   = 4'd3,
        ALU_XOR  = 4'd4,
        ALU_NOR  = 4'd5,
        ALU_SLL  = 4'd6,
        ALU_SRL  = 4'd7,
        ALU_SRA  = 4'd8,
        ALU_SLT  = 4'd9,    // signed less-than  -> 1 / 0
        ALU_SLTU = 4'd10,   // unsigned less-than
        ALU_PASSB = 4'd11   // result = b (used for LUI)
    } alu_op_t;

