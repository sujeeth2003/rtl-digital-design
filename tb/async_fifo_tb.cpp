// Async FIFO testbench: two independent clocks with randomized (jittered) periods
// and randomly changing frequency ratios; each domain samples its own flag.
// Scoreboard = std::deque. Safety checked every accepted transfer:
//   * never write when the model already holds DEPTH items  (overflow)
//   * never read  when the model is empty                   (underflow)
//   * data and order are preserved
// Liveness: after writers stop, the FIFO must drain completely.
#include <cstdint>
#include <cstdio>
#include <deque>
#include DUT_HEADER

static cxxrtl_design::p_async__fifo t;
static uint32_t st = 2718281828u;
static uint32_t rnd() { st ^= st << 13; st ^= st >> 17; st ^= st << 5; return st; }
static int errors = 0;
#define CHECK(c, ...) do { if (!(c)) { if (errors++ < 15) { std::printf("FAIL: "); std::printf(__VA_ARGS__); std::printf("\n"); } } } while (0)

int main() {
  const size_t DEPTH = 16;
  std::deque<uint8_t> model;
  long writes = 0, reads = 0, full_seen = 0, empty_seen = 0;

  t.p_wrst__n.set<bool>(false); t.p_rrst__n.set<bool>(false); t.step();
  // a few clocks in reset
  for (int i = 0; i < 4; ++i) { t.p_wclk.set<bool>(i & 1); t.p_rclk.set<bool>(i & 1); t.step(); }
  t.p_wclk.set<bool>(false); t.p_rclk.set<bool>(false); t.step();
  t.p_wrst__n.set<bool>(true); t.p_rrst__n.set<bool>(true); t.step();

  uint64_t now = 0, next_w = 3, next_r = 5;       // time in ps-like units
  bool wc = false, rc = false;
  uint32_t wper = 700, rper = 1100;               // half-periods
  double pw = 0.5, pr = 0.5;
  const long TOTAL_EDGES = 2'000'000;
  long edges = 0;
  bool stop_writes = false;

  while (edges < TOTAL_EDGES || !(model.empty() && t.p_rempty.get<bool>())) {
    if (edges > TOTAL_EDGES + 200000) { std::printf("FAIL: did not drain\n"); ++errors; break; }
    if (edges == TOTAL_EDGES) stop_writes = true;
    now = next_w < next_r ? next_w : next_r;
    bool do_w = next_w <= next_r, do_r = next_r <= next_w;   // may coincide: both edges at once
    // occasionally change frequency ratio and traffic shape
    if (edges % 20000 == 0) {
      wper = 300 + rnd() % 1500; rper = 300 + rnd() % 1500;
      pw = (rnd() % 100) / 100.0; pr = (rnd() % 100) / 100.0;
    }
    // sample DUT inputs/outputs on the domain's rising edge BEFORE applying the edge
    bool w_rise = do_w && !wc, r_rise = do_r && !rc;
    bool winc = false, rinc = false; uint8_t wd = 0;
    bool wfull_pre = t.p_wfull.get<bool>(), rempty_pre = t.p_rempty.get<bool>();
    uint8_t rdata_pre = t.p_rdata.get<uint8_t>();
    if (w_rise) { winc = !stop_writes && (rnd() % 1000) < pw * 1000; wd = rnd() & 0xFF; t.p_winc.set<bool>(winc); t.p_wdata.set<uint8_t>(wd); }
    if (r_rise) { rinc = (rnd() % 1000) < pr * 1000; t.p_rinc.set<bool>(rinc); }
    if (do_w) { wc = !wc; t.p_wclk.set<bool>(wc); next_w = now + wper + rnd() % 60; }
    if (do_r) { rc = !rc; t.p_rclk.set<bool>(rc); next_r = now + rper + rnd() % 60; }
    t.step();
    edges += 1;

