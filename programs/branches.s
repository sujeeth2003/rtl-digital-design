# Every branch type, taken and not taken, loops, and branches right after loads (flush + stall interaction).
        li   s0, 0x100
        li   a0, 0            # counts taken branches
        li   t0, 5
        li   t1, -3
        li   t2, 5
        beq  t0, t2, b1       # taken
        addi a0, a0, 100      # must be flushed
b1:     addi a0, a0, 1
        bne  t0, t2, bad      # not taken
        addi a0, a0, 1
        blt  t1, t0, b2       # signed: -3 < 5 taken
        addi a0, a0, 100
b2:     addi a0, a0, 1
        bltu t0, t1, b3       # unsigned: 5 < 0xFFFFFFFD taken
        addi a0, a0, 100
b3:     addi a0, a0, 1
        bge  t0, t1, b4       # 5 >= -3 taken
        addi a0, a0, 100
b4:     addi a0, a0, 1
        bgeu t1, t0, b5       # 0xFFFFFFFD >= 5 taken
        addi a0, a0, 100
b5:     addi a0, a0, 1
        bge  t1, t0, bad      # not taken
        # loop with a load in the branch condition path
        sw   t0, 0(s0)
        li   a1, 0
        li   a2, 10
loop:   lw   a3, 0(s0)
        addi a1, a1, 1
        beq  a1, a2, done     # loop 10 times
        bne  a3, x0, loop     # branch depends on a load
        j    bad
done:   add  a4, a1, a0
        # nested loops
        li   s1, 0
        li   t3, 1
outer:  li   t4, 1
inner:  add  t5, t3, x0
        slli t5, t5, 1
        add  s1, s1, t5
        addi t4, t4, 1
        li   t6, 6
        blt  t4, t6, inner
        addi t3, t3, 1
        li   t6, 6
        blt  t3, t6, outer
        ebreak
bad:    li   a5, -1
        ebreak
