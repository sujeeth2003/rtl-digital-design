#!/usr/bin/env python3
"""Random RV32I program generator aimed at pipeline hazards.

Programs draw operands from a small register pool so consecutive instructions depend on each
other (forwarding at every distance), mix loads/stores into a scratch region (load-use, store-load),
and use only FORWARD branches/jumps so every program terminates. Ends with EBREAK.
"""
import random

POOL = [5, 6, 7, 10, 11, 12, 13]          # t0-t2, a0-a3: heavy reuse => many hazards
BASE = 8                                   # s0 holds the scratch base address
R_OPS = ["add", "sub", "and", "or", "xor", "sll", "srl", "sra", "slt", "sltu"]
I_OPS = ["addi", "andi", "ori", "xori", "slti", "sltiu"]
SH_OPS = ["slli", "srli", "srai"]
B_OPS = ["beq", "bne", "blt", "bge", "bltu", "bgeu"]


def gen(seed, length=80):
    rnd = random.Random(seed)
    r = lambda: f"x{rnd.choice(POOL)}"
    lines = [f"li x{BASE}, 0x240"]
    for reg in POOL:
        lines.append(f"li x{reg}, {rnd.choice([0, 1, -1, 0x7FFFFFFF, -0x80000000, rnd.randint(-2**31, 2**31 - 1)])}")
    label_id = 0
    pending = []                            # (label, instructions_left)
    for i in range(length):
        for p in pending:
            p[1] -= 1
        for p in [p for p in pending if p[1] <= 0]:
            lines.append(f"{p[0]}:")
            pending.remove(p)
        k = rnd.random()
        if k < 0.35:
            lines.append(f"{rnd.choice(R_OPS)} {r()}, {r()}, {r()}")
        elif k < 0.50:
            lines.append(f"{rnd.choice(I_OPS)} {r()}, {r()}, {rnd.randint(-2048, 2047)}")
        elif k < 0.55:
            lines.append(f"{rnd.choice(SH_OPS)} {r()}, {r()}, {rnd.randint(0, 31)}")
        elif k < 0.62:
            lines.append(f"lui {r()}, {rnd.randint(0, 0xFFFFF)}")
        elif k < 0.75:
            sz = rnd.choice(["lb", "lbu", "lh", "lhu", "lw"])
            step = {"lb": 1, "lbu": 1, "lh": 2, "lhu": 2, "lw": 4}[sz]
            lines.append(f"{sz} {r()}, {rnd.randrange(0, 64, step)}(x{BASE})")
        elif k < 0.85:
            sz = rnd.choice(["sb", "sh", "sw"])
            step = {"sb": 1, "sh": 2, "sw": 4}[sz]
            lines.append(f"{sz} {r()}, {rnd.randrange(0, 64, step)}(x{BASE})")
