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

