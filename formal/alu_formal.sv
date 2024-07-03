// Formal proof (8-bit ALU, all inputs): every opcode matches an independent
// specification written with wider arithmetic.
import alu_pkg::*;

module alu_formal (
    input  logic [7:0] a, b,
    input  logic [3:0] op
);
    logic [7:0] result;
    logic [3:0] flags_bits;
    alu_pkg::alu_flags_t flags;
    assign flags = flags_bits;
    alu #(.WIDTH(8)) dut (.a(a), .b(b), .op(op), .result(result), .flags(flags_bits));

