#!/usr/bin/env python3
"""Golden instruction-set simulator for the core's RV32I subset (architectural model, no pipeline).

Semantics deliberately mirror the RTL where the ISA leaves room: 4 KiB instruction and data memories
that wrap, little-endian, unknown opcodes are NOPs, EBREAK halts, misaligned accesses use the aligned word.
"""
M32 = 0xFFFFFFFF


