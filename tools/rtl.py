#!/usr/bin/env python3
"""Build, simulate and formally check the RTL with open tools only.

    python tools/rtl.py list
    python tools/rtl.py sim tier0          # Yosys -> CXXRTL C++ -> compile -> run testbench
    python tools/rtl.py formal fifo        # SymbiYosys (BMC + induction with z3)
    python tools/rtl.py all

Requirements (all pip-installable, no commercial simulator):
    pip install yowasp-yosys z3-solver ziglang      # or a native yosys + sby + g++/clang++
Environment overrides: YOSYS, SBY, CXX (e.g. CXX="python -m ziglang c++").
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BUILD = ROOT / "build"

# block -> (top module, [rtl sources], C++ testbench)
SIM = {
    "tier0":      ("tier0_top",   ["rtl/tier0/*.sv"],                                     "tb/tier0_tb.cpp"),
    "alu":        ("alu",         ["rtl/alu/*.sv"],                                       "tb/alu_tb.cpp"),
    "fifo":       ("sync_fifo",   ["rtl/fifo/*.sv"],                                      "tb/fifo_tb.cpp"),
    "async_fifo": ("async_fifo",  ["rtl/cdc/*.sv"],                                       "tb/async_fifo_tb.cpp"),
    "axil":       ("axil_regs",   ["rtl/axi_lite/axil_regs.sv"],                          "tb/axil_tb.cpp"),
    "riscv":      ("riscv_top",   ["rtl/alu/*.sv", "rtl/riscv/*.sv"],                     "tb/riscv_tb.cpp"),
}
# formal jobs are .sby files in formal/
FORMAL = ["alu", "tier0", "fifo", "gray", "axil"]


def tool(env, *names):
    if os.environ.get(env):
        return os.environ[env].split()
    for n in names:
        p = shutil.which(n)
        if p:
            return [p]
    sys.exit(f"missing tool: set ${env} or install one of {names}")


def expand(patterns):
    files = []
    for pat in patterns:
        files += sorted(str(p.relative_to(ROOT)).replace("\\", "/") for p in ROOT.glob(pat))
    return files


def cxxrtl_include(yosys):
    """Locate the CXXRTL runtime headers shipped with (yowasp-)yosys."""
    try:
        import yowasp_yosys  # type: ignore
        p = Path(yowasp_yosys.__file__).parent / "share" / "include" / "backends" / "cxxrtl" / "runtime"
        if p.exists():
            return p
    except ImportError:
        pass
    out = subprocess.run(yosys + ["-p", "help"], capture_output=True, text=True)
    for cand in (Path(shutil.which("yosys") or "/usr").parent.parent / "share/yosys/include/backends/cxxrtl/runtime",):
        if cand.exists():
            return cand
    sys.exit("cannot find cxxrtl runtime headers")


def sim(name):
    top, srcs, tb = SIM[name]
    BUILD.mkdir(exist_ok=True)
    yosys = tool("YOSYS", "yosys", "yowasp-yosys")
    cxx = tool("CXX", "g++", "clang++")
    files = expand(srcs)
    gen = f"build/{name}_dut.cc"
    script = f"read_verilog -sv {' '.join(files)}; hierarchy -top {top}; proc; write_cxxrtl -header {gen}"
    print(f"[{name}] yosys: {len(files)} files, top={top}")
    subprocess.run(yosys + ["-q", "-p", script], cwd=ROOT, check=True)
    exe = BUILD / (f"{name}_sim" + (".exe" if os.name == "nt" else ""))
    inc = cxxrtl_include(yosys)
    cmd = cxx + ["-std=c++17", "-O2", "-w", f"-I{inc}", f"-I{BUILD}", f"-DDUT_HEADER=\"{name}_dut.h\"",
                 str(ROOT / tb), str(ROOT / gen), "-o", str(exe)]
    print(f"[{name}] compile testbench")
    subprocess.run(cmd, cwd=ROOT, check=True)
    print(f"[{name}] run")
    if name == "riscv":   # program-driven: assemble, run on RTL and on the ISS, compare
        subprocess.run([sys.executable, "tools/riscv_cosim.py", "--random", "200"], cwd=ROOT, check=True)
    else:
        subprocess.run([str(exe)], cwd=ROOT, check=True)


def formal(name):
    sby = tool("SBY", "sby", "yowasp-sby")
    print(f"[formal:{name}]")
    subprocess.run(sby + ["-f", f"{name}.sby"], cwd=ROOT / "formal", check=True)


def main():
    a = sys.argv[1:]
    if not a or a[0] == "list":
        print("sim   :", ", ".join(SIM))
        print("formal:", ", ".join(FORMAL))
    elif a[0] == "sim":
        for n in (a[1:] or SIM):
            sim(n)
    elif a[0] == "formal":
        for n in (a[1:] or FORMAL):
            formal(n)
    elif a[0] == "all":
        for n in SIM:
            sim(n)
        for n in FORMAL:
            formal(n)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
