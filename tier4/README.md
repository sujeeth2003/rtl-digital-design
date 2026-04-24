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

### Timing closure: 56 MHz -> 77 MHz
Baseline (25 MHz target passes easily; the interesting number is the maximum the design can reach):

| Step | Change | Fmax |
|---|---|---|
| baseline | as verified in tiers 0-3 | **56.0 MHz** |
| 1 | On a flush/stall, reset only the *control* bits of the ID/EX register (datapath values are ignored when `valid=0`); and get `<` / `<u` from **one** subtraction instead of three comparators | 61.6 MHz |
| 2 | Instruction/data RAM in **LUT RAM instead of block RAM** (`-nobram`): a block RAM's ~5.6 ns clk-to-q sat on the fetch -> decode -> stall path | 66.6 MHz |
| 3 | **Compute the forwarding selects one stage early (in ID) and register them**, instead of comparing register numbers in EX | **77.2 MHz** (timing **passes at a 75 MHz target**) |

How each fix was found: read the nextpnr critical-path report, fix the worst offender, re-run.
1. The baseline path was `forwarding mux -> 32-bit branch compare -> ex_taken -> flush -> reset of ~130 ID/EX flops` (17.9 ns, with 1.8 ns of routing on the flush net alone).
2. Then the path started at the block RAM output.
3. Then `memwb_rd == rs` compare -> select decode -> mux -> JALR target adder -> `pc`. After step 3 the worst path is the ALU itself (idex select -> forward mux -> ALU -> EX/MEM result), which is the natural limit of this pipeline.

**After every change the full CPU regression was re-run**: the core still matches the golden ISS on all 8 directed + 200 random hazard-stress programs (see the main README). Random hazard programs are what catches a wrong early-forwarding condition.

Resources at 25 MHz on the LFE5U-25F: about 3,255 LUT4-equivalents (13%), 358 flip-flops, 160 LUT-RAM write ports (5%), 10 I/O, 0 block RAMs. The bitstream builds (about 144 KB), and that is as far as I can take it without a board. (I do not commit the bitstream: it has never run and its pin map is unverified.)

Not done: a PLL to actually clock the core at 75 MHz on the board (the design closes there, but the top level uses the raw 25 MHz oscillator); a UART for output; a block-RAM version of the fetch stage (needs a registered-output redesign of IF to keep the speed).

