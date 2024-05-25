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
      for (int amt = 0; amt < 16; ++amt) {
        set(t.p_a, d); set(t.p_sh__mode, mode); set(t.p_sh__amt, amt); settle();
        uint16_t ref = mode == 0 ? (uint16_t)(d << amt) : mode == 1 ? (uint16_t)(d >> amt) : (uint16_t)((int16_t)d >> amt);
        CHECK(get(t.p_shf) == ref, "shift mode=%d amt=%d d=%04x got %04llx want %04x", mode, amt, d, (unsigned long long)get(t.p_shf), ref);
      }
  }

  // ---- sequential: model of dffs, counter, shift register, 1011 detector --
  set(t.p_rst__n, 0); set(t.p_en, 0);
  for (int i = 0; i < 3; ++i) tick();
  CHECK(get(t.p_cnt) == 0 && get(t.p_sr__q) == 0 && get(t.p_dff__a__q) == 0, "reset state");
  set(t.p_rst__n, 1);

  uint8_t m_cnt = 0, m_sr = 0; bool m_da = false, m_ds = false;
  int m_state = 0;   // 0 idle,1 "1",2 "10",3 "101",4 "1011"
  for (int c = 0; c < 200000; ++c) {
    bool en = rnd() & 1, load = (rnd() % 8) == 0, up = rnd() & 1, d = rnd() & 1, ser = rnd() & 1, bit = rnd() & 1;
    uint8_t lv = rnd() & 0xFF, pi = rnd() & 0xFF; int mode = rnd() & 3;
    bool rst_n = (rnd() % 500) != 0;
    set(t.p_en, en); set(t.p_load, load); set(t.p_up, up); set(t.p_d__in, d); set(t.p_ser__in, ser);
    set(t.p_bit__in, bit); set(t.p_load__val, lv); set(t.p_par__in, pi); set(t.p_sr__mode, mode);
    set(t.p_rst__n, rst_n);
    t.p_clk.set<bool>(false); settle();
    // async reset flop reacts immediately when rst_n falls
    if (!rst_n) m_da = false;
    settle();
    CHECK(get(t.p_dff__a__q) == m_da, "dff_async after async reset, cycle %d", c);
    t.p_clk.set<bool>(true); settle();
    // reference model, sampled on the rising edge
    if (!rst_n) { m_cnt = 0; m_sr = 0; m_ds = false; m_da = false; m_state = 0; }
    else {
      if (en) { m_da = d; m_ds = d; }
      if (load) m_cnt = lv; else if (en) m_cnt = up ? m_cnt + 1 : m_cnt - 1;
      if (mode == 1) m_sr = (ser << 7) | (m_sr >> 1); else if (mode == 2) m_sr = (m_sr << 1) | ser; else if (mode == 3) m_sr = pi;
      static const int nxt[5][2] = {{0, 1}, {2, 1}, {0, 3}, {2, 4}, {2, 1}};
      m_state = nxt[m_state][bit];
    }
    CHECK(get(t.p_dff__a__q) == m_da, "dff_async cycle %d", c);
    CHECK(get(t.p_dff__s__q) == m_ds, "dff_sync cycle %d", c);
    CHECK(get(t.p_cnt) == m_cnt, "counter cycle %d got %llu want %u", c, (unsigned long long)get(t.p_cnt), m_cnt);
    CHECK(get(t.p_sr__q) == m_sr, "shift_reg cycle %d", c);
    CHECK(get(t.p_detected) == (m_state == 4), "detector cycle %d", c);
  }

  if (errors) { std::printf("tier0: %d FAILURES\n", errors); return 1; }
  std::printf("tier0: all checks passed (adders 200k random, mult 65536 exhaustive, encoder 256 exhaustive, shifter 96k, 200k sequential cycles)\n");
  return 0;
}
