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

