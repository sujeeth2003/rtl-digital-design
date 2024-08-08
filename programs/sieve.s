# Sieve of Eratosthenes up to 100 using byte flags at 0x200; a0 = number of primes (25).
        li   s0, 0x200
        li   t0, 2
        li   t6, 101
        li   t1, 1
init:   add  t2, s0, t0
        sb   t1, 0(t2)
        addi t0, t0, 1
        blt  t0, t6, init
        li   t0, 2
outer:  add  t2, s0, t0
        lbu  t3, 0(t2)
        beqz t3, next         # composite: skip (load-use into branch)
        add  t4, t0, t0       # first multiple
mark:   bge  t4, t6, next
        add  t2, s0, t4
        sb   x0, 0(t2)
        add  t4, t4, t0
        j    mark
next:   addi t0, t0, 1
        li   t5, 11
        blt  t0, t5, outer
        li   a0, 0
        li   t0, 2
cnt:    add  t2, s0, t0
        lbu  t3, 0(t2)
        add  a0, a0, t3
        addi t0, t0, 1
        blt  t0, t6, cnt
        ebreak
