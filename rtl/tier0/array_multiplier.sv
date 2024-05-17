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

