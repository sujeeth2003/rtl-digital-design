// AXI4-Lite slave: a small register bank.
//   reg 0..NREGS-2 : read/write, byte-strobe aware
//   reg NREGS-1    : read-only "write counter" (counts accepted writes); writing it returns SLVERR
//   address outside the bank returns SLVERR
// Handshake rules implemented (AMBA AXI4-Lite):
//   * VALID is never dependent on READY; once raised it holds until the handshake
//   * payload (BRESP/RDATA/RRESP) is stable while VALID && !READY
//   * write:  slave waits for BOTH awvalid and wvalid, then handshakes them together
//   * read:   arready when no read response is pending
