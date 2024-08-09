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

