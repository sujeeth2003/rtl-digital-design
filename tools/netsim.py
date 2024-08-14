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
            raise RuntimeError("combinational loop in netlist")
        return order

    # ---------------------------------------------------------------- bit/word helpers
    def rd(self, bits):
        v, r = self.v, 0
        for i, b in enumerate(bits):
            if v[b]: r |= 1 << i
        return r

    def wr(self, bits, val):
        v = self.v
        for i, b in enumerate(bits):
            v[b] = (val >> i) & 1

    def set(self, name, val):
        self.wr(self.names[name], val)

    def get(self, name):
        return self.rd(self.names[name])

    # ---------------------------------------------------------------- comb cell evaluation
    @staticmethod
    def _ext(x, w, signed, to):
        x &= (1 << w) - 1
        if signed and (x >> (w - 1)) & 1: x -= 1 << w
        return x & ((1 << to) - 1) if to else x

    def _eval_cell(self, cell):
        t, par, con, d, name = cell
        if t == "$mem_v2":
            for r in range(par["RD_PORTS"]):
                aw = par["ABITS"]; w = par["WIDTH"]
                addr = self.rd(con["RD_ADDR"][r * aw:(r + 1) * aw]) - par["OFFSET"]
                mem = self.mem_data[name]
                self.wr(con["RD_DATA"][r * w:(r + 1) * w], mem[addr] if 0 <= addr < len(mem) else 0)
            return
        g = lambda p: self.rd(con[p])
        yw = par.get("Y_WIDTH", 0)
        ym = (1 << yw) - 1 if yw else 0
        aw, bw = par.get("A_WIDTH", 0), par.get("B_WIDTH", 0)
        asg, bsg = par.get("A_SIGNED", 0), par.get("B_SIGNED", 0)
        y = None
        if t in ("$not", "$pos", "$neg"):
            a = self._ext(g("A"), aw, asg, yw)
            y = (~a if t == "$not" else -a if t == "$neg" else a) & ym
        elif t in ("$and", "$or", "$xor", "$xnor"):
            a, b = self._ext(g("A"), aw, asg, yw), self._ext(g("B"), bw, bsg, yw)
            y = {"$and": a & b, "$or": a | b, "$xor": a ^ b, "$xnor": ~(a ^ b)}[t] & ym
        elif t in ("$reduce_and", "$reduce_or", "$reduce_xor", "$reduce_xnor", "$reduce_bool", "$logic_not"):
            a = g("A")
            r = {"$reduce_and": a == (1 << aw) - 1, "$reduce_or": a != 0, "$reduce_bool": a != 0,
                 "$reduce_xor": bin(a).count("1") & 1, "$reduce_xnor": not (bin(a).count("1") & 1), "$logic_not": a == 0}[t]
            y = int(bool(r))
        elif t in ("$logic_and", "$logic_or"):
            a, b = g("A") != 0, g("B") != 0
            y = int(a and b if t == "$logic_and" else a or b)
        elif t in ("$eq", "$ne", "$eqx", "$nex", "$lt", "$le", "$gt", "$ge"):
            signed = asg and bsg
            w = max(aw, bw)
            a = self._ext(g("A"), aw, signed, 0) if signed else g("A")
            b = self._ext(g("B"), bw, signed, 0) if signed else g("B")
            y = int({"$eq": a == b, "$eqx": a == b, "$ne": a != b, "$nex": a != b, "$lt": a < b, "$le": a <= b, "$gt": a > b, "$ge": a >= b}[t])
        elif t in ("$add", "$sub", "$mul"):
            a, b = self._ext(g("A"), aw, asg, yw), self._ext(g("B"), bw, bsg, yw)
            y = (a + b if t == "$add" else a - b if t == "$sub" else a * b) & ym
        elif t in ("$shl", "$sshl", "$shr", "$sshr", "$shift", "$shiftx"):
            b = g("B")
            if bsg and t in ("$shift", "$shiftx") and (b >> (bw - 1)) & 1: b -= 1 << bw
            if t in ("$shl", "$sshl"):
                a = self._ext(g("A"), aw, asg, yw) if asg else g("A")
                y = (a << b) & ym if b < 4096 else 0
            elif t == "$sshr" and asg:
                a = self._ext(g("A"), aw, True, 0)
                y = (a >> min(b, 4096)) & ym
            elif t in ("$shr", "$sshr"):
                a = g("A")
                y = (a >> b) & ym if b < 4096 else 0
            else:                                    # $shift / $shiftx: signed shift amount
                a = self._ext(g("A"), aw, asg, 0) if asg and t == "$shift" else g("A")
                y = ((a >> b) if b >= 0 else (a << -b)) & ym if abs(b) < 4096 else 0
        elif t == "$mux":
            y = g("B") if g("S") else g("A")
        elif t == "$pmux":
            w, sw = par["WIDTH"], par["S_WIDTH"]
            s, b = g("S"), g("B")
            y = g("A")
            for i in range(sw):
                if (s >> i) & 1:
                    y = (b >> (i * w)) & ((1 << w) - 1); break
        else:
            raise NotImplementedError(f"cell type {t}")
        self.wr(con["Y"], y)

    def eval(self):
        for cell in self.order:
            self._eval_cell(cell)

    # ---------------------------------------------------------------- clock edge
    def _posedge(self):
        upd = []
        for (t, par, con, d, name) in self.ffs:
            pol = lambda k: par.get(k, 1)
            q = None
            if "ARST" in con and self.rd(con["ARST"]) == pol("ARST_POLARITY"):
                q = par["ARST_VALUE"]
            else:
                en = self.rd(con["EN"]) == pol("EN_POLARITY") if "EN" in con else True
                srst = "SRST" in con and self.rd(con["SRST"]) == pol("SRST_POLARITY")
                if t == "$sdffce":                       # enable gates the reset
                    if en: q = par["SRST_VALUE"] if srst else self.rd(con["D"])
                elif t in ("$sdff", "$sdffe"):           # reset has priority over enable
                    q = par["SRST_VALUE"] if srst else (self.rd(con["D"]) if en else None)
                elif en:
                    q = self.rd(con["D"])
            if q is not None: upd.append((con["Q"], q))
        wrs = []
        for cell in self.mems:
            t, par, con, d, name = cell
            aw, w = par["ABITS"], par["WIDTH"]
            for p in range(par["WR_PORTS"]):
                en = self.rd(con["WR_EN"][p * w:(p + 1) * w])
                if not en: continue
                addr = self.rd(con["WR_ADDR"][p * aw:(p + 1) * aw]) - par["OFFSET"]
                data = self.rd(con["WR_DATA"][p * w:(p + 1) * w])
                wrs.append((name, addr, en, data))
        for bits, q in upd: self.wr(bits, q)
        for name, addr, en, data in wrs:
            mem = self.mem_data[name]
            if 0 <= addr < len(mem):
                mem[addr] = (mem[addr] & ~en) | (data & en)

    def cycle(self, clk="clk"):
        """One full clock: settle, rising edge, settle."""
        self.set(clk, 0); self.eval()
        self._posedge()
        self.set(clk, 1); self.eval()
