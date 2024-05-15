// N-bit ripple-carry adder built from gate-level full adders.
// (The first draft of this in my notes used `I++` / mixed-case genvar names and
// did not elaborate; this is the corrected version.)
module ripple_adder #(
    parameter int WIDTH = 8
) (
    input  logic [WIDTH-1:0] a, b,
    input  logic             cin,
    output logic [WIDTH-1:0] sum,
    output logic             cout
);
    logic [WIDTH:0] c;
    assign c[0] = cin;

