// Loads a program (hex, one word per line) and optional data-RAM image into the core through
// the testbench ports, runs until EBREAK retires, and prints the final architectural state in a
// line-oriented format that tools/riscv_cosim.py compares against the ISS.
//   riscv_sim <program.hex> [data.hex] [max_cycles]
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include DUT_HEADER

static cxxrtl_design::p_riscv__top t;
static void cycle() { t.p_clk.set<bool>(false); t.step(); t.p_clk.set<bool>(true); t.step(); }

