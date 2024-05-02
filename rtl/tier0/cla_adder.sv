// 4-bit carry-lookahead block: carries computed in parallel from generate (g)
// and propagate (p) instead of rippling.
module cla4 (
    input  logic [3:0] a, b,
    input  logic       cin,
    output logic [3:0] sum,
    output logic       cout
);
    logic [3:0] g, p;
    logic [4:0] c;
    assign g = a & b;
    assign p = a ^ b;
    assign c[0] = cin;
    assign c[1] = g[0] | (p[0] & cin);
    assign c[2] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & cin);
    assign c[3] = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) | (p[2] & p[1] & p[0] & cin);
    assign c[4] = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | (p[3] & p[2] & p[1] & g[0])
                | (p[3] & p[2] & p[1] & p[0] & cin);
    assign sum  = p ^ c[3:0];
    assign cout = c[4];
endmodule

// WIDTH-bit adder: 4-bit lookahead blocks with the block carries rippled.
module cla_adder #(
    parameter int WIDTH = 16   // must be a multiple of 4
) (
    input  logic [WIDTH-1:0] a, b,
    input  logic             cin,
    output logic [WIDTH-1:0] sum,
    output logic             cout
);
    localparam int BLOCKS = WIDTH / 4;
    logic [BLOCKS:0] c;
    assign c[0] = cin;

    genvar i;
    generate
        for (i = 0; i < BLOCKS; i++) begin : g_blk
            cla4 u (.a(a[4*i +: 4]), .b(b[4*i +: 4]), .cin(c[i]), .sum(sum[4*i +: 4]), .cout(c[i+1]));
        end
    endgenerate
    assign cout = c[BLOCKS];
endmodule
