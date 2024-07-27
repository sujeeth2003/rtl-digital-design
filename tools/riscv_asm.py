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

R_OPS = {"add": (0, 0), "sub": (0, 0x20), "sll": (1, 0), "slt": (2, 0), "sltu": (3, 0),
         "xor": (4, 0), "srl": (5, 0), "sra": (5, 0x20), "or": (6, 0), "and": (7, 0)}
I_OPS = {"addi": 0, "slti": 2, "sltiu": 3, "xori": 4, "ori": 6, "andi": 7}
SH_OPS = {"slli": (1, 0), "srli": (5, 0), "srai": (5, 0x20)}
LOADS = {"lb": 0, "lh": 1, "lw": 2, "lbu": 4, "lhu": 5}
STORES = {"sb": 0, "sh": 1, "sw": 2}
BRANCHES = {"beq": 0, "bne": 1, "blt": 4, "bge": 5, "bltu": 6, "bgeu": 7}


class AsmError(Exception):
    pass


def reg(tok):
    t = tok.strip()
    if t not in REGS:
        raise AsmError(f"bad register '{tok}'")
    return REGS[t]


def num(tok, labels=None, pc=None, relative=False):
    t = tok.strip()
    if labels is not None and t in labels:
        return labels[t] - pc if relative else labels[t]
    try:
        return int(t, 0)
    except ValueError:
        raise AsmError(f"bad number or unknown label '{tok}'")


def r_type(f7, rs2, rs1, f3, rd, op): return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op
def i_type(imm, rs1, f3, rd, op): return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op
def s_type(imm, rs2, rs1, f3, op): return (((imm >> 5) & 0x7F) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | op
def u_type(imm, rd, op): return ((imm & 0xFFFFF) << 12) | (rd << 7) | op


def b_type(off, rs2, rs1, f3):
    if off % 2 or not -4096 <= off < 4096:
        raise AsmError(f"branch offset {off} out of range")
    return (((off >> 12) & 1) << 31) | (((off >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (((off >> 1) & 0xF) << 8) | (((off >> 11) & 1) << 7) | 0x63


