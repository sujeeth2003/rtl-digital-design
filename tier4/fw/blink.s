# Firmware for the FPGA SoC: a binary counter on the 8 LEDs, one step every ~0.25 s at 25 MHz.
# LED register is memory mapped at 0x1000. Runs forever (no EBREAK): pressing reset restarts it.
        lui  s0, 1              # s0 = 0x1000, the LED register
        li   s1, 0              # counter
loop:   addi s1, s1, 1
        sw   s1, 0(s0)          # show it
        lui  t0, 0x1E8          # t0 = 0x1E8000 = 2,000,896 iterations of the delay loop
delay:  addi t0, t0, -1
        bnez t0, delay
        j    loop
