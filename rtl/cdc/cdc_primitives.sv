// Two-flop synchronizer: brings a signal from another clock domain into `clk`.
// Only safe for signals that change at most one bit at a time (single-bit
// levels, or Gray-coded buses). The first flop may go metastable; the second
// gives it a full cycle to resolve.
module sync2ff #(parameter int WIDTH = 1) (
    input  logic             clk, rst_n,
    input  logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);
    (* async_reg = "true" *) logic [WIDTH-1:0] meta;
    always_ff @(posedge clk or negedge rst_n)
        if (!rst_n) begin meta <= '0; q <= '0; end
        else        begin meta <= d;  q <= meta; end
endmodule

// Binary -> Gray: consecutive integers differ in exactly one bit.
module bin2gray #(parameter int WIDTH = 4) (
    input  logic [WIDTH-1:0] bin,
    output logic [WIDTH-1:0] gray
);
    assign gray = bin ^ (bin >> 1);
endmodule

// Gray -> binary: prefix XOR from the MSB down.
module gray2bin #(parameter int WIDTH = 4) (
    input  logic [WIDTH-1:0] gray,
    output logic [WIDTH-1:0] bin
);
    always_comb begin
        bin[WIDTH-1] = gray[WIDTH-1];
        for (int i = WIDTH-2; i >= 0; i--) bin[i] = bin[i+1] ^ gray[i];
    end
endmodule

// Free-running Gray pointer: keeps a binary counter for addressing and a
// registered Gray copy for crossing clock domains (registered => glitch-free).
module gray_counter #(parameter int WIDTH = 5) (
    input  logic             clk, rst_n, inc,
    output logic [WIDTH-1:0] bin, gray,
    output logic [WIDTH-1:0] bin_next, gray_next
);
    assign bin_next = bin + WIDTH'(inc);
    bin2gray #(WIDTH) u_b2g (.bin(bin_next), .gray(gray_next));
    always_ff @(posedge clk or negedge rst_n)
        if (!rst_n) begin bin <= '0; gray <= '0; end
        else        begin bin <= bin_next; gray <= gray_next; end
endmodule
