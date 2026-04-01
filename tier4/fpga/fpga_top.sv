// FPGA system-on-chip: the 5-stage RISC-V core + small instruction/data RAM + one memory-mapped LED register.
//
//   0x0000-0x03FF  data RAM (1 KiB)          0x1000  LED register (write: 8 LEDs, read: current value)
//
// The instruction RAM is initialised from a hex file at synthesis time (the firmware), so the bitstream is self-contained.
// When the CPU executes EBREAK it halts and the LEDs show the halted state (all on, blinking is stopped by the firmware anyway).
`ifndef FW_HEX
`define FW_HEX "tier4/build/blink.hex"
`endif

module fpga_top #(
    parameter int IAW = 8,          // instruction RAM: 2**IAW words (256 words = 1 KiB)
    parameter int DAW = 8           // data RAM:        2**DAW words
) (
    input  logic       clk_25mhz,
    input  logic       btn_rst_n,   // active-low reset button
    output logic [7:0] led
);
    // ---- reset: synchronise the button into the clock domain (4 flops) ------------------------------------
    logic [3:0] rst_sr = 4'b0000;
    always_ff @(posedge clk_25mhz) rst_sr <= {rst_sr[2:0], btn_rst_n};
    wire rst_n = rst_sr[3];

    // ---- core ---------------------------------------------------------------------------------------------
    logic [31:0] imem_addr, imem_rdata, dmem_addr, dmem_wdata, dmem_rdata_ram, dmem_rdata;
    logic        dmem_we;
    logic [2:0]  dmem_funct3;
    logic        halted;
    logic [31:0] retired, stalls, flushes;

