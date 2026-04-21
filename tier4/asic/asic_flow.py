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

ROOT = Path(__file__).resolve().parents[2]
BUILD = ROOT / "tier4" / "build"
YOSYS = [shutil.which("yowasp-yosys") or shutil.which("yosys")]

GATES = "AND,NAND,OR,NOR,XOR,XNOR,ANDNOT,ORNOT,MUX"


def yosys(script, log):
    p = subprocess.run(YOSYS + ["-p", script], cwd=ROOT, capture_output=True, text=True)
    out = p.stdout + p.stderr
    (BUILD / log).write_text(out)
    return p.returncode, out


def stats(out):
    cells = {}
    block = out.split("Number of cells")[-1] if "Number of cells" in out else out.split("=== design hierarchy ===")[-1]
    for n, name in re.findall(r"^\s+(\d+)\s+\$_(\w+)_\s*$", block, re.M):
        cells[name] = int(n)
    return cells


def synth_and_check(name, top, files, params=""):
    """Synthesise `top`; keep the RTL as 'gold' and the gate netlist as 'gate'; prove them equivalent."""
    read = f"read_verilog -sv {' '.join(files)}; {params} hierarchy -top {top}; proc; flatten; opt_clean; "
    script = (read + f"design -stash gold; " + read.replace("proc; flatten; opt_clean; ", "") +
              f"synth -top {top} -flatten -noabc; techmap; abc -g {GATES}; opt_clean; tee -o tier4/build/{name}_stat.txt stat; "
              f"write_verilog -noattr tier4/build/{name}_gates.v; design -stash gate; "
              f"design -copy-from gold -as gold {top}; design -copy-from gate -as gate {top}; "
              f"equiv_make gold gate eq; hierarchy -top eq; equiv_simple -seq 0; equiv_induct; tee -o tier4/build/{name}_equiv.txt equiv_status -assert")
    rc, out = yosys(script, f"{name}_asic.log")
    gate_stat = (BUILD / f"{name}_stat.txt").read_text() if (BUILD / f"{name}_stat.txt").exists() else ""
    cells = stats(gate_stat)
    eq = (BUILD / f"{name}_equiv.txt").read_text() if (BUILD / f"{name}_equiv.txt").exists() else ""
    ok = rc == 0 and "Equivalence successfully proven" in eq
    total = sum(cells.values())
    print(f"{name:<14} gates={total:>5}  " + "  ".join(f"{k}:{v}" for k, v in sorted(cells.items(), key=lambda kv: -kv[1])[:6]) +
          f"   equivalence RTL == gates: {'PROVEN' if ok else 'NOT PROVEN (see tier4/build/' + name + '_asic.log)'}")
    return ok

