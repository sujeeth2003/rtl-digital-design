#!/usr/bin/env python3
"""ASIC-style front end with Yosys: technology-independent gate-level synthesis, area/gate statistics, and a FORMAL EQUIVALENCE
CHECK that the synthesised gate netlist behaves exactly like the RTL (synthesis must never change function).

    python tier4/asic/asic_flow.py

What this is and is not: this is logic synthesis to a generic gate library (AND/NAND/OR/NOR/XOR/XNOR/ANDNOT/ORNOT/MUX/NOT) plus
equivalence checking. It is NOT a physical flow: no standard-cell library, floorplan, placement, clock tree, routing or signoff
timing. Those need a PDK and OpenROAD/OpenLane, see tier4/asic/openlane_config.json (not run here).
"""
import re
import shutil
import subprocess
import sys
from pathlib import Path

