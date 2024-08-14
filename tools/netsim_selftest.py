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


