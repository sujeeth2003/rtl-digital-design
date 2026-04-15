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

ROOT = Path(__file__).resolve().parents[2]
B = ROOT / "tier4" / "build"


def tool(*names):
    for n in names:
        p = shutil.which(n)
        if p: return [p]
    sys.exit(f"missing tool, install one of {names}")


def run(cmd, log):
    p = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True)
    (B / log).write_text(p.stdout + p.stderr)
    if p.returncode:
        print((p.stdout + p.stderr)[-1500:]); sys.exit(f"{cmd[0]} failed (see tier4/build/{log})")
    return p.stdout + p.stderr


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--freq", type=float, default=25.0, help="target clock in MHz")
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--fw", default="tier4/fw/blink.s")
    ap.add_argument("--no-bitstream", action="store_true")
    ap.add_argument("--bram", action="store_true", help="let Yosys use block RAM (default: LUT RAM: its ~5.6 ns clk-to-q is too slow on the fetch path)")
    a = ap.parse_args()
    B.mkdir(parents=True, exist_ok=True)

    sys.path.insert(0, str(ROOT / "tools"))
    import riscv_asm
    words, _ = riscv_asm.assemble((ROOT / a.fw).read_text())
    (B / "blink.hex").write_text("\n".join(f"{w:08x}" for w in words) + "\n")
    print(f"firmware: {len(words)} words")

    yosys, nextpnr, ecppack = tool("yowasp-yosys", "yosys"), tool("yowasp-nextpnr-ecp5", "nextpnr-ecp5"), tool("yowasp-ecppack", "ecppack")
    srcs = ["rtl/alu/alu.sv"] + [f"rtl/riscv/{f}.sv" for f in ("riscv_core", "regfile", "decode", "hazard_unit", "riscv_top")] + ["tier4/fpga/fpga_top.sv"]
    out = run(yosys + ["-p", f"read_verilog -sv {' '.join(srcs)}; synth_ecp5 {'' if a.bram else '-nobram '}-top fpga_top -json tier4/build/soc.json"], "yosys.log")
    stat = {k: int(v) for k, v in re.findall(r"^\s+(\S+)\s+(\d+)\s*$", out.split("Number of cells")[-1] if "Number of cells" in out else out, re.M)}
    print("yosys resources:", {k: v for k, v in stat.items() if k in ("LUT4", "TRELLIS_FF", "TRELLIS_DPR16X4", "DP16KD", "CCU2C", "MULT18X18D")})

    cmd = nextpnr + ["--25k", "--package", "CABGA381", "--json", "tier4/build/soc.json", "--lpf", "tier4/fpga/ulx3s.lpf",
                     "--freq", str(a.freq), "--seed", str(a.seed), "--timing-allow-fail", "--textcfg", "tier4/build/soc.config"]
    log = run(cmd, "nextpnr.log")
    fm = re.findall(r"Max frequency for clock\s+'([^']+)':\s+([\d.]+) MHz \((PASS|FAIL) at ([\d.]+) MHz\)", log)
    util = re.findall(r"^Info:\s+(TRELLIS_COMB|TRELLIS_FF|DP16KD|TRELLIS_IO|MULT18X18D|TRELLIS_RAMW):\s+(\d+)/\s*(\d+)\s+(\d+)%", log, re.M)
    for name, used, total, pct in util: print(f"  {name:<14}{used:>6} / {total:<6} ({pct}%)")
    last = fm[-1] if fm else None
    if last:
        print(f"target {a.freq:g} MHz -> achieved Fmax {last[1]} MHz: {last[2]}")
    crit = re.findall(r"Critical path report for clock '[^']+' \(posedge -> posedge\):(.*?)(?=\nInfo: Max delay|\Z)", log, re.S)
    if crit:
        lines = [l for l in crit[-1].splitlines() if "Source" in l or "Sink" in l or "Net " in l]
        (B / "critical_path.txt").write_text("\n".join(crit[-1].splitlines()[:60]))
    if not a.no_bitstream:
        run(ecppack + ["--compress", "tier4/build/soc.config", "--bit", "tier4/build/soc.bit"], "ecppack.log")
        print(f"bitstream: tier4/build/soc.bit ({(B / 'soc.bit').stat().st_size} bytes)")


if __name__ == "__main__":
    main()
