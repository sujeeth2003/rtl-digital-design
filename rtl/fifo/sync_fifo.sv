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

    assign empty        = (wptr == rptr);
    assign full         = (wptr[AW] != rptr[AW]) && (wptr[AW-1:0] == rptr[AW-1:0]);
    assign count        = wptr - rptr;
    assign almost_full  = (count >= (AW+1)'(DEPTH - AF_MARGIN));
    assign almost_empty = (count <= (AW+1)'(AE_MARGIN));
    assign rd_data      = mem[rptr[AW-1:0]];

    wire do_wr = wr_en && !full;
    wire do_rd = rd_en && !empty;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            wptr <= '0;
            rptr <= '0;
        end else begin
            if (do_wr) begin
                mem[wptr[AW-1:0]] <= wr_data;
                wptr <= wptr + 1'b1;
            end
            if (do_rd) rptr <= rptr + 1'b1;
        end
    end

`ifdef FORMAL
    // ---- formal properties (SymbiYosys, see formal/fifo.sby) -----------------
    reg f_past_valid = 1'b0;
    always @(posedge clk) f_past_valid <= 1'b1;
    always @(*) if (!f_past_valid) assume(!rst_n);       // start in reset

    // structural invariants
    always @(*) if (rst_n) begin
        assert(!(full && empty));
        assert(count <= DEPTH);
        assert(full  == (count == DEPTH));
        assert(empty == (count == 0));
        assert(almost_full  == (count >= DEPTH - AF_MARGIN));
        assert(almost_empty == (count <= AE_MARGIN));
    end

    // count moves by exactly do_wr - do_rd each cycle
    reg [AW:0] f_prev_count;
    reg        f_prev_wr, f_prev_rd, f_prev_rst_n;
    always @(posedge clk) begin
        f_prev_count <= count; f_prev_wr <= do_wr; f_prev_rd <= do_rd; f_prev_rst_n <= rst_n;
    end
    always @(*) if (f_past_valid && f_prev_rst_n && rst_n)
        assert(count == f_prev_count + f_prev_wr - f_prev_rd);
    always @(posedge clk) if (f_past_valid && !f_prev_rst_n) assert(count == 0);

    // data integrity / ordering: follow one arbitrary slot (pointer value + data value)
    (* anyconst *) wire [AW:0]      f_tag;
    (* anyconst *) wire [WIDTH-1:0] f_data;
    always @(*) if (do_wr && wptr == f_tag) assume(wr_data == f_data);   // constrain only what is written there
    wire f_occupied = ((f_tag - rptr) & ((1 << (AW+1)) - 1)) < count;    // tag lies in [rptr, wptr)
    always @(*) if (rst_n && f_occupied) assert(mem[f_tag[AW-1:0]] == f_data);
    always @(*) if (rst_n && do_rd && rptr == f_tag) assert(rd_data == f_data);
`endif
endmodule
