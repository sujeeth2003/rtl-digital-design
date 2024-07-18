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
