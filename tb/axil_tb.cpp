// AXI4-Lite randomized master + scoreboard, with protocol monitors:
//  * random address/data/strobe writes and reads with random valid/ready delays
//  * register-bank model (byte strobes, RO counter register, out-of-range -> SLVERR)
//  * VALID-hold / payload-stable rules checked every cycle
#include <cstdint>
#include <cstdio>
#include <queue>
#include DUT_HEADER

static cxxrtl_design::p_axil__regs t;
static uint32_t st = 1234567u;
static uint32_t rnd() { st ^= st << 13; st ^= st >> 17; st ^= st << 5; return st; }
static int errors = 0;
#define CHECK(c, ...) do { if (!(c)) { if (errors++ < 15) { std::printf("FAIL: "); std::printf(__VA_ARGS__); std::printf("\n"); } } } while (0)

static void tick() { t.p_clk.set<bool>(false); t.step(); t.p_clk.set<bool>(true); t.step(); }

int main() {
  const int NREGS = 4, ADDR_MAX = 64;
  uint32_t regs[NREGS] = {0};
  t.p_rst__n.set<bool>(false); tick(); tick(); t.p_rst__n.set<bool>(true);

  long writes = 0, reads = 0, slverr = 0;
  bool prev_bvalid = false, prev_bready = false, prev_rvalid = false, prev_rready = false;
  uint32_t prev_bresp = 0, prev_rdata = 0, prev_rresp = 0;

  for (long op = 0; op < 60000; ++op) {
    bool is_write = rnd() & 1;
    uint32_t addr = (rnd() % 8 == 0) ? (rnd() % ADDR_MAX) & ~3u : (rnd() % NREGS) * 4;   // mostly in range, sometimes not
    uint32_t idx = addr / 4;
    if (is_write) {
      uint32_t data = rnd(); uint32_t strb = rnd() & 0xF;
      // present AW and W with independent random delays; hold until accepted
      int aw_delay = rnd() % 4, w_delay = rnd() % 4, b_delay = rnd() % 4;
      bool aw_done = false, w_done = false, got_b = false; int cycles = 0; uint32_t exp_bresp = 0;
      t.p_awaddr.set<uint32_t>(addr); t.p_wdata.set<uint32_t>(data); t.p_wstrb.set<uint32_t>(strb);
      while (!got_b) {
        bool aw_on = aw_delay-- <= 0 && !aw_done, w_on = w_delay-- <= 0 && !w_done;
        t.p_awvalid.set<bool>(aw_on); t.p_wvalid.set<bool>(w_on);
        bool bready = b_delay-- <= 0 ? (rnd() % 3 != 0) : false;
        t.p_bready.set<bool>(bready);
        t.p_arvalid.set<bool>(false); t.p_rready.set<bool>(true);
        t.p_clk.set<bool>(false); t.step();
        // sample handshakes before the edge (ready may combinationally depend on valid)
        bool aw_hs = t.p_awvalid.get<bool>() && t.p_awready.get<bool>(), w_hs = t.p_wvalid.get<bool>() && t.p_wready.get<bool>();
        bool b_hs = t.p_bvalid.get<bool>() && bready;
        uint32_t bresp = t.p_bresp.get<uint32_t>();
        // protocol monitor for B
        if (prev_bvalid && !prev_bready) { CHECK(t.p_bvalid.get<bool>(), "BVALID dropped before BREADY"); CHECK(bresp == prev_bresp, "BRESP changed while stalled"); }
        prev_bvalid = t.p_bvalid.get<bool>(); prev_bready = bready; prev_bresp = bresp;
        t.p_clk.set<bool>(true); t.step();
        if (aw_hs) aw_done = true;
        if (w_hs) w_done = true;
        if (aw_hs && w_hs) {
          bool ok = idx < NREGS - 1; exp_bresp = ok ? 0 : 2;
          if (ok) { for (int b = 0; b < 4; ++b) if (strb >> b & 1) regs[idx] = (regs[idx] & ~(0xFFu << 8 * b)) | (data & (0xFFu << 8 * b)); regs[NREGS - 1]++; }
          else ++slverr;
          ++writes;
        }
        if (b_hs) { CHECK(bresp == exp_bresp, "BRESP got %u want %u (addr %u)", bresp, exp_bresp, addr); got_b = true; }
        CHECK(++cycles < 100, "write timeout");
        if (cycles >= 100) break;
      }
      // response code seen at handshake time is validated via the subsequent read-back below
      t.p_awvalid.set<bool>(false); t.p_wvalid.set<bool>(false); t.p_bready.set<bool>(false);
    } else {
      int ar_delay = rnd() % 4, r_delay = rnd() % 4; bool ar_done = false, got_r = false; int cycles = 0;
      t.p_araddr.set<uint32_t>(addr);
      t.p_awvalid.set<bool>(false); t.p_wvalid.set<bool>(false); t.p_bready.set<bool>(true);
      while (!got_r) {
        bool ar_on = ar_delay-- <= 0 && !ar_done;
        t.p_arvalid.set<bool>(ar_on);
        bool rready = r_delay-- <= 0 ? (rnd() % 3 != 0) : false;
        t.p_rready.set<bool>(rready);
        t.p_clk.set<bool>(false); t.step();
        bool ar_hs = t.p_arvalid.get<bool>() && t.p_arready.get<bool>();
        bool r_hs = t.p_rvalid.get<bool>() && rready;
        uint32_t rd = t.p_rdata.get<uint32_t>(), rr = t.p_rresp.get<uint32_t>();
        if (prev_rvalid && !prev_rready) { CHECK(t.p_rvalid.get<bool>(), "RVALID dropped before RREADY"); CHECK(rd == prev_rdata && rr == prev_rresp, "RDATA/RRESP changed while stalled"); }
        prev_rvalid = t.p_rvalid.get<bool>(); prev_rready = rready; prev_rdata = rd; prev_rresp = rr;
        if (r_hs) {
          if (idx < NREGS) { CHECK(rd == regs[idx] && rr == 0, "read reg %u got %08x resp %u want %08x", idx, rd, rr, regs[idx]); }
          else { CHECK(rr == 2, "out-of-range read must return SLVERR, got %u", rr); ++slverr; }
          ++reads;
        }
        t.p_clk.set<bool>(true); t.step();
        if (ar_hs) ar_done = true;
        if (r_hs) got_r = true;
        CHECK(++cycles < 100, "read timeout");
        if (cycles >= 100) break;
      }
      t.p_arvalid.set<bool>(false); t.p_rready.set<bool>(false);
    }
  }
  if (errors) { std::printf("axil: %d FAILURES\n", errors); return 1; }
  std::printf("axil: all checks passed (%ld writes, %ld reads, %ld SLVERR cases; hold/stability monitors clean)\n", writes, reads, slverr);
}
