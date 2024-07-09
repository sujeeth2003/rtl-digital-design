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

