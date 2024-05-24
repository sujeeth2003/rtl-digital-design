#!/usr/bin/env python3
"""Build, simulate and formally check the RTL with open tools only.

    python tools/rtl.py list
    python tools/rtl.py sim tier0          # Yosys -> CXXRTL C++ -> compile -> run testbench
    python tools/rtl.py formal fifo        # SymbiYosys (BMC + induction with z3)
    python tools/rtl.py all

Requirements (all pip-installable, no commercial simulator):
    pip install yowasp-yosys z3-solver ziglang      # or a native yosys + sby + g++/clang++
Environment overrides: YOSYS, SBY, CXX (e.g. CXX="python -m ziglang c++").
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build"

# block -> (top module, [rtl sources], C++ testbench)
SIM = {
    "tier0":      ("tier0_top",   ["rtl/tier0/*.sv"],                                     "tb/tier0_tb.cpp"),
    "alu":        ("alu",         ["rtl/alu/*.sv"],                                       "tb/alu_tb.cpp"),
    "fifo":       ("sync_fifo",   ["rtl/fifo/*.sv"],                                      "tb/fifo_tb.cpp"),
    "async_fifo": ("async_fifo",  ["rtl/cdc/*.sv"],                                       "tb/async_fifo_tb.cpp"),
    "axil":       ("axil_regs",   ["rtl/axi_lite/axil_regs.sv"],                          "tb/axil_tb.cpp"),
    "riscv":      ("riscv_top",   ["rtl/alu/*.sv", "rtl/riscv/*.sv"],                     "tb/riscv_tb.cpp"),
}
# formal jobs are .sby files in formal/
FORMAL = ["alu", "tier0", "fifo", "gray", "axil"]

