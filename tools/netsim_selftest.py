#!/usr/bin/env python3
"""Validate the pure-Python netlist simulator against independent models, on blocks that are
also checked with CXXRTL and formal proofs: the ALU (random ops vs a Python reference) and the
synchronous FIFO (random traffic vs collections.deque)."""
import random
import sys
from collections import deque
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from netsim import Netlist, build_json  # noqa: E402

M = 0xFFFFFFFF

