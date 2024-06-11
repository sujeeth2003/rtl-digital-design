// Self-checking ALU testbench against an independent C++ reference model
// (128-bit arithmetic for carry/overflow, so it does not share logic with the RTL).
#include <cstdint>
#include <cstdio>
#include DUT_HEADER

static cxxrtl_design::p_alu t;
static int errors = 0, checks = 0;
static uint32_t st = 2463534242u;
static uint32_t rnd() { st ^= st << 13; st ^= st >> 17; st ^= st << 5; return st; }

struct Ref { uint32_t r; bool z, n, c, v; };
static Ref model(int op, uint32_t a, uint32_t b) {
  Ref m{}; bool arith = false;
  int64_t sa = (int32_t)a, sb = (int32_t)b;
  unsigned sh = b & 31;
  switch (op) {
    case 0: { uint64_t s = (uint64_t)a + b; m.r = (uint32_t)s; m.c = s >> 32; int64_t ss = sa + sb; m.v = ss != (int32_t)ss; arith = true; break; }
    case 1: { uint64_t s = (uint64_t)a + (uint32_t)~b + 1; m.r = (uint32_t)s; m.c = s >> 32; int64_t ss = sa - sb; m.v = ss != (int32_t)ss; arith = true; break; }
    case 2: m.r = a & b; break;
    case 3: m.r = a | b; break;
    case 4: m.r = a ^ b; break;
    case 5: m.r = ~(a | b); break;
    case 6: m.r = a << sh; break;
    case 7: m.r = a >> sh; break;
    case 8: m.r = (uint32_t)((int32_t)a >> sh); break;
    case 9: m.r = sa < sb; break;
    case 10: m.r = a < b; break;
    case 11: m.r = b; break;
    default: m.r = 0;
  }
  m.z = m.r == 0; m.n = m.r >> 31;
  if (!arith) { m.c = false; m.v = false; }
  return m;
}

static void check(int op, uint32_t a, uint32_t b) {
  t.p_a.set<uint32_t>(a); t.p_b.set<uint32_t>(b); t.p_op.set<uint32_t>(op); t.step();
  Ref m = model(op, a, b);
  uint32_t r = t.p_result.get<uint32_t>(), f = t.p_flags.get<uint32_t>();   // {zero,negative,carry,overflow}
  bool z = f >> 3 & 1, n = f >> 2 & 1, c = f >> 1 & 1, v = f & 1;
  ++checks;
  if (r != m.r || z != m.z || n != m.n || c != m.c || v != m.v) {
    if (errors++ < 15) std::printf("FAIL op=%d a=%08x b=%08x  rtl r=%08x zncv=%d%d%d%d  ref r=%08x zncv=%d%d%d%d\n", op, a, b, r, z, n, c, v, m.r, m.z, m.n, m.c, m.v);
  }
}

