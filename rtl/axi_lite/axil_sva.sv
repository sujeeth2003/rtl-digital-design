// Concurrent SVA versions of the AXI-Lite handshake rules, for simulators/formal
// tools with full SVA support (Questa, VCS, Xcelium, Verilator --assert, SymbiYosys+Verific/slang).
// Attach with:   bind axil_regs axil_sva #(.ADDR_W(ADDR_W)) u_sva (.*);
//
// NOTE: open-source Yosys cannot parse concurrent assertions, so this file is NOT
// exercised in this repo. The same rules are proven with immediate assertions inside
// axil_regs.sv (`ifdef FORMAL`, see formal/axil.sby). Treat this file as unrun.
module axil_sva #(parameter int ADDR_W = 6) (
    input logic clk, rst_n,
    input logic [ADDR_W-1:0] awaddr, araddr,
    input logic awvalid, awready, wvalid, wready, bvalid, bready, arvalid, arready, rvalid, rready,
    input logic [31:0] wdata, rdata,
    input logic [1:0] bresp, rresp
);
    default clocking cb @(posedge clk); endclocking
    default disable iff (!rst_n);

    // VALID must be held until READY, and payload stable meanwhile
    a_aw_hold : assert property (awvalid && !awready |=> awvalid && $stable(awaddr));
    a_w_hold  : assert property (wvalid  && !wready  |=> wvalid  && $stable(wdata));
    a_ar_hold : assert property (arvalid && !arready |=> arvalid && $stable(araddr));
    a_b_hold  : assert property (bvalid  && !bready  |=> bvalid  && $stable(bresp));
    a_r_hold  : assert property (rvalid  && !rready  |=> rvalid  && $stable(rdata) && $stable(rresp));

