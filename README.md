# RTL / Digital Design (SystemVerilog)

Tiers 0-3 of a bottom-up RTL curriculum: gates and adders -> parameterized datapath blocks -> FIFOs and clock-domain crossing -> a 5-stage pipelined RISC-V core, each verified with more than one method. Everything is written in synthesizable SystemVerilog that open-source **Yosys** parses, so the whole repo can be checked with `pip install` tools only.

> **Not done: Tier 4** (FPGA board bring-up, timing closure, ASIC flow). Everything up to synthesis-ready RTL is covered; nothing here has been placed and routed.

## What is here, and how each block was verified

| Block | RTL | Simulation (CXXRTL, cycle accurate) | Formal (SymbiYosys + z3) |
|---|---|---|---|
| Tier 0: gate-level full adder, ripple and carry-lookahead adders, array multiplier, priority encoder, barrel shifter, D flip-flops (async/sync reset), up/down counter, universal shift register, Moore FSM (1011 detector) | `rtl/tier0/` | 200k random adds, **exhaustive** 8x8 multiplier (65,536) and priority encoder (256), 96k shifter cases, 200k random sequential cycles vs a C++ model | 16-bit ripple + CLA adders, 6x6 multiplier, 8-bit shifter and encoder proven equal to the behavioural operators for **all** inputs |
| Parameterized ALU (any width, enum opcodes, struct flags) | `rtl/alu/alu.sv` | 1.3M checks vs an independent 64-bit C++ model, incl. carry/overflow flags | 8-bit ALU, every opcode and flag, proven for all inputs (k-induction) |
| Configurable sync FIFO (extended pointers, full/empty/almost-full/almost-empty, count) | `rtl/fifo/sync_fifo.sv` | 1M random cycles vs `std::deque`, with resets and full/empty stress | **Ordering and data integrity proven** (tracks an arbitrary slot), plus flag/count invariants (k-induction) |
| CDC: 2-flop synchronizer, Gray counter, async FIFO with Gray pointers | `rtl/cdc/` | Two independent, randomly jittered clocks whose ratio is re-randomized every 20k edges; 153k transfers, no overflow/underflow, data in order, full drain | Gray properties proven: `gray2bin(bin2gray(x)) == x` and consecutive values differ in exactly 1 bit (incl. wrap) |
| AXI4-Lite slave register bank (VALID/READY, byte strobes, SLVERR, read-only counter) | `rtl/axi_lite/axil_regs.sv` | 60k random transactions with random VALID/READY delays, register scoreboard, hold/stability monitors | Handshake rules proven with immediate assertions. Concurrent SVA version: `rtl/axi_lite/axil_sva.sv` (**not run**, see below) |
| 5-stage RISC-V core (RV32I subset), forwarding, load-use stall, branch flush | `rtl/riscv/` | **Cosimulated against a golden Python ISS**: 8 directed programs + **200 random hazard-stress programs**, every register, all 1024 data words and the retired count compared: **208/208 match** | not attempted |

The core implements LUI AUIPC JAL JALR, all six branches, LB/LH/LW/LBU/LHU/SB/SH/SW, all OP-IMM and OP instructions, and EBREAK (halt). No CSRs, interrupts, FENCE, M/C extensions or misaligned-access traps.

### RISC-V core numbers (from the cosim run)
20,630 instructions retired in 26,528 cycles (**CPI 1.29**), 552 load-use stalls, 2,257 taken-branch/jump flushes over the 208 programs. Per program:

| program | retired | cycles | CPI |
|---|---|---|---|
| alu / memory / hazards | 31 / 30 / 27 | 35 / 34 / 35 | 1.13 / 1.13 / 1.30 |
| fib, branches, calls | 207 / 233 / 257 | 260 / 315 / 385 | 1.26 / 1.35 / 1.50 |
| sort (16 elements), sieve (primes <= 100) | 1933 / 1525 | 2855 / 2289 | 1.48 / 1.50 |

### Hazards handled (`rtl/riscv/hazard_unit.sv`)
- **Forwarding** from MEM and WB into EX (MEM has priority), plus a register-file write-first bypass for the ID/WB overlap
- **Load-use**: 1-cycle stall + bubble, then WB->EX forwarding
- **Control**: branches/jumps resolve in EX, 2-cycle flush of the younger instructions
- **EBREAK**: squashes everything younger, so the final state is exactly the state before the EBREAK

## Run it
```bash
pip install yowasp-yosys z3-solver ziglang        # or install yosys + sby + a C++ compiler natively
python tools/rtl.py list
python tools/rtl.py sim tier0     # also: alu fifo async_fifo axil riscv
python tools/rtl.py formal alu    # also: tier0 fifo gray axil
python tools/rtl.py all
python tools/riscv_cosim.py --netsim --random 200      # RISC-V cosim without a native simulator
python tools/netsim_selftest.py
```
`tools/rtl.py sim` runs Yosys -> CXXRTL C++ -> compiles `tb/*.cpp` with your C++ compiler -> runs it. `SBY`/`YOSYS`/`CXX` environment variables override tool locations (e.g. `CXX="python -m ziglang c++"`).

### Honest notes on tooling and coverage
- **Two simulation backends.** CXXRTL testbenches (`tb/`) were run for tier0, alu, fifo, async_fifo and axil. For the RISC-V core the CXXRTL harness (`tb/riscv_tb.cpp`) compiles, but on the development machine Windows Application Control refused to launch the freshly built executable, so the RISC-V results above come from `tools/netsim.py`, a small pure-Python simulator that executes Yosys's word-level JSON netlist. It was validated first against the ALU (3,000 random ops) and FIFO (20,000 random cycles), both of which also passed under CXXRTL. It is slow (~1-2k cycles/s) but complete for this design. On a normal machine `riscv_cosim.py` uses the CXXRTL executable automatically.
- **Zero-delay simulation only.** Neither backend models metastability or gate delays, so the CDC blocks are checked for *logic* correctness (Gray coding, pointer comparison, no overflow/underflow), not for MTBF. The CDC structure follows Cummings' Gray-pointer async FIFO.
- **UVM environment (`uvm/`) is written but has not been run.** No UVM-capable simulator (Questa, VCS, Xcelium, Verilator+UVM) was available. It contains driver, monitor, sequencer, scoreboard, agent, env, functional coverage and directed + random tests for the sync FIFO, but **no regression or coverage numbers are claimed**. The same FIFO is verified by the CXXRTL testbench and the formal proof above.
- **Concurrent SVA (`axil_sva.sv`) has not been run**; open-source Yosys cannot parse it. The same rules are proven with immediate assertions inside `axil_regs.sv`.
- Yosys' front end does not accept typedef'd/enum/struct *ports*, so the ALU's `op` and `flags` ports are plain `logic [3:0]`, with the enum (`alu_pkg::alu_op_t`) and struct (`alu_flags_t`) used inside.
- Formal depth/scope: proofs are for small instances (4x4 FIFO, 8-bit ALU, 6x6 multiplier) because SMT solving cost grows fast; the structure is parameterized and the CXXRTL runs cover the full-size instances.

## Layout
```
rtl/tier0 rtl/alu rtl/fifo rtl/cdc rtl/axi_lite rtl/riscv   synthesizable SystemVerilog
tb/                CXXRTL C++ testbenches
formal/            SymbiYosys jobs (.sby) and formal harnesses
programs/          RISC-V assembly test programs
tools/             rtl.py driver, RISC-V assembler + ISS + random generator + cosim, netsim.py
uvm/               UVM environment for the FIFO (unrun)
```
Related: [verilog-compiler](../verilog-compiler) is a from-scratch Verilog-subset compiler in C++ (lexer, parser, AST, netlist).
