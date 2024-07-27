#!/usr/bin/env python3
"""Tiny two-pass RV32I assembler for the subset the core implements.

    python tools/riscv_asm.py programs/fib.s build/fib.hex

Output: one 32-bit hex word per line (address = line number * 4).
Supports labels, `#` comments, `.word`, and the pseudo-instructions
nop li mv not neg j jr ret beqz bnez blez bgez bltz bgtz ble bgt bleu bgtu seqz snez.
"""
import re
import sys

REGS = {f"x{i}": i for i in range(32)}
REGS.update({"zero": 0, "ra": 1, "sp": 2, "gp": 3, "tp": 4, "t0": 5, "t1": 6, "t2": 7, "s0": 8, "fp": 8, "s1": 9})
REGS.update({f"a{i}": 10 + i for i in range(8)})
REGS.update({f"s{i}": 16 + i for i in range(2, 12)})
REGS.update({f"t{i}": 25 + i for i in range(3, 7)})

