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

    logic [11:0] mp;
    array_multiplier #(6) m (.a(a[5:0]), .b(b[5:0]), .p(mp));

    logic [7:0] sh;
    barrel_shifter #(8) s (.din(d), .amt(amt), .mode(mode), .dout(sh));
    logic [7:0] ref_sh;
    always_comb case (mode)
        2'b00:   ref_sh = d << amt;
        2'b01:   ref_sh = d >> amt;
        default: ref_sh = 8'($signed(d) >>> amt);
    endcase

    logic [2:0] pi; logic pv;
    priority_encoder #(8) pe (.req(d), .idx(pi), .valid(pv));
    logic [2:0] ref_idx;
    always_comb begin ref_idx = 3'd0; for (int i = 0; i < 8; i++) if (d[i]) ref_idx = 3'(i); end

