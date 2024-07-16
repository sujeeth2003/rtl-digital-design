// AXI4-Lite slave: a small register bank.
//   reg 0..NREGS-2 : read/write, byte-strobe aware
//   reg NREGS-1    : read-only "write counter" (counts accepted writes); writing it returns SLVERR
//   address outside the bank returns SLVERR
// Handshake rules implemented (AMBA AXI4-Lite):
//   * VALID is never dependent on READY; once raised it holds until the handshake
//   * payload (BRESP/RDATA/RRESP) is stable while VALID && !READY
//   * write:  slave waits for BOTH awvalid and wvalid, then handshakes them together
//   * read:   arready when no read response is pending
module axil_regs #(
    parameter int ADDR_W = 6,
    parameter int NREGS  = 4          // 32-bit registers
) (
    input  logic        clk, rst_n,
    // write address / data / response
    input  logic [ADDR_W-1:0] awaddr,
    input  logic              awvalid,
    output logic              awready,
    input  logic [31:0]       wdata,
    input  logic [3:0]        wstrb,
    input  logic              wvalid,
    output logic              wready,
    output logic [1:0]        bresp,
    output logic              bvalid,
    input  logic              bready,
    // read address / data
    input  logic [ADDR_W-1:0] araddr,
    input  logic              arvalid,
    output logic              arready,
    output logic [31:0]       rdata,
    output logic [1:0]        rresp,
    output logic              rvalid,
    input  logic              rready
);
    localparam logic [1:0] OKAY = 2'b00, SLVERR = 2'b10;

    logic [31:0] regs [0:NREGS-1];

    wire [ADDR_W-3:0] widx = awaddr[ADDR_W-1:2];
    wire [ADDR_W-3:0] ridx = araddr[ADDR_W-1:2];
    wire w_in_range = (widx < NREGS);
    wire w_writable = (widx < NREGS - 1);          // last register is read-only
    wire r_in_range = (ridx < NREGS);

    // ---- write channel ----------------------------------------------------
    assign awready = awvalid && wvalid && !bvalid;
    assign wready  = awvalid && wvalid && !bvalid;
    wire   w_fire  = awvalid && awready && wvalid && wready;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            bvalid <= 1'b0;
            bresp  <= OKAY;
            for (int i = 0; i < NREGS; i++) regs[i] <= '0;
        end else begin
            if (w_fire) begin
                bvalid <= 1'b1;
                bresp  <= (w_in_range && w_writable) ? OKAY : SLVERR;
                if (w_in_range && w_writable) begin
                    for (int b = 0; b < 4; b++)
                        if (wstrb[b]) regs[widx][8*b +: 8] <= wdata[8*b +: 8];
                    regs[NREGS-1] <= regs[NREGS-1] + 32'd1;      // write counter (any accepted write)
                end
            end else if (bvalid && bready) begin
                bvalid <= 1'b0;
            end
        end
    end

    // ---- read channel -----------------------------------------------------
    assign arready = arvalid && !rvalid;
    wire   r_fire  = arvalid && arready;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            rvalid <= 1'b0;
            rdata  <= '0;
            rresp  <= OKAY;
        end else begin
            if (r_fire) begin
                rvalid <= 1'b1;
                rdata  <= r_in_range ? regs[ridx] : 32'hDEAD_BEEF;
                rresp  <= r_in_range ? OKAY : SLVERR;
            end else if (rvalid && rready) begin
                rvalid <= 1'b0;
            end
        end
    end

