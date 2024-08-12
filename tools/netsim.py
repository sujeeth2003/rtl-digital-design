#!/usr/bin/env python3
"""Cycle-based simulator for Yosys word-level JSON netlists (pure Python, no native code).

Why it exists: it lets the RTL be exercised on machines where compiling and running a native
CXXRTL testbench is not possible (locked-down Windows, CI without a C++ toolchain). It is slower
than CXXRTL/Verilator (roughly 1-2k cycles/s on the RISC-V core) but needs nothing except Yosys.

    from netsim import Netlist, build_json
    nl = Netlist(build_json(["rtl/alu/alu.sv"], "alu"))
    nl.set("a", 3); nl.set("b", 4); nl.set("op", 0); nl.eval(); nl.get("result")

Supported: the coarse cells produced by `proc; flatten; opt; memory -nomap -nordff`
($add $sub $mul $neg $not $and $or $xor $xnor $reduce_* $logic_* $eq $ne $lt $le $gt $ge
 $shl $shr $sshl $sshr $shift $shiftx $mux $pmux $dff $dffe $adff $adffe $sdff $sdffe $sdffce $mem_v2).
Flops and memories start at zero. Single clock domain: call cycle() (falling edge, rising edge).
"""
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

