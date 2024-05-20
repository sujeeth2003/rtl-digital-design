// Priority encoder: index of the highest set request bit.
module priority_encoder #(
    parameter int WIDTH = 8,
    localparam int IDX  = $clog2(WIDTH)
) (
    input  logic [WIDTH-1:0] req,
    output logic [IDX-1:0]   idx,
    output logic             valid
);
    always_comb begin
        idx   = '0;
        valid = 1'b0;
        for (int i = 0; i < WIDTH; i++) begin
            if (req[i]) begin
                idx   = IDX'(i);
                valid = 1'b1;
            end
        end
    end
endmodule

// Barrel shifter: log2(WIDTH) mux stages, so any shift amount takes the same
// (short) path. mode: 00 logical left, 01 logical right, 10 arithmetic right.
module barrel_shifter #(
    parameter int WIDTH = 16,
    localparam int SH   = $clog2(WIDTH)
) (
    input  logic [WIDTH-1:0] din,
    input  logic [SH-1:0]    amt,
    input  logic [1:0]       mode,
    output logic [WIDTH-1:0] dout
);
    logic [WIDTH-1:0] stage [SH+1];
    logic             fill;
    assign fill = (mode == 2'b10) ? din[WIDTH-1] : 1'b0;
    assign stage[0] = din;

    genvar i;
    generate
        for (i = 0; i < SH; i++) begin : g_stage
            localparam int K = 1 << i;
            always_comb begin
                if (!amt[i])              stage[i+1] = stage[i];
                else if (mode == 2'b00)   stage[i+1] = {stage[i][WIDTH-K-1:0], {K{1'b0}}};
                else                      stage[i+1] = {{K{fill}}, stage[i][WIDTH-1:K]};
            end
        end
    endgenerate
    assign dout = stage[SH];
endmodule
