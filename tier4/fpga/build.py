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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--freq", type=float, default=25.0, help="target clock in MHz")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--fw", default="tier4/fw/blink.s")
    ap.add_argument("--no-bitstream", action="store_true")
    ap.add_argument("--bram", action="store_true", help="let Yosys use block RAM (default: LUT RAM: its ~5.6 ns clk-to-q is too slow on the fetch path)")
    a = ap.parse_args()
    B.mkdir(parents=True, exist_ok=True)

    sys.path.insert(0, str(ROOT / "tools"))
    import riscv_asm
    words, _ = riscv_asm.assemble((ROOT / a.fw).read_text())
    (B / "blink.hex").write_text("\n".join(f"{w:08x}" for w in words) + "\n")
    print(f"firmware: {len(words)} words")

