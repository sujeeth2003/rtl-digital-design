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

