#!/usr/bin/env python3
"""Golden instruction-set simulator for the core's RV32I subset (architectural model, no pipeline).

Semantics deliberately mirror the RTL where the ISA leaves room: 4 KiB instruction and data memories
that wrap, little-endian, unknown opcodes are NOPs, EBREAK halts, misaligned accesses use the aligned word.
"""
M32 = 0xFFFFFFFF


def s32(x): x &= M32; return x - (1 << 32) if x & 0x80000000 else x
def sext(x, bits): return (x ^ (1 << (bits - 1))) - (1 << (bits - 1))


class ISS:
    def __init__(self, program, dmem_init=None):
        self.imem = [0x13] * 1024
        for i, w in enumerate(program): self.imem[i] = w
        self.dmem = [0] * 1024
        for i, w in (dmem_init or {}).items(): self.dmem[i] = w
        self.x = [0] * 32
        self.pc = 0
        self.retired = 0
        self.halted = False

