#!/usr/bin/env python3
"""Validate the pure-Python netlist simulator against independent models, on blocks that are
also checked with CXXRTL and formal proofs: the ALU (random ops vs a Python reference) and the
synchronous FIFO (random traffic vs collections.deque)."""
import random
import sys
from collections import deque
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from netsim import Netlist, build_json  # noqa: E402

M = 0xFFFFFFFF


def s32(x): x &= M; return x - (1 << 32) if x >> 31 else x


def alu_ref(op, a, b):
    sh = b & 31
    return {0: a + b, 1: a - b, 2: a & b, 3: a | b, 4: a ^ b, 5: ~(a | b), 6: a << sh, 7: a >> sh,
            8: s32(a) >> sh, 9: int(s32(a) < s32(b)), 10: int(a < b), 11: b}.get(op, 0) & M


def test_alu(n=3000):
    nl = Netlist(build_json(["rtl/alu/alu.sv"], "alu"))
    rnd = random.Random(1)
    corners = [0, 1, 31, 32, 0x7FFFFFFF, 0x80000000, M]
    for i in range(n):
        a = rnd.choice(corners) if i % 5 == 0 else rnd.getrandbits(32)
        b = rnd.choice(corners) if i % 7 == 0 else rnd.getrandbits(32)
        op = rnd.randint(0, 12)
        nl.set("a", a); nl.set("b", b); nl.set("op", op); nl.eval()
        got, want = nl.get("result"), alu_ref(op, a, b)
        assert got == want, f"alu op={op} a={a:08x} b={b:08x} got {got:08x} want {want:08x}"
    print(f"netsim alu: {n} random ops match the reference")


def test_fifo(cycles=20000):
    nl = Netlist(build_json(["rtl/fifo/sync_fifo.sv"], "sync_fifo"))
    rnd = random.Random(2)
    model, depth = deque(), 16
    nl.set("rst_n", 0); nl.cycle(); nl.cycle(); nl.set("rst_n", 1)
    for c in range(cycles):
        wr, rd, wd = rnd.random() < (0.7 if (c // 400) % 2 else 0.3), rnd.random() < (0.3 if (c // 400) % 2 else 0.7), rnd.getrandbits(8)
        nl.set("wr_en", wr); nl.set("rd_en", rd); nl.set("wr_data", wd); nl.set("clk", 0); nl.eval()
        n = len(model)
        assert nl.get("full") == (n == depth) and nl.get("empty") == (n == 0) and nl.get("count") == n, f"flags cycle {c}"
        if n: assert nl.get("rd_data") == model[0], f"data cycle {c}"
        do_wr, do_rd = wr and n < depth, rd and n > 0
        nl.cycle()
        if do_rd: model.popleft()
        if do_wr: model.append(wd)
    print(f"netsim fifo: {cycles} random cycles match the deque model")


if __name__ == "__main__":
    test_alu()
    test_fifo()
    print("netsim self-test passed")
