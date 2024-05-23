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

