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


def main():
    words, _ = riscv_asm.assemble((ROOT / "tier4/fw/blink_sim.s").read_text())
    (ROOT / "tier4/build").mkdir(parents=True, exist_ok=True)
    (ROOT / "tier4/build/blink.hex").write_text("\n".join(f"{w:08x}" for w in words) + "\n")     # needed by $readmemh at read time
    files = ["rtl/alu/alu.sv"] + [f"rtl/riscv/{f}.sv" for f in ("riscv_core", "regfile", "decode", "hazard_unit", "riscv_top")] + ["tier4/fpga/fpga_top.sv"]
    nl = Netlist(build_json(files, "fpga_top"))
    # no explicit load: the instruction RAM powers up with the firmware ($readmemh -> memory INIT), as on the FPGA

    nl.set("btn_rst_n", 0)
    for _ in range(3): nl.cycle("clk_25mhz")
    nl.set("btn_rst_n", 1)
    seen, cyc = [], 0
    for cyc in range(4000):
        nl.cycle("clk_25mhz")
        v = nl.get("led")
        if not seen or v != seen[-1]: seen.append(v)
        if v == 0xFF and cyc > 20: break
    print(f"LED values over time: {seen}   ({cyc} cycles)")
    ok = seen[:9] == [0, 1, 2, 3, 4, 5, 6, 7, 8][:len(seen[:9])] and seen[-1] == 0xFF and seen[1:9] == list(range(1, 9))
    print("SoC firmware check:", "PASS" if ok else "FAIL")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
