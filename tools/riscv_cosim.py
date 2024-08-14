#!/usr/bin/env python3
"""Co-simulation: run each program on the RTL (via the CXXRTL testbench) and on the golden ISS,
then compare every register, all 1024 data-RAM words and the retired-instruction count.

    python tools/riscv_cosim.py [--netsim] [--random N] [program.s ...]

Backends: the CXXRTL testbench build/riscv_sim (from `python tools/rtl.py sim riscv`), or --netsim,
which runs the same experiment in pure Python (tools/netsim.py). `auto` falls back to netsim if the
native executable cannot be launched.
"""
import os
import subprocess
import sys
from pathlib import Path

