// Top-level: clock, reset, DUT, virtual interface into the config DB, run_test().
// Run (Questa):   vlog -sv +incdir+$UVM_HOME/src $UVM_HOME/src/uvm_pkg.sv ../rtl/fifo/sync_fifo.sv fifo_if.sv fifo_uvm_pkg.sv tb_top.sv
//                 vsim -c tb_top +UVM_TESTNAME=fifo_base_test +ntb_random_seed=1 -do "run -all"
// Regression: loop the seed, e.g.  for s in $(seq 1 100); do vsim ... +ntb_random_seed=$s; done
// NOT RUN in this repository (see fifo_uvm_pkg.sv header).
`timescale 1ns/1ps
module tb_top;
    import uvm_pkg::*;
    import fifo_uvm_pkg::*;

    logic clk = 0;
    always #5 clk = ~clk;

    fifo_if #(.WIDTH(fifo_uvm_pkg::WIDTH), .DEPTH(fifo_uvm_pkg::DEPTH)) vif (clk);

    sync_fifo #(.WIDTH(fifo_uvm_pkg::WIDTH), .DEPTH(fifo_uvm_pkg::DEPTH), .AF_MARGIN(2), .AE_MARGIN(2)) dut (
        .clk(clk), .rst_n(vif.rst_n),
        .wr_en(vif.wr_en), .wr_data(vif.wr_data), .rd_en(vif.rd_en), .rd_data(vif.rd_data),
        .full(vif.full), .empty(vif.empty), .almost_full(vif.almost_full), .almost_empty(vif.almost_empty),
        .count(vif.count));

    initial begin
        vif.rst_n = 0;
        repeat (3) @(posedge clk);
        vif.rst_n = 1;
    end

    initial begin
        uvm_config_db#(virtual fifo_if)::set(null, "*", "vif", vif);
        run_test();
    end
endmodule
