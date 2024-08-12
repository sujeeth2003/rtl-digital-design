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

ROOT = Path(__file__).resolve().parent.parent


def build_json(files, top, params=None):
    """Run Yosys to produce a flattened word-level JSON netlist and return it parsed."""
    yosys = os.environ.get("YOSYS", "").split() or [shutil.which("yosys") or shutil.which("yowasp-yosys")]
    if not yosys[0]:
        sys.exit("yosys not found (set $YOSYS)")
    (ROOT / "build").mkdir(exist_ok=True)
    chp = "".join(f"chparam -set {k} {v} {top}; " for k, v in (params or {}).items())
    script = (f"read_verilog -sv {' '.join(files)}; {chp}hierarchy -top {top}; proc; flatten; opt -fast; "
              f"memory -nomap -nordff; opt_clean; write_json build/_netlist.json")
    subprocess.run(yosys + ["-q", "-p", script], cwd=ROOT, check=True)
    p = ROOT / "build" / "_netlist.json"
    data = json.loads(p.read_text())
    return data


def _pint(v):
    if isinstance(v, int):
        return v
    return int(v, 2) if v and set(v) <= {"0", "1"} else 0


