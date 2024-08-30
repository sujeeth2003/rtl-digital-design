// UVM environment for sync_fifo: transaction, sequences, sequencer, driver, monitor,
// scoreboard, functional coverage, agent, env, tests.
//
// STATUS: written for UVM-1.2 but NOT run in this repository (no UVM-capable simulator was
// available: Questa/VCS/Xcelium or Verilator+UVM are required). Regression and coverage
// numbers are therefore not claimed. The same DUT is verified here with the CXXRTL
// testbench (tb/fifo_tb.cpp, 1M cycles) and proven formally (formal/fifo.sby).
package fifo_uvm_pkg;
    import uvm_pkg::*;
    `include "uvm_macros.svh"

    localparam int WIDTH = 8;
    localparam int DEPTH = 16;

    // ------------------------------------------------------------------ transaction
    class fifo_item extends uvm_sequence_item;
        rand bit             wr_en, rd_en;
        rand bit [WIDTH-1:0] wr_data;
        // observed by the monitor
        bit [WIDTH-1:0] rd_data;
        bit full, empty, almost_full, almost_empty;
        bit [$clog2(DEPTH):0] count;

        `uvm_object_utils_begin(fifo_item)
            `uvm_field_int(wr_en,   UVM_ALL_ON)
            `uvm_field_int(rd_en,   UVM_ALL_ON)
            `uvm_field_int(wr_data, UVM_ALL_ON)
            `uvm_field_int(rd_data, UVM_ALL_ON)
        `uvm_object_utils_end

