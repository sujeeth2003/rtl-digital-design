// Equivalence of the structural tier-0 blocks against the behavioural operators,
// for ALL inputs: 16-bit ripple and CLA adders, 6x6 array multiplier, 8-bit barrel
// shifter (three modes) and 8-bit priority encoder.
module tier0_formal (
    input logic [15:0] a, b,
    input logic        cin,
    input logic [7:0]  d,
    input logic [2:0]  amt,
    input logic [1:0]  mode
);
    logic [15:0] rs, cs; logic rc, cc;
    ripple_adder #(16) r (.a(a), .b(b), .cin(cin), .sum(rs), .cout(rc));
    cla_adder    #(16) c (.a(a), .b(b), .cin(cin), .sum(cs), .cout(cc));
    wire [16:0] ref_sum = {1'b0, a} + {1'b0, b} + {16'b0, cin};

