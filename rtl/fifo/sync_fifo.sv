// Synchronous FIFO, first-word fall-through, configurable width/depth.
// Extended pointers: wptr/rptr are AW+1 bits wide. The extra MSB toggles on wrap,
// so  full  = pointers equal in the low AW bits but different MSB, and
//     empty = pointers fully equal.  No wasted slot, no separate counter needed.
// Writes while full and reads while empty are ignored (never corrupt state).
module sync_fifo #(
    parameter int WIDTH     = 8,
    parameter int DEPTH     = 16,   // power of two
    parameter int AF_MARGIN = 2,    // almost_full  when free space  <= AF_MARGIN
    parameter int AE_MARGIN = 2     // almost_empty when stored items <= AE_MARGIN
) (
    input  logic             clk, rst_n,
    input  logic             wr_en,
    input  logic [WIDTH-1:0] wr_data,
    input  logic             rd_en,
    output logic [WIDTH-1:0] rd_data,
    output logic             full, empty, almost_full, almost_empty,
    output logic [$clog2(DEPTH):0] count
);
    localparam int AW = $clog2(DEPTH);
    logic [AW:0]      wptr, rptr;
    logic [WIDTH-1:0] mem [0:DEPTH-1];

