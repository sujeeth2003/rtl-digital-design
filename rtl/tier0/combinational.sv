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

