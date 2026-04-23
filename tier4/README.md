# Tier 4: FPGA implementation and ASIC-style synthesis

Takes the 5-stage RISC-V core from RTL to (a) an **FPGA bitstream** with a timing-closure exercise, and (b) **gate-level synthesis with formal equivalence checking**, the front end of an ASIC flow.

> **Honest scope.** No FPGA board was available, so **nothing here has been loaded onto hardware**: the design is verified by simulation and by the open-source toolchain's own place-and-route timing, not on a board. The ULX3S pin file is written from memory of the public pinout and **must be checked against the schematic** before use. For the ASIC side I ran logic synthesis and equivalence checking only; **floorplan, placement, clock-tree, routing and signoff timing were not run** (they need a PDK and OpenROAD/OpenLane, not installable here). `asic/openlane_config.json` is a starting point and is untested.

## FPGA: Lattice ECP5 (LFE5U-25F, ULX3S-style board)
```
firmware (assembly) --tools/riscv_asm.py--> hex --> initial contents of the instruction RAM
 SystemVerilog SoC --Yosys synth_ecp5--> netlist --nextpnr-ecp5 (place & route, timing-driven)--> config --ecppack--> bitstream
```
```bash
pip install yowasp-yosys yowasp-nextpnr-ecp5      # also provides yowasp-ecppack
python tier4/test_soc.py                          # simulate the SoC + firmware first
python tier4/fpga/build.py --freq 75 --no-bitstream   # place & route against a 75 MHz target
python tier4/fpga/build.py                        # 25 MHz build + bitstream (the board's oscillator)
```
- **SoC (`fpga/fpga_top.sv`):** the core, 1 KiB instruction RAM (initialised from the firmware at synthesis time), 1 KiB data RAM, one memory-mapped LED register at `0x1000`, reset-button synchroniser.
- **Firmware (`fw/blink.s`):** a binary counter on the 8 LEDs, one step about every 0.25 s. `fw/blink_sim.s` is the same with a tiny delay so a simulation can watch it.
- **Simulation before hardware (`test_soc.py`):** LEDs count 1..8 in order (including a read-back through the MMIO path) and the core then halts with all LEDs on. Passes.

