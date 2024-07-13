// Gray-code properties, proven for every 6-bit input (BMC depth 1, combinational):
//  1. gray2bin(bin2gray(x)) == x                        (bijection)
//  2. bin2gray(x) and bin2gray(x+1) differ in exactly one bit (the property the FIFO relies on),
//     including the wrap from all-ones back to zero
module gray_formal (input logic [5:0] x);
    logic [5:0] g, gn, back;
    bin2gray #(6) u0 (.bin(x),        .gray(g));
    bin2gray #(6) u1 (.bin(x + 6'd1), .gray(gn));
    gray2bin #(6) u2 (.gray(g),       .bin(back));
    wire [5:0] diff = g ^ gn;
    always_comb begin
        assert(back == x);
        assert(diff != 6'd0 && (diff & (diff - 6'd1)) == 6'd0);   // exactly one bit set
    end
endmodule
