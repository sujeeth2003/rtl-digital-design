// Randomized self-checking testbench for sync_fifo (16 x 8, defaults):
// std::deque scoreboard, checks data, ordering, all four flags and count every cycle,
// with bursts of writes-only / reads-only to hit full and empty, and mid-run resets.
#include <cstdint>
#include <cstdio>
#include <deque>
#include DUT_HEADER

static cxxrtl_design::p_sync__fifo t;
static uint32_t st = 88172645u;
static uint32_t rnd() { st ^= st << 13; st ^= st >> 17; st ^= st << 5; return st; }
static int errors = 0;
#define CHECK(c, ...) do { if (!(c)) { if (errors++ < 15) { std::printf("FAIL cycle: "); std::printf(__VA_ARGS__); std::printf("\n"); } } } while (0)

int main() {
  const int DEPTH = 16, AF = 2, AE = 2;
  std::deque<uint8_t> model;
  long full_cycles = 0, empty_cycles = 0, wraps = 0, reads = 0, writes = 0;
  t.p_rst__n.set<bool>(false);
  for (int i = 0; i < 3; ++i) { t.p_clk.set<bool>(false); t.step(); t.p_clk.set<bool>(true); t.step(); }
  t.p_rst__n.set<bool>(true);

  int phase = 0;
  for (long c = 0; c < 1000000; ++c) {
    if (c % 5000 == 0) phase = rnd() % 4;                 // 0 balanced, 1 write-heavy, 2 read-heavy, 3 bursty
    uint32_t pw = phase == 1 ? 90 : phase == 2 ? 20 : 50, pr = phase == 1 ? 20 : phase == 2 ? 90 : 50;
    if (phase == 3) { pw = (c / 37) % 2 ? 100 : 0; pr = (c / 37) % 2 ? 0 : 100; }
    bool wr = rnd() % 100 < pw, rd = rnd() % 100 < pr;
    uint8_t wd = rnd() & 0xFF;
    bool rst = (rnd() % 20000) == 0;
    t.p_wr__en.set<bool>(wr); t.p_wr__data.set<uint8_t>(wd); t.p_rd__en.set<bool>(rd); t.p_rst__n.set<bool>(!rst);
    t.p_clk.set<bool>(false); t.step();

    // combinational outputs before the edge must match the model
    size_t n = model.size();
    CHECK(t.p_full.get<bool>() == (n == DEPTH), "full n=%zu", n);
    CHECK(t.p_empty.get<bool>() == (n == 0), "empty n=%zu", n);
    CHECK(t.p_count.get<uint32_t>() == n, "count %u vs %zu", t.p_count.get<uint32_t>(), n);
    CHECK(t.p_almost__full.get<bool>() == (n >= (size_t)(DEPTH - AF)), "almost_full n=%zu", n);
    CHECK(t.p_almost__empty.get<bool>() == (n <= (size_t)AE), "almost_empty n=%zu", n);
    if (n) CHECK(t.p_rd__data.get<uint8_t>() == model.front(), "head data got %02x want %02x", t.p_rd__data.get<uint8_t>(), model.front());
    full_cycles += n == DEPTH; empty_cycles += n == 0;

    t.p_clk.set<bool>(true); t.step();
    if (rst) { model.clear(); continue; }
    bool do_wr = wr && n < DEPTH, do_rd = rd && n > 0;    // simultaneous read+write on a full FIFO: write is dropped (full is sampled pre-edge)
    if (do_rd) { model.pop_front(); ++reads; }
    if (do_wr) { model.push_back(wd); ++writes; }
    if (do_wr && do_rd && n == DEPTH) {}                   // unreachable: do_wr false when full
  }
  (void)wraps;
  if (errors) { std::printf("fifo: %d FAILURES\n", errors); return 1; }
  std::printf("fifo: all checks passed over 1M cycles (%ld writes, %ld reads, %ld cycles full, %ld cycles empty, mid-run resets)\n", writes, reads, full_cycles, empty_cycles);
}
