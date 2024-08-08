# Bubble sort of 16 words (pseudo-random input from an LCG), then a checksum and sortedness check.
        li   s0, 0x100
        li   t0, 12345
        li   s2, 12345
        li   t1, 16
        li   t2, 0
gen:    li   t3, 13
        li   t4, 0
mm:     add  t4, t4, t0       # t4 = t0 * 13 by repeated addition (base ISA has no multiply)
        addi t3, t3, -1
        bnez t3, mm
        add  t0, t4, s2
        andi t5, t0, 0x3FF
        slli t6, t2, 2
        add  t6, t6, s0
        sw   t5, 0(t6)
        addi t2, t2, 1
        blt  t2, t1, gen
        li   s1, 15           # last index for the inner pass
pass:   li   t2, 0
inn:    slli t3, t2, 2
        add  t3, t3, s0
        lw   t4, 0(t3)
        lw   t5, 4(t3)
        ble  t4, t5, noswap
        sw   t5, 0(t3)
        sw   t4, 4(t3)
noswap: addi t2, t2, 1
        blt  t2, s1, inn
        addi s1, s1, -1
        bnez s1, pass
        li   a0, 0
        li   a1, 0
        li   t2, 0
chk:    slli t3, t2, 2
        add  t3, t3, s0
        lw   t4, 0(t3)
        add  a0, a0, t4
        bgt  a1, t4, bad
        mv   a1, t4
        addi t2, t2, 1
        blt  t2, t1, chk
        li   a2, 1            # sorted OK
        ebreak
bad:    li   a2, 0
        ebreak
