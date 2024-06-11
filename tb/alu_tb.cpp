// Self-checking ALU testbench against an independent C++ reference model
// (128-bit arithmetic for carry/overflow, so it does not share logic with the RTL).
#include <cstdint>
#include <cstdio>
#include DUT_HEADER

static cxxrtl_design::p_alu t;
static int errors = 0, checks = 0;
static uint32_t st = 2463534242u;
static uint32_t rnd() { st ^= st << 13; st ^= st >> 17; st ^= st << 5; return st; }

