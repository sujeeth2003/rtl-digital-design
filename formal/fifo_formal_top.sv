// Small instance for the proof: 4 entries x 4 bits. The properties live inside
// sync_fifo.sv under `ifdef FORMAL; inputs are unconstrained here.
module fifo_formal_top (
    input  logic       clk, rst_n, wr_en, rd_en,
    input  logic [3:0] wr_data
);
    logic [3:0] rd_data;
    logic full, empty, almost_full, almost_empty;
    logic [2:0] count;
    sync_fifo #(.WIDTH(4), .DEPTH(4), .AF_MARGIN(1), .AE_MARGIN(1)) dut (
        .clk(clk), .rst_n(rst_n), .wr_en(wr_en), .wr_data(wr_data), .rd_en(rd_en), .rd_data(rd_data),
        .full(full), .empty(empty), .almost_full(almost_full), .almost_empty(almost_empty), .count(count));
endmodule
