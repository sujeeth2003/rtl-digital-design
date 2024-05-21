// D flip-flops: asynchronous-reset and synchronous-reset flavours, with enable.
module dff_async #(parameter int WIDTH = 1) (
    input  logic             clk, rst_n, en,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);
    always_ff @(posedge clk or negedge rst_n)
        if (!rst_n)  q <= '0;
        else if (en) q <= d;
endmodule

module dff_sync #(parameter int WIDTH = 1) (
    input  logic             clk, rst_n, en,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);
    always_ff @(posedge clk)
        if (!rst_n)  q <= '0;
        else if (en) q <= d;
endmodule

// Up/down counter with synchronous load.
