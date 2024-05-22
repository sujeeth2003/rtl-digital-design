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
module counter #(parameter int WIDTH = 8) (
    input  logic             clk, rst_n, en, load, up,
    input  logic [WIDTH-1:0] load_val,
    output logic [WIDTH-1:0] count
);
    always_ff @(posedge clk)
        if (!rst_n)    count <= '0;
        else if (load) count <= load_val;
        else if (en)   count <= up ? count + 1'b1 : count - 1'b1;
endmodule

// Universal shift register. mode: 00 hold, 01 shift right (serial in at MSB),
// 10 shift left (serial in at LSB), 11 parallel load.
module shift_reg #(parameter int WIDTH = 8) (
    input  logic             clk, rst_n,
    input  logic [1:0]       mode,
    input  logic             ser_in,
    input  logic [WIDTH-1:0] par_in,
    output logic [WIDTH-1:0] q
);
    always_ff @(posedge clk)
        if (!rst_n) q <= '0;
        else case (mode)
            2'b01:   q <= {ser_in, q[WIDTH-1:1]};
            2'b10:   q <= {q[WIDTH-2:0], ser_in};
            2'b11:   q <= par_in;
            default: q <= q;
        endcase
endmodule

