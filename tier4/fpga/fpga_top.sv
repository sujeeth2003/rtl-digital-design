// FPGA system-on-chip: the 5-stage RISC-V core + small instruction/data RAM + one memory-mapped LED register.
//
//   0x0000-0x03FF  data RAM (1 KiB)          0x1000  LED register (write: 8 LEDs, read: current value)
//
// The instruction RAM is initialised from a hex file at synthesis time (the firmware), so the bitstream is self-contained.
// When the CPU executes EBREAK it halts and the LEDs show the halted state (all on, blinking is stopped by the firmware anyway).
`ifndef FW_HEX
`define FW_HEX "tier4/build/blink.hex"
`endif

