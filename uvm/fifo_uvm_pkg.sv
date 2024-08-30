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

        function new(string name = "fifo_item"); super.new(name); endfunction
    endclass

    // ------------------------------------------------------------------ sequences
    class fifo_random_seq extends uvm_sequence #(fifo_item);
        `uvm_object_utils(fifo_random_seq)
        rand int unsigned n = 2000;
        int unsigned wr_weight = 50, rd_weight = 50;       // percent, tunable per test
        function new(string name = "fifo_random_seq"); super.new(name); endfunction
        task body();
            repeat (n) begin
                fifo_item it = fifo_item::type_id::create("it");
                start_item(it);
                if (!it.randomize() with {
                        wr_en dist {1 := wr_weight, 0 := 100 - wr_weight};
                        rd_en dist {1 := rd_weight, 0 := 100 - rd_weight}; })
                    `uvm_fatal("RAND", "randomize failed")
                finish_item(it);
            end
        endtask
    endclass

    class fifo_fill_seq extends uvm_sequence #(fifo_item);       // write DEPTH+4 times: hits full and overflow attempts
        `uvm_object_utils(fifo_fill_seq)
        function new(string name = "fifo_fill_seq"); super.new(name); endfunction
        task body();
            repeat (DEPTH + 4) begin
                fifo_item it = fifo_item::type_id::create("it");
                start_item(it);
                if (!it.randomize() with { wr_en == 1; rd_en == 0; }) `uvm_fatal("RAND", "randomize failed")
                finish_item(it);
            end
        endtask
    endclass

    class fifo_drain_seq extends uvm_sequence #(fifo_item);      // read DEPTH+4 times: hits empty and underflow attempts
        `uvm_object_utils(fifo_drain_seq)
        function new(string name = "fifo_drain_seq"); super.new(name); endfunction
        task body();
            repeat (DEPTH + 4) begin
                fifo_item it = fifo_item::type_id::create("it");
                start_item(it);
                if (!it.randomize() with { wr_en == 0; rd_en == 1; }) `uvm_fatal("RAND", "randomize failed")
                finish_item(it);
            end
        endtask
    endclass

    typedef uvm_sequencer #(fifo_item) fifo_sequencer;

    // ------------------------------------------------------------------ driver
    class fifo_driver extends uvm_driver #(fifo_item);
        `uvm_component_utils(fifo_driver)
        virtual fifo_if vif;
        function new(string name, uvm_component parent); super.new(name, parent); endfunction
        function void build_phase(uvm_phase phase);
            if (!uvm_config_db#(virtual fifo_if)::get(this, "", "vif", vif)) `uvm_fatal("NOVIF", "no virtual interface")
        endfunction
        task run_phase(uvm_phase phase);
            vif.drv_cb.wr_en <= 0; vif.drv_cb.rd_en <= 0;
            forever begin
                seq_item_port.get_next_item(req);
                @(vif.drv_cb);
                vif.drv_cb.wr_en   <= req.wr_en;
                vif.drv_cb.rd_en   <= req.rd_en;
                vif.drv_cb.wr_data <= req.wr_data;
                seq_item_port.item_done();
            end
        endtask
    endclass

    // ------------------------------------------------------------------ monitor
    // Emits one item per cycle with the DUT's pre-edge view (flags, head data) and the
    // request that was presented, so the scoreboard can decide what was accepted.
    class fifo_monitor extends uvm_monitor;
        `uvm_component_utils(fifo_monitor)
        virtual fifo_if vif;
        uvm_analysis_port #(fifo_item) ap;
        function new(string name, uvm_component parent); super.new(name, parent); endfunction
        function void build_phase(uvm_phase phase);
            ap = new("ap", this);
            if (!uvm_config_db#(virtual fifo_if)::get(this, "", "vif", vif)) `uvm_fatal("NOVIF", "no virtual interface")
        endfunction
        task run_phase(uvm_phase phase);
            forever begin
                @(vif.mon_cb);
                if (vif.mon_cb.rst_n) begin
                    fifo_item it = fifo_item::type_id::create("mon_it");
                    it.wr_en = vif.mon_cb.wr_en;   it.rd_en = vif.mon_cb.rd_en;   it.wr_data = vif.mon_cb.wr_data;
                    it.rd_data = vif.mon_cb.rd_data;
                    it.full = vif.mon_cb.full;     it.empty = vif.mon_cb.empty;
                    it.almost_full = vif.mon_cb.almost_full; it.almost_empty = vif.mon_cb.almost_empty;
                    it.count = vif.mon_cb.count;
                    ap.write(it);
                end
            end
        endtask
    endclass

