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

int main(int argc, char** argv) {
  if (argc < 2) { std::fprintf(stderr, "usage: riscv_sim prog.hex [data.hex] [max_cycles]\n"); return 2; }
  long max_cycles = argc > 3 ? std::atol(argv[3]) : 2000000;
  t.p_rst__n.set<bool>(false);
  if (load(argv[1], true) < 0) { std::fprintf(stderr, "cannot open %s\n", argv[1]); return 2; }
  if (argc > 2 && argv[2][0] != '-' && load(argv[2], false) < 0) { std::fprintf(stderr, "cannot open %s\n", argv[2]); return 2; }
  cycle(); cycle();
  t.p_rst__n.set<bool>(true);

  long cycles = 0;
  while (!t.p_halted.get<bool>() && cycles < max_cycles) { cycle(); ++cycles; }
  cycle(); cycle();   // let the pipeline settle after the halt
  std::printf("halted %d\ncycles %ld\nretired %u\nstalls %u\nflushes %u\n", (int)t.p_halted.get<bool>(), cycles,
              t.p_retired.get<uint32_t>(), t.p_stalls.get<uint32_t>(), t.p_flushes.get<uint32_t>());
  for (uint32_t r = 0; r < 32; ++r) { t.p_dbg__reg__addr.set<uint32_t>(r); t.step(); std::printf("x%u %08x\n", r, t.p_dbg__reg__data.get<uint32_t>()); }
  for (uint32_t a = 0; a < 1024; ++a) { t.p_dbg__mem__addr.set<uint32_t>(a); t.step(); std::printf("m%u %08x\n", a, t.p_dbg__mem__data.get<uint32_t>()); }
  return t.p_halted.get<bool>() ? 0 : 1;
}
