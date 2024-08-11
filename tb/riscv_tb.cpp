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

static int load(const char* path, bool prog) {
  FILE* f = std::fopen(path, "r");
  if (!f) return -1;
  char line[64]; int n = 0;
  while (std::fgets(line, sizeof line, f)) {
    uint32_t w = (uint32_t)std::strtoul(line, nullptr, 16);
    if (prog) { t.p_prog__we.set<bool>(true); t.p_prog__addr.set<uint32_t>(n); t.p_prog__data.set<uint32_t>(w); }
    else      { t.p_dinit__we.set<bool>(true); t.p_dinit__addr.set<uint32_t>(n); t.p_dinit__data.set<uint32_t>(w); }
    cycle(); ++n;
  }
  t.p_prog__we.set<bool>(false); t.p_dinit__we.set<bool>(false);
  std::fclose(f);
  return n;
}

