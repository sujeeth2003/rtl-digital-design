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

sys.path.insert(0, str(Path(__file__).parent))
import riscv_asm       # noqa: E402
import riscv_iss       # noqa: E402
import riscv_random    # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build"
EXE = BUILD / ("riscv_sim.exe" if os.name == "nt" else "riscv_sim")


BACKEND = "auto"     # auto | cxxrtl | netsim
_NL = None


def run_cxxrtl(words, hexfile):
    hexfile.write_text("\n".join(f"{w:08x}" for w in words) + "\n")
    p = subprocess.run([str(EXE), str(hexfile)], capture_output=True, text=True, timeout=120)
    out = {}
    for line in p.stdout.splitlines():
        k, v = line.split()
        out[k] = v
    return out


