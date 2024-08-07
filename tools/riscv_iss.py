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

    def step(self):
        ins = self.imem[(self.pc >> 2) & 1023]
        op, rd, f3 = ins & 0x7F, (ins >> 7) & 31, (ins >> 12) & 7
        rs1, rs2, f7 = (ins >> 15) & 31, (ins >> 20) & 31, ins >> 25
        a, b = self.x[rs1], self.x[rs2]
        nxt = (self.pc + 4) & M32
        wr = None
        if op == 0x33:
            sh = b & 31
            if f3 == 0: wr = (a - b) if f7 & 0x20 else (a + b)
            elif f3 == 1: wr = a << sh
            elif f3 == 2: wr = int(s32(a) < s32(b))
            elif f3 == 3: wr = int(a < b)
            elif f3 == 4: wr = a ^ b
            elif f3 == 5: wr = (s32(a) >> sh) if f7 & 0x20 else (a >> sh)
            elif f3 == 6: wr = a | b
            else: wr = a & b
        elif op == 0x13:
            imm = sext(ins >> 20, 12); sh = (ins >> 20) & 31
            if f3 == 0: wr = a + imm
            elif f3 == 1: wr = a << sh
            elif f3 == 2: wr = int(s32(a) < imm)
            elif f3 == 3: wr = int(a < (imm & M32))
            elif f3 == 4: wr = a ^ (imm & M32)
            elif f3 == 5: wr = (s32(a) >> sh) if (ins >> 30) & 1 else (a >> sh)
            elif f3 == 6: wr = a | (imm & M32)
            else: wr = a & (imm & M32)
        elif op == 0x03: wr = self.load((a + sext(ins >> 20, 12)) & M32, f3)
        elif op == 0x23:
            imm = sext(((ins >> 25) << 5) | ((ins >> 7) & 31), 12)
            self.store((a + imm) & M32, b, f3)
        elif op == 0x63:
