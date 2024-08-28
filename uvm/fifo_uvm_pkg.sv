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

