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

    def load(self, addr, f3):
        word = self.dmem[(addr >> 2) & 1023]
        off = addr & 3
        if f3 in (0, 4):
            b = (word >> (8 * off)) & 0xFF
            return sext(b, 8) & M32 if f3 == 0 else b
        if f3 in (1, 5):
            h = (word >> 16) & 0xFFFF if off & 2 else word & 0xFFFF
            return sext(h, 16) & M32 if f3 == 1 else h
        return word

    def store(self, addr, val, f3):
        i = (addr >> 2) & 1023
        off = addr & 3
        w = self.dmem[i]
        if f3 == 0:
            w = (w & ~(0xFF << (8 * off))) | ((val & 0xFF) << (8 * off))
        elif f3 == 1:
            sh = 16 if off & 2 else 0
            w = (w & ~(0xFFFF << sh)) | ((val & 0xFFFF) << sh)
        else:
            w = val & M32
        self.dmem[i] = w & M32

