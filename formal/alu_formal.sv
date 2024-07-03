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

    wire signed [8:0]  sa = {a[7], a}, sb = {b[7], b};
    wire        [8:0]  ua = {1'b0, a}, ub = {1'b0, b};
    wire signed [9:0]  wide_add = sa + sb, wide_sub = sa - sb;
    wire        [8:0]  uadd = ua + ub, usub_with_carry = ua + {1'b0, ~b} + 9'd1;

    always_comb begin
        case (op)
            4'd0: begin
                assert(result == wide_add[7:0]);
                assert(flags.carry == uadd[8]);
                assert(flags.overflow == (wide_add[9:0] != {{2{wide_add[7]}}, wide_add[7:0]}));
            end
            4'd1: begin
                assert(result == wide_sub[7:0]);
                assert(flags.carry == usub_with_carry[8]);
                assert(flags.overflow == (wide_sub[9:0] != {{2{wide_sub[7]}}, wide_sub[7:0]}));
            end
            4'd2:  assert(result == (a & b));
            4'd3:  assert(result == (a | b));
            4'd4:  assert(result == (a ^ b));
            4'd5:  assert(result == ~(a | b));
            4'd6:  assert(result == (a << b[2:0]));
            4'd7:  assert(result == (a >> b[2:0]));
            4'd8:  assert(result == 8'($signed(a) >>> b[2:0]));
            4'd9:  assert(result == (($signed(a) < $signed(b)) ? 8'd1 : 8'd0));
            4'd10: assert(result == ((a < b) ? 8'd1 : 8'd0));
            4'd11: assert(result == b);
            default: assert(result == 8'd0);
        endcase
        assert(flags.zero == (result == 8'd0));
        assert(flags.negative == result[7]);
        if (op > 4'd1) begin assert(!flags.carry); assert(!flags.overflow); end
    end
endmodule
