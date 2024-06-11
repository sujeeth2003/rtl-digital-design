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

    // carry: carry-out of a+b (ADD) or of a+~b+1 (SUB, i.e. NOT borrow).
    // overflow: signed overflow of ADD/SUB. Both are 0 for every other opcode.
    typedef struct packed {
        logic zero;
        logic negative;
        logic carry;
        logic overflow;
    } alu_flags_t;
endpackage

import alu_pkg::*;   // compilation-unit scope: keeps the ports readable and Yosys-compatible

module alu #(
    parameter int WIDTH = 32
) (
    input  logic [WIDTH-1:0]   a, b,
    input  logic [3:0]         op,        // alu_op_t encoding (see alu_pkg)
    output logic [WIDTH-1:0]   result,
    output logic [3:0]         flags     // packed alu_flags_t: {zero, negative, carry, overflow}
);
    localparam int SH = $clog2(WIDTH);
    logic [SH-1:0]    shamt;
    logic [WIDTH:0]   sum_ext;       // WIDTH+1 bits: keeps the carry-out
    logic [WIDTH-1:0] b_eff;
    logic             is_sub, carry, overflow, lt_signed, lt_unsigned;

    assign shamt    = b[SH-1:0];
    assign is_sub   = (op == ALU_SUB) || (op == ALU_SLT) || (op == ALU_SLTU);
    assign b_eff    = is_sub ? ~b : b;
    assign sum_ext  = {1'b0, a} + {1'b0, b_eff} + {{WIDTH{1'b0}}, is_sub};
    assign carry    = sum_ext[WIDTH];
    assign overflow = (a[WIDTH-1] == b_eff[WIDTH-1]) && (sum_ext[WIDTH-1] != a[WIDTH-1]);
    assign lt_signed   = sum_ext[WIDTH-1] ^ overflow;   // a < b (signed)
    assign lt_unsigned = ~carry;                        // a < b (unsigned): borrow occurred

    always_comb begin
        result = '0;
        case (op)
            ALU_ADD:   result = sum_ext[WIDTH-1:0];
            ALU_SUB:   result = sum_ext[WIDTH-1:0];
            ALU_AND:   result = a & b;
            ALU_OR:    result = a | b;
            ALU_XOR:   result = a ^ b;
            ALU_NOR:   result = ~(a | b);
            ALU_SLL:   result = a << shamt;
            ALU_SRL:   result = a >> shamt;
            ALU_SRA:   result = WIDTH'($signed(a) >>> shamt);
            ALU_SLT:   result = {{(WIDTH-1){1'b0}}, lt_signed};
            ALU_SLTU:  result = {{(WIDTH-1){1'b0}}, lt_unsigned};
            ALU_PASSB: result = b;
            default:   result = '0;
        endcase
    end

    wire arith = (op == ALU_ADD) || (op == ALU_SUB);
    alu_pkg::alu_flags_t fl;
    assign fl.zero     = (result == '0);
    assign fl.negative = result[WIDTH-1];
    assign fl.carry    = arith & carry;
    assign fl.overflow = arith & overflow;
    assign flags       = fl;
endmodule
