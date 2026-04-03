#!/usr/bin/env python3
"""Simulate the FPGA SoC (core + RAM + LED register) running the firmware, before spending time on place & route.

    python tier4/test_soc.py

Assembles tier4/fw/blink_sim.s, builds the netlist with Yosys, loads the firmware into the instruction RAM, releases reset, and
checks that the LED register counts 1..8 in order and that the core then halts (LEDs 0xFF).
"""
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))
import riscv_asm  # noqa: E402
from netsim import Netlist, build_json  # noqa: E402

