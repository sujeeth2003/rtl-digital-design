// Gate-level full adder (my first Verilog, kept as written).
`timescale 1ns/1ps

module full_adder (
    input  logic a, b, cin,
    output logic s, c
);
    logic s1, c1, c2;
    xor x1 (s1, a, b);
    xor x2 (s,  s1, cin);
    and y1 (c1, a, b);
    and y2 (c2, cin, s1);
    or  z1 (c,  c1, c2);
endmodule
