// Unsigned N x N array multiplier: one row of partial products per multiplier
// bit, accumulated with a ripple-carry adder per row (shift-and-add, unrolled).
module array_multiplier #(
    parameter int N = 8
) (
    input  logic [N-1:0]   a, b,
    output logic [2*N-1:0] p
);
    // upper[i] = running sum of the bits above product bit i
    logic [N-1:0] upper [N];
    logic [N-1:0] pp    [N];
    logic [N-1:0] s     [N];
    logic         co    [N];

    genvar i;
    generate
        for (i = 0; i < N; i++) begin : g_pp
            assign pp[i] = b[i] ? a : '0;
        end

        assign p[0]     = pp[0][0];
        assign upper[0] = {1'b0, pp[0][N-1:1]};

        for (i = 1; i < N; i++) begin : g_row
            ripple_adder #(.WIDTH(N)) add (.a(upper[i-1]), .b(pp[i]), .cin(1'b0), .sum(s[i]), .cout(co[i]));
            assign p[i]     = s[i][0];
            assign upper[i] = {co[i], s[i][N-1:1]};
        end
    endgenerate

    assign p[2*N-1:N] = upper[N-1];
endmodule
