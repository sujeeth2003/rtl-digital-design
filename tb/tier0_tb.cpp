// Self-checking testbench for the tier-0 blocks, driven through CXXRTL.
// Combinational blocks are compared against C++ reference expressions
// (exhaustively where the input space is small); sequential blocks are
// compared cycle by cycle against a C++ model.
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include DUT_HEADER

static cxxrtl_design::p_tier0__top t;
static int errors = 0;
#define CHECK(cond, ...) do { if (!(cond)) { if (errors < 20) { std::printf("FAIL: "); std::printf(__VA_ARGS__); std::printf("\n"); } ++errors; } } while (0)

template <class S, class V> static void set(S& s, V v) { s.template set<uint64_t>((uint64_t)v); }
template <class S> static uint64_t get(S& s) { return s.template get<uint64_t>(); }
static void settle() { t.step(); }
static void tick() { t.p_clk.set<bool>(false); settle(); t.p_clk.set<bool>(true); settle(); }

static uint32_t rng_state = 12345;
static uint32_t rnd() { rng_state = rng_state * 1664525u + 1013904223u; return rng_state >> 8; }

int main() {
  // ---- combinational: adders (random + corner cases) -------------------------
  for (int i = 0; i < 200000; ++i) {
    uint32_t a = (i < 4) ? (i & 1 ? 0xFFFF : 0) : rnd() & 0xFFFF;
    uint32_t b = (i < 4) ? (i & 2 ? 0xFFFF : 0) : rnd() & 0xFFFF;
    uint32_t cin = rnd() & 1;
    set(t.p_a, a); set(t.p_b, b); set(t.p_cin, cin); settle();
    uint32_t ref = a + b + cin;
    CHECK(get(t.p_rca__sum) == (ref & 0xFFFF) && get(t.p_rca__cout) == (ref >> 16), "ripple %x+%x+%x", a, b, cin);
    CHECK(get(t.p_cla__sum) == (ref & 0xFFFF) && get(t.p_cla__cout) == (ref >> 16), "cla %x+%x+%x", a, b, cin);
  }
  // ---- multiplier: exhaustive 8x8 ------------------------------------------
  for (uint32_t a = 0; a < 256; ++a)
    for (uint32_t b = 0; b < 256; ++b) {
      set(t.p_a, a); set(t.p_b, b); settle();
      CHECK(get(t.p_mul__p) == a * b, "mul %u*%u = %llu", a, b, (unsigned long long)get(t.p_mul__p));
    }
  // ---- priority encoder: exhaustive ---------------------------------------
  for (uint32_t r = 0; r < 256; ++r) {
    set(t.p_req, r); settle();
    int idx = -1;
    for (int i = 0; i < 8; ++i) if (r >> i & 1) idx = i;
    CHECK(get(t.p_enc__valid) == (idx >= 0), "enc valid req=%02x", r);
    if (idx >= 0) CHECK((int)get(t.p_enc__idx) == idx, "enc idx req=%02x got %llu want %d", r, (unsigned long long)get(t.p_enc__idx), idx);
  }
  // ---- barrel shifter: every amount x mode, many data words ----------------
  for (int n = 0; n < 2000; ++n) {
    uint16_t d = (n < 4) ? (n == 0 ? 0 : n == 1 ? 0xFFFF : n == 2 ? 0x8000 : 1) : rnd() & 0xFFFF;
    for (int mode = 0; mode < 3; ++mode)
