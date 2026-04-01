# Same firmware with a tiny delay so a simulation can watch the LED register count within a few hundred cycles.
        lui  s0, 1
        li   s1, 0
loop:   addi s1, s1, 1
        sw   s1, 0(s0)
        lw   t2, 0(s0)          # read the register back (exercises the MMIO read path)
        li   t0, 3
delay:  addi t0, t0, -1
        bnez t0, delay
        li   t1, 8
        blt  s1, t1, loop
        ebreak                  # after 8 steps: halt (the LEDs then show 0xFF)
