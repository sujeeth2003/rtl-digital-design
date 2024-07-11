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

