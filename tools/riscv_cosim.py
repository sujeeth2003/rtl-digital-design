#!/usr/bin/env python3
"""Co-simulation: run each program on the RTL (via the CXXRTL testbench) and on the golden ISS,
then compare every register, all 1024 data-RAM words and the retired-instruction count.

    python tools/riscv_cosim.py [--netsim] [--random N] [program.s ...]

Backends: the CXXRTL testbench build/riscv_sim (from `python tools/rtl.py sim riscv`), or --netsim,
which runs the same experiment in pure Python (tools/netsim.py). `auto` falls back to netsim if the
native executable cannot be launched.
"""
import os
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import riscv_asm       # noqa: E402
import riscv_iss       # noqa: E402
import riscv_random    # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build"
EXE = BUILD / ("riscv_sim.exe" if os.name == "nt" else "riscv_sim")


BACKEND = "auto"     # auto | cxxrtl | netsim
_NL = None


def run_cxxrtl(words, hexfile):
    hexfile.write_text("\n".join(f"{w:08x}" for w in words) + "\n")
    p = subprocess.run([str(EXE), str(hexfile)], capture_output=True, text=True, timeout=120)
    out = {}
    for line in p.stdout.splitlines():
        k, v = line.split()
        out[k] = v
    return out


def run_netsim(words, max_cycles=300000):
    """Same experiment as tb/riscv_tb.cpp, executed by the pure-Python netlist simulator."""
    global _NL
    from netsim import Netlist, build_json
    if _NL is None:
        files = ["rtl/alu/alu.sv"] + [f"rtl/riscv/{f}.sv" for f in ("riscv_top", "riscv_core", "regfile", "decode", "hazard_unit")]
        _NL = Netlist(build_json(files, "riscv_top"))
    nl = _NL
    nl.reset()
    nl.set("rst_n", 0)
    nl.set("prog_we", 1)
    for i, w in enumerate(words):
        nl.set("prog_addr", i); nl.set("prog_data", w); nl.cycle()
    nl.set("prog_we", 0)
    nl.cycle(); nl.cycle()
    nl.set("rst_n", 1)
    cycles = 0
    nl.eval()
    while not nl.get("halted") and cycles < max_cycles:
        nl.cycle(); cycles += 1
    nl.cycle(); nl.cycle()
    out = {"halted": str(nl.get("halted")), "cycles": str(cycles), "retired": str(nl.get("retired")),
           "stalls": str(nl.get("stalls")), "flushes": str(nl.get("flushes"))}
    for r in range(32):
        nl.set("dbg_reg_addr", r); nl.eval(); out[f"x{r}"] = f"{nl.get('dbg_reg_data'):08x}"
    dm = nl.memory("dmem")
    for a in range(1024): out[f"m{a}"] = f"{dm[a]:08x}"
    return out


def run_rtl(words, hexfile):
    global BACKEND
    if BACKEND in ("auto", "cxxrtl") and EXE.exists():
        try:
            return run_cxxrtl(words, hexfile)
        except OSError as e:          # e.g. the OS refused to launch a freshly built executable
            if BACKEND == "cxxrtl": raise
            print(f"[note] native simulator could not be launched ({e}); using the Python netlist simulator")
            BACKEND = "netsim"
    return run_netsim(words)


def compare(name, source):
    words, _ = riscv_asm.assemble(source)
    hexfile = BUILD / f"{name}.hex"
    iss = riscv_iss.ISS(words).run()
    rtl = run_rtl(words, hexfile)
    errs = []
    if not iss.halted: errs.append("ISS did not halt")
    if rtl.get("halted") != "1": errs.append("RTL did not halt")
    for i in range(32):
        got = int(rtl.get(f"x{i}", "0"), 16)
        if got != iss.x[i]:
            errs.append(f"x{i}: rtl={got:08x} iss={iss.x[i]:08x}")
    for a in range(1024):
        got = int(rtl.get(f"m{a}", "0"), 16)
        if got != iss.dmem[a]:
            errs.append(f"mem[{a * 4:#x}]: rtl={got:08x} iss={iss.dmem[a]:08x}")
            if len(errs) > 12: break
    if int(rtl.get("retired", -1)) != iss.retired:
        errs.append(f"retired: rtl={rtl.get('retired')} iss={iss.retired}")
    stats = (iss.retired, int(rtl.get("cycles", 0)), int(rtl.get("stalls", 0)), int(rtl.get("flushes", 0)))
    return errs, stats

