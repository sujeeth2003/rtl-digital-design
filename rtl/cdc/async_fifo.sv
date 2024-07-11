// Asynchronous (dual-clock) FIFO, Gray-code pointer design (after Cummings, SNUG 2002).
//  * write and read pointers are Gray coded, so only ONE bit changes per increment;
//    a synchronizer that samples mid-change sees either the old or the new value, never garbage
//  * each pointer is synchronized into the other domain through a 2-flop synchronizer
//  * full  is computed in the write domain from the synchronized read pointer
//  * empty is computed in the read  domain from the synchronized write pointer
//  * flags are conservative: they may lag reality by a few cycles (full a bit late to clear,
//    empty a bit late to clear) but can never claim room/data that is not there
module async_fifo #(
    parameter int WIDTH = 8,
    parameter int DEPTH = 16          // power of two
) (
    input  logic             wclk, wrst_n, winc,
    input  logic [WIDTH-1:0] wdata,
    output logic             wfull,
    input  logic             rclk, rrst_n, rinc,
    output logic [WIDTH-1:0] rdata,
    output logic             rempty
);
    localparam int AW = $clog2(DEPTH);
    logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [AW:0] wbin, wgray, wbin_next, wgray_next, rgray_sync;   // write domain
    logic [AW:0] rbin, rgray, rbin_next, rgray_next, wgray_sync;   // read domain

    // ---- write domain -----------------------------------------------------
    wire  wfull_next = (wgray_next == {~rgray_sync[AW:AW-1], rgray_sync[AW-2:0]});
    wire  wen = winc && !wfull;

    gray_counter #(AW+1) u_wptr (.clk(wclk), .rst_n(wrst_n), .inc(wen),
                                 .bin(wbin), .gray(wgray), .bin_next(wbin_next), .gray_next(wgray_next));
    sync2ff #(AW+1) u_sync_r2w (.clk(wclk), .rst_n(wrst_n), .d(rgray), .q(rgray_sync));

    always_ff @(posedge wclk or negedge wrst_n)
        if (!wrst_n) wfull <= 1'b0;
        else         wfull <= wfull_next;

    always_ff @(posedge wclk)
        if (wen) mem[wbin[AW-1:0]] <= wdata;

