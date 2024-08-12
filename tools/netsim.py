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


class Netlist:
    def __init__(self, js):
        mod = next(iter(js["modules"].values())) if len(js["modules"]) == 1 else \
            next(m for m in js["modules"].values() if m.get("attributes", {}).get("top"))
        nmax = 1
        for w in mod["netnames"].values():
            for b in w["bits"]:
                if isinstance(b, int): nmax = max(nmax, b + 1)
        for c in mod["cells"].values():
            for bits in c["connections"].values():
                for b in bits:
                    if isinstance(b, int): nmax = max(nmax, b + 1)
        self.C0, self.C1 = nmax, nmax + 1
        self.v = [0] * (nmax + 2)
        self.v[self.C1] = 1
        self.ports = {n: p for n, p in mod["ports"].items()}
        self.names = {n: w["bits"] for n, w in mod["netnames"].items()}
        self.cells = []
        self.ffs, self.mems, comb = [], [], []
        for name, c in mod["cells"].items():
            t = c["type"]
            if t in ("$scopeinfo", "$print", "$check", "$assert", "$assume", "$cover"): continue   # no simulation effect
            par = {k: _pint(x) for k, x in c["parameters"].items() if not isinstance(x, str) or set(x) <= {"0", "1"}}
            con = {k: [self._b(b) for b in bits] for k, bits in c["connections"].items()}
            d = c["port_directions"]
            cell = (t, par, con, d, name)
            if t.startswith("$dff") or t.startswith("$adff") or t.startswith("$sdff"): self.ffs.append(cell)
            elif t == "$mem_v2": self.mems.append(cell)
            else: comb.append(cell)
        self.order = self._toposort(comb)
        self.mem_data = {}
        self.memid = {name: str(c["parameters"].get("MEMID", name)) for name, c in mod["cells"].items() if c["type"] == "$mem_v2"}
        self.reset()

    def reset(self):
        """Zero every net, flop and memory (power-on state)."""
        self.v = [0] * len(self.v)
        self.v[self.C1] = 1
        self.mem_data = {name: [0] * par["SIZE"] for (_, par, _, _, name) in self.mems}

    def memory(self, contains):
        """Contents of the memory whose MEMID contains the given text (e.g. 'dmem')."""
        for name, mid in self.memid.items():
            if contains in mid: return self.mem_data[name]
        raise KeyError(contains)

    def _b(self, b):
        if isinstance(b, int): return b
        return self.C1 if b == "1" else self.C0

    # ---------------------------------------------------------------- scheduling
    def _toposort(self, comb):
        drivers = {}
        allcells = list(comb) + [m for m in self.mems]
        for i, (t, par, con, d, name) in enumerate(allcells):
            for port, dirn in d.items():
                if dirn == "output" and not (t == "$mem_v2" and not port.startswith("RD_DATA")):
                    for b in con.get(port, []): drivers[b] = i
        deps = [set() for _ in allcells]
        users = [[] for _ in allcells]
        for i, (t, par, con, d, name) in enumerate(allcells):
            for port, dirn in d.items():
                if dirn == "input":
                    if t == "$mem_v2" and not port.startswith("RD_"): continue      # write side is sequential
                    for b in con.get(port, []):
                        j = drivers.get(b)
                        if j is not None and j != i and j not in deps[i]:
                            deps[i].add(j); users[j].append(i)
        ready = [i for i in range(len(allcells)) if not deps[i]]
        order = []
        indeg = [len(x) for x in deps]
        while ready:
            i = ready.pop()
            order.append(allcells[i])
            for u in users[i]:
                indeg[u] -= 1
                if indeg[u] == 0: ready.append(u)
        if len(order) != len(allcells):
