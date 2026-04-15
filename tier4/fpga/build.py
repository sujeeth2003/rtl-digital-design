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

