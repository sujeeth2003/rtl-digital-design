#!/usr/bin/env python3
"""FPGA flow for the RISC-V SoC on a Lattice ECP5 (LFE5U-25F): assemble firmware -> Yosys synth_ecp5 -> nextpnr-ecp5 place & route
with a target clock -> report resources and achieved Fmax -> ecppack bitstream.

    python tier4/fpga/build.py [--freq 25] [--seed 1] [--no-bitstream]

Needs: pip install yowasp-yosys yowasp-nextpnr-ecp5   (also provides yowasp-ecppack). Run from the repository root.
"""
import argparse
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
B = ROOT / "tier4" / "build"


def tool(*names):
    for n in names:
        p = shutil.which(n)
        if p: return [p]
    sys.exit(f"missing tool, install one of {names}")


def run(cmd, log):
    p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    (B / log).write_text(p.stdout + p.stderr)
    if p.returncode:
        print((p.stdout + p.stderr)[-1500:]); sys.exit(f"{cmd[0]} failed (see tier4/build/{log})")
    return p.stdout + p.stderr


