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

