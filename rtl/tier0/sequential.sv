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

// Moore FSM: overlapping "1011" sequence detector. Output depends on state only.
module seq_detect_1011 (
    input  logic clk, rst_n, in,
    output logic detected
);
    typedef enum logic [2:0] {S_IDLE, S_1, S_10, S_101, S_1011} state_t;
    state_t state, next;

    always_ff @(posedge clk)
        if (!rst_n) state <= S_IDLE;
        else        state <= next;

    always_comb begin
        case (state)
            S_IDLE:  next = in ? S_1    : S_IDLE;
            S_1:     next = in ? S_1    : S_10;
            S_10:    next = in ? S_101  : S_IDLE;
            S_101:   next = in ? S_1011 : S_10;
            S_1011:  next = in ? S_1    : S_10;   // overlap: last '1' starts a new match
            default: next = S_IDLE;
        endcase
    end
    assign detected = (state == S_1011);
endmodule
