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

