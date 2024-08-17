// Interface for sync_fifo (16 x 8). Clocking blocks give race-free driving/sampling.
interface fifo_if #(parameter int WIDTH = 8, parameter int DEPTH = 16) (input logic clk);
    logic             rst_n;
    logic             wr_en, rd_en;
    logic [WIDTH-1:0] wr_data, rd_data;
    logic             full, empty, almost_full, almost_empty;
    logic [$clog2(DEPTH):0] count;

    clocking drv_cb @(posedge clk);
        default input #1step output #1;
        output wr_en, wr_data, rd_en;
        input  full, empty, almost_full, almost_empty, count, rd_data;
    endclocking

